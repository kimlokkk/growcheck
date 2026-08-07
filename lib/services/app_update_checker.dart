import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateChecker {
  static final String _versionUrl = ApiConfig.flutter('check_app_version.php');

  /*static const String _versionUrl =
      'http://app-kizzu.test/growkids/flutter/check_app_version.php';*/

  static bool _isShowing = false;
  static final Set<String> _checkedSessionKeys = {};

  static Future<void> check(
    BuildContext context, {
    required String appKey,
  }) async {
    // This checker targets the installed Android/iOS apps. Running dart:io
    // platform checks in a browser can throw UnsupportedError.
    if (kIsWeb) return;
    if (_isShowing) return;

    try {
      final platform = Platform.isIOS ? 'ios' : 'android';
      final sessionKey = '$appKey-$platform';

      if (_checkedSessionKeys.contains(sessionKey)) return;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final uri = Uri.parse(
        '$_versionUrl?app_key=$appKey&platform=$platform',
      );

      final response = await http.get(
        uri,
        headers: {'Accept': 'application/json'},
      ).timeout(const Duration(seconds: 8));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body);

      if (data['ok'] != true) return;
      _checkedSessionKeys.add(sessionKey);

      final latestVersion = data['latest_version']?.toString() ?? '';
      final minRequiredVersion = data['min_required_version']?.toString() ?? '';
      final updateUrl = data['update_url']?.toString() ?? '';
      final forceUpdate = data['force_update'] == true;

      if (latestVersion.isEmpty || updateUrl.isEmpty) return;

      final belowMinimum =
          _compareVersion(currentVersion, minRequiredVersion) < 0;
      final belowLatest = _compareVersion(currentVersion, latestVersion) < 0;

      if (!belowMinimum && !belowLatest) return;
      if (!context.mounted) return;

      _isShowing = true;

      await showDialog(
        context: context,
        barrierDismissible: !(forceUpdate || belowMinimum),
        builder: (_) {
          return PopScope(
            canPop: !(forceUpdate || belowMinimum),
            child: AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              title: Text(
                data['title']?.toString() ?? 'Update Available',
              ),
              content: Text(
                data['message']?.toString() ??
                    'A newer version is available. Please update the app.',
              ),
              actions: [
                if (!(forceUpdate || belowMinimum))
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Later'),
                  ),
                ElevatedButton(
                  onPressed: () async {
                    final url = Uri.parse(updateUrl);
                    await launchUrl(
                      url,
                      mode: LaunchMode.externalApplication,
                    );
                  },
                  child: const Text('Update Now'),
                ),
              ],
            ),
          );
        },
      );

      _isShowing = false;
    } catch (_) {
      _isShowing = false;
    }
  }

  static int _compareVersion(String current, String target) {
    if (target.isEmpty) return 0;

    final currentParts = current.split('.').map(_toInt).toList();
    final targetParts = target.split('.').map(_toInt).toList();

    final maxLength = currentParts.length > targetParts.length
        ? currentParts.length
        : targetParts.length;

    for (int i = 0; i < maxLength; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final t = i < targetParts.length ? targetParts[i] : 0;

      if (c < t) return -1;
      if (c > t) return 1;
    }

    return 0;
  }

  static int _toInt(String value) {
    return int.tryParse(value.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
  }
}
