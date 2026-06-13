import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';

/// Information about an available OTA update.
class UpdateInfo {
  final String version; // human readable, e.g. "1.0.1"
  final int buildNumber; // versionCode, used for comparison
  final String apkUrl; // direct download URL of the .apk asset
  final String releaseNotes;

  const UpdateInfo({
    required this.version,
    required this.buildNumber,
    required this.apkUrl,
    required this.releaseNotes,
  });
}

/// Checks GitHub Releases for a newer APK and exposes the download URL.
///
/// Release convention (set when publishing a Release on GitHub):
///  - Tag name encodes the version + build number, e.g. `v1.0.1+40`.
///  - Attach the release APK as an asset ending in `.apk`.
class UpdateService {
  /// `owner/repo` of the public GitHub repository hosting the releases.
  static const String repo = 'jhon1466/wumble';

  static Uri get _latestReleaseUri =>
      Uri.parse('https://api.github.com/repos/$repo/releases/latest');

  /// Returns an [UpdateInfo] when the latest GitHub release is newer than the
  /// currently installed build, otherwise `null`.
  Future<UpdateInfo?> checkForUpdate() async {
    // OTA only makes sense on Android (sideloaded APK installs).
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return null;

    try {
      final info = await PackageInfo.fromPlatform();
      final int currentBuild = int.tryParse(info.buildNumber) ?? 0;

      final res = await http.get(
        _latestReleaseUri,
        headers: {'Accept': 'application/vnd.github+json'},
      ).timeout(const Duration(seconds: 12));

      if (res.statusCode != 200) {
        debugPrint('UpdateService: GitHub returned ${res.statusCode}');
        return null;
      }

      final data = jsonDecode(res.body) as Map<String, dynamic>;
      if (data['draft'] == true || data['prerelease'] == true) return null;

      final String tag = (data['tag_name'] ?? '').toString();
      final _Version parsed = _parseTag(tag);
      if (parsed.buildNumber <= currentBuild) return null;

      // Find the first .apk asset.
      final assets = (data['assets'] as List?) ?? const [];
      String? apkUrl;
      for (final a in assets) {
        final name = (a['name'] ?? '').toString().toLowerCase();
        if (name.endsWith('.apk')) {
          apkUrl = (a['browser_download_url'] ?? '').toString();
          break;
        }
      }
      if (apkUrl == null || apkUrl.isEmpty) {
        debugPrint('UpdateService: release has no .apk asset');
        return null;
      }

      return UpdateInfo(
        version: parsed.name,
        buildNumber: parsed.buildNumber,
        apkUrl: apkUrl,
        releaseNotes: (data['body'] ?? '').toString(),
      );
    } catch (e) {
      debugPrint('UpdateService: check failed: $e');
      return null;
    }
  }

  /// Parses a tag like `v1.0.1+40`, `1.0.1+40` or `1.0.1` into name + build.
  _Version _parseTag(String tag) {
    var t = tag.trim();
    if (t.startsWith('v') || t.startsWith('V')) t = t.substring(1);
    String name = t;
    int build = 0;
    final plus = t.indexOf('+');
    if (plus != -1) {
      name = t.substring(0, plus);
      build = int.tryParse(t.substring(plus + 1).replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    } else {
      // No build suffix: derive a comparable number from the semver (1.2.3 -> 10203).
      final parts = name.split('.').map((p) => int.tryParse(p) ?? 0).toList();
      while (parts.length < 3) {
        parts.add(0);
      }
      build = parts[0] * 10000 + parts[1] * 100 + parts[2];
    }
    return _Version(name, build);
  }
}

class _Version {
  final String name;
  final int buildNumber;
  const _Version(this.name, this.buildNumber);
}
