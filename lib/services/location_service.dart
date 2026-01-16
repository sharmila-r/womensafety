import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  static Future<bool> checkPermission() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  static Future<Position?> getCurrentLocation() async {
    try {
      bool hasPermission = await checkPermission();
      if (!hasPermission) return null;

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<String> getAddressFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}';
      }
    } catch (e) {
      // Handle error
    }
    return 'Location: $latitude, $longitude';
  }

  /// Get country code from coordinates using reverse geocoding
  static Future<String?> getCountryCodeFromCoordinates(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        return placemarks[0].isoCountryCode?.toUpperCase();
      }
    } catch (e) {
      print('Error getting country code: $e');
    }
    return null;
  }

  /// Get full location details including country
  static Future<LocationDetails?> getLocationDetails(
      double latitude, double longitude) async {
    try {
      List<Placemark> placemarks =
          await placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks[0];
        return LocationDetails(
          latitude: latitude,
          longitude: longitude,
          address: '${place.street}, ${place.locality}, ${place.administrativeArea} ${place.postalCode}',
          city: place.locality ?? '',
          state: place.administrativeArea ?? '',
          countryCode: place.isoCountryCode?.toUpperCase() ?? '',
          country: place.country ?? '',
        );
      }
    } catch (e) {
      print('Error getting location details: $e');
    }
    return null;
  }

  static String getGoogleMapsUrl(double latitude, double longitude) {
    return 'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';
  }

  static Stream<Position> getLocationStream() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    );
  }

  static double calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) {
    return Geolocator.distanceBetween(
      startLatitude,
      startLongitude,
      endLatitude,
      endLongitude,
    );
  }
}

/// Location details with country information
class LocationDetails {
  final double latitude;
  final double longitude;
  final String address;
  final String city;
  final String state;
  final String countryCode;
  final String country;

  LocationDetails({
    required this.latitude,
    required this.longitude,
    required this.address,
    required this.city,
    required this.state,
    required this.countryCode,
    required this.country,
  });
}
