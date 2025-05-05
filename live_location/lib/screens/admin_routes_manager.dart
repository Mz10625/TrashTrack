import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:live_location/screens/routes_map_screen.dart';
import 'package:live_location/services/location_service.dart';

class AdminRoutesScreen extends StatefulWidget {
  const AdminRoutesScreen({super.key});

  @override
  State<AdminRoutesScreen> createState() => _AdminRoutesScreenState();
}

class _AdminRoutesScreenState extends State<AdminRoutesScreen> {
  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  bool isLoading = true;
  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> routes = [];
  Map<String, dynamic>? selectedVehicle;
  Map<String, dynamic>? selectedRoute;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });

    try {
      final vehiclesSnapshot = await FirebaseFirestore.instance.collection('vehicles').get();
      vehicles = vehiclesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'vehicle_no': data['vehicle_no'] ?? '',
          'ward_no': data['ward_no'] ?? '',
          'status': data['status'] ?? 'Inactive',
        };
      }).toList();

      final routesSnapshot = await FirebaseFirestore.instance.collection('routes').get();
      routes = routesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? 'Unnamed Route',
          'vehicle_id': data['vehicle_id'] ?? '',
          'created_at': data['created_at']?.toDate() ?? DateTime.now(),
          'waypoints': data['waypoints'] ?? [],
          'source_location': data['source_location'],
        };
      }).toList();

      setState(() {
        isLoading = false;
      });
    }
    catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Route Management', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader('Vehicle Routes', Icons.route),
            const SizedBox(height: 16),
            _buildVehicleSelector(),
            const SizedBox(height: 16),
            selectedVehicle != null
                ? _buildRouteInfo()
                : _buildEmptyState('Select a vehicle', 'Choose a vehicle to manage its route'),
          ],
        ),
      ),
      floatingActionButton: selectedVehicle != null ? FloatingActionButton(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        onPressed: () => _vehicleHasRoute() ? _editExistingRoute() : _showCreateRouteDialog(),
        tooltip: _vehicleHasRoute() ? 'Edit Route' : 'Create New Route',
        child: Icon(_vehicleHasRoute() ? Icons.edit : Icons.add),
      ) : null,
    );
  }

  bool _vehicleHasRoute() {
    if (selectedVehicle == null) return false;
    return routes.any((route) => route['vehicle_id'] == selectedVehicle!['id']);
  }

  void _editExistingRoute() {
    final existingRoute = routes.firstWhere((route) => route['vehicle_id'] == selectedVehicle!['id'],
      orElse: () => <String, dynamic>{},
    );

    if (existingRoute.isNotEmpty) {
      _checkLocationServicesAndNavigate(existingRoute);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: primaryColor,
            size: 28,
          ),
          const SizedBox(width: 10),
          Text(
            title,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelector() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Select Vehicle',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: selectedVehicle?['id'],
            decoration: InputDecoration(
              labelText: 'Vehicle',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              prefixIcon: const Icon(Icons.directions_bus),
            ),
            hint: const Text('Select a vehicle'),
            isExpanded: true,
            items: vehicles.map((vehicle) {
              return DropdownMenuItem<String>(
                value: vehicle['id'],
                child: Text(
                  'Vehicle ${vehicle['vehicle_no']} - Ward ${vehicle['ward_no']}',
                  overflow: TextOverflow.ellipsis,
                ),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() {
                  selectedVehicle = vehicles.firstWhere((v) => v['id'] == value);

                  // Find if this vehicle has a route
                  final vehicleRoute = routes.firstWhere(
                        (route) => route['vehicle_id'] == value,
                    orElse: () => <String, dynamic>{},
                  );

                  selectedRoute = vehicleRoute.isNotEmpty ? vehicleRoute : null;
                });
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRouteInfo() {
    if (!_vehicleHasRoute()) {
      return _buildEmptyState('No route found', 'Create a new route for this vehicle');
    }

    final route = routes.firstWhere(
          (route) => route['vehicle_id'] == selectedVehicle!['id'],
      orElse: () => <String, dynamic>{},
    );

    if (route.isEmpty) {
      return _buildEmptyState('No route found', 'Create a new route for this vehicle');
    }

    final waypointsCount = (route['waypoints'] as List?)?.length ?? 0;
    final hasSourceLocation = route['source_location'] != null;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            ListTile(
              title: Text(
                route['name'],
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                'Created: ${_formatDate(route['created_at'])}',
                style: TextStyle(color: Colors.grey.shade600),
              ),
              leading: CircleAvatar(
                backgroundColor: primaryColor.withOpacity(0.2),
                child: Icon(Icons.route, color: primaryColor),
              ),
            ),
            const Divider(),
            ListTile(
              leading: Icon(Icons.location_on, color: hasSourceLocation ? accentColor : Colors.grey),
              title: const Text('Source Location'),
              subtitle: Text(
                hasSourceLocation
                    ? 'Set (${route['source_location']['lat'].toStringAsFixed(4)}, ${route['source_location']['lng'].toStringAsFixed(4)})'
                    : 'Not set',
              ),
            ),
            ListTile(
              leading: Icon(Icons.place, color: waypointsCount > 0 ? accentColor : Colors.grey),
              title: const Text('Destinations'),
              subtitle: Text('$waypointsCount waypoints set'),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.edit),
                    label: const Text('Edit Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _checkLocationServicesAndNavigate(route),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.delete),
                    label: const Text('Delete Route'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: inactiveColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => _deleteRoute(route),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _checkLocationServicesAndNavigate(Map<String, dynamic> route) async {
    final LocationService _locationService = LocationService();
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
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RouteMapEditor(
          vehicleId: selectedVehicle!['id'],
          vehicleNo: selectedVehicle!['vehicle_no'].toString(),
          routeId: route['id'],
          routeName: route['name'],
          existingWaypoints: List<Map<String, dynamic>>.from(route['waypoints'] ?? []),
          existingSourceLocation: route['source_location'] != null
              ? Map<String, dynamic>.from(route['source_location'])
              : null,
        ),
      ),
    ).then((_) => _fetchData());
  }

  void _showLocationServicesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Location Services Disabled'),
        content: const Text('Please enable location services to edit or create routes.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Geolocator.openLocationSettings();
            },
            child: const Text('OPEN SETTINGS'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('CANCEL'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Expanded(
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.route,
              size: 80,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateRouteDialog() {
    final nameController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Create New Route',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: InputDecoration(
                labelText: 'Route Name',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                prefixIcon: const Icon(Icons.label),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'For Vehicle: ${selectedVehicle!['vehicle_no']}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              if (nameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter a route name')),
                );
                return;
              }

              Navigator.pop(context);
              _createRoute(nameController.text.trim());
            },
            child: const Text('Create Route'),
          ),
        ],
      ),
    );
  }

  void _createRoute(String name) async {
    final LocationService _locationService = LocationService();
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
          const SnackBar(content: Text('Location permissions are denied')),
        );
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location permissions are permanently denied')),
      );
      return;
    }

    try {
      setState(() {
        isLoading = true;
      });

      final existingRouteIndex = routes.indexWhere((route) => route['vehicle_id'] == selectedVehicle!['id']);

      if (existingRouteIndex != -1) {
        setState(() {
          isLoading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This vehicle already has a route. Please edit the existing route instead.'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      final routeRef = await FirebaseFirestore.instance.collection('routes').add({
        'name': name,
        'vehicle_id': selectedVehicle!['id'],
        'created_at': FieldValue.serverTimestamp(),
        'waypoints': [],
        'source_location': null
      });

      final newRoute = {
        'id': routeRef.id,
        'name': name,
        'vehicle_id': selectedVehicle!['id'],
        'created_at': DateTime.now(),
        'waypoints': [],
        'source_location': null
      };

      setState(() {
        routes.add(newRoute);
        selectedRoute = newRoute;
        isLoading = false;
      });

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RouteMapEditor(
              vehicleId: selectedVehicle!['id'],
              vehicleNo: selectedVehicle!['vehicle_no'].toString(),
              routeId: routeRef.id,
              routeName: name,
            ),
          ),
        ).then((_) => _fetchData());
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error creating route: $e')),
        );
      }
    }
  }

  void _deleteRoute(Map<String, dynamic> route) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Route'),
        content: Text('Are you sure you want to delete the route "${route['name']}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: inactiveColor,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(context);

              try {
                setState(() {
                  isLoading = true;
                });

                await FirebaseFirestore.instance
                    .collection('routes')
                    .doc(route['id'])
                    .delete();

                setState(() {
                  routes.removeWhere((r) => r['id'] == route['id']);
                  selectedRoute = null;
                  isLoading = false;
                });

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Route deleted successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error deleting route: $e')),
                  );
                }
              }
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
