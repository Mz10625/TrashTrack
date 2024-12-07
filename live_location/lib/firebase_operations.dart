

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

Future<int> login(String email, String password) async {
  try{
    await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email ,
      password: password,
    );
    return 1;
  }
  on FirebaseAuthException catch (e) {
    print(e.code);
    if(e.code == "network-request-failed"){
      return -1;
    }
    else{
      return -2;
    }

  }
}

Future<String> signUp(String userEmail, String userPassword, String wardNumber) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: userEmail,
      password: userPassword,
    );

    User? user = userCredential.user;

    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'email': userEmail,
        'wardNumber': wardNumber,
      });
    }
    return "1";
  } catch (e) {
    return e.toString();
  }
}