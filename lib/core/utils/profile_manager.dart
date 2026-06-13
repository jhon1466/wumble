import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:rxdart/subjects.dart';

class ProfileStreamController {
  final BehaviorSubject<Map<String, dynamic>> subject;
  StreamSubscription? subscription;
  int refCount = 0;

  ProfileStreamController(this.subject);
}

class UserProfileManager {
  static final Map<String, ProfileStreamController> _profileStreams = {};
  static final Map<String, ProfileStreamController> _memberStreams = {};

  static Stream<Map<String, dynamic>> getProfileStream(String uid) {
    if (!_profileStreams.containsKey(uid)) {
      final subject = BehaviorSubject<Map<String, dynamic>>();
      final controller = ProfileStreamController(subject);
      
      controller.subscription = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          subject.add(doc.data()!);
        }
      });
      
      _profileStreams[uid] = controller;
    }
    
    final controller = _profileStreams[uid]!;
    controller.refCount++;
    return controller.subject.stream;
  }

  static void releaseProfileStream(String uid) {
    final controller = _profileStreams[uid];
    if (controller != null) {
      controller.refCount--;
      if (controller.refCount <= 0) {
        controller.subscription?.cancel();
        controller.subject.close();
        _profileStreams.remove(uid);
      }
    }
  }

  static Stream<Map<String, dynamic>> getMemberStream(String uid, String communityId) {
    final key = '${uid}_$communityId';
    if (!_memberStreams.containsKey(key)) {
      final subject = BehaviorSubject<Map<String, dynamic>>();
      final controller = ProfileStreamController(subject);
      
      controller.subscription = FirebaseFirestore.instance
          .collection('communities')
          .doc(communityId)
          .collection('members')
          .doc(uid)
          .snapshots()
          .listen((doc) {
        if (doc.exists) {
          subject.add(doc.data()!);
        }
      });
      
      _memberStreams[key] = controller;
    }
    
    final controller = _memberStreams[key]!;
    controller.refCount++;
    return controller.subject.stream;
  }

  static void releaseMemberStream(String uid, String communityId) {
    final key = '${uid}_$communityId';
    final controller = _memberStreams[key];
    if (controller != null) {
      controller.refCount--;
      if (controller.refCount <= 0) {
        controller.subscription?.cancel();
        controller.subject.close();
        _memberStreams.remove(key);
      }
    }
  }

  /// Manually update the cache for instant local reflection
  static void updateCache(String uid, Map<String, dynamic> data, {String? communityId}) {
     if (communityId != null) {
       final key = '${uid}_$communityId';
       _memberStreams[key]?.subject.add(data);
     } else {
       _profileStreams[uid]?.subject.add(data);
     }
  }
}
