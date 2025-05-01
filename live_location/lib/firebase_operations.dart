import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<String> login(String email, String password) async {
  try{
    UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email ,
      password: password,
    );
    User? user = userCredential.user;
    if (user != null && user.emailVerified) {
      return "1";
    }
    else if(user != null){
      await user.delete();
      await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
    }
    return "Email not verified. Please verify your email.";
  }
  on FirebaseAuthException catch (e) {
    // print(e.code);
    return e.message ?? "An error occured";
  }
}

Future<String> signUp(String userEmail, String userPassword, String wardNumber) async {
  try {
    final UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: userEmail,
      password: userPassword,
    );
    await userCredential.user?.sendEmailVerification();
    User? user = userCredential.user;

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': userEmail,
        'ward_number': int.parse(wardNumber),
        'role' : 'user'
      });
    }
    return "1";
  } catch (e) {
    return e.toString();
  }
}

Future<Map<String, dynamic>> fetchWards() async {
  try {
    final QuerySnapshot wardSnapshot = await FirebaseFirestore.instance
        .collection('wards')
        .get();

    Map<String, dynamic> wardsMap = {};

    for (var doc in wardSnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final wardNo = data['number']?.toString() ?? doc.id;
      final wardName = data['name'] ?? '';

      wardsMap[wardNo] = wardName;
    }

    return wardsMap;
  } catch (e) {
    print('Error fetching wards: $e');
    return {};
  }
}

Future<Map<String, dynamic>> fetchCombinedData() async {
  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Map<String, dynamic> user = await fetchCurrentUserData() ;

  final vehicleSnapshot = await firestore
      .collection('vehicles')
      .where('ward_no', isEqualTo: user['ward_number'])
      .get();
  final wardSnapshot = await firestore.collection('wards').get();

  final vehicles = vehicleSnapshot.docs.map((doc) {
    return  Map<String, dynamic>.from(doc.data() as Map);
  }).toList();

  final wardsMap = Map.fromEntries(
    wardSnapshot.docs.map((doc) {
      final data = Map<String, dynamic>.from(doc.data() as Map);
      return MapEntry(
        data['number'].toString(),
        data['name'].toString(),
      );
    }),
  );

  return {
    'vehicles': vehicles,
    'wards': wardsMap,
  };
}

Future<Map<String, dynamic>> fetchCurrentUserData() async {
  final User? user = FirebaseAuth.instance.currentUser;

  if (user != null) {
    final userSnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();

    if (userSnapshot.exists) {
      final userData = userSnapshot.data() as Map<String, dynamic>;
      // print("User data: $userData");
      return userData;
    } else {
      // print("User document does not exist.");
    }
  } else {
    // print("No user is logged in.");
  }
  return <String, dynamic>{};
}

