import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../business_logic/auth_provider.dart';
import '../../../data/models/popup_choices.dart';
import '../../screens/login_page.dart';
import '../../screens/settings_page.dart';
import '../../styles/colors.dart';

class PopupMenuView extends StatefulWidget {
  const PopupMenuView({Key? key}) : super(key: key);

  @override
  State<PopupMenuView> createState() => _PopupMenuViewState();
}

class _PopupMenuViewState extends State<PopupMenuView> {

  late AuthProvider authProvider;

  List<PopupChoices> choices = <PopupChoices>[
    PopupChoices(title: 'Settings', icon: Icons.settings),
    PopupChoices(title: 'Log out', icon: Icons.exit_to_app),
  ];

  // Execute signing out process.
  Future<void> handleSignOut() async {
    authProvider.handleSignOut();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginPage()),
          (Route<dynamic> route) => false,
    );
  }

  // Handling appBar menu items press.
  void onItemMenuPress(PopupChoices choice) {
    if (choice.title == 'Log out') {
      handleSignOut();
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (context) => const SettingsPage()));
    }
  }

  @override
  void initState() {
    authProvider = context.read<AuthProvider>();
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<PopupChoices>(
      onSelected: onItemMenuPress,
      itemBuilder: (BuildContext context) {
        return choices.map((PopupChoices choice) {
          return PopupMenuItem<PopupChoices>(
              value: choice,
              child: Row(
                children: <Widget>[
                  Icon(
                    choice.icon,
                    color: MyColors.primaryColor,
                  ),
                  Container(
                    width: 10,
                  ),
                  Text(
                    choice.title,
                    style: const TextStyle(color: MyColors.primaryColor),
                  ),
                ],
              ));
        }).toList();
      },
    );
  }
}
