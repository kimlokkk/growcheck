import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/pages/login/onboard.dart';
import 'package:growcheck_app_v2/pages/login/onboard_shared.dart';
import 'package:sizer/sizer.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? staffNo;
  try {
    final preferences = await SharedPreferences.getInstance().timeout(
      const Duration(seconds: 5),
    );
    staffNo = preferences.getString('staffNo');
  } catch (error, stackTrace) {
    debugPrint('Unable to restore login session: $error');
    debugPrintStack(stackTrace: stackTrace);
  }

  // Orientation locking is a native concern. Do not make web startup depend
  // on a platform-channel call that may be unavailable in mobile browsers.
  if (!kIsWeb) {
    try {
      await SystemChrome.setPreferredOrientations([]);
    } catch (error) {
      debugPrint('Unable to configure device orientation: $error');
    }
  }

  runApp(
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
        );
      },
    ),
  );
}
