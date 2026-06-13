import 'package:flutter/material.dart';
import 'package:flutter_linkify/flutter_linkify.dart';
import 'package:wumble/core/utils/link_navigator.dart';

class LinkifyText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final TextStyle? linkStyle;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow overflow;

  const LinkifyText(
    this.text, {
    super.key,
    this.style,
    this.linkStyle,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow = TextOverflow.clip,
  });

  @override
  Widget build(BuildContext context) {
    return Linkify(
      onOpen: (link) => LinkNavigator.handleUrl(context, link.url),
      text: text,
      style: style,
      linkStyle: linkStyle ?? const TextStyle(
        color: Color(0xFF1D9BF0), // Modern X (Twitter) blue
        decoration: TextDecoration.none,
        fontWeight: FontWeight.bold,
      ),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: overflow,
      options: LinkifyOptions(humanize: false),
    );
  }
}
