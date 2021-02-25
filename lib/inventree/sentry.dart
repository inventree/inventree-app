import 'dart:io';

import 'package:device_info/device_info.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:package_info/package_info.dart';
import 'package:sentry_flutter/sentry_flutter.dart';
import 'package:one_context/one_context.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import 'package:InvenTree/api.dart';

Future<Map<String, dynamic>> getDeviceInfo() async {

  // Extract device information
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Map<String, dynamic> device_info = {};

  // Extract some platform information
  if (Platform.isIOS) {
    final iosDeviceInfo = await deviceInfo.iosInfo;

    device_info = {
      'name': iosDeviceInfo.name,
      'model': iosDeviceInfo.model,
      'systemName': iosDeviceInfo.systemName,
      'systemVersion': iosDeviceInfo.systemVersion,
      'localizedModel': iosDeviceInfo.localizedModel,
      'utsname': iosDeviceInfo.utsname.sysname,
      'identifierForVendor': iosDeviceInfo.identifierForVendor,
      'isPhysicalDevice': iosDeviceInfo.isPhysicalDevice,
    };

  } else if (Platform.isAndroid) {
    final androidDeviceInfo = await deviceInfo.androidInfo;

    device_info = {
      'type': androidDeviceInfo.type,
      'model': androidDeviceInfo.model,
      'device': androidDeviceInfo.device,
      'id': androidDeviceInfo.id,
      'androidId': androidDeviceInfo.androidId,
      'brand': androidDeviceInfo.brand,
      'display': androidDeviceInfo.display,
      'hardware': androidDeviceInfo.hardware,
      'manufacturer': androidDeviceInfo.manufacturer,
      'product': androidDeviceInfo.product,
      'version': androidDeviceInfo.version.release,
      'supported32BitAbis': androidDeviceInfo.supported32BitAbis,
      'supported64BitAbis': androidDeviceInfo.supported64BitAbis,
      'supportedAbis': androidDeviceInfo.supportedAbis,
      'isPhysicalDevice': androidDeviceInfo.isPhysicalDevice,
    };
  }

  return device_info;
}


Map<String, dynamic> getServerInfo() => {
  "version": InvenTreeAPI().version,
};


Future<Map<String, dynamic>> getAppInfo() async {
  // Add app info
  final package_info = await PackageInfo.fromPlatform();

  return {
    "name": package_info.appName,
    "build": package_info.buildNumber,
    "version": package_info.version,
    "package": package_info.packageName,
  };
}


bool isInDebugMode() {
  bool inDebugMode = false;

  assert(inDebugMode = true);

  return inDebugMode;
}

Future<void> sentryReportError(dynamic error, dynamic stackTrace) async {

  print('Intercepted error: $error');
  print(stackTrace);

  // Errors thrown in development mode are unlikely to be interesting. You can
  // check if you are running in dev mode using an assertion and omit sending
  // the report.
  if (isInDebugMode()) {

    print('In dev mode. Not sending report to Sentry.io.');
    return;
  }

  final server_info = getServerInfo();
  final app_info = await getAppInfo();
  final device_info = await getDeviceInfo();

  Sentry.configureScope((scope) {
    scope.setExtra("server", server_info);
    scope.setExtra("app", app_info);
    scope.setExtra("device", device_info);
  });

  Sentry.captureException(error, stackTrace: stackTrace).catchError((error) {
    print("Error uploading information to Sentry.io:");
    print(error);
  }).then((response) {
    print("Uploaded information to Sentry.io : ${response.toString()}");
  });
}


Future<bool> sentryReportMessage(String message) async {

  final server_info = getServerInfo();
  final app_info = await getAppInfo();
  final device_info = await getDeviceInfo();

  print("Sending user message to Sentry");

  Sentry.configureScope((scope) {
    scope.setExtra("server", server_info);
    scope.setExtra("app", app_info);
    scope.setExtra("device", device_info);
  });

  final sentryId = await Sentry.captureMessage(message).catchError((error) {
    print("Error uploading sentry messages...");
    print(error);
    return null;
  });

  return sentryId != null;
}