import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActiveVehiclesScreen extends StatefulWidget {
  const ActiveVehiclesScreen({super.key});

  @override
  State<ActiveVehiclesScreen> createState() => _ActiveVehiclesScreenState();
}

class _ActiveVehiclesScreenState extends State<ActiveVehiclesScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // title: Text('Active Vehicles'),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            UserAccountsDrawerHeader(
              accountName: Text('John Doe'),
              accountEmail: Text('johndoe@example.com'),
              currentAccountPicture: CircleAvatar(
                child: Icon(Icons.person),
              ),
            ),
            ListTile(
              leading: Icon(Icons.update),
              title: Text('Update Profile'),
              onTap: () {
                // Navigate to update profile screen
              },
            ),
            ListTile(
              leading: Icon(Icons.logout),
              title: Text('Logout'),
              onTap: () {
                // Implement logout functionality
              },
            ),
          ],
        ),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
                padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
                child: Text(
                  'Active Vehicles',
                  style: Theme.of(context).textTheme.headlineLarge,
                ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(5, 0, 0, 0),
              child: Text(
                'View real time location',
                style: TextStyle(fontSize: 15, color: Color.fromRGBO(99, 111, 129, 1), fontWeight: FontWeight.w500),
                // style: Theme.of(context).textTheme.labelLarge,
              ),
            ),
            SizedBox(height: 16.0),
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: _firestore.collection('vehicles').snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  if (!snapshot.hasData) {
                    return Center(child: CircularProgressIndicator());
                  }

                  final vehicles = snapshot.data!.docs;
                  return SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(

                      columns: [
                        DataColumn(label: Text('Vehicle No.')),
                        DataColumn(label: Text('Ward No.')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: vehicles.map((vehicle) {
                        final data = vehicle.data() as Map<String, dynamic>;
                        return DataRow(
                          cells: [
                            DataCell(Text('${data['vehicle_no']}')),
                            DataCell(Text('${data['ward_no']}')),
                            DataCell(Text('${data['status']}')),
                          ],
                        );
                      }).toList(),
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 16.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () {
                    // Navigate to view location screen
                  },
                  child: Text('View Location'),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}