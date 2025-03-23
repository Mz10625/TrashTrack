import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreService {
  // final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CollectionReference _vehiclesCollection = FirebaseFirestore.instance.collection('vehicles');

  // Get vehicle document reference
  DocumentReference getVehicleDocRef(String vehicleNumber) {
    int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

    return _vehiclesCollection.doc(vehicleNumber);
  }

  // Check if vehicle exists in Firestore
  Future<bool> checkVehicleExists(String vehicleNumber) async {
    int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

    var query = await _vehiclesCollection
        .where('vehicle_no', isEqualTo: vehicleNum)
        .limit(1)
        .get();

    return query.docs.isNotEmpty;
  }

  // Get vehicle data
  Future<Map<String, dynamic>?> getVehicleData(String vehicleNumber) async {
    int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

    var query = await _vehiclesCollection
        .where('vehicle_no', isEqualTo: vehicleNum)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return query.docs.first.data() as Map<String, dynamic>;
    }

    return null;
  }

  // Update vehicle status
  Future<void> updateVehicleStatus(String vehicleNumber, bool isActive) async {
    int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

    var query = await _vehiclesCollection
        .where('vehicle_no', isEqualTo: vehicleNum)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      String docId = query.docs.first.id;
      await _vehiclesCollection.doc(docId).update({
        'status': isActive ? 'Active' : 'Inactive',
        'last_updated': FieldValue.serverTimestamp(),
      });
    }
  }

  // Update vehicle location
  Future<void> updateVehicleLocation(String vehicleNumber, Position position) async {
    int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

    var query = await _vehiclesCollection
        .where('vehicle_no', isEqualTo: vehicleNum)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      String docId = query.docs.first.id;

      GeoPoint geoPoint = GeoPoint(position.latitude, position.longitude);

      await _vehiclesCollection.doc(docId).update({
        'current_location': geoPoint,
        'last_updated': FieldValue.serverTimestamp(),
      });
    }
  }

  // Get all vehicles
  Future<List<Map<String, dynamic>>> getAllVehicles() async {
    var query = await _vehiclesCollection.get();
    return query.docs.map((doc) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      data['id'] = doc.id; // Add document ID to the data
      return data;
    }).toList();
  }

  Stream<DocumentSnapshot> getVehicleDataStream(String vehicleNumber) {
    final vehicleRef = FirebaseFirestore.instance
        .collection('vehicles')
        .doc(vehicleNumber);

    return vehicleRef.snapshots();
  }
}