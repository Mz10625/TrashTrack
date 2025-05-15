import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:mapmyindia_gl/mapmyindia_gl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:math' show Point, atan2, cos, pi, sin, sqrt;

class MapViewScreen extends StatefulWidget {
  final String vehicleNumber;
  const MapViewScreen({super.key, required this.vehicleNumber});

  @override
  MapViewScreenState createState() => MapViewScreenState();
}

class MapViewScreenState extends State<MapViewScreen> {
  MapmyIndiaMapController? _mapController;
  final List<Symbol> _markers = [];
  final List<Line> _routes = [];
  final List<LatLng> _destinations = [];
  LatLng? _currentDeviceLocation;
  bool _isLoading = false;
  bool _existingRoutesDisplayed = false;
  String _statusMessage = "Calculating optimal routes...";
  String _accessToken = '';
  Symbol? _currentLocationMarker;
  StreamSubscription<QuerySnapshot>? _vehicleSubscription;
  final String _mapMyIndiaApiKey = dotenv.env['REST_API_KEY']!;
  final String _mapMyIndiaClientId = dotenv.env['ATLAS_CLIENT_ID'] ?? '';
  final String _mapMyIndiaClientSecret = dotenv.env['ATLAS_CLIENT_SECRET'] ?? '';
  String? _routeName;
  final List<LatLng> _storedWaypoints = [];
  bool _isExistingRouteLoaded = false;
  final String _sourceImageId = "marker-source";
  final String _currentLocationImageId = "marker-current";
  final String _destinationImageId = "marker-destination";

  @override
  void initState() {
    super.initState();
    _initializeMapMyIndia();
    _getAccessToken();
  }

  void _initializeMapMyIndia() {
    MapmyIndiaAccountManager.setMapSDKKey(_mapMyIndiaApiKey);
    MapmyIndiaAccountManager.setRestAPIKey(_mapMyIndiaApiKey);
    MapmyIndiaAccountManager.setAtlasClientId(_mapMyIndiaClientId);
    MapmyIndiaAccountManager.setAtlasClientSecret(_mapMyIndiaClientSecret);
  }

  Future<void> _getAccessToken() async {
    try {
      final response = await http.post(
        Uri.parse('https://outpost.mapmyindia.com/api/security/oauth/token'),
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {
          'grant_type': 'client_credentials',
          'client_id': _mapMyIndiaClientId,
          'client_secret': _mapMyIndiaClientSecret,
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
        // print(_accessToken);
      }
      else {
        print('failed to get token: ${response.body}');
      }
    }
    catch (e) {
      print('error getting token: $e');
    }
  }

  Future<void> _fetchVehicleRouteData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Fetching route data...";
    });

    try {
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('vehicles')
          .where('vehicle_no', isEqualTo: int.parse(widget.vehicleNumber))
          .get();

      if (vehicleDoc.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Vehicle not found";
        });
        return;
      }

      final vehicleId = vehicleDoc.docs.first.id;

      final routeDoc = await FirebaseFirestore.instance
          .collection('routes')
          .where('vehicle_id', isEqualTo: vehicleId)
          .get();

      if (routeDoc.docs.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Existing route not found";
        });
        return;
      }

      final routeData = routeDoc.docs.first.data();
      if (routeData['waypoints'] == null || routeData['source_location'] == null) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Route data is incomplete";
        });
        return;
      }

      _routeName = routeData['name'] ?? 'Unknown Route';

      final waypointsData = routeData['waypoints'];
      if (waypointsData != null) {
        _storedWaypoints.clear();
        for (var waypoint in waypointsData) {
          if (waypoint['lat'] != null && waypoint['lng'] != null) {
            _storedWaypoints.add(LatLng(waypoint['lat'], waypoint['lng']));
          }
        }

        _destinations.clear();
        _destinations.addAll(_storedWaypoints);
      }

      setState(() {
        _isLoading = false;
        _statusMessage = "Route loaded: ${_storedWaypoints.length} waypoints";
        _isExistingRouteLoaded = true;
      });

    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error loading route";
      });
      print("Error fetching route data: $e");
    }
  }

  Future<void> _drawExistingRoute() async {
    if (_mapController == null || _currentDeviceLocation == null || _storedWaypoints.isEmpty) {
      return;
    }

    _existingRoutesDisplayed = true;
    for (int i = 0; i < _storedWaypoints.length; i++) {
      await _addMarkerAtPosition(_storedWaypoints[i], index: i + 1);
    }

    await _calculateRoutes();

    _mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _currentDeviceLocation!,
          zoom: 14.0,
        ),
      ),
    );
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      if (_currentDeviceLocation == null) {
        await _getCurrentLocation();
      }
    }
    else {
      setState(() {
        _statusMessage = "Location permission denied";
      });
    }
  }

  Future<Uint8List> _resizeImage(Uint8List data, int width, int height) async {
    ui.Codec codec = await ui.instantiateImageCodec(
      data,
      targetWidth: width,
      targetHeight: height,
    );
    ui.FrameInfo frameInfo = await codec.getNextFrame();

    final byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  Future<Uint8List> _loadAssetImage(String path) async {
    final ByteData data = await rootBundle.load(path);
    return _resizeImage(data.buffer.asUint8List(), 100, 100);
  }

  Future<void> _getCurrentLocation() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Getting current location...";
    });

    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high
      );

      setState(() {
        _currentDeviceLocation = LatLng(position.latitude, position.longitude);
        _isLoading = false;
        _statusMessage = "Current location found. Fetching route data...";
      });
    }
    catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error getting location: $e";
      });
    }
  }

  Future<void> _addMarkerAtPosition(LatLng position, {bool isSource = false, bool isCurrentLocation = false, int? index}) async {
    if (_mapController == null) return;

    try {
      String iconImage;
      String textField;

      if (isCurrentLocation) {
        iconImage = _currentLocationImageId;
        textField = "Current Location";
      }
      else if (isSource) {
        iconImage = _sourceImageId;
        textField = "Route Start";
      }
      else {
        iconImage = _destinationImageId;
        textField = index != null ? "$index" : "";
      }

      final SymbolOptions symbolOptions = SymbolOptions(
        geometry: position,
        iconSize: 1.0,
        iconImage: iconImage,
        textField: textField,
        textSize: 12.0,
        textColor: "#000000",
        textOffset: const Offset(0, 1.5),
      );

      final Symbol symbol = await _mapController!.addSymbol(symbolOptions);
      setState(() {
        _markers.add(symbol);
        if (isCurrentLocation) {
          _currentLocationMarker = symbol;
        }
      });
    }
    catch (e) {
      print("Error adding marker: $e");
    }
  }

  void listenForVehicleUpdates() async {
    try {
      _vehicleSubscription = FirebaseFirestore.instance
          .collection('vehicles')
          .where('vehicle_no', isEqualTo: int.parse(widget.vehicleNumber))
          .snapshots()
          .listen((snapshot) async
      {
        if (snapshot.docs.isEmpty) {
          print('vehicle document not found for ${widget.vehicleNumber}');
          return;
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();

          if (data['current_location'] == null) {
            print('location data not found for vehicle ${widget.vehicleNumber}');
            continue;
          }

          final double newLat = data['current_location'].latitude;
          final double newLng = data['current_location'].longitude;
          final newLocation = LatLng(newLat, newLng);

          setState(() {
            _currentDeviceLocation = newLocation;
          });

          if (_currentLocationMarker != null && _mapController != null) {
            await _mapController!.updateSymbol(
              _currentLocationMarker!,
              SymbolOptions(geometry: newLocation),
            );

            if (_destinations.isNotEmpty) {
              await _clearRoutes();
              await _calculateRoutes();
            }
          }
        }
      },
          onError: (error) {
            print('Error in Firestore listener: $error');
          });
    }
    catch (error) {
      print('Error setting up vehicle listener: $error');
    }
  }

  void _onMapTap(Point<double> point, LatLng coordinates) {
      setState(() {
        _destinations.add(coordinates);
        _addMarkerAtPosition(coordinates, index: _destinations.length);
        _statusMessage = "Added destination ${_destinations.length}";
      });
  }

  Future<void> _calculateRoutes() async {
    if (_currentDeviceLocation == null || _destinations.isEmpty) {
      setState(() {
        _statusMessage = "Missing location data for route calculation";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Calculating optimal routes...";
      _clearRoutes();
    });

    try {
      List<LatLng> orderedPoints = [_currentDeviceLocation!];

      final distanceMatrix = await _getDistanceMatrix();

      final optimizedDestinationOrder = _findOptimalRoute(distanceMatrix);

      for (int i = 0; i < optimizedDestinationOrder.length; i++) {
        int idx = optimizedDestinationOrder[i];
        orderedPoints.add(_destinations[idx]);

      }

      for (int i = 0; i < orderedPoints.length - 1; i++) {
        LatLng from = orderedPoints[i];
        LatLng to = orderedPoints[i + 1];

        List<LatLng> routePoints = await _getRouteBetweenPoints(from, to);

        if (routePoints.isNotEmpty) {
          await _drawRoute(routePoints);
        }
      }

      setState(() {
        _isLoading = false;
        _statusMessage = "Routes calculated successfully";
      });
    }
    catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error calculating routes";
      });
      print("calculation error: $e");
    }
  }

  Future<Map<String, Map<String, double>>> _getDistanceMatrix() async {
    Map<String, Map<String, double>> distanceMatrix = {};
    List<LatLng> allPoints = [..._destinations];

    for (int i = 0; i < allPoints.length; i++) {
      String key = "$i";
      distanceMatrix[key] = {};

      for (int j = 0; j < allPoints.length; j++) {
        if (i != j) {
          distanceMatrix[key]?["$j"] = double.infinity;
        } else {
          distanceMatrix[key]?["$j"] = 0.0;
        }
      }
    }

    try {
      // use estimated distances
      for (int i = 0; i < allPoints.length; i++) {
        for (int j = 0; j < allPoints.length; j++) {
          if (i != j) {
            distanceMatrix["$i"]?["$j"] = _calculateDistance(allPoints[i], allPoints[j]);
          }
        }
      }
    }
    catch (e) {
      print('Error in _getDistanceMatrix: $e');
    }

    return distanceMatrix;
  }

  List<int> _findOptimalRoute(Map<String, Map<String, double>> distanceMatrix) {
    int sourceIndex = 0; // source is at index 0
    List<int> unvisited = List.generate(_destinations.length, (i) => i + 1);
    List<int> route = [sourceIndex];

    // Greedy algorithm: always visit the closest unvisited point
    while (unvisited.isNotEmpty) {
      int current = route.last;
      int? nearest;
      double minDist = double.infinity;

      for (int next in unvisited) {
        double dist = distanceMatrix["$current"]?["$next"] ?? double.infinity;
        if (dist < minDist) {
          minDist = dist;
          nearest = next;
        }
      }

      if (nearest != null) {
        route.add(nearest);
        unvisited.remove(nearest);
      }
      else {
        break;
      }
    }
    return route;
  }

  Future<List<LatLng>> _getRouteBetweenPoints(LatLng start, LatLng end) async {
    List<LatLng> routePoints = [];

    try {
      final url = 'https://apis.mappls.com/advancedmaps/v1/$_mapMyIndiaApiKey/route_eta/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline&rtype=0&steps=false&exclude=ferry&region=IND&alternatives=1&overview=simplified';

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (_accessToken.isNotEmpty) 'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // handle different geometry formats
          if (route['geometry'] != null) {
            if (route['geometry'] is String) {
              // decode polyline format
              routePoints = _decodePolyline(route['geometry']);
            }
            else if (route['geometry'] is Map && route['geometry']['coordinates'] != null) {
              // handle GeoJSON format
              final List<dynamic> coordinates = route['geometry']['coordinates'];

              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
            }
          }
          else if (route['legs'] != null && route['legs'].isNotEmpty) {
            for (var leg in route['legs']) {
              if (leg['steps'] != null) {
                for (var step in leg['steps']) {
                  if (step['geometry'] != null) {
                    List<LatLng> stepPoints = _decodePolyline(step['geometry']);
                    routePoints.addAll(stepPoints);
                  }
                }
              }
            }
          }
          // If empty, use straight line
          if (routePoints.isEmpty) {
            routePoints = [start, end];
          }
        }
        else {
          routePoints = [start, end];
        }
      }
      else {
        routePoints = [start, end];
      }
    }
    catch (e) {
      print('Error in _getRouteBetweenPoints: $e');
      routePoints = [start, end];
    }
    return routePoints;
  }

  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;

        // Decode latitude
        do {
          b = encoded.codeUnitAt(index++) - 63;  // get the unicode value of the character and subtract 63 from the character code to get ASCII characters
          result = result | (b & 0x1f) << shift;  // masks off the lower 5 bits of the byte (0x1f = 31 = 0b11111)
          shift = shift + 5;
        } while (b >= 0x20);    // continue the loop if the high bit (0x20 = 32 = 0b100000) is set. A set high bit indicates more characters follow for this delta value

        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        // Decode longitude
        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);

        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;

        // divide by 100,000 to get actual coordinates
        double latitude = lat / 1E5;
        double longitude = lng / 1E5;
        points.add(LatLng(latitude, longitude));
      }
    }
    catch (e) {
      print('Error decoding polyline: $e');
    }

    return points;
  }

  Future<void> _drawRoute(List<LatLng> routePoints) async {
    if (_mapController == null) return;

    try {
      final LineOptions lineOptions = LineOptions(
        geometry: routePoints,
        lineColor: "#4595d6",
        lineWidth: 5.0,
      );

      final Line line = await _mapController!.addLine(lineOptions);
      setState(() {
        _routes.add(line);
      });
    }
    catch (e) {
      print("Error drawing route: $e");
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // earth radius in kilometers

    // convert degrees to radians
    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);

    // haversine formula
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  Future<void> _clearRoutes() async {
    if (_mapController != null) {
      for (Line route in _routes) {
        await _mapController!.removeLine(route);
      }
      _routes.clear();
    }
  }

  void _onMapCreated(MapmyIndiaMapController controller) async {
    _mapController = controller;

    await _checkLocationPermission();
    if (_currentDeviceLocation != null && _currentLocationMarker == null) {
      await _addMarkerAtPosition(_currentDeviceLocation!, isCurrentLocation: true);
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _currentDeviceLocation!,
            zoom: 14.0,
          ),
        ),
      );
    }
    await _fetchVehicleRouteData();

    if (_isExistingRouteLoaded && _currentDeviceLocation != null && !_existingRoutesDisplayed) {
      _drawExistingRoute();
    }
    listenForVehicleUpdates();
  }

  Future<void> _loadMapIcons() async {
    try {
      await _mapController!.addImage(
        _sourceImageId,
        await _loadAssetImage("assets/icon/logo.png"),
      );
      await _mapController!.addImage(
        _destinationImageId,
        await _loadAssetImage("assets/icon/destination.png"),
      );
      await _mapController!.addImage(
        _currentLocationImageId,
        await _loadAssetImage("assets/icon/logo.png"),
      );
    }
    catch (e) {
      print("Error loading marker icons: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_routeName != null ? 'Route: $_routeName' : 'Find Optimal Route'),
      ),
      body: Stack(
        children: [
          MapmyIndiaMap(
              initialCameraPosition: CameraPosition(
                target: _currentDeviceLocation ?? const LatLng(20.5937, 78.9629), // default to India
                zoom: 5.0,
              ),
              onMapCreated: _onMapCreated,
              onStyleLoadedCallback: _loadMapIcons,
              onMapClick: _onMapTap
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              color: Colors.white.withOpacity(0.8),
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _statusMessage,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: _calculateRoutes,
                        child: const Text('Calculate Optimal Route'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _mapController?.dispose();
    _vehicleSubscription?.cancel();
    super.dispose();
  }
}
