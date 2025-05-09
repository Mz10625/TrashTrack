import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trash_track/screens/mapView.dart';
import 'package:trash_track/services/location_service.dart';
import 'package:trash_track/services/firestore_service.dart';
import 'package:trash_track/widgets/countdown_timer.dart';
import 'package:background_location/background_location.dart';

class LocationTrackingScreen extends StatefulWidget {
  final String vehicleNumber;

  const LocationTrackingScreen({
    super.key,
    required this.vehicleNumber,
  });

  @override
  State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
}

class _LocationTrackingScreenState extends State<LocationTrackingScreen> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  final FirestoreService _firestoreService = FirestoreService();
  bool _isTrackingActive = false;
  Position? _currentPosition;
  String _address = 'Enable location sharing to fetch address.';
  Timer? _locationUpdateTimer;
  DateTime? _trackingStartTime;
  final int _trackingDurationHours = 2;
  bool _isLoading = true;
  Map<String, dynamic>? _vehicleData;
  String _wardNumber = '';
  bool _isInBackgroundMode = false;
  StreamSubscription<dynamic>? _backgroundLocationSubscription;
  final bool _isDisposed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    try {
      await _loadVehicleData();
      await _initLocationService();

      final prefs = await SharedPreferences.getInstance();
      final isInBackgroundMode = prefs.getBool('isInBackgroundMode') ?? false;
      final trackingStartTimeStr = prefs.getString('trackingStartTime');
      final isTrackingActive = prefs.getBool('isTrackingActive') ?? false;
      final storedVehicleNumber = prefs.getString('vehicleNumber');

      final shouldRestoreTracking = isTrackingActive && storedVehicleNumber == widget.vehicleNumber && trackingStartTimeStr != null;

      if (shouldRestoreTracking) {
        if (!_isDisposed) {
          setState(() {
            _isTrackingActive = true;
            _isInBackgroundMode = isInBackgroundMode;
            _trackingStartTime = DateTime.parse(trackingStartTimeStr);
          });
        }

        if (_trackingStartTime != null && DateTime.now().difference(_trackingStartTime!).inHours >= _trackingDurationHours) {
          _stopLocationTracking();
          if (!_isDisposed && mounted) {
            _showTrackingTimeoutDialog();
          }
        }
        else {
          if (isInBackgroundMode) {
            _startBackgroundLocationTracking();
          } else {
            _startLocationUpdateTimer();
          }
        }
      }
    }
    catch (e) {
      debugPrint('Error initializing screen: $e');
    }
    finally {
      if (!_isDisposed && mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadTrackingStartTime() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final trackingStartTimeStr = prefs.getString('trackingStartTime');
      if (trackingStartTimeStr != null && !_isDisposed && mounted) {
        setState(() {
          _trackingStartTime = DateTime.parse(trackingStartTimeStr);
        });
      }
    }
    catch (e) {
      debugPrint('Error loading tracking start time: $e');
    }
  }

  Future<void> _loadVehicleData() async {
    try {
      Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
      if (!_isDisposed && mounted) {
        setState(() {
          _vehicleData = data;
          if (data != null) {
            _isTrackingActive = data['status'] == 'Active';
            if (data['ward_no'] != null) {
              _wardNumber = data['ward_no'].toString();
            }

            if (_isTrackingActive) {
              _loadTrackingStartTime();
            }
          }
        });
      }
    }
    catch (e) {
      debugPrint('Error loading vehicle data: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error loading vehicle data')),
        );
      }
    }
  }

  Future<bool> _isLocationServiceEnabled() async {
    try {
      bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
      LocationPermission permission = await _locationService.checkLocationPermission();
      if(!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
        return false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking location service: $e');
      return false;
    }
  }

  Future<void> _initLocationService() async {
    try {
      bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
      if (!serviceEnabled) {
        if (!_isDisposed && mounted) {
          _showLocationServicesDialog();
        }
        return;
      }

      LocationPermission permission = await _locationService.checkLocationPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestLocationPermission();
        if (permission == LocationPermission.denied) {
          if (!_isDisposed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location permissions are denied'),
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (!_isDisposed && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are permanently denied, cannot request permissions.'),
            ),
          );
        }
        return;
      }

      if (permission != LocationPermission.always) {
        bool backgroundGranted = await _locationService.requestBackgroundLocationPermission();
        if (!backgroundGranted) {
          if (!_isDisposed && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Background location permission is required for tracking when app is minimized.'),
              ),
            );
          }
        }
      }

      try {
        await BackgroundLocation.setAndroidNotification(
          title: "Location updates enabled in background",
          message: "Location updates are enabled in the background.",
          icon: "@mipmap/launcher_icon",
        );

        await BackgroundLocation.setAndroidConfiguration(5000); // Update interval in milliseconds
      }
      catch (e) {
        debugPrint('Error setting up background location: $e');
      }
      await _updateCurrentLocation();
    }
    catch (e) {
      debugPrint('Error initializing location service: $e');
    }
  }

  void _showLocationServicesDialog() {
    if (!mounted) return;

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
    if (_isDisposed) return;

    try {
      var locationServiceEnabled = await _isLocationServiceEnabled();
      if(!locationServiceEnabled){
        await _initLocationService();
        return;
      }

      Position position = await _locationService.getCurrentPosition();
      String address = await _locationService.getAddressFromPosition(position);

      if (!_isDisposed && mounted) {
        setState(() {
          _currentPosition = position;
          _address = address;
        });
      }

      if (_isTrackingActive && _currentPosition != null && !_isInBackgroundMode) {
        await _refreshVehicleData();
        await _firestoreService.updateVehicleLocation(widget.vehicleNumber, _currentPosition!);
        debugPrint('Location updated in foreground mode');
      }
    } catch (e) {
      debugPrint('Error updating location: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error updating location')),
        );
      }
    }
  }

  void _startLocationTracking() async {
    if (_isDisposed) return;

    try {
      var locationServiceEnabled = await _isLocationServiceEnabled();
      if(!locationServiceEnabled){
        await _initLocationService();
        return;
      }

      await _firestoreService.updateVehicleStatus(widget.vehicleNumber, true);

      if (!_isDisposed && mounted) {
        setState(() {
          _isTrackingActive = true;
          _trackingStartTime = DateTime.now();
        });
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('vehicleNumber', widget.vehicleNumber);
      await prefs.setString('trackingStartTime', _trackingStartTime!.toIso8601String());
      await prefs.setInt('trackingDurationHours', _trackingDurationHours);
      await prefs.setBool('isTrackingActive', true);
      await prefs.setBool('isInBackgroundMode', false);

      await _updateCurrentLocation();

      _isInBackgroundMode = false;
      _startLocationUpdateTimer();
    } catch (e) {
      debugPrint('Error starting location tracking: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error starting location tracking')),
        );
      }
    }
  }

  void _startLocationUpdateTimer() {
    _locationUpdateTimer?.cancel();
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_isDisposed) {
        timer.cancel();
        return;
      }

      if (mounted) {
        try {
          var locationServiceEnabled = await _isLocationServiceEnabled();
          if(!locationServiceEnabled){
            _stopLocationTracking();
            return;
          }

          await _updateCurrentLocation();

          if (_trackingStartTime != null &&
              DateTime.now().difference(_trackingStartTime!).inHours >= _trackingDurationHours) {
            _stopLocationTracking();
            _showTrackingTimeoutDialog();
          }
        } catch (e) {
          debugPrint('Error in location update timer: $e');
        }
      }
    });
  }

  void _startBackgroundLocationTracking() async {
    if (_isDisposed) return;

    try {
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      try {
        await BackgroundLocation.stopLocationService();
      } catch (e) {
        debugPrint('Error stopping existing background location: $e');
      }

      try {
        await BackgroundLocation.setAndroidNotification(
          title: "TrashTrack Active",
          message: "Location tracking is running in background",
          icon: "@mipmap/launcher_icon",
        );
        await BackgroundLocation.startLocationService(distanceFilter: 30);
      } catch (e) {
        debugPrint('Error starting background location: $e');
        if (!_isDisposed && mounted) {
          setState(() {
            _isInBackgroundMode = false;
          });
          _startLocationUpdateTimer();
          return;
        }
      }

      _backgroundLocationSubscription = BackgroundLocation.getLocationUpdates((location) async {
        try {
          debugPrint('Background location update: ${location.latitude}, ${location.longitude}');

          final prefs = await SharedPreferences.getInstance();
          final trackingStartTimeStr = prefs.getString('trackingStartTime');

          if (trackingStartTimeStr != null) {
            final startTime = DateTime.parse(trackingStartTimeStr);
            if (DateTime.now().difference(startTime).inHours >= _trackingDurationHours) {
              _stopLocationTracking();
              return;
            }
          }

          if (location.latitude == null || location.longitude == null) {
            debugPrint('Invalid location data received');
            return;
          }

          try {
            final vehiclesCollection = FirebaseFirestore.instance.collection('vehicles');
            int vehicleNum = int.tryParse(widget.vehicleNumber) ?? 0;
            var query = await vehiclesCollection
                .where('vehicle_no', isEqualTo: vehicleNum)
                .limit(1)
                .get();

            if (query.docs.isNotEmpty) {
              String docId = query.docs.first.id;
              GeoPoint geoPoint = GeoPoint(location.latitude!, location.longitude!);

              await vehiclesCollection.doc(docId).update({
                'current_location': geoPoint,
                'last_updated': FieldValue.serverTimestamp(),
              });
              debugPrint('Background location updated in Firestore');
            }
          } catch (e) {
            debugPrint('Error updating Firestore in background: $e');
          }
        } catch (e) {
          debugPrint('Error processing background location update: $e');
        }
      });
    } catch (e) {
      debugPrint('Error in startBackgroundLocationTracking: $e');
      if (!_isDisposed && mounted) {
        setState(() {
          _isInBackgroundMode = false;
        });
        _startLocationUpdateTimer();
      }
    }
  }

  Future<void> _refreshVehicleData() async {
    if (_isDisposed) return;

    try {
      Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
      if (!_isDisposed && mounted) {
        setState(() {
          _vehicleData = data;
        });
      }
    } catch (e) {
      debugPrint('Error refreshing vehicle data: $e');
      if (!_isDisposed && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing vehicle data: $e')),
        );
      }
    }
  }

  Future<void> _stopLocationTracking() async {
    if (_isDisposed) return;

    try {
      _locationUpdateTimer?.cancel();
      _locationUpdateTimer = null;

      try {
        await BackgroundLocation.stopLocationService();
      }
      catch (e) {
        debugPrint('Error stopping background location: $e');
      }

      _backgroundLocationSubscription?.cancel();
      _backgroundLocationSubscription = null;

      if (_isTrackingActive) {
        try {
          await _firestoreService.updateVehicleStatus(widget.vehicleNumber, false);
        }
        catch (e) {
          debugPrint('Error updating vehicle status: $e');
        }
      }

      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('trackingStartTime');
        await prefs.remove('vehicleNumber');
        await prefs.setBool('isTrackingActive', false);
        await prefs.setBool('isInBackgroundMode', false);
      }
      catch (e) {
        debugPrint('Error clearing SharedPreferences: $e');
      }

      if (!_isDisposed && mounted) {
        setState(() {
          _isTrackingActive = false;
          _trackingStartTime = null;
          _isInBackgroundMode = false;
        });
      }
    }
    catch (e) {
      debugPrint('Error stopping location tracking: $e');
    }
  }

  void _showTrackingTimeoutDialog() {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tracking Timeout'),
        content: const Text('Location tracking has been automatically stopped after 2 hours.'),
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

  void _switchToBackgroundMode() async {
    if (_isDisposed) return;

    try {
      if (_isTrackingActive && !_isInBackgroundMode) {
        _locationUpdateTimer?.cancel();
        _locationUpdateTimer = null;

        if (!_isDisposed && mounted) {
          setState(() {
            _isInBackgroundMode = true;
          });
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isInBackgroundMode', true);

        _startBackgroundLocationTracking();
      }
    } catch (e) {
      debugPrint('Error switching to background mode: $e');
    }
  }

  void _switchToForegroundMode() async {
    if (_isDisposed) return;

    try {
      if (_isTrackingActive && _isInBackgroundMode) {
        try {
          await BackgroundLocation.stopLocationService();
        }
        catch (e) {
          debugPrint('Error stopping background location: $e');
        }

        _backgroundLocationSubscription?.cancel();
        _backgroundLocationSubscription = null;

        if (!_isDisposed && mounted) {
          setState(() {
            _isInBackgroundMode = false;
          });
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isInBackgroundMode', false);

        _startLocationUpdateTimer();
      }
    } catch (e) {
      debugPrint('Error switching to foreground mode: $e');
    }
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

  void _openMapView() {
    if (_currentPosition != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MapViewScreen(vehicleNumber: widget.vehicleNumber),
        ),
      );
    }
    else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to open map. Location data not available.')),
      );
    }
  }

  Future<void> _performCleanup() async {
    try {
      _locationUpdateTimer?.cancel();
      await _stopLocationTracking();
    }
    catch (e) {
      debugPrint('Error in cleanup: $e');
    }
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
            },
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      // Add the drawer
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TrashTrack',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Vehicle #${widget.vehicleNumber}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Chip(
                    label: Text(_isTrackingActive ? 'Active' : 'Inactive'),
                    backgroundColor: _isTrackingActive
                        ? Colors.green.withOpacity(0.7)
                        : Colors.red.withOpacity(0.7),
                    labelStyle: TextStyle(
                      color: Theme.of(context).colorScheme.onPrimary,
                    ),
                  ),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.home),
              title: const Text('Home'),
              onTap: () {
                Navigator.of(context).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.map),
              title: const Text('Map View'),
              onTap: _openMapView,
              enabled: _isTrackingActive,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.info),
              title: const Text('About'),
              onTap: () {
                Navigator.of(context).pop();
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('About TrashTrack'),
                    content: const Text(
                      'This application allows you to share your vehicle\'s location in real-time. '
                          'Enable location sharing to start sharing your location.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('OK'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
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
                      crossAxisAlignment: CrossAxisAlignment.center,
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
                        if (_isTrackingActive) ...[
                          const SizedBox(width: 8),
                          Text(_isInBackgroundMode ? "(Background mode)" : "(Foreground mode)",
                            style: const TextStyle(
                              fontStyle: FontStyle.italic,
                              fontSize: 12,
                              color: Colors.green,
                            ),
                          ),
                        ],
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
                    if (_isTrackingActive && _currentPosition != null) ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.map),
                          label: const Text('Open Map View'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          onPressed: _openMapView,
                        ),
                      ),
                    ],
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.detached) {
      _performCleanup();
    }
    if (_isTrackingActive) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _switchToBackgroundMode();
      }
      else if (state == AppLifecycleState.resumed) {
        _switchToForegroundMode();
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    _backgroundLocationSubscription?.cancel();
    _stopLocationTracking();
    super.dispose();
  }
}