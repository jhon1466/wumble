
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final snapshot = await FirebaseFirestore.instance.collection('chatRooms').get();
  for (var doc in snapshot.docs) {
    print('Room ID: ${doc.id}');
    final data = doc.data();
    print('Participants: ${data['participants']}');
    print('UnreadCounts: ${data['unreadCounts']}');
    print('LastMessage: ${data['lastMessage']}');
    print('---');
  }
}
