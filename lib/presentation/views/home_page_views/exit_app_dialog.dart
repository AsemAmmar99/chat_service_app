import 'package:flutter/material.dart';

import '../../styles/colors.dart';

class ExitAppDialog extends StatelessWidget {
  const ExitAppDialog({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SimpleDialog(
      clipBehavior: Clip.hardEdge,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      contentPadding: EdgeInsets.zero,
      children: <Widget>[
        Container(
          color: MyColors.themeColor,
          padding: const EdgeInsets.only(bottom: 10, top: 10),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: const Icon(
                  Icons.exit_to_app,
                  size: 30,
                  color: Colors.white,
                ),
              ),
              const Text(
                'Exit app',
                style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                'Are you sure to exit app?',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context, 0);
          },
          child: Row(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(right: 10),
                child: const Icon(
                  Icons.cancel,
                  color: MyColors.primaryColor,
                ),
              ),
              const Text(
                'Cancel',
                style: TextStyle(color: MyColors.primaryColor, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
        SimpleDialogOption(
          onPressed: () {
            Navigator.pop(context, 1);
          },
          child: Row(
            children: <Widget>[
              Container(
                margin: const EdgeInsets.only(right: 10),
                child: const Icon(
                  Icons.check_circle,
                  color: MyColors.primaryColor,
                ),
              ),
              const Text(
                'Yes',
                style: TextStyle(color: MyColors.primaryColor, fontWeight: FontWeight.bold),
              )
            ],
          ),
        ),
      ],
    );
  }
}
