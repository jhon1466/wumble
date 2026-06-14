import 'dart:convert';
import 'package:wumble/core/localization/translations.dart';
import 'package:http/http.dart' as http;
import 'package:wumble/core/domain/link_preview_data.dart';
import 'package:wumble/injection_container.dart';
import 'package:wumble/features/community/domain/community_repository.dart';
import 'package:wumble/features/profile/domain/profile_repository.dart';
import 'package:wumble/features/feed/domain/feed_repository.dart';

class LinkPreviewHelper {
  static final RegExp _urlRegExp = RegExp(
    r'(https?://[^\s]+)',
    caseSensitive: false,
  );

  // Regex to extract tweet ID from x.com or twitter.com URLs
  static final RegExp _tweetIdRegExp = RegExp(
    r'(?:x\.com|twitter\.com)/(?:[^/]+/)?status/(\d+)',
    caseSensitive: false,
  );

  // Helper to extract YouTube video ID from various URL formats
  static String? _extractYoutubeId(String url) {
    // Patterns:
    // https://www.youtube.com/watch?v=ID
    // https://youtu.be/ID
    // https://www.youtube.com/embed/ID
    // https://www.youtube.com/shorts/ID
    final regExp = RegExp(
      r'.*(?:(?:youtu\.be\/|v\/|vi\/|u\/\w\/|embed\/|shorts\/)|(?:(?:watch)?\?v(?:i)?=|\&v(?:i)?=))([^#\&\?]*).*',
      caseSensitive: false,
    );
    final match = regExp.firstMatch(url);
    if (match != null && match.groupCount >= 1) {
      final id = match.group(1);
      if (id != null && id.length == 11) {
        return id;
      }
    }
    return null;
  }

  /// Extracts the first URL found in a string.
  static String? extractFirstUrl(String text) {
    final match = _urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  /// Fetches metadata from a URL.
  static Future<LinkPreviewData?> fetchMetadata(String url) async {
    try {
      // Special fast path for internal Wumble links (test domain support)
      final uri = Uri.tryParse(url);
      if (uri?.host == 'wumble.link') {
        return await _fetchInternalMetadata(url);
      }

      // Special fast path for X / Twitter: use the fxtwitter JSON API
      final tweetIdMatch = _tweetIdRegExp.firstMatch(url);
      if (tweetIdMatch != null) {
        final tweetId = tweetIdMatch.group(1)!;
        return await _fetchTwitterMetadata(url, tweetId);
      }

      // Generic path: scrape Open Graph tags from HTML
      final data = await _fetchGenericMetadata(url);
      
      // If it's a YouTube link, attach the video ID
      if (data != null) {
        final youtubeId = _extractYoutubeId(url);
        if (youtubeId != null) {
          return LinkPreviewData(
            url: data.url,
            title: data.title,
            description: data.description,
            imageUrl: data.imageUrl ?? 'https://img.youtube.com/vi/$youtubeId/hqdefault.jpg',
            siteName: data.siteName ?? 'YouTube',
            faviconUrl: data.faviconUrl,
            youtubeVideoId: youtubeId,
          );
        }
      }
      
      return data;
    } catch (e) {
      print('LinkPreviewHelper error: $e');
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // Twitter / X  →  fxtwitter JSON API
  // ─────────────────────────────────────────────────────────────────
  static Future<LinkPreviewData?> _fetchTwitterMetadata(
      String originalUrl, String tweetId) async {
    final apiUrl = 'https://api.fxtwitter.com/status/$tweetId';
    print('LinkPreview [Twitter]: calling $apiUrl');

    final response = await http
        .get(Uri.parse(apiUrl), headers: {
          'User-Agent': 'AminoApp/1.0',
          'Accept': 'application/json',
        })
        .timeout(const Duration(seconds: 8));

    print('LinkPreview [Twitter]: status=${response.statusCode}');

    if (response.statusCode != 200) return null;

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final tweet = json['tweet'] as Map<String, dynamic>?;
    if (tweet == null) return null;

    final author = tweet['author'] as Map<String, dynamic>?;
    final media = tweet['media'] as Map<String, dynamic>?;
    final photos = media?['photos'] as List<dynamic>?;
    final videos = media?['videos'] as List<dynamic>?;

    String? imageUrl;
    if (photos != null && photos.isNotEmpty) {
      imageUrl = (photos.first as Map<String, dynamic>)['url'] as String?;
    } else if (videos != null && videos.isNotEmpty) {
      imageUrl =
          (videos.first as Map<String, dynamic>)['thumbnail_url'] as String?;
    }

    final authorName = author?['name'] as String?;
    final handle = author?['screen_name'] as String?;
    final title =
        (authorName != null && handle != null) ? '$authorName (@$handle)' : null;
    final description = tweet['text'] as String?;
    final avatar = author?['avatar_url'] as String?;

    print('LinkPreview [Twitter]: image=$imageUrl, title=$title');

    return LinkPreviewData(
      url: originalUrl,
      title: title,
      description: description,
      imageUrl: imageUrl,
      siteName: 'X (Twitter)',
      faviconUrl: avatar,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Internal Wumble Links (Mock for Test Domain)
  // ─────────────────────────────────────────────────────────────────
  static Future<LinkPreviewData?> _fetchInternalMetadata(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return null;

    final segments = uri.pathSegments;
    if (segments.isEmpty) return null;

    final type = segments[0];
    final id = segments.length > 1 ? segments[1] : '';

    try {
      if (type == 'c') {
        // Fetch real community from Firestore
        final community = await sl<CommunityRepository>().getCommunityByHandle(id);
        if (community != null) {
          return LinkPreviewData(
            url: url,
            title: community.name,
            description: community.description,
            imageUrl: community.bannerUrl.isNotEmpty ? community.bannerUrl : community.iconUrl,
            siteName: 'Wumble Community',
            faviconUrl: community.iconUrl,
          );
        }
      } else if (type == 'u') {
        // Fetch real user profile from Firestore
        final profile = await sl<ProfileRepository>().getProfileByUsername(id);
        if (profile != null) {
          return LinkPreviewData(
            url: url,
            title: profile.displayName,
            description: profile.bio,
            imageUrl: profile.bannerUrl.isNotEmpty ? profile.bannerUrl : profile.avatarUrl,
            siteName: 'Wumble Profile',
            faviconUrl: profile.avatarUrl,
          );
        }
      } else if (type == 'p') {
        // Fetch real post from Firestore
        final post = await sl<FeedRepository>().getPost(id);
        if (post != null) {
          return LinkPreviewData(
            url: url,
            title: post.title?.isNotEmpty == true ? post.title : 'Publicación de ${post.authorName}',
            description: post.content,
            imageUrl: post.images.isNotEmpty ? post.images.first : post.authorAvatarUrl,
            siteName: 'Wumble Post',
            faviconUrl: post.authorAvatarUrl,
          );
        }
      }
    } catch (e) {
      print('LinkPreviewHelper: Error fetching real internal data: $e');
    }

    // Fallback placeholders if not found in Firestore
    if (type == 'c') {
      return LinkPreviewData(
        url: url,
        title: tr('Comunidad en Wumble'),
        description: 'Explora esta comunidad, únete a chats y comparte con otros miembros.',
        imageUrl: 'https://images.unsplash.com/photo-1511671782779-c97d3d27a1d4?q=80&w=1000&auto=format&fit=crop',
        siteName: 'Wumble Community',
      );
    } else if (type == 'u') {
      return LinkPreviewData(
        url: url,
        title: tr('Perfil de Usuario'),
        description: 'Mira el perfil, muro y seguidores de este usuario.',
        imageUrl: 'https://images.unsplash.com/photo-1535713875002-d1d0cf377fde?q=80&w=1000&auto=format&fit=crop',
        siteName: 'Wumble Profile',
      );
    } else if (type == 'p') {
      return LinkPreviewData(
        url: url,
        title: tr('Publicación en Wumble'),
        description: 'Mira este nuevo contenido compartido en la plataforma.',
        imageUrl: 'https://images.unsplash.com/photo-1498050108023-c5249f4df085?q=80&w=1000&auto=format&fit=crop',
        siteName: 'Wumble Feed',
      );
    }

    return null;
  }

  // ─────────────────────────────────────────────────────────────────
  // Generic URLs  →  Open Graph HTML scraping
  // ─────────────────────────────────────────────────────────────────
  static Future<LinkPreviewData?> _fetchGenericMetadata(String url) async {
    final response = await http.get(Uri.parse(url), headers: {
      'User-Agent':
          'Mozilla/5.0 (compatible; Discordbot/2.0; +https://discordapp.com)',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    }).timeout(const Duration(seconds: 6));

    if (response.statusCode != 200) return null;

    final html = response.body;
    final title = _getMetaContent(html, 'og:title') ??
        _getMetaContent(html, 'twitter:title') ??
        _getHtmlTitle(html);
    final description = _getMetaContent(html, 'og:description') ??
        _getMetaContent(html, 'twitter:description');
    final imageUrl = _getMetaContent(html, 'og:image') ??
        _getMetaContent(html, 'twitter:image');
    final siteName = _getMetaContent(html, 'og:site_name');

    return LinkPreviewData(
      url: url,
      title: _decodeHtmlEntities(title),
      description: _decodeHtmlEntities(description),
      imageUrl: imageUrl,
      siteName: siteName,
    );
  }

  // ─────────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────────
  static String? _getMetaContent(String html, String property) {
    final needles = [
      'property="$property"',
      "property='$property'",
      'name="$property"',
      "name='$property'",
    ];
    for (final needle in needles) {
      final idx = html.indexOf(needle);
      if (idx == -1) continue;
      final tagStart = html.lastIndexOf('<', idx);
      final tagEnd = html.indexOf('>', idx);
      if (tagStart == -1 || tagEnd == -1) continue;
      final tag = html.substring(tagStart, tagEnd + 1);

      var cIdx = tag.indexOf('content="');
      if (cIdx != -1) {
        cIdx += 'content="'.length;
        final eq = tag.indexOf('"', cIdx);
        if (eq != -1) return tag.substring(cIdx, eq);
      }
      cIdx = tag.indexOf("content='");
      if (cIdx != -1) {
        cIdx += "content='".length;
        final eq = tag.indexOf("'", cIdx);
        if (eq != -1) return tag.substring(cIdx, eq);
      }
    }
    return null;
  }

  static String? _getHtmlTitle(String html) {
    final m = RegExp(r'<title>(.*?)</title>', caseSensitive: false, dotAll: true)
        .firstMatch(html);
    return m?.group(1)?.trim();
  }

  static String? _decodeHtmlEntities(String? text) {
    if (text == null) return null;
    return text
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&nbsp;', ' ');
  }
}
