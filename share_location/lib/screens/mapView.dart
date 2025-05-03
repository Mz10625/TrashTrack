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
  LatLng? _sourceLocation;
  bool _isLoading = false;
  String _statusMessage = "Select source and destinations";
  String _accessToken = '';
  Symbol? existingSourceMarker;
  StreamSubscription<QuerySnapshot>? _vehicleSubscription;
  final String _mapMyIndiaApiKey = dotenv.env['REST_API_KEY']!;
  final String _mapMyIndiaClientId = dotenv.env['ATLAS_CLIENT_ID'] ?? '';
  final String _mapMyIndiaClientSecret = dotenv.env['ATLAS_CLIENT_SECRET'] ?? '';

  @override
  void initState() {
    super.initState();
    _initializeMapmyIndia();
    _checkLocationPermission();
    _getAccessToken(); // OAuth token for API calls
  }

  void _initializeMapmyIndia() {
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
        print('OAuth token acquired successfully');
        // print(_accessToken);
      }
      else {
        print('Failed to get OAuth token: ${response.body}');
      }
    }
    catch (e) {
      print('Error getting OAuth token: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    final status = await Permission.location.request();
    if (status.isGranted) {
      _getCurrentLocation();
    } else {
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
        _sourceLocation = LatLng(position.latitude, position.longitude);
        _addMarkerAtPosition(_sourceLocation!, isSource: true);
        _isLoading = false;
        _statusMessage = "Source location set. Now add destinations by tapping on the map.";
      });


      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _sourceLocation!,
            zoom: 14.0,
          ),
        ),
      );
    }
    catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error getting location: $e";
      });
    }
  }

  void _addMarkerAtPosition(LatLng position, {bool isSource = false, int? index}) async {
    if (_mapController == null) return;

    try {
      final SymbolOptions symbolOptions = SymbolOptions(
        geometry: position,
        iconSize: 1.0,
        iconImage: isSource ? "marker-source" : "marker-destination",
        textField: isSource ? "Your Location" : index != null ? "$index" : "",
        textSize: 12.0,
        textColor: "#000000",
        textOffset: const Offset(0, 1.5),
      );

      final Symbol symbol = await _mapController!.addSymbol(symbolOptions);
      setState(() {
        _markers.add(symbol);
        if(isSource){
          existingSourceMarker = symbol;
        }
      });
    }
    catch (e) {
      print("Error adding marker: $e");
    }
  }

  void listenForVehicleUpdates() async {
    print('Listening to updates for vehicle: ${widget.vehicleNumber}');

    try {
      _vehicleSubscription = FirebaseFirestore.instance
          .collection('vehicles')
          .where('vehicle_no', isEqualTo: int.parse(widget.vehicleNumber))
          .snapshots()
          .listen((snapshot) async
      {
        if (snapshot.docs.isEmpty) {
          print('No vehicle document found for ${widget.vehicleNumber}');
          return;
        }

        for (var doc in snapshot.docs) {
          final data = doc.data();

          if (data['current_location'] == null) {
            print('No location data found for vehicle ${widget.vehicleNumber}');
            continue;
          }

          final double newLat = data['current_location'].latitude;
          final double newLng = data['current_location'].longitude;
          final newLocation = LatLng(newLat, newLng);

          bool significantChange = false;
          if (_sourceLocation != null) {
            double distance = _calculateDistance(_sourceLocation!, newLocation);
            significantChange = distance > 0.05; // recalculate if moved more than 50m
          }

          setState(() {
            _sourceLocation = newLocation;
          });

          if (existingSourceMarker != null && _mapController != null) {
            await _mapController!.updateSymbol(
              existingSourceMarker!,
              SymbolOptions(geometry: newLocation),
            );
            print('Location updated to $newLat, $newLng');

            _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(
                CameraPosition(
                  target: newLocation,
                  zoom: 14.0,
                ),
              ),
            );

            if (_destinations.isNotEmpty && significantChange) {
              print('Recalculating routes due to vehicle location change');
              await _clearRoutes();
              await _calculateRoutes();
            }
          }
          else {
            print('Marker or map controller not initialized yet');
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
    if (_sourceLocation == null) {
      setState(() {
        _sourceLocation = coordinates;
        _addMarkerAtPosition(coordinates, isSource: true);
        _statusMessage = "Source location set. Now add destinations by tapping on the map.";
      });
    }
    else {
      setState(() {
        _destinations.add(coordinates);
        _addMarkerAtPosition(coordinates, index: _destinations.length);
        _statusMessage = "Added destination ${_destinations.length}";
      });
    }
  }

  Future<void> _calculateRoutes() async {
    if (_sourceLocation == null || _destinations.isEmpty) {
      setState(() {
        _statusMessage = "Please set source and at least one destination";
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Calculating optimal routes...";
      _clearRoutes();
    });

    try {
      // Build a complete distance matrix between all points
      final distanceMatrix = await _getDistanceMatrix();

      // Find the optimal order to visit destinations using TSP approach
      final optimizedOrder = _findOptimalRoute(distanceMatrix);

      // Get and draw actual road paths between consecutive points in the optimal order
      await _drawOptimalRoute(optimizedOrder);

      setState(() {
        _isLoading = false;
        _statusMessage = "Routes calculated successfully";
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error calculating routes: $e";
      });
      print("Route calculation error: $e");
    }
  }

  Future<Map<String, Map<String, double>>> _getDistanceMatrix() async {
    Map<String, Map<String, double>> distanceMatrix = {};
    List<LatLng> allPoints = [_sourceLocation!, ..._destinations];

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

      List<String> coords = allPoints.map((point) => "${point.longitude},${point.latitude}").toList();

      final url = 'https://apis.mapmyindia.com/advancedmaps/v1/$_mapMyIndiaApiKey/distance_matrix/driving';

      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_accessToken',
        },
        body: json.encode({
          'coordinates': coords,
          'rtype': 1, // For time-based routing
        }),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['results'] != null &&
            data['results']['durations'] != null &&
            data['results']['distances'] != null) {

          final durations = data['results']['durations']; // Time matrix in seconds

          // Fill the distance matrix with travel times (for time optimization)
          for (int i = 0; i < allPoints.length; i++) {
            for (int j = 0; j < allPoints.length; j++) {
              if (i != j) {
                // Use travel time (in minutes) as the "distance" for optimization
                distanceMatrix["$i"]?["$j"] = durations[i][j] / 60.0;
              }
            }
          }
        } else {
          print('Invalid response structure from Distance Matrix API: $data');
        }
      } else {
        print('Distance Matrix API error: ${response.statusCode} - ${response.body}');

        // Fallback to estimated distances if API fails
        for (int i = 0; i < allPoints.length; i++) {
          for (int j = 0; j < allPoints.length; j++) {
            if (i != j) {
              distanceMatrix["$i"]?["$j"] = _calculateDistance(allPoints[i], allPoints[j]);
            }
          }
        }
      }
    }
    catch (e) {
      print('Error in _getDistanceMatrix: $e');
      // Fallback to estimated distances
      for (int i = 0; i < allPoints.length; i++) {
        for (int j = 0; j < allPoints.length; j++) {
          if (i != j) {
            distanceMatrix["$i"]?["$j"] = _calculateDistance(allPoints[i], allPoints[j]);
          }
        }
      }
    }

    return distanceMatrix;
  }

  // Find optimal route order using greedy approach for TSP
  List<int> _findOptimalRoute(Map<String, Map<String, double>> distanceMatrix) {
    int sourceIndex = 0; // Source is always at index 0
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

  Future<void> _drawOptimalRoute(List<int> optimizedOrder) async {
    List<LatLng> allPoints = [_sourceLocation!, ..._destinations];

    for (int i = 0; i < optimizedOrder.length - 1; i++) {
      int fromIdx = optimizedOrder[i];
      int toIdx = optimizedOrder[i + 1];

      LatLng from = allPoints[fromIdx];
      LatLng to = allPoints[toIdx];

      List<LatLng> routePoints = await _getRouteBetweenPoints(from, to);

      if (routePoints.isNotEmpty) {
        await _drawRoute(routePoints);
      }
    }
  }

  Future<List<LatLng>> _getRouteBetweenPoints(LatLng start, LatLng end) async {
    List<LatLng> routePoints = [];

    try {
      final url = 'https://apis.mappls.com/advancedmaps/v1/$_mapMyIndiaApiKey/route_adv/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline&rtype=0&steps=false&exclude=ferry&region=IND&alternatives=1&overview=simplified';

      print('Route API URL: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          if (_accessToken.isNotEmpty) 'Authorization': 'Bearer $_accessToken',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print('Route API response: $data');

        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final route = data['routes'][0];

          // Handle different geometry formats
          if (route['geometry'] != null) {
            if (route['geometry'] is String) {
              // Decode polyline format
              routePoints = _decodePolyline(route['geometry']);
            } else if (route['geometry'] is Map && route['geometry']['coordinates'] != null) {
              // Handle GeoJSON format
              final List<dynamic> coordinates = route['geometry']['coordinates'];

              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  // MapMyIndia returns [longitude, latitude] format
                  routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
            }
          } else if (route['legs'] != null && route['legs'].isNotEmpty) {
            // Try to extract coordinates from route legs if available
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

          print('Extracted ${routePoints.length} route points');

          // If still empty, fallback to straight line
          if (routePoints.isEmpty) {
            print('No route geometry found in API response, using fallback');
            routePoints = [start, end];
          }
        } else {
          print('No routes in API response');
          routePoints = [start, end];
        }
      } else {
        print('Direction API error: ${response.statusCode} - ${response.body}');
        // Fallback: direct line if API fails
        routePoints = [start, end];
      }
    } catch (e) {
      print('Error in _getRouteBetweenPoints: $e');
      // Fallback: direct line
      routePoints = [start, end];
    }

    return routePoints;
  }

  // Decode polyline string to list of coordinates
  List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    try {
      while (index < len) {
        int b, shift = 0, result = 0;

        // Decode latitude
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);

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

        // Convert to actual coordinates
        double latitude = lat / 1E5;
        double longitude = lng / 1E5;
        points.add(LatLng(latitude, longitude));
      }
    } catch (e) {
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
    } catch (e) {
      print("Error drawing route: $e");
    }
  }

  // Basic distance calculation (Haversine formula)
  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    // Convert degrees to radians
    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);

    // Haversine formula
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  void _resetMap() async {
    if (_mapController != null) {
      for (Symbol marker in _markers) {
        if(marker.options.textField != "Your Location"){
          await _mapController!.removeSymbol(marker);
        }
      }
      _clearRoutes();
    }

    setState(() {
      _markers.clear();
      _destinations.clear();
      // _sourceLocation = null;
      _statusMessage = "Map reset. Select source and destinations.";
    });
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

    _loadMapIcons();

    if (_sourceLocation != null) {
      _mapController?.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _sourceLocation!,
            zoom: 14.0,
          ),
        ),
      );
      await _mapController?.addSymbol(
        SymbolOptions(
          geometry: _sourceLocation!,
          iconImage: "marker-source",
          textField: "Your Location",
          textOffset: const Offset(0, 1.5),
        ),
      ).then((symbol){
        existingSourceMarker = symbol;
      });
    }
    listenForVehicleUpdates();
  }

  void _loadMapIcons() async {
    try {
      await _mapController!.addImage(
        "marker-source",
        await _loadAssetImage("assets/icon/logo.png"),
      );
      await _mapController!.addImage(
        "marker-destination",
        await _loadAssetImage("assets/icon/destination.png"),
      );
    } catch (e) {
      print("Error loading marker icons: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find Optimal Route'),
      ),
      body: Stack(
        children: [
          MapmyIndiaMap(
            initialCameraPosition: CameraPosition(
              target: _sourceLocation ?? const LatLng(20.5937, 78.9629), // Default to India
              zoom: 5.0,
            ),
            onMapCreated: _onMapCreated,
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
                      ElevatedButton(
                        onPressed: _resetMap,
                        child: const Text('Reset'),
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