import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:chat_service_app/core/constants/constants.dart';
import 'package:chat_service_app/data/models/models.dart';
import 'package:chat_service_app/business_logic/providers.dart';
import 'package:chat_service_app/presentation/widgets/loading_view.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../styles/colors.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          AppConstants.settingsTitle,
          style: TextStyle(color: MyColors.greyColor2),
        ),
        centerTitle: true,
      ),
      body: const SettingsPageState(),
    );
  }
}

class SettingsPageState extends StatefulWidget {
  const SettingsPageState({super.key});

  @override
  State createState() => SettingsPageStateState();
}

class SettingsPageStateState extends State<SettingsPageState> {
  // Needed Variables and Objects
  TextEditingController? controllerNickname;
  TextEditingController? controllerAboutMe;

  String id = '';
  String nickname = '';
  String aboutMe = '';
  String photoUrl = '';

  bool isLoading = false;
  File? avatarImageFile;
  late SettingProvider settingProvider;

  final FocusNode focusNodeNickname = FocusNode();
  final FocusNode focusNodeAboutMe = FocusNode();

  @override
  void initState() {
    super.initState();
    settingProvider = context.read<SettingProvider>();
    readLocal();
  }

  // Get user's data from sharedPreferences.
  void readLocal() {
    setState(() {
      id = settingProvider.getPref(FirestoreConstants.id) ?? "";
      nickname = settingProvider.getPref(FirestoreConstants.nickname) ?? "";
      aboutMe = settingProvider.getPref(FirestoreConstants.aboutMe) ?? "";
      photoUrl = settingProvider.getPref(FirestoreConstants.photoUrl) ?? "";
    });

    controllerNickname = TextEditingController(text: nickname);
    controllerAboutMe = TextEditingController(text: aboutMe);
  }

  // Choosing an image from gallery and calling uploadImage method.
  Future getImage() async {
    ImagePicker imagePicker = ImagePicker();
    XFile? pickedFile = await imagePicker.pickImage(source: ImageSource.gallery).catchError((err) {
      Fluttertoast.showToast(msg: err.toString());
      return null;
    });
    File? image;
    if (pickedFile != null) {
      image = File(pickedFile.path);
    }
    if (image != null) {
      setState(() {
        avatarImageFile = image;
        isLoading = true;
      });
      uploadImage();
    }
  }

  // Uploading the selected image to firebase.
  Future uploadImage() async {
    String fileName = id;
    UploadTask uploadTask = settingProvider.uploadImage(avatarImageFile!, fileName);
    try {
      TaskSnapshot snapshot = await uploadTask;
      photoUrl = await snapshot.ref.getDownloadURL();
      UserChat updateInfo = UserChat(
        id: id,
        photoUrl: photoUrl,
        nickname: nickname,
        aboutMe: aboutMe,
      );
      settingProvider
          .updateDataFirestore(FirestoreConstants.pathUserCollection, id, updateInfo.toJson())
          .then((data) async {
        await settingProvider.setPref(FirestoreConstants.photoUrl, photoUrl);
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: "Upload success");
      }).catchError((err) {
        setState(() {
          isLoading = false;
        });
        Fluttertoast.showToast(msg: err.toString());
      });
    } on FirebaseException catch (e) {
      setState(() {
        isLoading = false;
      });
      Fluttertoast.showToast(msg: e.message ?? e.toString());
    }
  }

  // Handling updating user's old data with the new one.
  void handleUpdateData() {
    focusNodeNickname.unfocus();
    focusNodeAboutMe.unfocus();

    setState(() {
      isLoading = true;
    });
    UserChat updateInfo = UserChat(
      id: id,
      photoUrl: photoUrl,
      nickname: nickname,
      aboutMe: aboutMe,
    );
    settingProvider
        .updateDataFirestore(FirestoreConstants.pathUserCollection, id, updateInfo.toJson())
        .then((data) async {
      await settingProvider.setPref(FirestoreConstants.nickname, nickname);
      await settingProvider.setPref(FirestoreConstants.aboutMe, aboutMe);
      await settingProvider.setPref(FirestoreConstants.photoUrl, photoUrl);

      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: "Update success");
    }).catchError((err) {
      setState(() {
        isLoading = false;
      });

      Fluttertoast.showToast(msg: err.toString());
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: <Widget>[
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Avatar
              CupertinoButton(
                onPressed: getImage,
                child: Container(
                  margin: const EdgeInsets.all(20),
                  child: avatarImageFile == null
                      ? photoUrl.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(45),
                              child: Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                width: 90,
                                height: 90,
                                errorBuilder: (context, object, stackTrace) {
                                  return const Icon(
                                    Icons.account_circle,
                                    size: 90,
                                    color: MyColors.greyColor,
                                  );
                                },
                                loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return SizedBox(
                                    width: 90,
                                    height: 90,
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
                              ),
                            )
                          : const Icon(
                              Icons.account_circle,
                              size: 90,
                              color: MyColors.greyColor,
                            )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(45),
                          child: Image.file(
                            avatarImageFile!,
                            width: 90,
                            height: 90,
                            fit: BoxFit.cover,
                          ),
                        ),
                ),
              ),

              // Input
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Username
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 10, bottom: 5, top: 10),
                    child: const Text(
                      'Nickname',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: MyColors.primaryColor),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    child: Theme(
                      data: Theme.of(context).copyWith(primaryColor: MyColors.primaryColor),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Sweetie',
                          contentPadding: EdgeInsets.all(5),
                          hintStyle: TextStyle(color: MyColors.greyColor),
                        ),
                        controller: controllerNickname,
                        onChanged: (value) {
                          nickname = value;
                        },
                        focusNode: focusNodeNickname,
                      ),
                    ),
                  ),

                  // About me
                  Container(
                    margin: const EdgeInsetsDirectional.only(start: 10, top: 30, bottom: 5),
                    child: const Text(
                      'About me',
                      style: TextStyle(
                          fontStyle: FontStyle.italic, fontWeight: FontWeight.bold, color: MyColors.primaryColor),
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 30),
                    child: Theme(
                      data: Theme.of(context).copyWith(primaryColor: MyColors.primaryColor),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Fun, like travel and play PES...',
                          contentPadding: EdgeInsets.all(5),
                          hintStyle: TextStyle(color: MyColors.greyColor),
                        ),
                        controller: controllerAboutMe,
                        onChanged: (value) {
                          aboutMe = value;
                        },
                        focusNode: focusNodeAboutMe,
                      ),
                    ),
                  ),
                ],
              ),

              // Button
              Container(
                margin: const EdgeInsets.symmetric(vertical: 50),
                child: TextButton(
                  onPressed: handleUpdateData,
                  style: ButtonStyle(
                    backgroundColor: MaterialStateProperty.all<Color>(MyColors.primaryColor),
                    padding: MaterialStateProperty.all<EdgeInsets>(
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 30),
                    ),
                  ),
                  child: const Text(
                    'Update',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Loading
        Positioned(child: isLoading ? const LoadingView() : const SizedBox.shrink()),
      ],
    );
  }
}
