import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:mapmyindia_gl/mapmyindia_gl.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:math' show Point, atan2, cos, pi, sin, sqrt;


class RouteMapEditor extends StatefulWidget {
  final String vehicleId;
  final String vehicleNo;
  final String routeId;
  final String routeName;
  final List<Map<String, dynamic>>? existingWaypoints;
  final Map<String, dynamic>? existingSourceLocation;

  const RouteMapEditor({
    super.key,
    required this.vehicleId,
    required this.vehicleNo,
    required this.routeId,
    required this.routeName,
    this.existingWaypoints,
    this.existingSourceLocation,
  });

  @override
  State<RouteMapEditor> createState() => _RouteMapEditorState();
}

class _RouteMapEditorState extends State<RouteMapEditor> {
  MapmyIndiaMapController? _mapController;
  final List<Symbol> _markers = [];
  Symbol? _sourceMarker;
  final List<Line> _routes = [];
  final List<LatLng> _waypoints = [];
  LatLng? _sourceLocation;
  bool _isLoading = false;
  bool _isSourceSet = false;
  String _statusMessage = "Set source location first, then add waypoints";
  String _accessToken = '';
  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color sourceColor = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();

    if (widget.existingSourceLocation != null) {
      double lat = widget.existingSourceLocation!['lat'];
      double lng = widget.existingSourceLocation!['lng'];
      _sourceLocation = LatLng(lat, lng);
      _isSourceSet = true;
      _addSourceMarker(_sourceLocation!);
    }
    else{
      _getCurrentLocation();
    }

    if (widget.existingWaypoints != null && widget.existingWaypoints!.isNotEmpty) {
      for (var waypoint in widget.existingWaypoints!) {
        if (waypoint['lat'] != null && waypoint['lng'] != null) {
          _waypoints.add(LatLng(waypoint['lat'], waypoint['lng']));
        }
      }
    }

    _initializeMapmyIndia();
    _getAccessToken();
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
        if(_mapController != null){
          _addSourceMarker(_sourceLocation!);
          _isSourceSet = true;
          _statusMessage = "Source location set. Now add destinations by tapping on the map.";
        }
        _isLoading = false;
      });
    }
    catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error getting location: $e";
      });
    }
  }

  void _initializeMapmyIndia() {
    MapmyIndiaAccountManager.setMapSDKKey(dotenv.env['REST_API_KEY']!);
    MapmyIndiaAccountManager.setRestAPIKey(dotenv.env['REST_API_KEY']!);
    MapmyIndiaAccountManager.setAtlasClientId(dotenv.env['ATLAS_CLIENT_ID'] ?? '');
    MapmyIndiaAccountManager.setAtlasClientSecret(dotenv.env['ATLAS_CLIENT_SECRET'] ?? '');
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
          'client_id': dotenv.env['ATLAS_CLIENT_ID'] ?? '',
          'client_secret': dotenv.env['ATLAS_CLIENT_SECRET'] ?? '',
        },
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        _accessToken = data['access_token'];
      }
    } catch (e) {
      print('Error getting token: $e');
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

  void _loadMapIcons() async {
    try {
      await _mapController!.addImage(
        "marker-source",
        await _loadAssetImage("assets/images/logo.png"),
      );
      await _mapController!.addImage(
        "marker-destination",
        await _loadAssetImage("assets/images/destination.png"),
      );
    } catch (e) {
      print("Error loading marker icons: $e");
    }
  }

  void _drawExistingWaypoints() async {
    for (int i = 0; i < _waypoints.length; i++) {
      await _addMarkerAtPosition(_waypoints[i], index: i + 1);
    }

    if (_isSourceSet && _waypoints.isNotEmpty) {
      _calculateAndDrawRoutes();
    }
  }

  Future<void> _addSourceMarker(LatLng position) async {
    if (_mapController == null) return;

    int retryCount = 0;
    const maxRetries = 3;
    const retryDelay = Duration(milliseconds: 300);

    while (retryCount < maxRetries) {
      try {
        if (_sourceMarker != null) {
          await _mapController!.removeSymbol(_sourceMarker!);
          _sourceMarker = null;
        }

        final SymbolOptions symbolOptions = SymbolOptions(
          geometry: position,
          iconSize: 1.2,
          iconImage: "marker-source",
          textField: "Source",
          textSize: 14.0,
          textColor: "#000000",
          textOffset: const Offset(0, 1.8),
        );

        final Symbol symbol = await _mapController!.addSymbol(symbolOptions);

        setState(() {
          _sourceMarker = symbol;
          _isSourceSet = true;
          _statusMessage = "Source set. Add waypoints by tapping on the map";
        });

        _mapController?.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: _sourceLocation!,
              zoom: 14.0,
            ),
          ),
        );

        if (_waypoints.isNotEmpty) {
          _calculateAndDrawRoutes();
        }

        return;
      }
      catch (e) {
        retryCount++;
        if (retryCount >= maxRetries) {
          return;
        }
        await Future.delayed(retryDelay * retryCount);
      }
    }
  }

  Future<void> _addMarkerAtPosition(LatLng position, {int? index}) async {
    if (_mapController == null) return;

    try {
      final SymbolOptions symbolOptions = SymbolOptions(
        geometry: position,
        iconSize: 1.0,
        iconImage: "marker-destination",
        textField: index != null ? "$index" : "",
        textSize: 12.0,
        textColor: "#000000",
        textOffset: const Offset(0, 2),
      );

      final Symbol symbol = await _mapController!.addSymbol(symbolOptions);
      setState(() {
        _markers.add(symbol);
      });
    } catch (e) {
      print("Error adding marker: $e");
    }
  }

  void _onMapTap(Point<double> point, LatLng coordinates) {
    if (_sourceLocation == null || _sourceMarker == null) {
      setState(() {
        _sourceLocation = coordinates;
        _addSourceMarker(coordinates);
        _statusMessage = "Source location set. Now add destinations by tapping on the map.";
      });
    }
    else {
      setState(() {
        _waypoints.add(coordinates);
        _addMarkerAtPosition(coordinates, index: _waypoints.length);
        _statusMessage = "Added waypoint ${_waypoints.length}. Add more or calculate route.";
      });
    }
  }

  Future<void> _calculateAndDrawRoutes() async {
    setState(() {
      _isLoading = true;
      _statusMessage = "Calculating optimal route...";
      _clearRoutes();
    });

    try {
      if (_sourceLocation == null || _waypoints.isEmpty) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Need source and at least one destination";
        });
        return;
      }

      List<LatLng> allPoints = [_sourceLocation!, ..._waypoints];

      List<LatLng> optimizedPath = [];
      Set<int> visitedIndices = {};
      int currentIndex = 0;

      optimizedPath.add(allPoints[currentIndex]);
      visitedIndices.add(currentIndex);

      while (visitedIndices.length < allPoints.length) {
        int nearestIndex = -1;
        double minDistance = double.infinity;

        for (int i = 0; i < allPoints.length; i++) {
          if (!visitedIndices.contains(i)) {
            double distance = _calculateDistance(allPoints[currentIndex],allPoints[i]);

            if (distance < minDistance) {
              minDistance = distance;
              nearestIndex = i;
            }
          }
        }

        if (nearestIndex != -1) {
          currentIndex = nearestIndex;
          optimizedPath.add(allPoints[currentIndex]);
          visitedIndices.add(currentIndex);
        }
      }

      for (int i = 0; i < optimizedPath.length - 1; i++) {
        final from = optimizedPath[i];
        final to = optimizedPath[i + 1];

        List<LatLng> routePoints = await _getRouteBetweenPoints(from, to);

        if (routePoints.isNotEmpty) {
          await _drawRoute(routePoints);
        }
      }

      await _updateMarkerIndices(optimizedPath);

      setState(() {
        _isLoading = false;
        _statusMessage = "Optimal route calculated successfully";
      });
    }
    catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error calculating routes. Try Again";
      });
    }
  }

  double _calculateDistance(LatLng point1, LatLng point2) {
    const double earthRadius = 6371.0; // Earth radius in kilometers

    double lat1 = point1.latitude * (pi / 180);
    double lon1 = point1.longitude * (pi / 180);
    double lat2 = point2.latitude * (pi / 180);
    double lon2 = point2.longitude * (pi / 180);

    // Haversine formula
    double dLat = lat2 - lat1;
    double dLon = lon2 - lon1;
    double a = sin(dLat / 2) * sin(dLat / 2) + cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    double distance = earthRadius * c;

    return distance;
  }

  Future<void> _updateMarkerIndices(List<LatLng> optimizedPath) async {
    // Skip the first point (source) when updating waypoint indices
    List<LatLng> optimizedWaypoints = optimizedPath.sublist(1);

    // Remove all existing waypoint markers
    for (Symbol marker in _markers) {
      await _mapController!.removeSymbol(marker);
    }
    _markers.clear();

    // Add markers with updated indices
    for (int i = 0; i < optimizedWaypoints.length; i++) {
      await _addMarkerAtPosition(optimizedWaypoints[i], index: i + 1);
    }

    // Update waypoints list to match the optimized order
    setState(() {
      _waypoints.clear();
      _waypoints.addAll(optimizedWaypoints);
    });
  }

  Future<List<LatLng>> _getRouteBetweenPoints(LatLng start, LatLng end) async {
    List<LatLng> routePoints = [];

    try {
      final url = 'https://apis.mappls.com/advancedmaps/v1/${dotenv.env['REST_API_KEY']}/route_eta/driving/${start.longitude},${start.latitude};${end.longitude},${end.latitude}?geometries=polyline&rtype=0&steps=false&exclude=ferry&region=IND&alternatives=1&overview=simplified';

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

          if (route['geometry'] != null) {
            if (route['geometry'] is String) {
              routePoints = _decodePolyline(route['geometry']);
            } else if (route['geometry'] is Map && route['geometry']['coordinates'] != null) {
              final List<dynamic> coordinates = route['geometry']['coordinates'];

              for (var coord in coordinates) {
                if (coord is List && coord.length >= 2) {
                  routePoints.add(LatLng(coord[1].toDouble(), coord[0].toDouble()));
                }
              }
            }
          } else if (route['legs'] != null && route['legs'].isNotEmpty) {
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

          if (routePoints.isEmpty) {
            routePoints = [start, end];
          }
        } else {
          routePoints = [start, end];
        }
      } else {
        routePoints = [start, end];
      }
    } catch (e) {
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

  Future<void> _clearRoutes() async {
    if (_mapController != null) {
      for (Line route in _routes) {
        await _mapController!.removeLine(route);
      }
      _routes.clear();
    }
  }

  void _resetMap() async {
    if (_mapController != null) {
      for (Symbol marker in _markers) {
        await _mapController!.removeSymbol(marker);
      }
      await _mapController!.removeSymbol(_sourceMarker!);
      _clearRoutes();
    }

    setState(() {
      _markers.clear();
      _waypoints.clear();
      _sourceMarker = null;
      _statusMessage = "Map reset. Add waypoints by tapping on the map.";
    });
  }

  void _saveRoute() async {
    if (_waypoints.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one waypoint')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _statusMessage = "Saving route...";
    });

    try {
      List<Map<String, dynamic>> waypointsData = _waypoints.map((point) {
        return {
          'lat': point.latitude,
          'lng': point.longitude,
        };
      }).toList();

      // Update source location data
      Map<String, dynamic> sourceLocationData = {
        'lat': _sourceLocation!.latitude,
        'lng': _sourceLocation!.longitude,
      };

      await FirebaseFirestore.instance
          .collection('routes')
          .doc(widget.routeId)
          .update({
        'waypoints': waypointsData,
        'source_location': sourceLocationData,
        'updated_at': FieldValue.serverTimestamp(),
      });

      setState(() {
        _isLoading = false;
        _statusMessage = "Route saved successfully";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Route saved successfully'),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = "Error saving route:";
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving route: $e')),
        );
      }
    }
  }

  void _initializeMap() {
      Future.delayed(const Duration(milliseconds: 1000), (){
        if (_sourceMarker == null && _sourceLocation != null) {
          _addSourceMarker(_sourceLocation!);
        }
        if (_sourceLocation != null && _isSourceSet) {
          if (_waypoints.isNotEmpty) {
            _drawExistingWaypoints();
          }
          setState(() {
            _statusMessage = _isSourceSet
                ? "Add waypoints by tapping on the map"
                : "Set source location by tapping on the map";
          });
        }
      });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Edit Route: ${widget.routeName}'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: Stack(
        children: [
          MapmyIndiaMap(
              initialCameraPosition: CameraPosition(
                target: _sourceLocation ?? const LatLng(28.551087, 77.257373), // Default Delhi
                zoom: 14.0,
              ),
              onMapCreated: (controller) {
                setState(() {
                  _mapController = controller;
                });
                _initializeMap();
              },
              onStyleLoadedCallback: _loadMapIcons,
              onMapClick: _onMapTap,
          ),
          Positioned(
            top: 16,
            left: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: primaryColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Vehicle: ${widget.vehicleNo} - ${_waypoints.length} waypoints',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Text(
                    _statusMessage,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: _isLoading ? primaryColor : Colors.black87,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Add calculate route button
                if (_waypoints.length > 1)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                    ),
                    onPressed: _isLoading ? null : _calculateAndDrawRoutes,
                    icon: const Icon(Icons.route),
                    label: const Text('Calculate Optimal Route'),
                  ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _resetMap,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Reset'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: _isLoading ? null : _saveRoute,
                        icon: const Icon(Icons.save),
                        label: const Text('Save Route'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}
