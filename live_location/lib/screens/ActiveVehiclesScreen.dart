import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:live_location/screens/FeedbackScreen.dart';
import 'package:live_location/screens/login.dart';
import 'package:live_location/screens/map_screen.dart';
import 'package:live_location/services/firebase_operations.dart';
import 'package:live_location/services/notificationController.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';


class ActiveVehiclesScreen extends StatefulWidget {
  const ActiveVehiclesScreen({super.key});

  @override
  State<ActiveVehiclesScreen> createState() => _ActiveVehiclesScreenState();
}

class _ActiveVehiclesScreenState extends State<ActiveVehiclesScreen> {
  final user = FirebaseAuth.instance.currentUser;
  List<Map<String, dynamic>> vehicles = [];
  Map<String, dynamic> wardsMap = {};
  bool isLoading = true;
  Map<String, dynamic>? currentUserData;
  bool hasActiveVehicles = false;
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  String? _token;

  final Color primaryColor = const Color(0xFF3F51B5);
  final Color accentColor = const Color(0xFF4CAF50);
  final Color backgroundColor = const Color(0xFFF5F7FA);
  final Color cardColor = Colors.white;
  final Color inactiveColor = const Color(0xFFE57373);

  @override
  void initState() {
    super.initState();
    _setupRealTimeUpdates();

    NotificationController.initializeNotificationListeners();
    _initializeFCM();
  }

  void _setupRealTimeUpdates() async {
    try {
      currentUserData = await fetchCurrentUserData();

      if (currentUserData == null || currentUserData!['ward_number'] == null) {
        setState(() {
          isLoading = false;
        });
        return;
      }

      wardsMap = await fetchWards();

      FirebaseFirestore.instance
          .collection('vehicles')
          .where('ward_no', isEqualTo: currentUserData!['ward_number'])
          .snapshots()
          .listen((snapshot) {
        setState(() {
          vehicles = snapshot.docs
              .map((doc) => Map<String, dynamic>.from(doc.data() as Map))
              .toList();


          hasActiveVehicles = vehicles.any((vehicle) => vehicle['status'] == 'Active');
          isLoading = false;
        });
      }, onError: (error) {
        debugPrint("Error in vehicles stream: $error");
        setState(() {
          isLoading = false;
        });
      });
    } catch (e) {
      debugPrint("Error setting up real-time updates: $e");
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _initializeFCM() async {
    NotificationSettings settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      );

      await _manageTokenEfficiently();

      _setupMessageListeners();

      FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
        if (message != null) {
          _handleNotificationPressed(message.data);
        }
      });
    }
  }

  Future<void> _manageTokenEfficiently() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? newToken = await _messaging.getToken();
      String? oldToken = prefs.getString('fcm_token');

      if (newToken != null) {
        setState(() {
          _token = newToken;
        });

        if (newToken != oldToken) {
          await prefs.setString('fcm_token', newToken);

          User? currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser != null) {
            await FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .update({
              'fcmToken': newToken,
              'tokenUpdatedAt': FieldValue.serverTimestamp(),
            });
          }
        }
      }

      _messaging.onTokenRefresh.listen((refreshedToken) {
        setState(() {
          _token = refreshedToken;
        });

        _storeAndRegisterNewToken(refreshedToken);
      });

    }
    catch (e) {
      print('Error managing FCM token');
    }
  }

  Future<void> _storeAndRegisterNewToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('fcm_token', token);

      User? currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser.uid)
            .update({
          'fcmToken': token,
          'tokenUpdatedAt': FieldValue.serverTimestamp(),
        });
      }
    }
    catch (e) {
      print('Error storing new token');
    }
  }

  void _setupMessageListeners() {

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      if (message.notification != null) {
        AwesomeNotifications().createNotification(
          content: NotificationContent(
            id: message.hashCode,
            channelKey: 'vehicle_updates',
            title: message.notification?.title ?? 'Vehicle Update',
            body: message.notification?.body ?? 'A vehicle status has changed',
            notificationLayout: NotificationLayout.Default,
            icon: 'resource://drawable/notification_icon',
            largeIcon: 'resource://drawable/app_icon',
            payload: message.data.map((key, value) => MapEntry(key, value.toString())),
          ),
          actionButtons: [
            NotificationActionButton(
              key: 'VIEW_DETAILS',
              label: 'View Details',
            ),
            NotificationActionButton(
              key: 'DISMISS',
              label: 'Dismiss',
              isDangerousOption: true,
            ),
          ],
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _handleNotificationPressed(message.data);
    });
  }

  void _handleNotificationPressed(Map<String, dynamic> data) {
    if (data.containsKey('vehicleId')) {
      // Navigator.push(
      //   context,
      //   MaterialPageRoute(
      //     builder: (context) => VehicleDetailsScreen(vehicleId: data['vehicleId']),
      //   ),
      // );
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
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() {
                isLoading = true;
              });
              _setupRealTimeUpdates();
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      drawer: Drawer(
        elevation: 2,
        child: Container(
          color: cardColor,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                children: [
                  UserAccountsDrawerHeader(
                    accountName: Text(
                      currentUserData?['role'] == 'admin' ? 'Admin' : 'User',
                      style: const TextStyle(
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
                      child: Icon(Icons.person, color: primaryColor, size: 40),
                    ),
                    decoration: BoxDecoration(
                      color: primaryColor,
                    ),
                  ),
                  ListTile(
                    leading: Icon(Icons.home, color: primaryColor),
                    title: const Text('Home'),
                    onTap: () {
                      Navigator.pop(context);
                    },
                  ),
                  ListTile(
                    leading: Icon(Icons.location_on, color: primaryColor),
                    title: const Text('Map View'),
                    onTap: hasActiveVehicles
                        ? () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MapScreen(),
                        ),
                      );
                    }
                        : null,
                    enabled: hasActiveVehicles,
                  ),
                  ListTile(
                    leading: Icon(Icons.feedback, color: primaryColor),
                    title: const Text('Submit Feedback'),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FeedbackScreen(),
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
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Container(
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
                    Row(
                      children: [
                        Icon(
                          Icons.directions_bus_rounded,
                          color: primaryColor,
                          size: 28,
                        ),
                        const SizedBox(width: 10),
                        Text(
                          'Vehicles',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentUserData != null
                          ? 'Garbage collection vehicles in ward ${currentUserData!['ward_number']}'
                          : 'Garbage collection vehicles in your area',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildStatusIndicator('Active', accentColor),
                        const SizedBox(width: 16),
                        _buildStatusIndicator('Inactive', inactiveColor),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // Vehicles Table
              Expanded(
                child: isLoading
                    ? Center(child: CircularProgressIndicator(color: primaryColor))
                    : vehicles.isEmpty
                    ? _buildEmptyState()
                    : _buildVehiclesTable(),
              ),

              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: hasActiveVehicles ? primaryColor : Colors.grey.shade300,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                    ),
                    elevation: hasActiveVehicles ? 3 : 0,
                  ),
                  icon: const Icon(Icons.location_on),
                  label: const Text(
                    'View Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                  onPressed: hasActiveVehicles
                      ? () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const MapScreen(),
                      ),
                    );
                  }
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String status, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          status,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.w500,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.no_transfer,
            size: 80,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No vehicles available in your ward',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back later for updates',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade500,
            ),
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
                    headingRowColor: WidgetStateProperty.all(
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
                          'Ward Name',
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
                    ],
                    rows: vehicles.asMap().entries.map((entry) {
                      int index = entry.key;
                      var vehicle = entry.value;
                      final wardNo = vehicle['ward_no'].toString();
                      final wardName = wardsMap[wardNo] ?? '';
                      final isActive = vehicle['status'] == 'Active';

                      return DataRow(
                        color: WidgetStateProperty.resolveWith<Color>(
                              (Set<WidgetState> states) {
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
                              wardNo,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                          DataCell(
                            Text(
                              wardName,
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
}

