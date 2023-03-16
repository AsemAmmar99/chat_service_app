import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:chat_service_app/core/constants/constants.dart';
import 'package:chat_service_app/data/models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ChatProvider {
  final SharedPreferences prefs;
  final FirebaseFirestore firebaseFirestore;
  final FirebaseStorage firebaseStorage;

  ChatProvider(
      {required this.firebaseFirestore,
      required this.prefs,
      required this.firebaseStorage});

  String? getPref(String key) {
    return prefs.getString(key);
  }

  UploadTask uploadImage(File image, String fileName) {
    Reference reference = firebaseStorage.ref().child('image/').child(fileName);
    UploadTask uploadTask = reference.putFile(image);
    return uploadTask;
  }

  UploadTask uploadFile(File document, String fileName) {
    Reference reference = firebaseStorage.ref().child('file/').child(fileName);
    UploadTask uploadTask = reference.putFile(document);
    return uploadTask;
  }

  UploadTask uploadAudio(var audioFile, String fileName) {
    Reference reference = firebaseStorage.ref().child(fileName);
    UploadTask uploadTask = reference.putFile(audioFile);
    return uploadTask;
  }

  Future<void> updateDataFirestore(String collectionPath, String docPath,
      Map<String, dynamic> dataNeedUpdate) {
    return firebaseFirestore
        .collection(collectionPath)
        .doc(docPath)
        .update(dataNeedUpdate);
  }

  Stream<QuerySnapshot> getChatStream(String groupChatId, int limit) {
    return firebaseFirestore
        .collection(FirestoreConstants.pathMessageCollection)
        .doc(groupChatId)
        .collection(groupChatId)
        .orderBy(FirestoreConstants.timestamp, descending: true)
        .limit(limit)
        .snapshots();
  }

  void sendMessage(
    String content,
    int type,
    String groupChatId,
    String currentUserId,
    String peerId, {
    String duration = "",
    String fileName = "",
    int fileSize = 0,
  }) {
    DocumentReference documentReference = firebaseFirestore
        .collection('messages')
        .doc(groupChatId)
        .collection(groupChatId)
        .doc(DateTime.now().millisecondsSinceEpoch.toString());

    MessageChat messageChat = MessageChat(
        idFrom: currentUserId,
        idTo: peerId,
        timestamp: DateTime.now().millisecondsSinceEpoch.toString(),
        content: content,
        type: type,
        duration: duration,
        fileName: fileName,
        fileSize: fileSize);

    FirebaseFirestore.instance.runTransaction((transaction) async {
      transaction.set(
        documentReference,
        messageChat.toJson(),
      );
    });
  }
}

class TypeMessage {
  static const text = 0;
  static const image = 1;
  static const sticker = 2;
  static const audio = 3;
  static const file = 4;
}
