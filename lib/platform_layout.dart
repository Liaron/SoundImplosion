import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class PlatformLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget webBody;

  const PlatformLayout({
    super.key,
    required this.mobileBody,
    required this.webBody,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return webBody;
    } else {
      return mobileBody;
    }
  }
}
