import 'package:flutter/material.dart';

/// A [TextEditingController] that renders Amino-style formatting tags
/// in real-time inside the editor — but with tags rendered as zero-size
/// (completely invisible) so they don't cause visual layout shifts.
///
/// When the cursor is on a line, the tag is shown as a tiny dim label
/// so the user knows formatting is active. On all other lines the tag
/// is rendered at fontSize≈0 and transparent — invisible but still
/// present in the character stream so cursor offsets remain correct.
class RichTextEditingController extends TextEditingController {
  bool showTags = false;
  int? cursorLine;
  bool _isFocused = false;

  bool get isFocused => _isFocused;
  set isFocused(bool value) {
    if (_isFocused != value) {
      _isFocused = value;
      notifyListeners();
    }
  }

  void updateCursorLine(int line) {
    if (cursorLine != line) {
      cursorLine = line;
      notifyListeners();
    }
  }

  void toggleTags(bool show) {
    if (showTags != show) {
      showTags = show;
      notifyListeners();
    }
  }

  // ── Regex helpers ──────────────────────────────────────────────────────────
  static final _tagRe    = RegExp(r'^\[([^\]]+)\]');
  static final _sizeRe   = RegExp(r'T=(\d+(?:\.\d+)?)');
  static final _colorRe  = RegExp(r'#=([A-Fa-f0-9]{6})');
  static final _bgRe     = RegExp(r'G=([A-Fa-f0-9]{6})');
  static final _fontRe   = RegExp(r'K=([a-zA-Z0-9_-]+)');

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final base = style ?? const TextStyle();
    final spans = <TextSpan>[];
    final lines = text.split('\n');

    for (int i = 0; i < lines.length; i++) {
      final line  = lines[i];
      final match = _tagRe.firstMatch(line);

      if (match != null) {
        final String tagStr  = match.group(1)!;
        final String content = line.substring(match.group(0)!.length);
        final bool   onThisLine = (i == cursorLine);

        // ── Formatting flags ─────────────────────────────────────────────────
        final bool bold   = tagStr.contains('B');
        final bool italic = tagStr.contains('I');
        final bool under  = tagStr.contains('U');
        final bool strike = tagStr.contains('S');
        final bool title  = tagStr.contains('M');

        double? fontSize;
        if (title) {
          fontSize = 26;
        } else {
          final sm = _sizeRe.firstMatch(tagStr);
          if (sm != null) fontSize = double.tryParse(sm.group(1)!);
        }

        Color? color;
        final cm = _colorRe.firstMatch(tagStr);
        if (cm != null) {
          color = Color(int.parse('FF${cm.group(1)!.toUpperCase()}', radix: 16));
        }

        Color? bgColor;
        final bm = _bgRe.firstMatch(tagStr);
        if (bm != null) {
          bgColor = Color(int.parse('FF${bm.group(1)!.toUpperCase()}', radix: 16));
        }

        String? fontFamily;
        final fm = _fontRe.firstMatch(tagStr);
        if (fm != null) {
          final f = fm.group(1)!.toLowerCase();
          if (f == 'serif')     fontFamily = 'serif';
          if (f == 'monospace') fontFamily = 'monospace';
        }

        final decs = <TextDecoration>[];
        if (under)  decs.add(TextDecoration.underline);
        if (strike) decs.add(TextDecoration.lineThrough);

        final contentStyle = base.copyWith(
          fontWeight:      bold   ? FontWeight.bold   : FontWeight.normal,
          fontStyle:       italic ? FontStyle.italic  : FontStyle.normal,
          decoration:      decs.isNotEmpty ? TextDecoration.combine(decs) : TextDecoration.none,
          decorationColor: Colors.white,
          fontSize:        fontSize,
          color:           color,
          backgroundColor: bgColor,
          fontFamily:      fontFamily,
        );

        // ── Tag label: visible only on active line, otherwise zero-size ───────
        final bool showLabel = showTags || onThisLine;
        spans.add(TextSpan(
          text: match.group(0),          // e.g. "[BC]"
          style: base.copyWith(
            color:       showLabel ? Colors.white30 : Colors.transparent,
            fontSize:    showLabel ? 10.0 : 0.001,
            height:      showLabel ? null : 0.001,
            letterSpacing: 0,
            fontWeight:  FontWeight.normal,
            fontStyle:   FontStyle.normal,
            decoration:  TextDecoration.none,
          ),
        ));

        // ── Formatted content ────────────────────────────────────────────────
        spans.add(TextSpan(text: content, style: contentStyle));

      } else {
        // Plain line — no tags.
        spans.add(TextSpan(text: line, style: base));
      }

      if (i < lines.length - 1) {
        spans.add(const TextSpan(text: '\n'));
      }
    }

    return TextSpan(children: spans, style: base);
  }
}
