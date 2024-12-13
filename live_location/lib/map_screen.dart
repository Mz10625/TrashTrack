import 'dart:async';
// import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:live_location/firebase_operations.dart';
import 'package:mapmyindia_gl/mapmyindia_gl.dart';
// import 'package:http/http.dart' as http;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver{
  static const String ACCESS_TOKEN = "9ecd93fedbea8dcfd1dfcd0df0e7d1b5";
  static const String REST_API_KEY = "9ecd93fedbea8dcfd1dfcd0df0e7d1b5";
  static const String ATLAS_CLIENT_ID ="96dHZVzsAuuY2o7_yhcCsIgLxFgHYKZkLA3AC4vFr5wJFgGCvag0ubkJ6zk0b6BALPsTHYBmuae8ZwAHFdn3Og==";
  static const String ATLAS_CLIENT_SECRET = "lrFxI-iSEg9L_R4EGPyA0OKRTT11Va2wQsIHtMMRxiPN2fwUK9vGGY1rbOw2nDKf300UdtpIz_5ISYFJDmQF1V26BKfdvpWf";

  final firestore = FirebaseFirestore.instance;
  late MapmyIndiaMapController mapController;
  LatLng? _currentLocation;
  // List<Map<String, dynamic>> vehicleLocations = [];
  bool _isCheckingSettings = false;
  Completer<bool>? _settingsCompleter;
  Map<String, Symbol> vehicleMarkers = {};
  // static const platform = MethodChannel('com.example.location');
  // String _locationMessage = "No location yet";

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    MapmyIndiaAccountManager.setMapSDKKey(ACCESS_TOKEN);
    MapmyIndiaAccountManager.setRestAPIKey(REST_API_KEY);
    MapmyIndiaAccountManager.setAtlasClientId(ATLAS_CLIENT_ID);
    MapmyIndiaAccountManager.setAtlasClientSecret(ATLAS_CLIENT_SECRET);
    fetchCurrentLocation();
  }
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_isCheckingSettings && state == AppLifecycleState.resumed) {
      _checkLocationServiceAndComplete();
    }
  }
  Future<Uint8List> _loadAssetImage(String path) async {
    final ByteData data = await rootBundle.load(path);
    return data.buffer.asUint8List();
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

  Future<void> moveToCurrentLocation() async {
    if (_currentLocation != null) {
      await mapController.moveCamera(
        CameraUpdate.newLatLngZoom(_currentLocation!, 14.0),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Current location is unavailable"), backgroundColor: Colors.red,),
      );
    }
  }

  Future<void> fetchCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if(await _promptLocationServices() == false && mounted){
          Navigator.pop(context);
          return;
      }
    }
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // print('Location permission are denied.');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      // print('Location permission are permanently denied.');
      return;
    }
    Position currentPosition = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
    if(mounted){
      setState(() {
        _currentLocation = LatLng(currentPosition.latitude, currentPosition.longitude);
      });
    }
  }

  void _checkLocationServiceAndComplete() async {
    if (_settingsCompleter != null && !_settingsCompleter!.isCompleted) {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      _settingsCompleter!.complete(serviceEnabled);
      _isCheckingSettings = false;
    }
  }

  Future<bool> _promptLocationServices() async {
    bool openSettings = await _showEnableLocationDialog();

    if (openSettings) {
      _isCheckingSettings = true;
      _settingsCompleter = Completer<bool>();

      await Geolocator.openLocationSettings();

      bool serviceEnabled = await _settingsCompleter!.future;
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
        title: const Row(
          children: [
            Icon(Icons.error_outline_outlined, size: 38, color: Colors.orange,),
            Padding(
              padding: EdgeInsets.all(8),
              child: Text("Enable Location", style: TextStyle(fontSize: 19, fontWeight: FontWeight.w500),),
            )
          ],
        ),
        content: const Text("Location services are required for this app to work properly. Would you like to enable them?", style: TextStyle(fontSize: 15,)),
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
    ) ?? false;
  }

  void listenForVehicleUpdates() async {
    Map<String, dynamic> user = await fetchCurrentUserData();

    firestore
        .collection('vehicles')
        .where('ward_no', isEqualTo: user['ward_number'])
        .snapshots()
        .listen((snapshot) {
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final double newLat = data['current_location'].latitude;
        final double newLng = data['current_location'].longitude;

        if (vehicleMarkers.containsKey(data['vehicle_no'].toString())) {
          Symbol existingMarker = vehicleMarkers[data['vehicle_no'].toString()]!;
          LatLng existingLatLng = existingMarker.options.geometry!;

          // print("${existingLatLng.latitude} ${existingLatLng.longitude}");
          // print("$newLat $newLng");
          if (existingLatLng.latitude != newLat || existingLatLng.longitude != newLng) {
            mapController.updateSymbol(
              existingMarker,
              SymbolOptions(geometry: LatLng(newLat, newLng)),
            );
          }
        }
        else{
          mapController.addSymbol(
            SymbolOptions(
              geometry: LatLng(newLat, newLng),
              iconSize: 0.2,
              iconImage: "garbage-vehicle-icon",
              textField: data['vehicle_no'].toString(),
              textOffset: const Offset(0, 1.5),
            ),
          ).then((symbol) {
            vehicleMarkers[data['vehicle_no'].toString()] = symbol;
          });
        }
      }
    });
  }

  // Future<String> calculateETAWithTraffic(LatLng start, LatLng end) async {
  //   const String baseUrl = "https://apis.mapmyindia.com/advancedmaps/v1";
  //
  //   const String url = "$baseUrl/$REST_API_KEY/route_eta?geometries=polyline&steps=false&resource=route";
  //
  //   try {
  //     final response = await http.get(
  //       Uri.parse("$url&start=${start.latitude},${start.longitude}&end=${end.latitude},${end.longitude}"),
  //     );
  //
  //     if (response.statusCode == 200) {
  //       final data = jsonDecode(response.body);
  //
  //       if (data['routes'] != null && data['routes'].isNotEmpty) {
  //         double durationInSeconds = data['routes'][0]['duration'];
  //
  //         // Convert seconds to minutes and seconds
  //         int minutes = (durationInSeconds / 60).floor();
  //         int seconds = (durationInSeconds % 60).floor();
  //
  //         print("${minutes}m ${seconds}s");
  //         return "${minutes}m ${seconds}s";
  //       } else {
  //         return "Route not available";
  //       }
  //     } else {
  //       throw Exception("Failed to fetch ETA: ${response.reasonPhrase}");
  //     }
  //   } catch (e) {
  //     print("Error calculating ETA: $e");
  //     return "Error calculating ETA";
  //   }
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Live Locations"),
        backgroundColor: Colors.deepPurple.shade50,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: MediaQuery.of(context).size.height / 1.5,
                width: MediaQuery.of(context).size.width / 1.1,
                child: _currentLocation == null ?
                const Center(
                    child: CircularProgressIndicator(
                            backgroundColor: Colors.purple,
                            valueColor: AlwaysStoppedAnimation(Colors.white70),
                            strokeWidth: 5,
                    )
                ) :
                Stack(
                  children: [
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
                        // addVehicleMarker();
                        listenForVehicleUpdates();

                      },
                    ),
                    Positioned(
                      bottom: MediaQuery.of(context).size.height * 0.02,
                      right: MediaQuery.of(context).size.width * 0.04,
                        child: FloatingActionButton(
                          backgroundColor: Colors.orangeAccent.shade100,
                          onPressed: moveToCurrentLocation,
                            child: const Icon(Icons.my_location,),
                          ),
                    ),
                  ]
                ),
              ),
            ],
          ),
          // ElevatedButton(
          //     onPressed:()async{
          //       calculateETAWithTraffic(_currentLocation!, LatLng(vehicleMarkers.values.first.options.geometry!.latitude, vehicleMarkers.values.first.options.geometry!.latitude));
          //     },
          //     child: const Text("ETA"))
        ],
      ),
    );
  }
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


// try {
// await platform.invokeMethod('getLastKnownLocation');
// setState(() {
// _locationMessage = "Location updates started.";
// });
// platform.setMethodCallHandler((call) async {
// if (call.method == 'locationUpdate') {
// final double latitude = call.arguments['latitude'];
// final double longitude = call.arguments['longitude'];
// print('Location update: Latitude: $latitude, Longitude: $longitude');
// }
// });
// } on PlatformException catch (e) {
// setState(() {
// _locationMessage = "Failed to start location updates: ${e.message}";
// });
// }