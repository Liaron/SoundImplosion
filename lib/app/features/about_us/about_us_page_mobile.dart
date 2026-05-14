import 'package:flutter/material.dart';
import 'package:soundimplosion/common/widgets/formatted_text.dart';
import 'package:soundimplosion/web/public/public_site_content.dart';

class AboutUsPageMobile extends StatelessWidget {
  const AboutUsPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(PublicSiteContent.aboutEyebrow)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            PublicSiteContent.aboutTitle,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          FormattedText(
            PublicSiteContent.aboutDescription,
            style: theme.textTheme.bodyLarge?.copyWith(height: 1.55),
          ),
          const SizedBox(height: 28),
          const _AboutSection(
            title: PublicSiteContent.story1Title,
            body: PublicSiteContent.story1Description,
          ),
          const _AboutSection(
            title: PublicSiteContent.story2Title,
            body: PublicSiteContent.story2Description,
          ),
          const _AboutSection(
            title: PublicSiteContent.value1Title,
            body: PublicSiteContent.value1Description,
          ),
          const _AboutSection(
            title: PublicSiteContent.value2Title,
            body: PublicSiteContent.value2Description,
          ),
          const _AboutSection(
            title: PublicSiteContent.value3Title,
            body: PublicSiteContent.value3Description,
          ),
        ],
      ),
    );
  }
}

class _AboutSection extends StatelessWidget {
  const _AboutSection({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          FormattedText(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
          ),
        ],
      ),
    );
  }
}
