import 'package:flutter/material.dart';

class FormattedText extends StatelessWidget {
  const FormattedText(this.text, {super.key, this.style, this.textAlign});

  final String text;
  final TextStyle? style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(style: style, children: _parseFormattedText(text, style)),
      textAlign: textAlign,
    );
  }
}

List<TextSpan> _parseFormattedText(String text, TextStyle? baseStyle) {
  final spans = <TextSpan>[];
  final buffer = StringBuffer();
  var bold = false;
  var italic = false;
  var underline = false;
  var index = 0;

  void flush() {
    if (buffer.isEmpty) {
      return;
    }

    spans.add(
      TextSpan(
        text: buffer.toString(),
        style: baseStyle?.copyWith(
          fontWeight: bold ? FontWeight.w800 : baseStyle.fontWeight,
          fontStyle: italic ? FontStyle.italic : baseStyle.fontStyle,
          decoration: underline
              ? TextDecoration.combine([
                  if (baseStyle.decoration != null) baseStyle.decoration!,
                  TextDecoration.underline,
                ])
              : baseStyle.decoration,
        ),
      ),
    );
    buffer.clear();
  }

  while (index < text.length) {
    if (text.startsWith('**', index)) {
      flush();
      bold = !bold;
      index += 2;
      continue;
    }

    if (text.startsWith('__', index)) {
      flush();
      underline = !underline;
      index += 2;
      continue;
    }

    if (text.startsWith('*', index)) {
      flush();
      italic = !italic;
      index += 1;
      continue;
    }

    buffer.write(text[index]);
    index += 1;
  }

  flush();
  return spans;
}
