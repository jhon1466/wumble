import 'package:flutter/foundation.dart';
import 'config.dart';

/// Utility class to optimize image delivery using Cloudinary Fetch API.
/// 
/// CURRENTLY DISABLED: Cloudinary proxy was causing persistent 400/401 errors
/// across avatars, stickers, and chat images. Firebase Storage URLs work
/// natively with CachedNetworkImage caching. This can be re-enabled once
/// the Cloudinary account configuration is fully verified.
class MediaOptimizer {
  static const String _baseUrl = 'https://res.cloudinary.com/${AppConfig.cloudinaryCloudName}/image/fetch';

  /// Currently returns the original URL unchanged.
  /// When re-enabled, transforms Firebase Storage URLs into optimized Cloudinary Fetch URLs.
  static String optimize(
    String? url, {
    int? width,
    int? height,
    String quality = 'auto',
    String format = 'auto',
    String crop = 'fill',
    bool isGif = false,
  }) {
    if (url == null || url.isEmpty) return '';
    return url;
  }

  /// Helper for Avatars
  static String avatar(String? url, {int size = 200}) {
    if (url == null || url.isEmpty) return '';
    return url;
  }

  /// Helper for Banners
  static String banner(String? url) {
    if (url == null || url.isEmpty) return '';
    return url;
  }

  /// Helper for Feed/Posts
  static String post(String? url) {
    if (url == null || url.isEmpty) return '';
    return url;
  }
}
