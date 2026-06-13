import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

class PresenceService with WidgetsBindingObserver {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  
  StreamSubscription? _authSubscription;
  StreamSubscription? _settingsSubscription;
  bool _showOnlineStatus = true;
  String? _currentUserId;

  bool get showOnlineStatus => _showOnlineStatus;

  PresenceService() {
    _init();
  }

  void _init() {
    WidgetsBinding.instance.addObserver(this);
    
    _authSubscription = _auth.authStateChanges().listen((user) {
      if (user != null) {
        _currentUserId = user.uid;
        _listenToSettings(user.uid);
        _updateStatus(true);
      } else {
        if (_currentUserId != null) {
          _updateStatus(false);
          _currentUserId = null;
        }
        _settingsSubscription?.cancel();
      }
    });
  }

  void _listenToSettings(String userId) {
    _settingsSubscription?.cancel();
    // 🛑 REMOVED BY USER REQUEST (Performance/Privacy)
    return;

    /*
    _settingsSubscription = _firestore
        .collection('users')
        .doc(userId)
        .snapshots()
        .listen((doc) {
      if (doc.exists) {
        final data = doc.data()!;
        final newValue = data['showOnlineStatus'] ?? true;
        
        // If settings changed from true to false, update status immediately to offline
        if (_showOnlineStatus && !newValue) {
          _showOnlineStatus = false;
          _updateStatus(false);
        } else {
          _showOnlineStatus = newValue;
          if (_showOnlineStatus) {
            _updateStatus(true);
          }
        }
      }
    });
    */
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_currentUserId == null) return;

    if (state == AppLifecycleState.resumed) {
      _updateStatus(true);
    } else {
      _updateStatus(false);
    }
  }

  Future<void> _updateStatus(bool isOnline) async {
    final uid = _currentUserId;
    if (uid == null) return;

    // IMPORTANT: If user wants to hide status, we always report offline to others
    final effectiveOnline = _showOnlineStatus ? isOnline : false;

    // 🛑 REMOVED BY USER REQUEST (Performance/Privacy)
    return;

    /*
    try {
      await _firestore.collection('users').doc(uid).update({
        'isOnline': effectiveOnline,
        'lastSeen': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('PresenceService Error: $e');
    }
    */
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _authSubscription?.cancel();
    _settingsSubscription?.cancel();
  }
}
