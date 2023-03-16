import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:chat_service_app/core/constants/constants.dart';
import 'package:chat_service_app/data/models/models.dart';
import 'package:chat_service_app/business_logic/providers.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:record_mp3/record_mp3.dart';
import 'package:sizer/sizer.dart';

import '../styles/colors.dart';
import '../widgets/widgets.dart';
import 'screens.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({Key? key, required this.arguments}) : super(key: key);

  final ChatPageArguments arguments;

  @override
  ChatPageState createState() => ChatPageState();
}

class ChatPageState extends State<ChatPage> {
  // Needed Variables and Objects
  late String currentUserId;
  bool temp = false;
  bool audio = false;
  List<QueryDocumentSnapshot> listMessage = [];
  int _limit = 20;
  final int _limitIncrement = 20;
  String groupChatId = "";

  File? imageFile;
  File? file;
  bool isLoading = false;
  bool isShowSticker = false;
  String imageUrl = "";
  String fileUrl = "";
  String fileSize = "";
  final ScrollController _scrollController = ScrollController();

  AudioController audioController = Get.put(AudioController());
  AudioPlayer audioPlayer = AudioPlayer();
  String audioURL = "";
  final ReceivePort _port = ReceivePort();

  final TextEditingController textEditingController = TextEditingController();
  final ScrollController listScrollController = ScrollController();
  final FocusNode focusNode = FocusNode();

  late ChatProvider chatProvider;
  late AuthProvider authProvider;
  late SettingProvider settingProvider;

  @override
  void initState() {
    super.initState();
    chatProvider = context.read<ChatProvider>();
    authProvider = context.read<AuthProvider>();
    settingProvider = context.read<SettingProvider>();

    focusNode.addListener(onFocusChange);
    listScrollController.addListener(_scrollListener);
    readLocal();

    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    _port.listen((dynamic data) {
      setState(() {});
    });

    FlutterDownloader.registerCallback(downloadCallback);
  }

  @override
  void dispose() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
    super.dispose();
  }

  static void downloadCallback(
      String id, DownloadTaskStatus status, int progress) {
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  // Handling scrolling when receiving new messages.
  _scrollListener() {
    if (!listScrollController.hasClients) return;
    if (listScrollController.offset >=
            listScrollController.position.maxScrollExtent &&
        !listScrollController.position.outOfRange &&
        _limit <= listMessage.length) {
      setState(() {
        _limit += _limitIncrement;
      });
    }
  }

  void onFocusChange() {
    if (focusNode.hasFocus) {
      // Hide sticker when keyboard appear
      setState(() {
        isShowSticker = false;
      });
    }
  }

  // Asking for microphone permission for voice notes.
  Future<bool> checkPermission() async {
    if (!await Permission.microphone.isGranted) {
      PermissionStatus status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  // Start recording voice notes method.
  void startRecord() async {
    bool hasPermission = await checkPermission();
    if (hasPermission) {
      recordFilePath = await getFilePath();
      RecordMp3.instance.start(recordFilePath, (type) {
        setState(() {});
      });
    } else {}
    setState(() {});
  }

  // Stop recording voice notes method.
  void stopRecord() async {
    bool stop = RecordMp3.instance.stop();
    audioController.end.value = DateTime.now();
    audioController.calcDuration();
    var ap = AudioPlayer();
    await ap.play(AssetSource("Notification.mp3"));
    ap.onPlayerComplete.listen((a) {});
    if (stop) {
      audioController.isRecording.value = false;
      audioController.isSending.value = true;
      await uploadAudio();
    }
  }

  int i = 0;

  // Getting recorded voice note path in mobile storage.
  Future<String> getFilePath() async {
    Directory storageDirectory = await getApplicationDocumentsDirectory();
    String sdPath =
        "${storageDirectory.path}/record${DateTime.now().microsecondsSinceEpoch}.acc";
    var d = Directory(sdPath);
    if (!d.existsSync()) {
      d.createSync(recursive: true);
    }
    return "$sdPath/test_${i++}.mp3";
  }

  // Uploading voice record to firebase storage and send it into a message.
  uploadAudio() async {
    UploadTask uploadTask = chatProvider.uploadAudio(File(recordFilePath),
        "audio/${DateTime.now().millisecondsSinceEpoch.toString()}");
    try {
      TaskSnapshot snapshot = await uploadTask;
      audioURL = await snapshot.ref.getDownloadURL();
      String strVal = audioURL.toString();
      setState(() {
        audioController.isSending.value = false;
        onSendMessage(strVal, TypeMessage.audio,
            duration: audioController.total);
      });
    } on FirebaseException catch (e) {
      setState(() {
        audioController.isSending.value = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  late String recordFilePath;

  // Checking if the user's account is still exist and available.
  void readLocal() {
    if (authProvider.getUserFirebaseId()?.isNotEmpty == true) {
      currentUserId = authProvider.getUserFirebaseId()!;
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    }
    String peerId = widget.arguments.peerId;
    if (currentUserId.compareTo(peerId) > 0) {
      groupChatId = '$currentUserId-$peerId';
    } else {
      groupChatId = '$peerId-$currentUserId';
    }

    chatProvider.updateDataFirestore(
      FirestoreConstants.pathUserCollection,
      currentUserId,
      {FirestoreConstants.chattingWith: peerId},
    );
  }

  // Choosing an image from gallery and calling uploadImage method.
  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? pickedImage;

    pickedImage = await imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedImage != null) {
      imageFile = File(pickedImage.path);
      if (imageFile != null) {
        setState(() {
          isLoading = true;
        });
        uploadImage();
      }
    }
  }

  // Choosing a file from the local storage and calling uploadFile method.
  Future getFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();

    if (result != null) {
      file = File(result.files.single.path!);
      if (file != null) {
        setState(() {
          isLoading = true;
        });
        uploadFile(
            pickedFileName: result.files.first.name,
            pickedFileSize: result.files.first.size);
      }
    }
  }

  // Converting uploaded file size from bytes into the suitable suffix.
  String getFileSize(int sizeInBytes) {
    if (sizeInBytes <= 0) return "0 B";
    const suffixes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
    var i = (log(sizeInBytes) / log(1024)).floor();
    return fileSize =
        '${(sizeInBytes / pow(1024, i)).toStringAsFixed(2)} ${suffixes[i]}';
  }

  // Download a file from chat.
  void downloadFile(String downloadUrl) async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      final externalDir = Platform.isAndroid
          ? await getExternalStorageDirectory()
          : await getApplicationDocumentsDirectory();
      setState(
        () {
          Fluttertoast.showToast(
              msg: 'Download Started..', backgroundColor: Colors.grey);
        },
      );
      final taskId = await FlutterDownloader.enqueue(
        url: downloadUrl,
        savedDir: externalDir!.path + Platform.pathSeparator,
        showNotification:
            true, // show download progress in status bar (for Android)
        openFileFromNotification:
            true, // click on notification to open downloaded file (for Android)
        saveInPublicStorage: true,
      ).then((value) {
        setState(
              () {
            Fluttertoast.showToast(
                msg: 'Download Completed..', backgroundColor: Colors.grey);
          },
        );
      }).catchError((error){
        setState(
              () {
            Fluttertoast.showToast(
                msg: 'Download Failed..', backgroundColor: Colors.grey);
          },
        );
      });

      if (taskId != null) {
        FlutterDownloader.open(taskId: taskId);
      }
    } else {
      if (kDebugMode) {
        print('Permission Denied');
      }
    }
  }

  // Open Stickers menu.
  void getSticker() {
    // Hide keyboard when stickers menu appear
    focusNode.unfocus();
    setState(() {
      isShowSticker = !isShowSticker;
    });
  }

  // Uploading image to firebase storage and send it into a message.
  Future uploadImage() async {
    String fileName = DateTime.now().millisecondsSinceEpoch.toString();
    UploadTask uploadTask = chatProvider.uploadImage(imageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      imageUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        isLoading = false;
        onSendMessage(imageUrl, TypeMessage.image);
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  // Uploading voice record to firebase storage and send it into a message.
  Future uploadFile({
    required String pickedFileName,
    required int pickedFileSize,
  }) async {
    String fileName = pickedFileName;
    UploadTask uploadTask = chatProvider.uploadFile(file!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      fileUrl = await snapshot.ref.getDownloadURL();
      setState(() {
        isLoading = false;
        onSendMessage(
          fileUrl,
          TypeMessage.file,
          fileSize: pickedFileSize,
          fileName: fileName,
        );
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  // Text message validation ( send if not empty ).
  void onSendMessage(
    String content,
    int type, {
    String duration = "",
    String fileName = "",
    int fileSize = 0,
  }) {
    if (content.trim().isNotEmpty) {
      textEditingController.clear();
      chatProvider.sendMessage(
        content,
        type,
        groupChatId,
        currentUserId,
        widget.arguments.peerId.toString(),
        duration: duration,
        fileSize: fileSize,
        fileName: fileName,
      );
      if (_scrollController.hasClients) {
        _scrollController.animateTo(0,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    } else {
      Fluttertoast.showToast(
          msg: 'Nothing to send', backgroundColor: Colors.grey);
    }
  }

  Widget buildItem(int index, DocumentSnapshot? document) {
    if (document != null) {
      MessageChat messageChat = MessageChat.fromDocument(document);
      if (messageChat.idFrom == currentUserId) {
        // Right (my message)
        return Row(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            // Text
            if (messageChat.type == TypeMessage.text)
              Container(
                padding:
                    EdgeInsets.symmetric(vertical: 1.4.h, horizontal: 3.5.w),
                width: 200,
                decoration: BoxDecoration(
                    color: MyColors.greyColor2,
                    borderRadius: BorderRadius.circular(8)),
                margin: EdgeInsetsDirectional.only(
                    bottom: isLastMessageRight(index) ? 2.8.h : 1.4.h,
                    end: 3.w),
                child: Text(
                  messageChat.content,
                  style: const TextStyle(color: MyColors.primaryColor),
                ),
              ),
            // Image
            if (messageChat.type == TypeMessage.image)
              Container(
                margin: EdgeInsetsDirectional.only(
                    bottom: isLastMessageRight(index) ? 2.8.h : 1.4.h,
                    end: 3.w),
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => FullPhotoPage(
                          url: messageChat.content,
                        ),
                      ),
                    );
                  },
                  style: ButtonStyle(
                      padding: MaterialStateProperty.all<EdgeInsets>(
                          const EdgeInsets.all(0))),
                  child: Material(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      messageChat.content,
                      loadingBuilder: (BuildContext context, Widget child,
                          ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          decoration: const BoxDecoration(
                            color: MyColors.greyColor2,
                            borderRadius: BorderRadius.all(
                              Radius.circular(8),
                            ),
                          ),
                          width: 200,
                          height: 200,
                          child: Center(
                            child: CircularProgressIndicator(
                              color: MyColors.themeColor,
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded /
                                      loadingProgress.expectedTotalBytes!
                                  : null,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, object, stackTrace) {
                        return Material(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(8),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.asset(
                            'assets/img_not_available.jpeg',
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                      width: 200,
                      height: 200,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
            // audio
            if (messageChat.type == TypeMessage.audio)
              Container(
                margin: EdgeInsetsDirectional.only(
                    bottom: isLastMessageRight(index) ? 2.8.h : 1.4.h,
                    end: 3.w),
                child: _audio(
                  message: messageChat.content,
                  isCurrentUser: messageChat.idFrom == currentUserId,
                  index: index,
                  time: messageChat.timestamp.toString(),
                  duration: messageChat.duration.toString(),
                ),
              ),
            // Sticker
            if (messageChat.type == TypeMessage.sticker)
              Container(
                margin: EdgeInsetsDirectional.only(
                    bottom: isLastMessageRight(index) ? 2.8.h : 1.4.h,
                    end: 3.w),
                child: Image.asset(
                  'assets/${messageChat.content}.gif',
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                ),
              ),
            // File
            if (messageChat.type == TypeMessage.file)
              InkWell(
                onTap: () => downloadFile(messageChat.content),
                child: Container(
                  padding:
                      EdgeInsets.symmetric(vertical: 1.4.h, horizontal: 3.5.w),
                  width: 200,
                  decoration: BoxDecoration(
                      color: MyColors.greyColor2,
                      borderRadius: BorderRadius.circular(8)),
                  margin: const EdgeInsetsDirectional.only(end: 10),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.file_open_outlined,
                        color: MyColors.primaryColor,
                      ),
                      Flexible(
                        child: Text(
                          messageChat.fileName!,
                          style: const TextStyle(color: MyColors.primaryColor),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        getFileSize(messageChat.fileSize!),
                        style: const TextStyle(color: MyColors.primaryColor),
                      ),
                    ],
                  ),
                ),
              ),
            // My photo
            isLastMessageRight(index)
                ? Material(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(18),
                    ),
                    clipBehavior: Clip.hardEdge,
                    child: Image.network(
                      settingProvider.getPref(FirestoreConstants.photoUrl)!,
                      loadingBuilder: (BuildContext context, Widget child,
                          ImageChunkEvent? loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: MyColors.themeColor,
                            value: loadingProgress.expectedTotalBytes != null
                                ? loadingProgress.cumulativeBytesLoaded /
                                    loadingProgress.expectedTotalBytes!
                                : null,
                          ),
                        );
                      },
                      errorBuilder: (context, object, stackTrace) {
                        return const Icon(
                          Icons.account_circle,
                          size: 35,
                          color: MyColors.greyColor,
                        );
                      },
                      width: 35,
                      height: 35,
                      fit: BoxFit.cover,
                    ),
                  )
                : Container(width: 35),
          ],
        );
      } else {
        // Left (peer message)
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  isLastMessageLeft(index)
                      ? Material(
                          borderRadius: const BorderRadius.all(
                            Radius.circular(18),
                          ),
                          clipBehavior: Clip.hardEdge,
                          child: Image.network(
                            widget.arguments.peerAvatar,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Center(
                                child: CircularProgressIndicator(
                                  color: MyColors.themeColor,
                                  value: loadingProgress.expectedTotalBytes !=
                                          null
                                      ? loadingProgress.cumulativeBytesLoaded /
                                          loadingProgress.expectedTotalBytes!
                                      : null,
                                ),
                              );
                            },
                            errorBuilder: (context, object, stackTrace) {
                              return const Icon(
                                Icons.account_circle,
                                size: 35,
                                color: MyColors.greyColor,
                              );
                            },
                            width: 35,
                            height: 35,
                            fit: BoxFit.cover,
                          ),
                        )
                      : Container(width: 35),
                  if (messageChat.type == TypeMessage.text)
                    Container(
                      padding: EdgeInsets.symmetric(
                          vertical: 1.4.h, horizontal: 3.5.w),
                      width: 200,
                      decoration: BoxDecoration(
                          color: MyColors.primaryColor,
                          borderRadius: BorderRadius.circular(8)),
                      margin: const EdgeInsetsDirectional.only(start: 10),
                      child: Text(
                        messageChat.content,
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  if (messageChat.type == TypeMessage.image)
                    Container(
                      margin: EdgeInsetsDirectional.only(start: 3.w),
                      child: TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  FullPhotoPage(url: messageChat.content),
                            ),
                          );
                        },
                        style: ButtonStyle(
                            padding: MaterialStateProperty.all<EdgeInsets>(
                                const EdgeInsets.all(0))),
                        child: Material(
                          borderRadius:
                              const BorderRadius.all(Radius.circular(8)),
                          clipBehavior: Clip.hardEdge,
                          child: Image.network(
                            messageChat.content,
                            loadingBuilder: (BuildContext context, Widget child,
                                ImageChunkEvent? loadingProgress) {
                              if (loadingProgress == null) return child;
                              return Container(
                                decoration: const BoxDecoration(
                                  color: MyColors.greyColor2,
                                  borderRadius: BorderRadius.all(
                                    Radius.circular(8),
                                  ),
                                ),
                                width: 200,
                                height: 200,
                                child: Center(
                                  child: CircularProgressIndicator(
                                    color: MyColors.themeColor,
                                    value: loadingProgress.expectedTotalBytes !=
                                            null
                                        ? loadingProgress
                                                .cumulativeBytesLoaded /
                                            loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                ),
                              );
                            },
                            errorBuilder: (context, object, stackTrace) =>
                                Material(
                              borderRadius: const BorderRadius.all(
                                Radius.circular(8),
                              ),
                              clipBehavior: Clip.hardEdge,
                              child: Image.asset(
                                'assets/img_not_available.jpeg',
                                width: 200,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                            width: 200,
                            height: 200,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                  if (messageChat.type == TypeMessage.audio)
                    Container(
                      margin: EdgeInsetsDirectional.only(
                          bottom: isLastMessageRight(index) ? 1.4.h : 2.8.h,
                          start: 3.w),
                      child: _audio(
                        message: messageChat.content,
                        isCurrentUser: messageChat.idFrom == currentUserId,
                        index: index,
                        time: messageChat.timestamp.toString(),
                        duration: messageChat.duration.toString(),
                      ),
                    ),
                  if (messageChat.type == TypeMessage.sticker)
                    Container(
                      margin: EdgeInsetsDirectional.only(
                          bottom: isLastMessageRight(index) ? 2.8.h : 1.4.h,
                          start: 3.w),
                      child: Image.asset(
                        'assets/${messageChat.content}.gif',
                        width: 100,
                        height: 100,
                        fit: BoxFit.cover,
                      ),
                    ),
                  if (messageChat.type == TypeMessage.file)
                    InkWell(
                      onTap: () => downloadFile(messageChat.content),
                      child: Container(
                        padding: EdgeInsets.symmetric(
                            vertical: 1.4.h, horizontal: 3.5.w),
                        width: 200,
                        decoration: BoxDecoration(
                            color: MyColors.primaryColor,
                            borderRadius: BorderRadius.circular(8)),
                        margin: const EdgeInsetsDirectional.only(start: 10),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.file_open_outlined,
                              color: Colors.white,
                            ),
                            Flexible(
                              child: Text(
                                messageChat.fileName!,
                                style: const TextStyle(color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Text(
                              getFileSize(messageChat.fileSize!),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),

              // Time
              isLastMessageLeft(index)
                  ? Container(
                      margin: const EdgeInsetsDirectional.only(
                          start: 50, top: 5, bottom: 5),
                      child: Text(
                        DateFormat('dd MMM kk:mm').format(
                            DateTime.fromMillisecondsSinceEpoch(
                                int.parse(messageChat.timestamp))),
                        style: const TextStyle(
                            color: MyColors.greyColor,
                            fontSize: 12,
                            fontStyle: FontStyle.italic),
                      ),
                    )
                  : const SizedBox.shrink()
            ],
          ),
        );
      }
    } else {
      return const SizedBox.shrink();
    }
  }

  // Check if the last message is from the peer.
  bool isLastMessageLeft(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirestoreConstants.idFrom) ==
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  // Check if the last message is from the user.
  bool isLastMessageRight(int index) {
    if ((index > 0 &&
            listMessage[index - 1].get(FirestoreConstants.idFrom) !=
                currentUserId) ||
        index == 0) {
      return true;
    } else {
      return false;
    }
  }

  // Cancel stickers menu if opened, otherwise, close the chat and go back.
  Future<bool> onBackPress() {
    if (isShowSticker) {
      setState(() {
        isShowSticker = false;
      });
    } else {
      chatProvider.updateDataFirestore(
        FirestoreConstants.pathUserCollection,
        currentUserId,
        {FirestoreConstants.chattingWith: null},
      );
      Navigator.pop(context);
    }

    return Future.value(false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.only(end: 2.w),
              child: Material(
                borderRadius: const BorderRadius.all(
                  Radius.circular(18),
                ),
                clipBehavior: Clip.hardEdge,
                child: Image.network(
                  widget.arguments.peerAvatar,
                  loadingBuilder: (BuildContext context, Widget child,
                      ImageChunkEvent? loadingProgress) {
                    if (loadingProgress == null) return child;
                    return Center(
                      child: CircularProgressIndicator(
                        color: MyColors.themeColor,
                        value: loadingProgress.expectedTotalBytes != null
                            ? loadingProgress.cumulativeBytesLoaded /
                                loadingProgress.expectedTotalBytes!
                            : null,
                      ),
                    );
                  },
                  errorBuilder: (context, object, stackTrace) {
                    return const Icon(
                      Icons.account_circle,
                      size: 35,
                      color: MyColors.greyColor,
                    );
                  },
                  width: 35,
                  height: 35,
                  fit: BoxFit.cover,
                ),
              ),
            ),
            Flexible(
              child: Text(
                widget.arguments.peerNickname,
                style: const TextStyle(color: MyColors.greyColor2),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: WillPopScope(
          onWillPop: onBackPress,
          child: Stack(
            children: <Widget>[
              Column(
                children: <Widget>[
                  // List of messages
                  buildListMessage(),

                  // Sticker
                  isShowSticker ? buildSticker() : const SizedBox.shrink(),

                  // Input content
                  buildInput(),
                ],
              ),

              // Loading
              buildLoading()
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSticker() {
    return Expanded(
      child: Container(
        decoration: const BoxDecoration(
            border:
                Border(top: BorderSide(color: MyColors.greyColor2, width: 0.5)),
            color: Colors.white),
        padding: const EdgeInsets.all(5),
        height: 180,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                TextButton(
                  onPressed: () => onSendMessage('mimi1', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi1.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi2', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi2.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi3', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi3.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                TextButton(
                  onPressed: () => onSendMessage('mimi4', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi4.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi5', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi5.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi6', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi6.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              ],
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: <Widget>[
                TextButton(
                  onPressed: () => onSendMessage('mimi7', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi7.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi8', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi8.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                ),
                TextButton(
                  onPressed: () => onSendMessage('mimi9', TypeMessage.sticker),
                  child: Image.asset(
                    'assets/mimi9.gif',
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget buildLoading() {
    return Positioned(
      child: isLoading ? const LoadingView() : const SizedBox.shrink(),
    );
  }

  Widget buildInput() {
    return Container(
      width: double.infinity,
      height: 8.h,
      decoration: const BoxDecoration(
          border:
              Border(top: BorderSide(color: MyColors.greyColor2, width: 0.5)),
          color: Colors.white),
      child: Row(
        children: <Widget>[
          // Button send image
          Material(
            color: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.image),
              onPressed: getImage,
              color: MyColors.primaryColor,
              constraints: const BoxConstraints(minWidth: 0),
            ),
          ),
          // Button send file
          Material(
            color: Colors.white,
            child: IconButton(
              icon: const Icon(Icons.attachment),
              onPressed: getFile,
              color: MyColors.primaryColor,
              constraints: const BoxConstraints(minWidth: 0),
            ),
          ),
          // Start Record
          GestureDetector(
            child: const Icon(Icons.mic, color: MyColors.primaryColor),
            onLongPress: () async {
              var audioPlayer = AudioPlayer();
              await audioPlayer.play(AssetSource("Notification.mp3"));
              audioPlayer.onPlayerComplete.listen((a) {
                audioController.start.value = DateTime.now();
                startRecord();
                audioController.isRecording.value = true;
              });
            },
            onLongPressEnd: (details) {
              stopRecord();
            },
          ),
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              child: IconButton(
                icon: const Icon(Icons.face),
                onPressed: getSticker,
                color: MyColors.primaryColor,
              ),
            ),
          ),

          // Edit text
          Flexible(
            child: TextField(
              onSubmitted: (value) {
                onSendMessage(textEditingController.text, TypeMessage.text);
              },
              style: TextStyle(color: MyColors.primaryColor, fontSize: 13.sp),
              controller: textEditingController,
              maxLines: 2,
              scrollPhysics: const AlwaysScrollableScrollPhysics(),
              decoration: InputDecoration(
                hintText: 'Type your message...',
                contentPadding: EdgeInsets.only(top: 1.h),
                hintStyle:
                    TextStyle(color: MyColors.greyColor, fontSize: 13.sp),
              ),
              focusNode: focusNode,
              autofocus: true,
            ),
          ),

          // Button send message
          Material(
            color: Colors.white,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 8),
              child: IconButton(
                icon: const Icon(Icons.send),
                onPressed: () =>
                    onSendMessage(textEditingController.text, TypeMessage.text),
                color: MyColors.primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildListMessage() {
    return Flexible(
      child: groupChatId.isNotEmpty
          ? StreamBuilder<QuerySnapshot>(
              stream: chatProvider.getChatStream(groupChatId, _limit),
              builder: (BuildContext context,
                  AsyncSnapshot<QuerySnapshot> snapshot) {
                if (snapshot.hasData) {
                  listMessage = snapshot.data!.docs;
                  if (listMessage.isNotEmpty) {
                    return ListView.builder(
                      padding: const EdgeInsets.all(10),
                      itemBuilder: (context, index) =>
                          buildItem(index, snapshot.data?.docs[index]),
                      itemCount: snapshot.data?.docs.length,
                      reverse: true,
                      controller: listScrollController,
                    );
                  } else {
                    return const Center(child: Text("No message here yet..."));
                  }
                } else {
                  return const Center(
                    child: CircularProgressIndicator(
                      color: MyColors.themeColor,
                    ),
                  );
                }
              },
            )
          : const Center(
              child: CircularProgressIndicator(
                color: MyColors.themeColor,
              ),
            ),
    );
  }

  Widget _audio({
    required String message,
    required bool isCurrentUser,
    required int index,
    required String time,
    required String duration,
  }) {
    return Container(
      width: 50.w,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isCurrentUser
            ? MyColors.primaryColor.withOpacity(0.18)
            : MyColors.primaryColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              audioController.onPressedPlayButton(index, message);
            },
            onSecondaryTap: () {
              audioPlayer.stop();
            },
            child: Obx(
              () => (audioController.isRecordPlaying &&
                      audioController.currentId == index)
                  ? Icon(
                      Icons.cancel,
                      color:
                          isCurrentUser ? MyColors.primaryColor : Colors.white,
                    )
                  : Icon(
                      Icons.play_arrow,
                      color:
                          isCurrentUser ? MyColors.primaryColor : Colors.white,
                    ),
            ),
          ),
          Obx(
            () => Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 0),
                child: Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    // Text(audioController.completedPercentage.value.toString(),style: TextStyle(color: Colors.white),),
                    LinearProgressIndicator(
                      minHeight: 5,
                      backgroundColor: Colors.grey,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        isCurrentUser ? MyColors.primaryColor : Colors.white,
                      ),
                      value: (audioController.isRecordPlaying &&
                              audioController.currentId == index)
                          ? audioController.completedPercentage.value
                          : audioController.totalDuration.value.toDouble(),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(
            width: 10,
          ),
          Text(
            duration,
            style: TextStyle(
                fontSize: 12,
                color: isCurrentUser ? MyColors.primaryColor : Colors.white),
          ),
        ],
      ),
    );
  }
}