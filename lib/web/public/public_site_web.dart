import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/home/auth_form_card.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/web/public/public_site_content.dart';

enum PublicSiteSection { home, about, pricing }

class PublicSiteWeb extends StatefulWidget {
  const PublicSiteWeb({super.key});

  @override
  State<PublicSiteWeb> createState() => _PublicSiteWebState();
}

class _PublicSiteWebState extends State<PublicSiteWeb> {
  PublicSiteSection _section = PublicSiteSection.home;

  void _openAuthPanel() {
    final isCompact = MediaQuery.of(context).size.width < 900;
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: EdgeInsets.symmetric(
            horizontal: isCompact ? 16 : 24,
            vertical: isCompact ? 16 : 32,
          ),
          backgroundColor: Colors.transparent,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Container(
                constraints: const BoxConstraints(maxWidth: 520),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: const Color(0xFFD4E3F8)),
                ),
                child: const SingleChildScrollView(
                  child: AuthFormCard(maxWidth: 460),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 960;
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      body: Stack(
        children: [
          const _PublicBackground(),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _PublicHeader(
                  currentSection: _section,
                  isCompact: isCompact,
                  onSelectSection: (section) {
                    setState(() {
                      _section = section;
                    });
                  },
                  onLoginPressed: _openAuthPanel,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    layoutBuilder: (currentChild, previousChildren) {
                      return Stack(
                        fit: StackFit.expand,
                        children: [
                          ...previousChildren,
                          if (currentChild != null) currentChild,
                        ],
                      );
                    },
                    child: _PublicPageView(
                      key: ValueKey(_section),
                      section: _section,
                      onSelectSection: (section) {
                        setState(() {
                          _section = section;
                        });
                      },
                      onLoginPressed: _openAuthPanel,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PublicHeader extends StatelessWidget {
  const _PublicHeader({
    required this.currentSection,
    required this.isCompact,
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final PublicSiteSection currentSection;
  final bool isCompact;
  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF10233E).withValues(alpha: 0.06),
                  blurRadius: 24,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: isCompact
                ? _CompactHeaderRow(
                    currentSection: currentSection,
                    onSelectSection: onSelectSection,
                    onLoginPressed: onLoginPressed,
                  )
                : _DesktopHeaderRow(
                    currentSection: currentSection,
                    onSelectSection: onSelectSection,
                    onLoginPressed: onLoginPressed,
                  ),
          ),
        ),
      ),
    );
  }
}

class _DesktopHeaderRow extends StatelessWidget {
  const _DesktopHeaderRow({
    required this.currentSection,
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final PublicSiteSection currentSection;
  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _BrandLockup()),
        const SizedBox(width: 32),
        _NavItem(
          label: 'Home',
          selected: currentSection == PublicSiteSection.home,
          onTap: () => onSelectSection(PublicSiteSection.home),
        ),
        _NavItem(
          label: 'Chi siamo',
          selected: currentSection == PublicSiteSection.about,
          onTap: () => onSelectSection(PublicSiteSection.about),
        ),
        _NavItem(
          label: 'Pricing',
          selected: currentSection == PublicSiteSection.pricing,
          onTap: () => onSelectSection(PublicSiteSection.pricing),
        ),
        const SizedBox(width: 8),
        TextButton(onPressed: onLoginPressed, child: const Text('Accedi')),
      ],
    );
  }
}

class _CompactHeaderRow extends StatelessWidget {
  const _CompactHeaderRow({
    required this.currentSection,
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final PublicSiteSection currentSection;
  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Expanded(child: _BrandLockup()),
        TextButton(onPressed: onLoginPressed, child: const Text('Accedi')),
        PopupMenuButton<PublicSiteSection>(
          icon: const Icon(Icons.menu_rounded),
          initialValue: currentSection,
          onSelected: onSelectSection,
          itemBuilder: (context) => const [
            PopupMenuItem(value: PublicSiteSection.home, child: Text('Home')),
            PopupMenuItem(
              value: PublicSiteSection.about,
              child: Text('Chi siamo'),
            ),
            PopupMenuItem(
              value: PublicSiteSection.pricing,
              child: Text('Pricing'),
            ),
          ],
        ),
      ],
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003B95).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: const EdgeInsets.all(8),
          child: Image.asset(startupLogoAsset),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PublicSiteContent.brandName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10233E),
              ),
            ),
            Text(
              PublicSiteContent.brandTagline,
              style: theme.textTheme.bodySmall?.copyWith(
                color: const Color(0xFF60738B),
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: selected
              ? const Color(0xFF003B95)
              : const Color(0xFF4F627B),
          backgroundColor: selected
              ? const Color(0xFFDCEAFF)
              : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: Text(label),
      ),
    );
  }
}

class _PublicPageView extends StatelessWidget {
  const _PublicPageView({
    super.key,
    required this.section,
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final PublicSiteSection section;
  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    switch (section) {
      case PublicSiteSection.home:
        return _HomePublicPage(
          onSelectSection: onSelectSection,
          onLoginPressed: onLoginPressed,
        );
      case PublicSiteSection.about:
        return _AboutPublicPage(onLoginPressed: onLoginPressed);
      case PublicSiteSection.pricing:
        return _PricingPublicPage(onLoginPressed: onLoginPressed);
    }
  }
}

class _HomePublicPage extends StatelessWidget {
  const _HomePublicPage({
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      child: Column(
        children: [
          _HeroSection(
            onPrimaryPressed: onLoginPressed,
            onSecondaryPressed: () =>
                onSelectSection(PublicSiteSection.pricing),
          ),
          const SizedBox(height: 28),
          const _HighlightsSection(),
          const SizedBox(height: 28),
          const _StatsBand(),
          const SizedBox(height: 28),
          const _WorkflowSection(),
        ],
      ),
    );
  }
}

class _AboutPublicPage extends StatelessWidget {
  const _AboutPublicPage({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      child: Column(
        children: [
          _PageIntroCard(
            eyebrow: PublicSiteContent.aboutEyebrow,
            title: PublicSiteContent.aboutTitle,
            description: PublicSiteContent.aboutDescription,
            actionLabel: PublicSiteContent.aboutActionButton,
            onActionPressed: onLoginPressed,
          ),
          const SizedBox(height: 28),
          const _StoryGrid(),
          const SizedBox(height: 28),
          const _ValuesSection(),
        ],
      ),
    );
  }
}

class _PricingPublicPage extends StatelessWidget {
  const _PricingPublicPage({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      child: Column(
        children: [
          _PageIntroCard(
            eyebrow: PublicSiteContent.pricingEyebrow,
            title: PublicSiteContent.pricingTitle,
            description: PublicSiteContent.pricingDescription,
            actionLabel: PublicSiteContent.pricingActionButton,
            onActionPressed: onLoginPressed,
          ),
          const SizedBox(height: 28),
          _PricingGrid(onLoginPressed: onLoginPressed),
          const SizedBox(height: 28),
          const _PricingFaqSection(),
        ],
      ),
    );
  }
}

class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: child,
              ),
            ),
          ),
          const _Footer(),
        ],
      ),
    );
  }
}

class _HeroSection extends StatelessWidget {
  const _HeroSection({
    required this.onPrimaryPressed,
    required this.onSecondaryPressed,
  });

  final VoidCallback onPrimaryPressed;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    final theme = Theme.of(context);
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (PublicSiteContent.heroBadge.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFDCEAFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Text(
              PublicSiteContent.heroBadge,
              style: TextStyle(
                color: Color(0xFF003B95),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          PublicSiteContent.heroTitle,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: const Color(0xFF10233E),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          PublicSiteContent.heroDescription,
          style: theme.textTheme.titleMedium?.copyWith(
            color: const Color(0xFF4C6078),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            ElevatedButton(
              onPressed: onPrimaryPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003B95),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
              ),
              child: const Text(PublicSiteContent.heroPrimaryButton),
            ),
            OutlinedButton(
              onPressed: onSecondaryPressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF003B95),
                side: const BorderSide(color: Color(0xFF003B95)),
                padding: const EdgeInsets.symmetric(
                  horizontal: 22,
                  vertical: 16,
                ),
              ),
              child: const Text(PublicSiteContent.heroSecondaryButton),
            ),
          ],
        ),
      ],
    );

    return Container(
      padding: EdgeInsets.all(isCompact ? 24 : 36),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFCFF), Color(0xFFEAF4FF), Color(0xFFFDF8EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(36),
        border: Border.all(color: const Color(0xFFDDE8F6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F223A).withValues(alpha: 0.08),
            blurRadius: 36,
            offset: const Offset(0, 24),
          ),
        ],
      ),
      child: isCompact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 24),
                const _HeroPreviewCard(),
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 6, child: details),
                const SizedBox(width: 24),
                const Expanded(flex: 5, child: _HeroPreviewCard()),
              ],
            ),
    );
  }
}

class _HeroPreviewCard extends StatelessWidget {
  const _HeroPreviewCard();

  @override
  Widget build(BuildContext context) {
    if (PublicSiteContent.heroImagePath.isNotEmpty) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: Image.asset(
            PublicSiteContent.heroImagePath,
            fit: BoxFit.cover,
          ),
        ),
      );
    }

    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF112540),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              _Dot(color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              _Dot(color: Color(0xFFFFD166)),
              SizedBox(width: 8),
              _Dot(color: Color(0xFF06D6A0)),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Dashboard booking',
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF06D6A0).withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: const Text(
                        'Live',
                        style: TextStyle(
                          color: Color(0xFF8AF0D0),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const _PreviewLine(label: 'Sale disponibili', value: '12'),
                const _PreviewLine(label: 'Jam in programma', value: '8'),
                const _PreviewLine(label: 'Richieste confermate', value: '94%'),
                const SizedBox(height: 18),
                Container(
                  height: 160,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: const LinearGradient(
                      colors: [
                        Color(0xFF0E86D4),
                        Color(0xFF46B1C9),
                        Color(0xFFF3A712),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Flusso semplificato',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: const [
                            _GraphBar(height: 54),
                            SizedBox(width: 10),
                            _GraphBar(height: 88),
                            SizedBox(width: 10),
                            _GraphBar(height: 68),
                            SizedBox(width: 10),
                            _GraphBar(height: 116),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HighlightsSection extends StatelessWidget {
  const _HighlightsSection();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _HighlightCard(
            icon: Icons.speaker_group_rounded,
            title: PublicSiteContent.highlight1Title,
            description: PublicSiteContent.highlight1Description,
            accent: Color(0xFF003B95),
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _HighlightCard(
            icon: Icons.graphic_eq_rounded,
            title: PublicSiteContent.highlight2Title,
            description: PublicSiteContent.highlight2Description,
            accent: Color(0xFFB7410E),
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _HighlightCard(
            icon: Icons.local_cafe_rounded,
            title: PublicSiteContent.highlight3Title,
            description: PublicSiteContent.highlight3Description,
            accent: Color(0xFF0E9F6E),
          ),
        ),
      ],
    );
  }
}

class _HighlightCard extends StatelessWidget {
  const _HighlightCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.accent,
  });

  final IconData icon;
  final String title;
  final String description;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: accent),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10233E),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF52657D),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatsBand extends StatelessWidget {
  const _StatsBand();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF10233E),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Wrap(
        spacing: 20,
        runSpacing: 20,
        children: [
          SizedBox(
            width: isCompact ? double.infinity : 340,
            child: const _StatTile(
              value: PublicSiteContent.stat1Value,
              label: PublicSiteContent.stat1Label,
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 340,
            child: const _StatTile(
              value: PublicSiteContent.stat2Value,
              label: PublicSiteContent.stat2Label,
            ),
          ),
          SizedBox(
            width: isCompact ? double.infinity : 340,
            child: const _StatTile(
              value: PublicSiteContent.stat3Value,
              label: PublicSiteContent.stat3Label,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: theme.textTheme.headlineMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFC9D8EA),
          ),
        ),
      ],
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    final summaryCard = _PageIntroCard(
      eyebrow: PublicSiteContent.workflowEyebrow,
      title: PublicSiteContent.workflowTitle,
      description: PublicSiteContent.workflowDescription,
      actionLabel: PublicSiteContent.workflowActionLabel,
      onActionPressed: () {},
      actionEnabled: false,
    );
    final checklistCard = Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE0EAF6)),
      ),
      child: Column(
        children: [
          ...PublicSiteContent.workflowSteps
              .map((step) => _ChecklistRow(text: step)),
          if (PublicSiteContent.workflowImagePath.isNotEmpty) ...[
            const SizedBox(height: 20),
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                PublicSiteContent.workflowImagePath,
                fit: BoxFit.cover,
              ),
            ),
          ],
        ],
      ),
    );

    return isCompact
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              summaryCard,
              const SizedBox(height: 20),
              checklistCard
            ],
          )
        : Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: summaryCard),
              const SizedBox(width: 20),
              Expanded(child: checklistCard),
            ],
          );
  }
}

class _ChecklistRow extends StatelessWidget {
  const _ChecklistRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFFDCEAFF),
              borderRadius: BorderRadius.circular(999),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 18,
              color: Color(0xFF003B95),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF445A74),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PageIntroCard extends StatelessWidget {
  const _PageIntroCard({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onActionPressed,
    this.actionEnabled = true,
  });

  final String eyebrow;
  final String title;
  final String description;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final bool actionEnabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFDDE8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow.toUpperCase(),
            style: theme.textTheme.labelLarge?.copyWith(
              color: const Color(0xFF003B95),
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: theme.textTheme.headlineMedium?.copyWith(
              color: const Color(0xFF10233E),
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF52657D),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          if (actionEnabled)
            ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003B95),
                foregroundColor: Colors.white,
              ),
              child: Text(actionLabel),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFEAF1FA),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                actionLabel,
                style: const TextStyle(
                  color: Color(0xFF40556E),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StoryGrid extends StatelessWidget {
  const _StoryGrid();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : 560,
          child: const _NarrativeCard(
            title: PublicSiteContent.story1Title,
            description: PublicSiteContent.story1Description,
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 560,
          child: const _NarrativeCard(
            title: PublicSiteContent.story2Title,
            description: PublicSiteContent.story2Description,
          ),
        ),
      ],
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFDDE8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
              color: const Color(0xFF10233E),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF52657D),
            ),
          ),
        ],
      ),
    );
  }
}

class _ValuesSection extends StatelessWidget {
  const _ValuesSection();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 920;
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _ValueTile(
            title: PublicSiteContent.value1Title,
            body: PublicSiteContent.value1Description,
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _ValueTile(
            title: PublicSiteContent.value2Title,
            body: PublicSiteContent.value2Description,
          ),
        ),
        SizedBox(
          width: isCompact ? double.infinity : 360,
          child: const _ValueTile(
            title: PublicSiteContent.value3Title,
            body: PublicSiteContent.value3Description,
          ),
        ),
      ],
    );
  }
}

class _ValueTile extends StatelessWidget {
  const _ValueTile({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF10233E),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFC9D8EA),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingGrid extends StatelessWidget {
  const _PricingGrid({required this.onLoginPressed});

  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: PublicSiteContent.pricingPlans.map((plan) {
        final isPopular = plan['popular'] as bool;
        return SizedBox(
          width: isCompact ? double.infinity : 360,
          child: _PricingCard(
            title: plan['title'] as String,
            price: plan['price'] as String,
            cadence: plan['period'] as String,
            description: plan['description'] as String,
            accent: isPopular ? const Color(0xFFB7410E) : const Color(0xFF003B95),
            features: List<String>.from(plan['features'] as List),
            actionLabel: plan['cta'] as String,
            onActionPressed: onLoginPressed,
            highlighted: isPopular,
          ),
        );
      }).toList(),
    );
  }
}

class _PricingCard extends StatelessWidget {
  const _PricingCard({
    required this.title,
    required this.price,
    required this.cadence,
    required this.description,
    required this.accent,
    required this.features,
    required this.actionLabel,
    required this.onActionPressed,
    this.highlighted = false,
  });

  final String title;
  final String price;
  final String cadence;
  final String description;
  final Color accent;
  final List<String> features;
  final String actionLabel;
  final VoidCallback onActionPressed;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(26),
      decoration: BoxDecoration(
        color: highlighted ? accent : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
        boxShadow: highlighted
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: 0.24),
                  blurRadius: 30,
                  offset: const Offset(0, 18),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (highlighted)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Consigliato',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          if (highlighted) const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              color: highlighted ? Colors.white : const Color(0xFF10233E),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: theme.textTheme.headlineMedium?.copyWith(
                color: highlighted ? Colors.white : const Color(0xFF10233E),
                fontWeight: FontWeight.w900,
              ),
              children: [
                TextSpan(text: price),
                TextSpan(
                  text: cadence,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: highlighted
                        ? Colors.white.withValues(alpha: 0.8)
                        : const Color(0xFF60738B),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Text(
            description,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: highlighted
                  ? const Color(0xFFF2F7FF)
                  : const Color(0xFF52657D),
            ),
          ),
          const SizedBox(height: 20),
          ...features.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: highlighted ? Colors.white : accent,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      feature,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: highlighted
                            ? const Color(0xFFF2F7FF)
                            : const Color(0xFF425770),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlighted ? Colors.white : accent,
                foregroundColor: highlighted ? accent : Colors.white,
              ),
              child: Text(actionLabel),
            ),
          ),
        ],
      ),
    );
  }
}

class _PricingFaqSection extends StatelessWidget {
  const _PricingFaqSection();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFDDE8F5)),
      ),
      child: Column(
        children: PublicSiteContent.pricingFaqs.map((faq) {
          return _FaqRow(
            question: faq['question']!,
            answer: faq['answer']!,
          );
        }).toList(),
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: theme.textTheme.titleMedium?.copyWith(
              color: const Color(0xFF10233E),
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            answer,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFF52657D),
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;

    return Container(
      color: const Color(0xFF10233E),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? 20 : 40,
        vertical: 40,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: isCompact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _FooterBrand(),
                    const SizedBox(height: 32),
                    _FooterContactSection(),
                    const SizedBox(height: 32),
                    _FooterLinksSection(),
                    const SizedBox(height: 32),
                    const _FooterCopyright(),
                  ],
                )
              : Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _FooterBrand()),
                        const SizedBox(width: 60),
                        Expanded(child: _FooterContactSection()),
                        const SizedBox(width: 60),
                        Expanded(child: _FooterLinksSection()),
                      ],
                    ),
                    const SizedBox(height: 32),
                    const Divider(
                      color: Color(0xFF3A5580),
                      height: 2,
                    ),
                    const SizedBox(height: 24),
                    const _FooterCopyright(),
                  ],
                ),
        ),
      ),
    );
  }
}

class _FooterBrand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          PublicSiteContent.brandName,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          PublicSiteContent.brandTagline,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: const Color(0xFFC9D8EA),
          ),
        ),
      ],
    );
  }
}

class _FooterContactSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'Contatti',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        _FooterContactItem(
          icon: Icons.phone_rounded,
          text: PublicSiteContent.footerPhone,
          centered: isCompact,
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.email_rounded,
          text: PublicSiteContent.footerEmail,
          centered: isCompact,
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.location_on_rounded,
          text: PublicSiteContent.footerAddress,
          centered: isCompact,
        ),
        const SizedBox(height: 12),
        _FooterContactItem(
          icon: Icons.schedule_rounded,
          text: PublicSiteContent.footerHours,
          centered: isCompact,
        ),
      ],
    );
  }
}

class _FooterContactItem extends StatelessWidget {
  const _FooterContactItem({
    required this.icon,
    required this.text,
    this.centered = false,
  });

  final IconData icon;
  final String text;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6BA3E5), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Color(0xFFC9D8EA),
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }
}

class _FooterLinksSection extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment:
          isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          'Link Utili',
          style: theme.textTheme.titleMedium?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        ...PublicSiteContent.footerLinks.map((link) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Text(
                link['label']!,
                style: const TextStyle(
                  color: Color(0xFF6BA3E5),
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          );
        }),
      ],
    );
  }
}

class _FooterCopyright extends StatelessWidget {
  const _FooterCopyright();

  @override
  Widget build(BuildContext context) {
    return Text(
      PublicSiteContent.footerText,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: Color(0xFF7A8FA8),
        fontSize: 12,
      ),
    );
  }
}

class _PublicBackground extends StatelessWidget {
  const _PublicBackground();

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Stack(
        children: [
          Positioned(
            top: -80,
            left: -40,
            child: Container(
              width: 320,
              height: 320,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x553FA9F5), Color(0x003FA9F5)],
                  center: Alignment.center,
                  radius: 0.8,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -120,
            right: -80,
            child: Container(
              width: 400,
              height: 400,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [Color(0x44FDB451), Color(0x00FDB451)],
                  center: Alignment.center,
                  radius: 0.8,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFFB8D4FF),
            fontSize: 13,
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _GraphBar extends StatelessWidget {
  const _GraphBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        height: height,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }
}
