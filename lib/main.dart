import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/pages/login/onboard.dart';
import 'package:growcheck_app_v2/pages/login/onboard_shared.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences preferences = await SharedPreferences.getInstance();
  var staffNo = preferences.getString('staffNo');
  print(staffNo);
  SystemChrome.setPreferredOrientations([]).then(
    (value) => runApp(
      Sizer(
        builder: (context, orientation, deviceType) {
          return MaterialApp(
            theme: ThemeData(
              canvasColor: Colors.white,
              scaffoldBackgroundColor: Colors.white,
              primaryColor: Colors.white,
              fontFamily: 'Renogare',
            ),
            debugShowCheckedModeBanner: false,
            home: staffNo == null ? const Onboard() : const OnboardShared(),
            //home: const TabPage(),
          );
        },
      ),
    ),
  );
}
