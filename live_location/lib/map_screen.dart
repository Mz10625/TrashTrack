
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_location/firebase_operations.dart';
import 'package:mapmyindia_gl/mapmyindia_gl.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const String ACCESS_TOKEN = "9ecd93fedbea8dcfd1dfcd0df0e7d1b5";
  static const String REST_API_KEY = "9ecd93fedbea8dcfd1dfcd0df0e7d1b5";
  static const String ATLAS_CLIENT_ID ="96dHZVzsAuuY2o7_yhcCsIgLxFgHYKZkLA3AC4vFr5wJFgGCvag0ubkJ6zk0b6BALPsTHYBmuae8ZwAHFdn3Og==";
  static const String ATLAS_CLIENT_SECRET = "lrFxI-iSEg9L_R4EGPyA0OKRTT11Va2wQsIHtMMRxiPN2fwUK9vGGY1rbOw2nDKf300UdtpIz_5ISYFJDmQF1V26BKfdvpWf";

  final firestore = FirebaseFirestore.instance;
  late MapmyIndiaMapController mapController;
  LatLng? _currentLocation;
  bool _hasCurrentLocation = false;
  List<Map<String, dynamic>> vehicleLocations = [];
  static const platform = MethodChannel('com.example.location');
  String _locationMessage = "No location yet";


  Future<Uint8List> _loadAssetImage(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
  }

  void addVehicleMarker() async{
    print(vehicleLocations[0]['latitude']);
    for (var vehicle in vehicleLocations) {
      await mapController.addSymbol(
        SymbolOptions(
            geometry: LatLng(vehicle['latitude'], vehicle['longitude']),
            iconSize: 0.2,
            iconImage: "garbage-vehicle-icon",
            textField: vehicle['name'].toString(),
            textOffset: const Offset(0, 1.5)
        ),
      );
    }
  }
  void addCurrentLocationMarker() async{
    await mapController.addSymbol(
      SymbolOptions(
        geometry: _currentLocation!,
        iconImage: "home-icon",
        iconSize: 0.2,
        textField: "Your Location",
        textOffset: const Offset(0, 1.5),
        // textColor: "Orange",
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    MapmyIndiaAccountManager.setMapSDKKey(ACCESS_TOKEN);
    MapmyIndiaAccountManager.setRestAPIKey(REST_API_KEY);
    MapmyIndiaAccountManager.setAtlasClientId(ATLAS_CLIENT_ID);
    MapmyIndiaAccountManager.setAtlasClientSecret(ATLAS_CLIENT_SECRET);
    fetchCurrentLocation();
    fetchVehicleLocations();
  }

  // Future<void> startLocationUpdates() async {
  //   try {
  //     await platform.invokeMethod('startLocationUpdates');
  //     setState(() {
  //       _locationMessage = "Location updates started.";
  //     });
  //   } on PlatformException catch (e) {
  //     setState(() {
  //       _locationMessage = "Failed to start location updates: ${e.message}";
  //     });
  //   }
  //   print(_locationMessage);
  // }


  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print('Location services are disabled.');
      if(await _promptLocationServices() == false){
          Navigator.pop(context);
      }
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        print('Location permission are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      print('Location permission are permanently denied.');
      return;
    }
    print('Getting Location.');
    try {
      await platform.invokeMethod('getLastKnownLocation');
      setState(() {
        _locationMessage = "Location updates started.";
      });
      platform.setMethodCallHandler((call) async {
        if (call.method == 'locationUpdate') {
          final double latitude = call.arguments['latitude'];
          final double longitude = call.arguments['longitude'];
          print('Location update: Latitude: $latitude, Longitude: $longitude');
        }
      });
    } on PlatformException catch (e) {
      setState(() {
        _locationMessage = "Failed to start location updates: ${e.message}";
      });
    }
    print(_locationMessage);
    // Position currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    //
    // setState(() {
    //   _currentLocation = LatLng(currentPosition.latitude, currentPosition.longitude);
    // });
  }

  Future<bool> _promptLocationServices() async {

      bool openSettings = await _showEnableLocationDialog();
      if (openSettings) {
        await Geolocator.openLocationSettings();
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (serviceEnabled) {
            return true;
        }
      }
      return false;
  }

  Future<bool> _showEnableLocationDialog() async {
    return await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Enable Location Services"),
        content: const Text(
            "Location services are required for this app to work properly. Would you like to enable them?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    ) ??
        false;
  }

  Future<void> fetchVehicleLocations() async {
    Map<String, dynamic> user = await fetchCurrentUserData();

    final vehicleSnapshot = await firestore
        .collection('vehicles')
        .where('ward_no', isEqualTo: user['ward_number'])
        .get();

    setState(() {
      vehicleLocations = vehicleSnapshot.docs.map((doc) {
        final data = doc.data();
        GeoPoint location = data['current_location'];
        return {
          'id': doc.id,
          'latitude': location.latitude,
          'longitude': location.longitude,
          'name': data['vehicle_no'] ?? 'Unknown Vehicle',
        };
      }).toList().cast<Map<String, dynamic>>();
    });
    // print(vehicleLocations.isEmpty);
  }

  void listenForVehicleUpdates() async{
    Map<String, dynamic> user = await fetchCurrentUserData();
    firestore.collection('vehicles').where('ward_no', isEqualTo: user['ward_number']).snapshots().listen((vehicleSnapshot) {
      // setState(() {
        vehicleLocations = vehicleSnapshot.docs.map((doc) {
          final data = doc.data();
          GeoPoint location = data['current_location'];

          return {
            'id': doc.id,
            'latitude': location.latitude,
            'longitude': location.longitude,
            'name': data['vehicle_no'] ?? 'Unknown Vehicle',
          };
        }).toList();
      // });
      addVehicleMarker();
      print("Vehicle location updated");
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Vehicle Locations"),
        backgroundColor: Colors.deepPurple.shade50,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height / 1.8,
                width: MediaQuery.of(context).size.width / 1.1,
                child: _currentLocation == null || vehicleLocations.isEmpty ? const Center(child: CircularProgressIndicator()) :
                  MapmyIndiaMap(
                    initialCameraPosition: CameraPosition(
                      target: _currentLocation!,
                      zoom: 14.0,
                    ),
                    onMapCreated: (map) async {
                      mapController = map;
                      await Future.delayed(const Duration(milliseconds: 500));
                      await mapController.addImage(
                        "garbage-vehicle-icon",
                        await _loadAssetImage("assets/images/logo.png"),
                      );
                      await mapController.addImage(
                        "home-icon",
                        await _loadAssetImage("assets/images/home.png"),
                      );
                      if (_currentLocation != null) {
                        addCurrentLocationMarker();
                      }
                      addVehicleMarker();
                      listenForVehicleUpdates();
                    },
                  ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}


// Future<void> fetchCurrentLocation() async {
//   final location = Location();
//   bool serviceEnabled = await location.serviceEnabled();
//   if (!serviceEnabled) {
//     serviceEnabled = await location.requestService();
//     if (!serviceEnabled) return;
//   }
//
//   PermissionStatus permissionGranted = await location.hasPermission();
//   if (permissionGranted != PermissionStatus.granted) {
//     permissionGranted = await location.requestPermission();
//     if (permissionGranted != PermissionStatus.granted) return;
//   }
//
//   final locData = await location.getLocation();
//   setState(() {
//     currentLocation = LatLng(locData.latitude!, locData.longitude!);
//   });
// }