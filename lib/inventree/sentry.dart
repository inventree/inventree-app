import "dart:io";

import "package:device_info_plus/device_info_plus.dart";
import "package:inventree/preferences.dart";
import "package:package_info_plus/package_info_plus.dart";
import "package:sentry_flutter/sentry_flutter.dart";

import "package:inventree/api.dart";

Future<Map<String, dynamic>> getDeviceInfo() async {

  // Extract device information
  final DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();

  Map<String, dynamic> device_info = {};

  // Extract some platform information
  if (Platform.isIOS) {
    final iosDeviceInfo = await deviceInfo.iosInfo;

    device_info = {
      "name": iosDeviceInfo.name,
      "model": iosDeviceInfo.model,
      "systemName": iosDeviceInfo.systemName,
      "systemVersion": iosDeviceInfo.systemVersion,
      "localizedModel": iosDeviceInfo.localizedModel,
      "utsname": iosDeviceInfo.utsname.sysname,
      "identifierForVendor": iosDeviceInfo.identifierForVendor,
      "isPhysicalDevice": iosDeviceInfo.isPhysicalDevice,
    };

  } else if (Platform.isAndroid) {
    final androidDeviceInfo = await deviceInfo.androidInfo;

    device_info = {
      "type": androidDeviceInfo.type,
      "model": androidDeviceInfo.model,
      "device": androidDeviceInfo.device,
      "id": androidDeviceInfo.id,
      "androidId": androidDeviceInfo.id,
      "brand": androidDeviceInfo.brand,
      "display": androidDeviceInfo.display,
      "hardware": androidDeviceInfo.hardware,
      "manufacturer": androidDeviceInfo.manufacturer,
      "product": androidDeviceInfo.product,
      "version": androidDeviceInfo.version.release,
      "supported32BitAbis": androidDeviceInfo.supported32BitAbis,
      "supported64BitAbis": androidDeviceInfo.supported64BitAbis,
      "supportedAbis": androidDeviceInfo.supportedAbis,
      "isPhysicalDevice": androidDeviceInfo.isPhysicalDevice,
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

Future<bool> sentryReportMessage(String message, {Map<String, String>? context}) async {

  final server_info = getServerInfo();
  final app_info = await getAppInfo();
  final device_info = await getDeviceInfo();

  // Remove any sensitive information from a URL
  if (context != null) {
    if (context.containsKey("url")) {
      final String url = context["url"] ?? "";

      try {
        final uri = Uri.parse(url);

        // We don't care about the server address, only the path and query parameters!
        // Overwrite the provided URL
        context["url"] = uri.path + "?" + uri.query;

      } catch (error) {
        // Ignore if any errors are thrown here
      }

    }
  }

  print("Sending user message to Sentry: ${message}, ${context}");

  if (isInDebugMode()) {

    print("----- In dev mode. Not sending message to Sentry.io -----");
    return true;
  }

  final upload = await InvenTreeSettingsManager().getValue(INV_REPORT_ERRORS, true) as bool;

  if (!upload) {
    print("----- Error reporting disabled -----");
    return true;
  }

  Sentry.configureScope((scope) {
    scope.setExtra("server", server_info);
    scope.setExtra("app", app_info);
    scope.setExtra("device", device_info);

    if (context != null) {
      scope.setExtra("context", context);
    }

    // Catch stacktrace data if possible
    scope.setExtra("stacktrace", StackTrace.current.toString());
  });

  try {
    await Sentry.captureMessage(message);
    return true;
  } catch (error) {
    print("Error uploading sentry messages...");
    print(error);
    return false;
  }
}


/*
 * Report an error message to sentry.io
 */
Future<void> sentryReportError(String source, dynamic error, dynamic stackTrace, {Map<String, String> context = const {}}) async {

  print("----- Sentry Intercepted error: $error -----");
  print(stackTrace);

  // Errors thrown in development mode are unlikely to be interesting. You can
  // check if you are running in dev mode using an assertion and omit sending
  // the report.
  if (isInDebugMode()) {

    print("----- In dev mode. Not sending report to Sentry.io -----");
    return;
  }

  final upload = await InvenTreeSettingsManager().getValue(INV_REPORT_ERRORS, true) as bool;

  if (!upload) {
    print("----- Error reporting disabled -----");
    return;
  }

  // Some errors are outside our control, and we do not want to "pollute" the uploaded data
  if (source == "FlutterError.onError") {

    String errorString = error.toString();

    // Missing media file
    if (errorString.contains("HttpException") && errorString.contains("404") && errorString.contains("/media/")) {
      return;
    }

    // Local file system exception
    if (errorString.contains("FileSystemException")) {
      return;
    }
  }

  final server_info = getServerInfo();
  final app_info = await getAppInfo();
  final device_info = await getDeviceInfo();

  // Ensure we pass the 'source' of the error
  context["source"] = source;

  Sentry.configureScope((scope) {
    scope.setExtra("server", server_info);
    scope.setExtra("app", app_info);
    scope.setExtra("device", device_info);
    scope.setExtra("context", context);
  });

  Sentry.captureException(error, stackTrace: stackTrace).catchError((error) {
    print("Error uploading information to Sentry.io:");
    print(error);
    return SentryId.empty();
  }).then((response) {
    print("Uploaded information to Sentry.io : ${response.toString()}");
  });
}
