import 'package:flutter/material.dart';
import 'package:soundimplosion/common/widgets/formatted_text.dart';
import 'package:soundimplosion/web/public/public_site_content.dart';

class AboutUsPageWeb extends StatelessWidget {
  const AboutUsPageWeb({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text(PublicSiteContent.aboutEyebrow)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 980),
          child: ListView(
            padding: const EdgeInsets.all(40),
            children: [
              Text(
                PublicSiteContent.aboutTitle,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 18),
              FormattedText(
                PublicSiteContent.aboutDescription,
                style: theme.textTheme.titleMedium?.copyWith(height: 1.55),
              ),
              const SizedBox(height: 32),
              const Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _AboutCard(
                    title: PublicSiteContent.story1Title,
                    body: PublicSiteContent.story1Description,
                  ),
                  _AboutCard(
                    title: PublicSiteContent.story2Title,
                    body: PublicSiteContent.story2Description,
                  ),
                  _AboutCard(
                    title: PublicSiteContent.value1Title,
                    body: PublicSiteContent.value1Description,
                  ),
                  _AboutCard(
                    title: PublicSiteContent.value2Title,
                    body: PublicSiteContent.value2Description,
                  ),
                  _AboutCard(
                    title: PublicSiteContent.value3Title,
                    body: PublicSiteContent.value3Description,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 300,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              FormattedText(
                body,
                style: theme.textTheme.bodyMedium?.copyWith(height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
