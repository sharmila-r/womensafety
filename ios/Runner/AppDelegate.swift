import Flutter
import UIKit
import GoogleMaps
import FirebaseCore
import FirebaseAuth

@main
@objc class AppDelegate: FlutterAppDelegate {

  private var methodChannel: FlutterMethodChannel?
  private var apnsTokenReceived = false

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Firebase first
    FirebaseApp.configure()

    // Load Google Maps API key from Info.plist (set via Secrets.xcconfig)
    if let apiKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String, !apiKey.isEmpty {
      GMSServices.provideAPIKey(apiKey)
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    GeneratedPluginRegistrant.register(with: self)

    // Set up method channel to communicate APNs status to Flutter
    if let controller = window?.rootViewController as? FlutterViewController {
      methodChannel = FlutterMethodChannel(name: "com.forwardalpha.womenSafety/apns",
                                           binaryMessenger: controller.binaryMessenger)
      methodChannel?.setMethodCallHandler { [weak self] (call, result) in
        if call.method == "isAPNSReady" {
          result(self?.apnsTokenReceived ?? false)
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Explicitly pass APNs token to Firebase Auth (required for phone auth)
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("✅ APNs token received: \(deviceToken.map { String(format: "%02.2hhx", $0) }.joined())")
    apnsTokenReceived = true

    // Pass device token to Firebase Auth
    // Determine token type based on provisioning profile
    let tokenType: AuthAPNSTokenType
    #if targetEnvironment(simulator)
    tokenType = .sandbox
    #else
    // Check if using sandbox (development) or production APNs
    if let provisionPath = Bundle.main.path(forResource: "embedded", ofType: "mobileprovision"),
       let provisionData = try? Data(contentsOf: URL(fileURLWithPath: provisionPath)),
       let provisionString = String(data: provisionData, encoding: .ascii),
       provisionString.contains("<key>aps-environment</key>") {
      // If contains "development", use sandbox
      tokenType = provisionString.contains("development") ? .sandbox : .prod
    } else {
      // Default to sandbox for debug builds
      tokenType = .sandbox
    }
    #endif
    Auth.auth().setAPNSToken(deviceToken, type: tokenType)
    print("✅ Set APNs token type: \(tokenType == .sandbox ? "sandbox" : "prod")")

    // Also call super to let other plugins handle it
    super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
  }

  // Handle APNs registration failure
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("❌ Failed to register for remote notifications: \(error.localizedDescription)")
    super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
  }

  // Handle incoming remote notifications for Firebase Auth verification
  override func application(_ application: UIApplication,
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
    // Let Firebase Auth handle the notification
    if Auth.auth().canHandleNotification(userInfo) {
      completionHandler(.noData)
      return
    }

    // Pass to super for other handlers
    super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
  }
}
