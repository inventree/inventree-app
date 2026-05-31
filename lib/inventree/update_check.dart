import "dart:convert";

import "package:http/http.dart" as http;
import "package:package_info_plus/package_info_plus.dart";

const String _githubReleasesUrl =
    "https://api.github.com/repos/inventree/inventree-app/releases/latest";

const String _githubReleasesHtmlUrl =
    "https://github.com/inventree/inventree-app/releases/latest";

class UpdateChecker {
  factory UpdateChecker() => _instance;

  UpdateChecker._();

  static final UpdateChecker _instance = UpdateChecker._();

  bool _fetched = false;
  bool _newVersionAvailable = false;
  String _latestVersion = "";
  String _releaseUrl = _githubReleasesHtmlUrl;

  bool get newVersionAvailable => _newVersionAvailable;
  String get latestVersion => _latestVersion;
  String get releaseUrl => _releaseUrl;

  Future<void> checkForUpdate() async {
    if (_fetched) return;

    try {
      final PackageInfo info = await PackageInfo.fromPlatform();
      final String currentVersion = info.version;

      final response = await http
          .get(
            Uri.parse(_githubReleasesUrl),
            headers: {"Accept": "application/vnd.github+json"},
          )
          .timeout(const Duration(seconds: 10));

      if (response.statusCode != 200) return;

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      String tagName = (data["tag_name"] as String?) ?? "";
      final String htmlUrl =
          (data["html_url"] as String?) ?? _githubReleasesHtmlUrl;

      if (tagName.startsWith("v")) {
        tagName = tagName.substring(1);
      }

      if (tagName.isEmpty) return;

      _latestVersion = tagName;
      _releaseUrl = htmlUrl;
      _newVersionAvailable = _isNewerVersion(tagName, currentVersion);
      _fetched = true;
    } catch (_) {
      // Fail silently — no network, parse error, API rate limit, etc.
    }
  }

  bool _isNewerVersion(String latest, String current) {
    try {
      // Strip any pre-release suffix (e.g. "0.24.4-rc1" → "0.24.4")
      final latestClean = latest.split("-").first;
      final currentClean = current.split("-").first;

      final latestParts = latestClean.split(".").map(int.parse).toList();
      final currentParts = currentClean.split(".").map(int.parse).toList();

      for (int i = 0; i < 3; i++) {
        final l = i < latestParts.length ? latestParts[i] : 0;
        final c = i < currentParts.length ? currentParts[i] : 0;
        if (l > c) return true;
        if (l < c) return false;
      }
      return false;
    } catch (_) {
      return false;
    }
  }
}
