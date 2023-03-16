import 'package:flutter/material.dart';
import 'package:chat_service_app/presentation/styles/colors.dart';
import 'package:chat_service_app/business_logic/auth_provider.dart';
import 'package:provider/provider.dart';

import 'screens.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({Key? key}) : super(key: key);

  @override
  SplashPageState createState() => SplashPageState();
}

class SplashPageState extends State<SplashPage> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 1000), () {
      // just delay for showing this splash page clearer because it's too fast
      checkSignedIn();
    });
  }

  // Check if there's an already signed in account
  // if yes, go to home screen, otherwise, go to login screen
  void checkSignedIn() async {
    AuthProvider authProvider = context.read<AuthProvider>();
    bool isLoggedIn = await authProvider.isLoggedIn();
    if (isLoggedIn) {
      if(mounted) {
        Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const HomePage()),
      );
      }
      return;
    }
    if(mounted) {
      Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
    );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              "assets/app_icon.png",
              width: 100,
              height: 100,
            ),
            const SizedBox(height: 20),
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(color: MyColors.themeColor),
            ),
          ],
        ),
      ),
    );
  }
}
