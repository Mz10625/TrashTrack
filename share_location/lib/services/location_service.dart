import 'package:geolocator/geolocator.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class LocationService {
  static final LocationService _instance = LocationService._internal();
  factory LocationService() => _instance;
  LocationService._internal();

  Future<bool> checkLocationServicesEnabled() async {
    try {
      return await Geolocator.isLocationServiceEnabled();
    }
    catch (e) {
      print('Error checking location services: $e');
      return false;
    }
  }

  Future<LocationPermission> checkLocationPermission() async {
    try {
      return await Geolocator.checkPermission();
    } catch (e) {
      print('Error checking location permission: $e');
      return LocationPermission.denied;
    }
  }

  Future<LocationPermission> requestLocationPermission() async {
    try {
      return await Geolocator.requestPermission();
    } catch (e) {
      print('Error requesting location permission: $e');
      return LocationPermission.denied;
    }
  }

  Future<bool> requestBackgroundLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.whileInUse) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always;
    }
    catch (e) {
      print('Error requesting background location: $e');
      return false;
    }
  }

  Future<Position> getCurrentPosition() async {
    try {
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10), // timeout to prevent hanging
      );
    }
    catch (e) {
      print('Error getting current position: $e');
      throw Exception('Failed to get location: $e');
    }
  }

  Future<String> getAddressFromPosition(Position position) async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse?format=json&lat=${position.latitude}&lon=${position.longitude}&zoom=18&addressdetails=1',
        ),
        headers: {'User-Agent': 'VehicleTrackerApp'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['display_name'] ?? 'Unknown location';
      }
      else {
        return 'Could not determine address';
      }
    }
    catch (e) {
      return 'Error getting address: $e';
    }
  }
}