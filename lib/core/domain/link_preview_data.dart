import 'package:equatable/equatable.dart';

class LinkPreviewData extends Equatable {
  final String url;
  final String? title;
  final String? description;
  final String? imageUrl;
  final String? siteName;
  final String? faviconUrl;
  final String? youtubeVideoId;

  const LinkPreviewData({
    required this.url,
    this.title,
    this.description,
    this.imageUrl,
    this.siteName,
    this.faviconUrl,
    this.youtubeVideoId,
  });

  @override
  List<Object?> get props => [url, title, description, imageUrl, siteName, faviconUrl, youtubeVideoId];

  Map<String, dynamic> toMap() {
    return {
      'url': url,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (imageUrl != null) 'imageUrl': imageUrl,
      if (siteName != null) 'siteName': siteName,
      if (faviconUrl != null) 'faviconUrl': faviconUrl,
      if (youtubeVideoId != null) 'youtubeVideoId': youtubeVideoId,
    };
  }

  factory LinkPreviewData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const LinkPreviewData(url: '');
    return LinkPreviewData(
      url: map['url'] ?? '',
      title: map['title'],
      description: map['description'],
      imageUrl: map['imageUrl'],
      siteName: map['siteName'],
      faviconUrl: map['faviconUrl'],
      youtubeVideoId: map['youtubeVideoId'],
    );
  }

  bool get isEmpty => url.isEmpty;
  bool get isNotEmpty => url.isNotEmpty;
}
