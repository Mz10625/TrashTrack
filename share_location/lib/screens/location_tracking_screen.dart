import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vehicle_tracker/services/location_service.dart';
import 'package:vehicle_tracker/services/firestore_service.dart';
import 'package:vehicle_tracker/widgets/countdown_timer.dart';
import 'package:firebase_core/firebase_core.dart';

import '../firebase_options.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true,
      foregroundServiceNotificationId: 888,
      initialNotificationTitle: 'Location Tracking',
      initialNotificationContent: 'Location tracking enabled in background',
    ),
    iosConfiguration: IosConfiguration(
      autoStart: false,
      onForeground: (_) async => true,
      onBackground: (_) async => true,
    ),
  );
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  StreamSubscription<Position>? positionStreamSubscription;

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final CollectionReference vehiclesCollection = FirebaseFirestore.instance.collection('vehicles');
  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();

    service.on('stopService').listen((event) {
      positionStreamSubscription?.cancel();
      service.stopSelf();
    });
  }

  final prefs = await SharedPreferences.getInstance();
  final vehicleNumber = prefs.getString('vehicleNumber') ?? '';
  final trackingStartTime = prefs.getString('trackingStartTime');
  final trackingDurationHours = prefs.getInt('trackingDurationHours') ?? 3;
  final isInBackgroundMode = prefs.getBool('isInBackgroundMode') ?? false;

  if (!isInBackgroundMode) {
    service.stopSelf();
    return;
  }

  DateTime? startTime;

  if (trackingStartTime != null) {
    startTime = DateTime.parse(trackingStartTime);
  }

  bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    service.stopSelf();
    return;
  }

  // Check location permissions
  LocationPermission permission = await Geolocator.checkPermission();
  if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
    service.stopSelf();
    return;
  }

  positionStreamSubscription = Geolocator.getPositionStream(
    locationSettings: AndroidSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 1,
    ),
  ).listen((Position position) async {
    try {
      int vehicleNum = int.tryParse(vehicleNumber) ?? 0;
      print('*****************************************');
      var query = await vehiclesCollection
          .where('vehicle_no', isEqualTo: vehicleNum)
          .limit(1)
          .get();

      if (query.docs.isNotEmpty) {
        String docId = query.docs.first.id;
        GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);

        await vehiclesCollection.doc(docId).update({
          'current_location': geoPoint,
          'last_updated': FieldValue.serverTimestamp(),
        });

        print('Background location updated for $vehicleNumber: ${position.latitude}, ${position.longitude}');
      }

      if (startTime != null && DateTime.now().difference(startTime).inHours >= trackingDurationHours) {
        await prefs.setBool('isInBackgroundMode', false);
        positionStreamSubscription?.cancel();
        service.stopSelf();
      }
    } catch (e) {
      print('Error updating location in background: $e');
    }
  });
}

class LocationTrackingScreen extends StatefulWidget {
  final String vehicleNumber;

  const LocationTrackingScreen({
    Key? key,
    required this.vehicleNumber,
  }) : super(key: key);

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
  late FlutterBackgroundService _backgroundService;
  bool _isInBackgroundMode = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _backgroundService = FlutterBackgroundService();
    _initializeScreen();
  }

  Future<void> _initializeScreen() async {
    await initializeBackgroundService();

    await _loadVehicleData();
    await _initLocationService();


    final prefs = await SharedPreferences.getInstance();
    _isInBackgroundMode = prefs.getBool('isInBackgroundMode') ?? false;

    bool isServiceRunning = await _backgroundService.isRunning();

    if (isServiceRunning && _isInBackgroundMode) {
      setState(() {
        _isTrackingActive = true;
        _loadTrackingStartTime();
      });
    } else if (isServiceRunning && !_isInBackgroundMode) {
      _backgroundService.invoke('stopService');
    } else if (_isTrackingActive && _isInBackgroundMode) {
      _startBackgroundService();
    }

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadTrackingStartTime() async {
    final prefs = await SharedPreferences.getInstance();
    final trackingStartTimeStr = prefs.getString('trackingStartTime');
    if (trackingStartTimeStr != null) {
      setState(() {
        _trackingStartTime = DateTime.parse(trackingStartTimeStr);
      });
    }
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
            _loadTrackingStartTime();
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
    WidgetsBinding.instance.removeObserver(this);
    _locationUpdateTimer?.cancel();
    super.dispose();
  }

  Future<bool> _isLocationServiceEnabled() async {
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
      var locationServiceEnabled = await _isLocationServiceEnabled();
      if(!locationServiceEnabled){
        _initLocationService();
        return;
      }
      Position position = await _locationService.getCurrentPosition();
      String address = await _locationService.getAddressFromPosition(position);

      setState(() {
        _currentPosition = position;
        _address = address;
      });

      if (_isTrackingActive && _currentPosition != null && !_isInBackgroundMode) {
        _refreshVehicleData();
        await _firestoreService.updateVehicleLocation(widget.vehicleNumber, _currentPosition!);
        print('location updated in foreground mode.....');
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
    var locationServiceEnabled = await _isLocationServiceEnabled();
    if(!locationServiceEnabled){
      _initLocationService();
      return;
    }

    await _firestoreService.updateVehicleStatus(widget.vehicleNumber, true);

    setState(() {
      _isTrackingActive = true;
      _trackingStartTime = DateTime.now();
    });

    // Save tracking information to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('vehicleNumber', widget.vehicleNumber);
    await prefs.setString('trackingStartTime', _trackingStartTime!.toIso8601String());
    await prefs.setInt('trackingDurationHours', _trackingDurationHours);

    await _updateCurrentLocation();

    if (_determineIfBackgroundNeeded()) {
      _isInBackgroundMode = true;
      await prefs.setBool('isInBackgroundMode', true);
      _startBackgroundService();
    } else {
      _isInBackgroundMode = false;
      await prefs.setBool('isInBackgroundMode', false);
      _startLocationUpdateTimer();
    }
  }

  bool _determineIfBackgroundNeeded() {
    return false;
  }

  void _startBackgroundService() async {
    await _backgroundService.startService();
  }

  void _startLocationUpdateTimer() {
    _locationUpdateTimer = Timer.periodic(const Duration(seconds: 15), (timer) async {
      if (mounted) {
        print('updating in foreground mode...');
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

    _backgroundService.invoke('stopService');

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('trackingStartTime');
    await prefs.setBool('isInBackgroundMode', false);

    setState(() {
      _isTrackingActive = false;
      _trackingStartTime = null;
      _isInBackgroundMode = false;
    });
  }

  void _showTrackingTimeoutDialog() {
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

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isTrackingActive) {
      if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
        _switchToBackgroundMode();
      } else if (state == AppLifecycleState.resumed) {
        _switchToForegroundMode();
      }
    }
  }

  void _switchToBackgroundMode() async {
    if (_isTrackingActive && !_isInBackgroundMode) {
      _locationUpdateTimer?.cancel();
      _isInBackgroundMode = true;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isInBackgroundMode', true);
      _startBackgroundService();
    }
  }

  void _switchToForegroundMode() async {
    if (_isTrackingActive && _isInBackgroundMode) {
      _backgroundService.invoke('stopService');

      _isInBackgroundMode = false;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isInBackgroundMode', false);

      _startLocationUpdateTimer();
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


// import 'dart:async';
// import 'package:flutter/material.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:intl/intl.dart';
// import 'package:vehicle_tracker/services/location_service.dart';
// import 'package:vehicle_tracker/services/firestore_service.dart';
// import 'package:vehicle_tracker/widgets/countdown_timer.dart';
//
// class LocationTrackingScreen extends StatefulWidget {
//   final String vehicleNumber;
//
//   const LocationTrackingScreen({
//     Key? key,
//     required this.vehicleNumber,
//   }) : super(key: key);
//
//   @override
//   State<LocationTrackingScreen> createState() => _LocationTrackingScreenState();
// }
//
// class _LocationTrackingScreenState extends State<LocationTrackingScreen> {
//   final LocationService _locationService = LocationService();
//   final FirestoreService _firestoreService = FirestoreService();
//   bool _isTrackingActive = false;
//   Position? _currentPosition;
//   String _address = 'Enable location sharing to fetch address.';
//   Timer? _locationUpdateTimer;
//   DateTime? _trackingStartTime;
//   final int _trackingDurationHours = 3;
//   bool _isLoading = true;
//   Map<String, dynamic>? _vehicleData;
//   String _wardNumber = '';
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeScreen();
//   }
//
//   Future<void> _initializeScreen() async {
//     await _loadVehicleData();
//     await _initLocationService();
//     setState(() {
//       _isLoading = false;
//     });
//   }
//
//   Future<void> _loadVehicleData() async {
//     try {
//       Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
//       setState(() {
//         _vehicleData = data;
//         if (data != null) {
//           _isTrackingActive = data['status'] == 'Active';
//           if (data['ward_no'] != null) {
//             _wardNumber = data['ward_no'].toString();
//           }
//
//           if (_isTrackingActive) {
//             _trackingStartTime = DateTime.now();
//             _startLocationUpdateTimer();
//           }
//         }
//       });
//     } catch (e) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(content: Text('Error loading vehicle data: $e')),
//       );
//     }
//   }
//
//   @override
//   void dispose() {
//     _stopLocationTracking();
//     super.dispose();
//   }
//
//   Future<bool> _isLocationServiceEnabld() async {
//     bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
//     LocationPermission permission = await _locationService.checkLocationPermission();
//     if(!serviceEnabled || permission == LocationPermission.denied || permission == LocationPermission.deniedForever){
//       return false;
//     }
//     return true;
//   }
//
//   Future<void> _initLocationService() async {
//     bool serviceEnabled = await _locationService.checkLocationServicesEnabled();
//     if (!serviceEnabled) {
//       _showLocationServicesDialog();
//       return;
//     }
//
//     LocationPermission permission = await _locationService.checkLocationPermission();
//     if (permission == LocationPermission.denied) {
//       permission = await _locationService.requestLocationPermission();
//       if (permission == LocationPermission.denied) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           const SnackBar(
//             content: Text('Location permissions are denied'),
//           ),
//         );
//         return;
//       }
//     }
//
//     if (permission == LocationPermission.deniedForever) {
//       ScaffoldMessenger.of(context).showSnackBar(
//         const SnackBar(
//           content: Text('Location permissions are permanently denied, cannot request permissions.'),
//         ),
//       );
//       return;
//     }
//
//     _updateCurrentLocation();
//   }
//
//   void _showLocationServicesDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Location Services Disabled'),
//         content: const Text('Please enable location services to use this app.'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               Geolocator.openLocationSettings();
//             },
//             child: const Text('OPEN SETTINGS'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _updateCurrentLocation() async {
//     try {
//       var locationServiceEnabld = await _isLocationServiceEnabld();
//       if(!locationServiceEnabld){
//         _initLocationService();
//         return;
//       }
//       Position position = await _locationService.getCurrentPosition();
//       String address = await _locationService.getAddressFromPosition(position);
//
//       setState(() {
//         _currentPosition = position;
//         _address = address;
//       });
//
//       if (_isTrackingActive && _currentPosition != null) {
//         _refreshVehicleData();
//         await _firestoreService.updateVehicleLocation(widget.vehicleNumber, _currentPosition!);
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error updating location: $e')),
//         );
//       }
//     }
//   }
//
//   void _startLocationTracking() async {
//     var locationServiceEnabld = await _isLocationServiceEnabld();
//     if(!locationServiceEnabld){
//       _initLocationService();
//       return;
//     }
//
//     await _firestoreService.updateVehicleStatus(widget.vehicleNumber, true);
//
//     setState(() {
//       _isTrackingActive = true;
//       _trackingStartTime = DateTime.now();
//     });
//
//     await _updateCurrentLocation();
//     _startLocationUpdateTimer();
//   }
//
//   void _startLocationUpdateTimer() {
//     _locationUpdateTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
//       var locationServiceEnabld = await _isLocationServiceEnabld();
//       if(!locationServiceEnabld){
//         _stopLocationTracking();
//         return;
//       }
//       await _updateCurrentLocation();
//       if (_trackingStartTime != null &&
//           DateTime.now().difference(_trackingStartTime!).inHours >= _trackingDurationHours) {
//         _stopLocationTracking();
//         _showTrackingTimeoutDialog();
//       }
//     });
//   }
//
//   Future<void> _refreshVehicleData() async {
//     try {
//       Map<String, dynamic>? data = await _firestoreService.getVehicleData(widget.vehicleNumber);
//       if (mounted) {
//         setState(() {
//           _vehicleData = data;
//         });
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error refreshing vehicle data: $e')),
//         );
//       }
//     }
//   }
//
//   void _stopLocationTracking() async {
//     _locationUpdateTimer?.cancel();
//     _locationUpdateTimer = null;
//
//     if (_isTrackingActive) {
//       await _firestoreService.updateVehicleStatus(widget.vehicleNumber, false);
//     }
//
//     setState(() {
//       _isTrackingActive = false;
//       _trackingStartTime = null;
//     });
//   }
//
//   void _showTrackingTimeoutDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         title: const Text('Tracking Timeout'),
//         content: const Text('Location tracking has been automatically stopped after 3 hours.'),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//             },
//             child: const Text('OK'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   String _formatCoordinates() {
//     if (_currentPosition == null) return 'Enable location sharing to determine location.';
//     return 'Lat: ${_currentPosition!.latitude.toStringAsFixed(6)}° N, Lng: ${_currentPosition!.longitude.toStringAsFixed(6)}° E';
//   }
//
//   String _getVehicleLocationFromFirestore() {
//     if (_vehicleData == null || _vehicleData!['current_location'] == null) {
//       return 'No location data';
//     }
//
//     GeoPoint location = _vehicleData!['current_location'];
//     return 'Lat: ${location.latitude.toStringAsFixed(6)}° N, Lng: ${location.longitude.toStringAsFixed(6)}° E';
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_isLoading) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Vehicle #${widget.vehicleNumber}'),
//           centerTitle: true,
//         ),
//         body: const Center(
//           child: CircularProgressIndicator(),
//         ),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Vehicle #${widget.vehicleNumber}'),
//         centerTitle: true,
//         backgroundColor: Theme.of(context).colorScheme.primary,
//         foregroundColor: Theme.of(context).colorScheme.onPrimary,
//         actions: [
//           IconButton(
//             onPressed: () async {
//               _updateCurrentLocation();
//               // ScaffoldMessenger.of(context).showSnackBar(
//               //   const SnackBar(content: Text('Updating location...')),
//               // );
//             },
//             icon: const Icon(Icons.refresh),
//           ),
//         ],
//       ),
//       body: Padding(
//         padding: const EdgeInsets.all(16),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       children: [
//                         const Icon(Icons.local_taxi, size: 24),
//                         const SizedBox(width: 8),
//                         Text(
//                           'Vehicle Status',
//                           style: Theme.of(context).textTheme.titleLarge,
//                         ),
//                       ],
//                     ),
//                     const Divider(),
//                     Row(
//                       children: [
//                         const Text('Status: '),
//                         Chip(
//                           label: Text(_isTrackingActive ? 'Active' : 'Inactive'),
//                           backgroundColor: _isTrackingActive
//                               ? Colors.green.withOpacity(0.2)
//                               : Colors.red.withOpacity(0.2),
//                           side: BorderSide(
//                             color: _isTrackingActive ? Colors.green : Colors.red,
//                           ),
//                         ),
//                       ],
//                     ),
//                     const SizedBox(height: 8),
//                     Row(
//                       children: [
//                         const Text('Ward Number: '),
//                         Text(
//                           _wardNumber,
//                           style: const TextStyle(fontWeight: FontWeight.bold),
//                         ),
//                       ],
//                     ),
//                     if (_trackingStartTime != null && _isTrackingActive) ...[
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           const Text('Started: '),
//                           Text(
//                             DateFormat('MMM d, yyyy HH:mm:ss').format(_trackingStartTime!),
//                           ),
//                         ],
//                       ),
//                       const SizedBox(height: 8),
//                       Row(
//                         children: [
//                           const Text('Auto-stop in: '),
//                           CountdownTimer(
//                             startTime: _trackingStartTime!,
//                             durationHours: _trackingDurationHours,
//                           ),
//                         ],
//                       ),
//                     ],
//                   ],
//                 ),
//               ),
//             ),
//             const SizedBox(height: 16),
//             Card(
//               elevation: 4,
//               shape: RoundedRectangleBorder(
//                 borderRadius: BorderRadius.circular(16),
//               ),
//               child: Padding(
//                 padding: const EdgeInsets.all(16),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     Row(
//                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                       children: [
//                         Row(
//                           children: [
//                             const Icon(Icons.location_on, size: 24),
//                             const SizedBox(width: 8),
//                             Text(
//                               'Current Location',
//                               style: Theme.of(context).textTheme.titleLarge,
//                             ),
//                           ],
//                         ),
//                         if (_isTrackingActive)
//                           const Chip(
//                             label: Text('LIVE'),
//                             backgroundColor: Colors.green,
//                             labelStyle: TextStyle(color: Colors.white),
//                           ),
//                       ],
//                     ),
//                     const Divider(),
//                     Text(
//                       'Device Coordinates:',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(_formatCoordinates()),
//                     const SizedBox(height: 8),
//                     Text(
//                       'Address:',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(_address),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Database Vehicle Location:',
//                       style: Theme.of(context).textTheme.titleMedium,
//                     ),
//                     const SizedBox(height: 4),
//                     Text(_getVehicleLocationFromFirestore()),
//                   ],
//                 ),
//               ),
//             ),
//             const Spacer(),
//             SizedBox(
//               width: double.infinity,
//               child: FilledButton(
//                 onPressed: _isTrackingActive ? _stopLocationTracking : _startLocationTracking,
//                 style: FilledButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                   backgroundColor: _isTrackingActive ? Colors.red : Colors.green,
//                 ),
//                 child: Row(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     Icon(
//                       _isTrackingActive ? Icons.location_off : Icons.location_on,
//                     ),
//                     const SizedBox(width: 8),
//                     Text(
//                       _isTrackingActive ? 'Stop Sharing Location' : 'Start Sharing Location',
//                       style: const TextStyle(fontSize: 18),
//                     ),
//                   ],
//                 ),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }
