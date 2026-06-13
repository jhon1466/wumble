
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('users').limit(1).get();
  if (snapshot.docs.isNotEmpty) {
    print('User Data: ${snapshot.docs.first.data()}');
  } else {
    print('No users found.');
  }
}
