import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:chat_service_app/core/constants/constants.dart';

class MessageChat {
  String idFrom;
  String idTo;
  String timestamp;
  String content;
  String? duration;
  String? fileName;
  int? fileSize;
  int type;

  MessageChat({
    required this.idFrom,
    required this.idTo,
    required this.timestamp,
    required this.content,
    this.duration,
    this.fileName,
    this.fileSize,
    required this.type,
  });

  Map<String, dynamic> toJson() {
    return {
      FirestoreConstants.idFrom: idFrom,
      FirestoreConstants.idTo: idTo,
      FirestoreConstants.timestamp: timestamp,
      FirestoreConstants.content: content,
      FirestoreConstants.duration: duration,
      FirestoreConstants.fileName: fileName,
      FirestoreConstants.fileSize: fileSize,
      FirestoreConstants.type: type,
    };
  }

  factory MessageChat.fromDocument(DocumentSnapshot doc) {
    String idFrom = doc.get(FirestoreConstants.idFrom);
    String idTo = doc.get(FirestoreConstants.idTo);
    String timestamp = doc.get(FirestoreConstants.timestamp);
    String content = doc.get(FirestoreConstants.content);
    String duration = doc.get(FirestoreConstants.duration);
    String fileName = doc.get(FirestoreConstants.fileName);
    int fileSize = doc.get(FirestoreConstants.fileSize);
    int type = doc.get(FirestoreConstants.type);
    return MessageChat(
        idFrom: idFrom,
        idTo: idTo,
        timestamp: timestamp,
        content: content,
        duration: duration,
        fileName: fileName,
        fileSize: fileSize,
        type: type);
  }
}
