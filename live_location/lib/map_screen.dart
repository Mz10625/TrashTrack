
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:live_location/firebase_operations.dart';
import 'package:location/location.dart';
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
  LatLng? currentLocation;
  List<Map<String, dynamic>> vehicleLocations = [];

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
        geometry: currentLocation!,
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

  Future<void> fetchCurrentLocation() async {
    final location = Location();
    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    PermissionStatus permissionGranted = await location.hasPermission();
    if (permissionGranted != PermissionStatus.granted) {
      permissionGranted = await location.requestPermission();
      if (permissionGranted != PermissionStatus.granted) return;
    }

    final locData = await location.getLocation();
    setState(() {
      currentLocation = LatLng(locData.latitude!, locData.longitude!);
    });
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
                child: currentLocation == null || vehicleLocations.isEmpty ? const Center(child: CircularProgressIndicator()) :
                  MapmyIndiaMap(
                    initialCameraPosition: CameraPosition(
                      target: currentLocation!,
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
                      if (currentLocation != null) {
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
