/**
 * Firebase Cloud Functions for Kaavala App
 * Handles push notification delivery for SOS alerts
 */

const functions = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();

const db = admin.firestore();
const messaging = admin.messaging();

/**
 * Process notification queue - triggered when new notification is added
 */
exports.processNotificationQueue = functions.firestore
    .document("notificationQueue/{notificationId}")
    .onCreate(async (snap, context) => {
      const notification = snap.data();
      const notificationId = context.params.notificationId;

      console.log(`Processing notification: ${notificationId}`);

      try {
        const {tokens, notification: notificationData, data, priority} = notification;

        if (!tokens || tokens.length === 0) {
          console.log("No tokens to send to");
          await snap.ref.update({status: "no_tokens", processedAt: admin.firestore.FieldValue.serverTimestamp()});
          return;
        }

        // Build the message
        const message = {
          notification: {
            title: notificationData.title,
            body: notificationData.body,
          },
          data: data || {},
          android: {
            priority: priority === "high" ? "high" : "normal",
            notification: {
              channelId: data?.type === "sos_alert" ? "sos_alerts" : "general",
              priority: priority === "high" ? "max" : "default",
              defaultSound: true,
              defaultVibrateTimings: true,
              visibility: "public",
            },
          },
          apns: {
            payload: {
              aps: {
                alert: {
                  title: notificationData.title,
                  body: notificationData.body,
                },
                sound: "default",
                badge: 1,
                "interruption-level": data?.type === "sos_alert" ? "critical" : "active",
              },
            },
          },
        };

        // Send to all tokens
        const response = await messaging.sendEachForMulticast({
          tokens: tokens,
          ...message,
        });

        console.log(`Successfully sent ${response.successCount}/${tokens.length} messages`);

        // Update notification status
        await snap.ref.update({
          status: "sent",
          successCount: response.successCount,
          failureCount: response.failureCount,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Handle failed tokens (remove invalid ones)
        if (response.failureCount > 0) {
          const failedTokens = [];
          response.responses.forEach((resp, idx) => {
            if (!resp.success) {
              failedTokens.push(tokens[idx]);
              console.log(`Failed to send to ${tokens[idx]}: ${resp.error?.message}`);
            }
          });

          // Remove invalid tokens from userTokens collection
          await removeInvalidTokens(failedTokens);
        }
      } catch (error) {
        console.error("Error processing notification:", error);
        await snap.ref.update({
          status: "error",
          error: error.message,
          processedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    });

/**
 * Send SOS alert notification - callable function
 */
exports.sendSOSAlert = functions.https.onCall(async (data, context) => {
  // Verify authentication
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }

  const {
    senderName,
    senderPhone,
    latitude,
    longitude,
    address,
    contactUserIds,
    message,
  } = data;

  if (!contactUserIds || contactUserIds.length === 0) {
    throw new functions.https.HttpsError("invalid-argument", "No contacts specified");
  }

  try {
    // Get FCM tokens for contacts
    const tokens = [];
    for (let i = 0; i < contactUserIds.length; i += 10) {
      const batch = contactUserIds.slice(i, i + 10);
      const snapshot = await db.collection("userTokens")
          .where("userId", "in", batch)
          .get();

      snapshot.forEach((doc) => {
        const token = doc.data().token;
        if (token) tokens.push(token);
      });
    }

    if (tokens.length === 0) {
      return {success: false, message: "No registered contacts found"};
    }

    // Create SOS alert record
    const alertRef = await db.collection("sosAlerts").add({
      senderId: context.auth.uid,
      senderName,
      senderPhone,
      latitude,
      longitude,
      address,
      message: message || null,
      contactIds: contactUserIds,
      status: "active",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Send notifications
    const notificationMessage = {
      notification: {
        title: `SOS ALERT from ${senderName}`,
        body: message || `${senderName} needs help! Location: ${address}`,
      },
      data: {
        type: "sos_alert",
        alertId: alertRef.id,
        senderId: context.auth.uid,
        senderName: senderName,
        senderPhone: senderPhone,
        latitude: String(latitude),
        longitude: String(longitude),
        address: address,
        mapsUrl: `https://www.google.com/maps/search/?api=1&query=${latitude},${longitude}`,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "sos_alerts",
          priority: "max",
          defaultSound: true,
          defaultVibrateTimings: true,
        },
      },
      apns: {
        payload: {
          aps: {
            alert: {
              title: `SOS ALERT from ${senderName}`,
              body: message || `${senderName} needs help!`,
            },
            sound: "default",
            badge: 1,
            "interruption-level": "critical",
          },
        },
      },
    };

    const response = await messaging.sendEachForMulticast({
      tokens: tokens,
      ...notificationMessage,
    });

    // Update alert with notification status
    await alertRef.update({
      notificationsSent: response.successCount,
      notificationsTotal: tokens.length,
      notificationsSentAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    return {
      success: true,
      alertId: alertRef.id,
      sentCount: response.successCount,
      totalContacts: tokens.length,
    };
  } catch (error) {
    console.error("Error sending SOS alert:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Send escort request notification to volunteers
 */
exports.sendEscortRequestNotification = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError("unauthenticated", "Must be logged in");
  }

  const {requestId, userName, eventName, address, volunteerIds} = data;

  try {
    const tokens = [];
    for (let i = 0; i < volunteerIds.length; i += 10) {
      const batch = volunteerIds.slice(i, i + 10);
      const snapshot = await db.collection("userTokens")
          .where("userId", "in", batch)
          .get();

      snapshot.forEach((doc) => {
        const token = doc.data().token;
        if (token) tokens.push(token);
      });
    }

    if (tokens.length === 0) {
      return {success: false, message: "No volunteers available"};
    }

    const response = await messaging.sendEachForMulticast({
      tokens: tokens,
      notification: {
        title: "New Escort Request",
        body: `${userName} needs an escort to ${eventName}`,
      },
      data: {
        type: "escort_request",
        requestId: requestId,
        userName: userName,
        eventName: eventName,
        address: address,
      },
      android: {
        priority: "high",
        notification: {
          channelId: "escort_requests",
        },
      },
    });

    return {
      success: true,
      sentCount: response.successCount,
      totalVolunteers: tokens.length,
    };
  } catch (error) {
    console.error("Error sending escort notification:", error);
    throw new functions.https.HttpsError("internal", error.message);
  }
});

/**
 * Webhook handler for BGV status updates
 */
exports.bgvWebhook = functions.https.onRequest(async (req, res) => {
  if (req.method !== "POST") {
    res.status(405).send("Method Not Allowed");
    return;
  }

  try {
    const payload = req.body;
    console.log("BGV Webhook received:", JSON.stringify(payload));

    // Determine provider from payload
    let volunteerId;
    let status;
    let provider;

    if (payload.profile_id) {
      // IDfy
      provider = "idfy";
      volunteerId = payload.profile_id.replace("bgv_", "");
      status = payload.status === "completed" && payload.result === "clear" ? "cleared" : "review_required";
    } else if (payload.verification_id) {
      // OnGrid
      provider = "ongrid";
      volunteerId = payload.verification_id.replace("ongrid_", "");
      status = payload.status === "completed" && payload.result?.overall === "clear" ? "cleared" : "review_required";
    } else if (payload.data?.object?.report_id) {
      // Checkr
      provider = "checkr";
      // Need to lookup volunteer by report ID
      const checkrReport = payload.data.object;
      status = checkrReport.status === "clear" ? "cleared" : "review_required";

      // Find volunteer by backgroundCheckId
      const volunteerSnapshot = await db.collection("volunteers")
          .where("backgroundCheckId", "==", checkrReport.report_id)
          .limit(1)
          .get();

      if (!volunteerSnapshot.empty) {
        volunteerId = volunteerSnapshot.docs[0].id;
      }
    }

    if (volunteerId) {
      // Update volunteer status
      await db.collection("volunteers").doc(volunteerId).update({
        backgroundCheckStatus: status,
        bgvCompletedAt: admin.firestore.FieldValue.serverTimestamp(),
        bgvProvider: provider,
        bgvResult: payload,
        verificationLevel: status === "cleared" ? "backgroundChecked" : "idVerified",
      });

      // Notify volunteer
      const volunteerDoc = await db.collection("volunteers").doc(volunteerId).get();
      const volunteer = volunteerDoc.data();

      if (volunteer?.userId) {
        const tokenDoc = await db.collection("userTokens").doc(volunteer.userId).get();
        const token = tokenDoc.data()?.token;

        if (token) {
          await messaging.send({
            token: token,
            notification: {
              title: "Background Check Update",
              body: status === "cleared" ?
                "Your background check is complete! You are now a verified volunteer." :
                "Your background check requires review. We will contact you shortly.",
            },
            data: {
              type: "bgv_update",
              status: status,
              volunteerId: volunteerId,
            },
          });
        }
      }
    }

    res.status(200).json({received: true});
  } catch (error) {
    console.error("BGV Webhook error:", error);
    res.status(500).json({error: error.message});
  }
});

/**
 * Remove invalid FCM tokens
 */
async function removeInvalidTokens(tokens) {
  if (!tokens || tokens.length === 0) return;

  const batch = db.batch();
  const snapshot = await db.collection("userTokens")
      .where("token", "in", tokens.slice(0, 10))
      .get();

  snapshot.forEach((doc) => {
    batch.delete(doc.ref);
  });

  await batch.commit();
  console.log(`Removed ${snapshot.size} invalid tokens`);
}

/**
 * Cleanup old notifications from queue (scheduled)
 */
exports.cleanupNotificationQueue = functions.pubsub
    .schedule("every 24 hours")
    .onRun(async (context) => {
      const cutoff = new Date();
      cutoff.setDate(cutoff.getDate() - 7); // Delete notifications older than 7 days

      const snapshot = await db.collection("notificationQueue")
          .where("createdAt", "<", cutoff)
          .limit(500)
          .get();

      const batch = db.batch();
      snapshot.forEach((doc) => {
        batch.delete(doc.ref);
      });

      await batch.commit();
      console.log(`Cleaned up ${snapshot.size} old notifications`);
    });
