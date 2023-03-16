import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_service_app/core/constants/constants.dart';
import 'package:flutter/foundation.dart';

class UserChat {
  String id;
  String photoUrl;
  String nickname;
  String aboutMe;

  UserChat({required this.id, required this.photoUrl, required this.nickname, required this.aboutMe});

  Map<String, String> toJson() {
    return {
      FirestoreConstants.nickname: nickname,
      FirestoreConstants.aboutMe: aboutMe,
      FirestoreConstants.photoUrl: photoUrl,
    };
  }

  factory UserChat.fromDocument(DocumentSnapshot doc) {
    String aboutMe = "";
    String photoUrl = "";
    String nickname = "";
    try {
      aboutMe = doc.get(FirestoreConstants.aboutMe);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    try {
      photoUrl = doc.get(FirestoreConstants.photoUrl);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    try {
      nickname = doc.get(FirestoreConstants.nickname);
    } catch (e) {
      if (kDebugMode) {
        print(e);
      }
    }
    return UserChat(
      id: doc.id,
      photoUrl: photoUrl,
      nickname: nickname,
      aboutMe: aboutMe,
    );
  }
}
