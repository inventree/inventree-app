
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";

// This is the same as the following issue except it keeps the http client
// TestWidgetsFlutterBinding.ensureInitialized();
class CustomBinding extends AutomatedTestWidgetsFlutterBinding {
  @override
  bool get overrideHttpClient => false;
}

void setupTestEnv() {
  // Uses custom binding to not override the http client
  CustomBinding();

  // Mock the path provider
  const MethodChannel channel = MethodChannel("plugins.flutter.io/path_provider");
  TestDefaultBinaryMessengerBinding.instance?.defaultBinaryMessenger
      .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
    return ".";
  });
}