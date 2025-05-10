import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/cupertino.dart';
import 'package:geolocator/geolocator.dart';

class FirestoreService {
  final CollectionReference _vehiclesCollection = FirebaseFirestore.instance.collection('vehicles');

  DocumentReference? getVehicleDocRef(String vehicleNumber) {
    try{
      return _vehiclesCollection.doc(vehicleNumber);
    }
    catch(err){
      return null;
    }
  }

  Future<bool> checkVehicleExists(String vehicleNumber) async {
    try{
      int vehicleNum = int.tryParse(vehicleNumber) ?? 0;

      var query = await _vehiclesCollection
          .where('vehicle_no', isEqualTo: vehicleNum)
          .limit(1)
          .get();

      return query.docs.isNotEmpty;
    }
    catch(err){
      return false;
    }
  }


  Future<Map<String, dynamic>?> getVehicleData(String vehicleNumber) async {
    try{
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
    catch(err){
      return null;
    }
  }


  Future<void> updateVehicleStatus(String vehicleNumber, bool isActive) async {
    try{
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
    catch(err){
      return;
    }
  }


  Future<void> updateVehicleLocation(String vehicleNumber, Position position) async {
    try{
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
    catch(err){
      return;
    }
  }


  Future<List<Map<String, dynamic>>?> getAllVehicles() async {
    try{
      var query = await _vehiclesCollection.get();
      return query.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return data;
      }).toList();
    }
    catch(err){
      return null;
    }
  }

  Stream<DocumentSnapshot>? getVehicleDataStream(String vehicleNumber) {
    try{
      final vehicleRef = FirebaseFirestore.instance
          .collection('vehicles')
          .doc(vehicleNumber);

      return vehicleRef.snapshots();
    }
    catch(err){
      return null;
    }
  }
}