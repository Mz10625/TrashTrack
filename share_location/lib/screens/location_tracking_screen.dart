
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:vehicle_tracker/services/location_service.dart';
import 'package:vehicle_tracker/services/firestore_service.dart';
import 'package:vehicle_tracker/widgets/countdown_timer.dart';

class LocationTrackingScreen extends StatefulWidget {
  final String vehicleNumber;

  const LocationTrackingScreen({
    Key? key,
    required this.vehicleNumber,
  }) : super(key: key);

  @override
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isTrackingActive = false;
  Position? _currentPosition;
  String _address = 'Enable location sharing to fetch address.';
  Timer? _locationUpdateTimer;
  DateTime? _trackingStartTime;
  final int _trackingDurationHours = 3;
  bool _isLoading = true;
  Map<String, dynamic>? _vehicleData;
  String _wardNumber = '';

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await _loadVehicleData();
    await _initLocationService();
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadVehicleData() async {
    try {
      Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
      setState(() {
        _vehicleData = data;
        if (data != null) {
          _isTrackingActive = data['status'] == 'Active';
          if (data['ward_no'] != null) {
            _wardNumber = data['ward_no'].toString();
          }

          if (_isTrackingActive) {
            _trackingStartTime = DateTime.now();
            _startLocationUpdateTimer();
          }
        }
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading vehicle data: $e')),
      );
    }
  }

  @override
  void dispose() {
    _stopLocationTracking();
    super.dispose();
  }

  Future<bool> _isLocationServiceEnabld() async {
    bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
    LocationPermission permission = await _locationService.checkLocationPermission();
    if(!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
      return false;
    }
    return true;
  }

  Future<void> _initLocationService() async {
    bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
    if (!serviceEnabled) {
      _showLocationServicesDialog();
      return;
    }

    LocationPermission permission = await _locationService.checkLocationPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestLocationPermission();
      if (permission == LocationPermission.denied) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permissions are denied'),
          ),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location permissions are permanently denied, cannot request permissions.'),
        ),
      );
      return;
    }

    _updateCurrentLocation();
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to use this app.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateCurrentLocation() async {
    try {
      var locationServiceEnabld = await _isLocationServiceEnabld();
      if(!locationServiceEnabld){
        _initLocationService();
        return;
      }
      Position position = await _locationService.getCurrentPosition();
      String address = await _locationService.getAddressFromPosition(position);

      setState(() {
        _currentPosition = position;
        _address = address;
      });

      if (_isTrackingActive && _currentPosition != null) {
        _refreshVehicleData();
        await _firestoreService.updateVehicleLocation(widget.vehicleNumber, _currentPosition!);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error updating location: $e')),
        );
      }
    }
  }

  void _startLocationTracking() async {
    var locationServiceEnabld = await _isLocationServiceEnabld();
    if(!locationServiceEnabld){
      _initLocationService();
      return;
    }

    await _firestoreService.updateVehicleStatus(widget.vehicleNumber, true);

    setState(() {
      _isTrackingActive = true;
      _trackingStartTime = DateTime.now();
    });

    await _updateCurrentLocation();
    _startLocationUpdateTimer();
  }

  void _startLocationUpdateTimer() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      var locationServiceEnabld = await _isLocationServiceEnabld();
      if(!locationServiceEnabld){
        _stopLocationTracking();
        return;
      }
      await _updateCurrentLocation();
      if (_trackingStartTime != null &&
          DateTime.now().difference(_trackingStartTime!).inHours >= _trackingDurationHours) {
        _stopLocationTracking();
        _showTrackingTimeoutDialog();
      }
    });
  }

  Future<void> _refreshVehicleData() async {
    try {
      Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
      if (mounted) {
        setState(() {
          _vehicleData = data;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing vehicle data: $e')),
        );
      }
    }
  }

  void _stopLocationTracking() async {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = null;

    if (_isTrackingActive) {
      await _firestoreService.updateVehicleStatus(widget.vehicleNumber, false);
    }

    setState(() {
      _isTrackingActive = false;
      _trackingStartTime = null;
    });
  }

  void _showTrackingTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tracking Timeout'),
        content: const Text('Location tracking has been automatically stopped after 3 hours.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatCoordinates() {
    if (_currentPosition == null) return 'Enable location sharing to determine location.';
    return 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}° N, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}° E';
  }

  String _getVehicleLocationFromFirestore() {
    if (_vehicleData == null || _vehicleData!['current_location'] == null) {
      return 'No location data';
    }

    GeoPoint location = _vehicleData!['current_location'];
    return 'Lat: ${location.latitude.toStringAsFixed(6)}° N, Lng: ${location.longitude.toStringAsFixed(6)}° E';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: Text('Vehicle #${widget.vehicleNumber}'),
          centerTitle: true,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Vehicle #${widget.vehicleNumber}'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            onPressed: () async {
              _updateCurrentLocation();
              // ScaffoldMessenger.of(context).showSnackBar(
              //   const SnackBar(content: Text('Updating location...')),
              // );
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.local_taxi, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'Vehicle Status',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text('Status: '),
                        Chip(
                          label: Text(_isTrackingActive ? 'Active' : 'Inactive'),
                          backgroundColor: _isTrackingActive
                              ? Colors.green.withOpacity(0.2)
                              : Colors.red.withOpacity(0.2),
                          side: BorderSide(
                            color: _isTrackingActive ? Colors.green : Colors.red,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Text('Ward Number: '),
                        Text(
                          _wardNumber,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    if (_trackingStartTime != null && _isTrackingActive) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Started: '),
                          Text(
                            DateFormat('MMM d, yyyy HH:mm:ss').format(_trackingStartTime!),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Text('Auto-stop in: '),
                          CountdownTimer(
                            startTime: _trackingStartTime!,
                            durationHours: _trackingDurationHours,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.location_on, size: 24),
                            const SizedBox(width: 8),
                            Text(
                              'Current Location',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ],
                        ),
                        if (_isTrackingActive)
                          const Chip(
                            label: Text('LIVE'),
                            backgroundColor: Colors.green,
                            labelStyle: TextStyle(color: Colors.white),
                          ),
                      ],
                    ),
                    const Divider(),
                    Text(
                      'Device Coordinates:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(_formatCoordinates()),
                    const SizedBox(height: 8),
                    Text(
                      'Address:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(_address),
                    const SizedBox(height: 16),
                    Text(
                      'Database Vehicle Location:',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(_getVehicleLocationFromFirestore()),
                  ],
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isTrackingActive ? _stopLocationTracking : _startLocationTracking,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: _isTrackingActive ? Colors.red : Colors.green,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isTrackingActive ? Icons.location_off : Icons.location_on,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isTrackingActive ? 'Stop Sharing Location' : 'Start Sharing Location',
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
