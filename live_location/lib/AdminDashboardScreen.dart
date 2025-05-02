import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:live_location/AdminFeedbackScreen.dart';
import 'package:live_location/login.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  bool isLoading = true;

  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  List<Map<String, dynamic>> vehicles = [];
  List<Map<String, dynamic>> wards = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    fetchData();
  }

  Future<void> fetchData() async {
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

      final wardsSnapshot = await FirebaseFirestore.instance.collection('wards').get();
      wards = wardsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'ward_no': data['number'] ?? '',
          'ward_name': data['name'] ?? '',
        };
      }).toList();

      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e')),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        title: const Text('Admin Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accentColor,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'VEHICLES'),
            Tab(text: 'WARDS'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : TabBarView(
        controller: _tabController,
        children: [
          _buildVehiclesTab(),
          _buildWardsTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: accentColor,
        foregroundColor: Colors.white,
        onPressed: () {
          if (_tabController.index == 0) {
            _showVehicleDialog();
          } else {
            _showWardDialog();
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      elevation: 2,
      child: Container(
        color: cardColor,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              children: [
                UserAccountsDrawerHeader(
                  accountName: const Text(
                    'Admin',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                  accountEmail: Text(
                    user?.email ?? '',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                  currentAccountPicture: CircleAvatar(
                    backgroundColor: Colors.white,
                    child: Icon(Icons.admin_panel_settings, color: primaryColor, size: 40),
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor,
                  ),
                ),
                ListTile(
                  leading: Icon(Icons.dashboard, color: primaryColor),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: Icon(Icons.feedback, color: primaryColor),
                  title: const Text('View Feedbacks'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AdminFeedbackScreen()
                      ),
                    );
                  },
                ),
                const Divider(),
              ],
            ),
            Column(
              children: [
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout'),
                  onTap: () async {
                    try {
                      await FirebaseAuth.instance.signOut();
                      final prefs = await SharedPreferences.getInstance();
                      prefs.setBool('isLoggedIn', false);
                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const Login()),
                        );
                      }
                    } catch (e) {
                      debugPrint("Error signing out: $e");
                    }
                  },
                ),
                const SizedBox(height: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVehiclesTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Vehicles Management', Icons.directions_bus_rounded),
          const SizedBox(height: 16),
          Expanded(
            child: vehicles.isEmpty
                ? _buildEmptyState('No vehicles available', 'Add a vehicle to get started')
                : _buildVehiclesTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildVehiclesTable() {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: DataTable(
                    headingRowHeight: 50,
                    dataRowHeight: 60,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: MaterialStateProperty.all(
                      primaryColor.withOpacity(0.9),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Vehicle No.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Ward No.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Status',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    rows: vehicles.asMap().entries.map((entry) {
                      int index = entry.key;
                      var vehicle = entry.value;
                      final isActive = vehicle['status'] == 'Active';

                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                            return index % 2 == 0
                                ? Colors.white
                                : const Color(0xFFF8F9FA);
                          },
                        ),
                        cells: [
                          DataCell(
                            Text(
                              '${vehicle['vehicle_no']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${vehicle['ward_no']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DataCell(
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? accentColor.withOpacity(0.1)
                                    : inactiveColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: isActive ? accentColor : inactiveColor,
                                    ),
                                    margin: const EdgeInsets.only(right: 8),
                                  ),
                                  Text(
                                    '${vehicle['status']}',
                                    style: TextStyle(
                                      color: isActive ? accentColor : inactiveColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: primaryColor),
                                  onPressed: () => _showVehicleDialog(vehicle: vehicle),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteDialog('vehicle', vehicle),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildWardsTab() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionHeader('Wards Management', Icons.location_city),
          const SizedBox(height: 16),
          Expanded(
            child: wards.isEmpty
                ? _buildEmptyState('No wards available', 'Add a ward to get started')
                : _buildWardsTable(),
          ),
        ],
      ),
    );
  }

  Widget _buildWardsTable() {
    return Container(
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minWidth: constraints.maxWidth,
                  ),
                  child: DataTable(
                    headingRowHeight: 50,
                    dataRowHeight: 60,
                    columnSpacing: 20,
                    horizontalMargin: 16,
                    headingRowColor: MaterialStateProperty.all(
                      primaryColor.withOpacity(0.9),
                    ),
                    columns: const [
                      DataColumn(
                        label: Text(
                          'Ward No.',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Ward Name',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'Actions',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                    rows: wards.asMap().entries.map((entry) {
                      int index = entry.key;
                      var ward = entry.value;

                      return DataRow(
                        color: MaterialStateProperty.resolveWith<Color>(
                              (Set<MaterialState> states) {
                            return index % 2 == 0
                                ? Colors.white
                                : const Color(0xFFF8F9FA);
                          },
                        ),
                        cells: [
                          DataCell(
                            Text(
                              '${ward['ward_no']}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w500,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              '${ward['ward_name']}',
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DataCell(
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: Icon(Icons.edit, color: primaryColor),
                                  onPressed: () => _showWardDialog(ward: ward),
                                  tooltip: 'Edit',
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  onPressed: () => _showDeleteDialog('ward', ward),
                                  tooltip: 'Delete',
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
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

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inbox,
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
    );
  }

  void _showVehicleDialog({Map<String, dynamic>? vehicle}) {
    final isEditing = vehicle != null;
    final vehicleNoController = TextEditingController(text: isEditing ? vehicle['vehicle_no'].toString() : '');
    final wardNoController = TextEditingController(text: isEditing ? vehicle['ward_no'].toString() : '');
    String selectedStatus = isEditing ? vehicle['status'] : 'Inactive';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? 'Edit Vehicle' : 'Add New Vehicle',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: vehicleNoController,
                decoration: InputDecoration(
                  labelText: 'Vehicle Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.directions_bus),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: wardNoController.text.isEmpty ? null : wardNoController.text,
                decoration: InputDecoration(
                  labelText: 'Ward Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_city),
                ),
                hint: const Text('Select Ward'),
                isExpanded: true,
                items: wards.map((ward) {
                  return DropdownMenuItem<String>(
                    value: ward['ward_no'].toString(),
                    child: Text(
                      '${ward['ward_no']} - ${ward['ward_name']}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    wardNoController.text = value;
                  }
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.check_circle),
                ),
                items: const [
                  DropdownMenuItem(value: 'Active', child: Text('Active')),
                  DropdownMenuItem(value: 'Inactive', child: Text('Inactive')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    selectedStatus = value;
                  }
                },
              ),
            ],
          ),
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
            onPressed: () async {
              if (vehicleNoController.text.trim().isEmpty || wardNoController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                setState(() {
                  isLoading = true;
                });
                Navigator.pop(context);

                if (isEditing) {
                  await FirebaseFirestore.instance
                      .collection('vehicles')
                      .doc(vehicle['id'])
                      .update({
                    'vehicle_no': int.parse(vehicleNoController.text.trim()),
                    'ward_no': int.parse(wardNoController.text.trim()),
                    'status': selectedStatus,
                  });
                } else {
                  await FirebaseFirestore.instance.collection('vehicles').add({
                    'vehicle_no': int.parse(vehicleNoController.text.trim()),
                    'ward_no': int.parse(wardNoController.text.trim()),
                    'status': selectedStatus,
                    'current_location' : const GeoPoint(0,0)
                  });
                }

                fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing ? 'Vehicle updated successfully' : 'Vehicle added successfully'),
                      backgroundColor: accentColor,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showWardDialog({Map<String, dynamic>? ward}) {
    final isEditing = ward != null;
    final wardNoController = TextEditingController(text: isEditing ? ward['ward_no'] : '');
    final wardNameController = TextEditingController(text: isEditing ? ward['ward_name'] : '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          isEditing ? 'Edit Ward' : 'Add New Ward',
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: wardNoController,
                decoration: InputDecoration(
                  labelText: 'Ward Number',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.numbers),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: wardNameController,
                decoration: InputDecoration(
                  labelText: 'Ward Name',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.location_city),
                ),
              ),
            ],
          ),
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
            onPressed: () async {
              if (wardNoController.text.trim().isEmpty || wardNameController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please fill all fields')),
                );
                return;
              }

              try {
                setState(() {
                  isLoading = true;
                });
                Navigator.pop(context);

                if (isEditing) {
                  // Update existing ward
                  await FirebaseFirestore.instance
                      .collection('wards')
                      .doc(ward['id'])
                      .update({
                    'ward_no': wardNoController.text.trim(),
                    'ward_name': wardNameController.text.trim(),
                  });
                } else {
                  // Add new ward
                  await FirebaseFirestore.instance.collection('wards').add({
                    'ward_no': wardNoController.text.trim(),
                    'ward_name': wardNameController.text.trim(),
                  });
                }

                fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isEditing ? 'Ward updated successfully' : 'Ward added successfully'),
                      backgroundColor: accentColor,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
                  );
                }
              }
            },
            child: Text(isEditing ? 'Update' : 'Add'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String type, Map<String, dynamic> item) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete ${type.capitalize()}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          'Are you sure you want to delete this ${type}? This action cannot be undone.',
        ),
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
              try {
                setState(() {
                  isLoading = true;
                });
                Navigator.pop(context);

                // Delete document from Firestore
                await FirebaseFirestore.instance
                    .collection('${type}s')
                    .doc(item['id'])
                    .delete();

                fetchData();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${type.capitalize()} deleted successfully'),
                      backgroundColor: accentColor,
                    ),
                  );
                }
              } catch (e) {
                setState(() {
                  isLoading = false;
                });
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e')),
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

// Helper extension
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}