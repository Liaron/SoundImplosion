import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/home/auth_form_card.dart';
import 'package:soundimplosion/app/startup_loading_screen.dart';
import 'package:soundimplosion/web/public/public_site_content.dart';
import 'package:url_launcher/url_launcher.dart';

enum PublicSiteSection { home, about, pricing, contact }

Future<void> _launchPublicLink(String url) async {
  final uri = Uri.tryParse(url);
  if (uri == null) {
    return;
  }

  await launchUrl(uri);
}

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
                child: SingleChildScrollView(
                  child: AuthFormCard(
                    maxWidth: 460,
                    onAuthenticated: () {
                      if (Navigator.of(dialogContext).canPop()) {
                        Navigator.of(dialogContext).pop();
                      }
                    },
                  ),
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
      endDrawer: isCompact
          ? _PublicMobileMenu(
              currentSection: _section,
              onSelectSection: (section) {
                Navigator.of(context).maybePop();
                setState(() {
                  _section = section;
                });
              },
              onLoginPressed: () {
                Navigator.of(context).maybePop();
                _openAuthPanel();
              },
            )
          : null,
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        isNarrow ? 14 : 20,
        isNarrow ? 14 : 20,
        isNarrow ? 14 : 20,
        isNarrow ? 8 : 12,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isNarrow ? 20 : 24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 12 : 18,
              vertical: isNarrow ? 10 : 14,
            ),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.82),
              borderRadius: BorderRadius.circular(isNarrow ? 20 : 24),
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
        _NavItem(
          label: 'Contatti',
          selected: currentSection == PublicSiteSection.contact,
          onTap: () => onSelectSection(PublicSiteSection.contact),
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
    final isNarrow = MediaQuery.of(context).size.width < 430;
    return Row(
      children: [
        const Expanded(child: _BrandLockup()),
        if (isNarrow)
          IconButton(
            onPressed: onLoginPressed,
            icon: const Icon(Icons.login_rounded),
            tooltip: 'Accedi',
          )
        else
          TextButton(onPressed: onLoginPressed, child: const Text('Accedi')),
        const SizedBox(width: 6),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFF003B95),
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003B95).withValues(alpha: 0.2),
                blurRadius: 18,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: IconButton(
            onPressed: () => Scaffold.of(context).openEndDrawer(),
            tooltip: 'Apri menu',
            icon: const Icon(Icons.menu_rounded),
            color: Colors.white,
          ),
        ),
      ],
    );
  }
}

class _PublicMobileMenu extends StatelessWidget {
  const _PublicMobileMenu({
    required this.currentSection,
    required this.onSelectSection,
    required this.onLoginPressed,
  });

  final PublicSiteSection currentSection;
  final ValueChanged<PublicSiteSection> onSelectSection;
  final VoidCallback onLoginPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Drawer(
      width: 300,
      backgroundColor: const Color(0xFFF7FAFD),
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(28),
          bottomLeft: Radius.circular(28),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: _BrandLockup()),
                  IconButton(
                    onPressed: () => Navigator.of(context).maybePop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: 'Chiudi menu',
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text(
                'Menu',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: const Color(0xFF60738B),
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 12),
              _MobileDrawerItem(
                label: 'Home',
                icon: Icons.home_rounded,
                selected: currentSection == PublicSiteSection.home,
                onTap: () => onSelectSection(PublicSiteSection.home),
              ),
              _MobileDrawerItem(
                label: 'Chi siamo',
                icon: Icons.groups_rounded,
                selected: currentSection == PublicSiteSection.about,
                onTap: () => onSelectSection(PublicSiteSection.about),
              ),
              _MobileDrawerItem(
                label: 'Pricing',
                icon: Icons.sell_rounded,
                selected: currentSection == PublicSiteSection.pricing,
                onTap: () => onSelectSection(PublicSiteSection.pricing),
              ),
              _MobileDrawerItem(
                label: 'Contatti',
                icon: Icons.call_rounded,
                selected: currentSection == PublicSiteSection.contact,
                onTap: () => onSelectSection(PublicSiteSection.contact),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: onLoginPressed,
                  icon: const Icon(Icons.login_rounded),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF003B95),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  label: const Text('Accedi'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MobileDrawerItem extends StatelessWidget {
  const _MobileDrawerItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFFDCEAFF) : const Color(0xFFF5F8FC),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? const Color(0xFF003B95)
                      : const Color(0xFF60738B),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected
                          ? const Color(0xFF003B95)
                          : const Color(0xFF10233E),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_rounded,
                    color: Color(0xFF003B95),
                    size: 18,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BrandLockup extends StatelessWidget {
  const _BrandLockup();

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < 430;
    final hideTagline = width < 520;
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isNarrow ? 42 : 52,
          height: isNarrow ? 42 : 52,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(isNarrow ? 12 : 16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF003B95).withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          padding: EdgeInsets.all(isNarrow ? 6 : 8),
          child: Image.asset(startupLogoAsset),
        ),
        SizedBox(width: isNarrow ? 10 : 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              PublicSiteContent.brandName,
              style: theme.textTheme.titleLarge?.copyWith(
                fontSize: isNarrow ? 20 : null,
                fontWeight: FontWeight.w800,
                color: const Color(0xFF10233E),
              ),
            ),
            if (!hideTagline)
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
        return _AboutPublicPage(
          onLoginPressed: onLoginPressed,
          onSelectSection: onSelectSection,
        );
      case PublicSiteSection.pricing:
        return _PricingPublicPage(
          onLoginPressed: onLoginPressed,
          onSelectSection: onSelectSection,
        );
      case PublicSiteSection.contact:
        return _ContactPublicPage(
          onLoginPressed: onLoginPressed,
          onSelectSection: onSelectSection,
        );
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
      onSelectSection: onSelectSection,
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
          _WorkflowSection(onActionPressed: onLoginPressed),
        ],
      ),
    );
  }
}

class _AboutPublicPage extends StatelessWidget {
  const _AboutPublicPage({
    required this.onLoginPressed,
    required this.onSelectSection,
  });

  final VoidCallback onLoginPressed;
  final ValueChanged<PublicSiteSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      onSelectSection: onSelectSection,
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
  const _PricingPublicPage({
    required this.onLoginPressed,
    required this.onSelectSection,
  });

  final VoidCallback onLoginPressed;
  final ValueChanged<PublicSiteSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      onSelectSection: onSelectSection,
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

class _ContactPublicPage extends StatelessWidget {
  const _ContactPublicPage({
    required this.onLoginPressed,
    required this.onSelectSection,
  });

  final VoidCallback onLoginPressed;
  final ValueChanged<PublicSiteSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    return _ScrollablePage(
      onSelectSection: onSelectSection,
      child: Column(
        children: [
          _PageIntroCard(
            eyebrow: PublicSiteContent.contactEyebrow,
            title: PublicSiteContent.contactTitle,
            descriptionLines: PublicSiteContent.contactDescription,
            actionLabel: PublicSiteContent.contactActionButton,
            onActionPressed: onLoginPressed,
          ),
          const SizedBox(height: 28),
          const _ContactGrid(),
        ],
      ),
    );
  }
}

class _ScrollablePage extends StatelessWidget {
  const _ScrollablePage({
    required this.child,
    required this.onSelectSection,
  });

  final Widget child;
  final ValueChanged<PublicSiteSection> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    return SingleChildScrollView(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              isNarrow ? 14 : 20,
              isNarrow ? 4 : 8,
              isNarrow ? 14 : 20,
              isNarrow ? 20 : 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1180),
                child: child,
              ),
            ),
          ),
          _Footer(onSelectSection: onSelectSection),
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 980;
    final isNarrow = width < 640;
    final theme = Theme.of(context);
    final downloadCard = const _HeroDownloadCard();
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
                fontSize: 13,
              ),
            ),
          ),
        SizedBox(height: isNarrow ? 16 : 20),
        Text(
          PublicSiteContent.heroTitle,
          style: (isNarrow
                  ? theme.textTheme.headlineMedium
                  : theme.textTheme.displaySmall)
              ?.copyWith(
            fontWeight: FontWeight.w900,
            height: 1.1,
            color: const Color(0xFF10233E),
          ),
        ),
        SizedBox(height: isNarrow ? 14 : 16),
        Text(
          PublicSiteContent.heroDescription,
          style: (isNarrow
                  ? theme.textTheme.bodyLarge
                  : theme.textTheme.titleMedium)
              ?.copyWith(
            color: const Color(0xFF4C6078),
            height: 1.5,
          ),
        ),
        SizedBox(height: isNarrow ? 20 : 24),
        if (isNarrow)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ElevatedButton(
                onPressed: onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF003B95),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(PublicSiteContent.heroPrimaryButton),
              ),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: onSecondaryPressed,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF003B95),
                  side: const BorderSide(color: Color(0xFF003B95)),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(PublicSiteContent.heroSecondaryButton),
              ),
            ],
          )
        else
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
      padding: EdgeInsets.all(isNarrow ? 20 : (isCompact ? 24 : 36)),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFCFF), Color(0xFFEAF4FF), Color(0xFFFDF8EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isNarrow ? 28 : 36),
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 20),
                downloadCard,
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 6,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: details,
                  ),
                ),
                const SizedBox(width: 24),
                const Expanded(
                  flex: 5,
                  child: _HeroDownloadCard(),
                ),
              ],
            ),
    );
  }
}

class _HeroDownloadCard extends StatelessWidget {
  const _HeroDownloadCard();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final hasDownload = PublicSiteContent.heroDownloadUrl.trim().isNotEmpty;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF112540),
        borderRadius: BorderRadius.circular(isNarrow ? 24 : 30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF112540).withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: const Color(0xFF39D98A).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(
                  Icons.android_rounded,
                  color: Color(0xFF8AF0D0),
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      PublicSiteContent.heroDownloadEyebrow.toUpperCase(),
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: const Color(0xFF8AF0D0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      PublicSiteContent.heroDownloadTitle,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            PublicSiteContent.heroDownloadDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFD5E3F5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Column(
              children: PublicSiteContent.heroDownloadHighlights
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Padding(
                            padding: EdgeInsets.only(top: 2),
                            child: Icon(
                              Icons.check_circle_rounded,
                              size: 18,
                              color: Color(0xFF8AF0D0),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: Colors.white,
                                height: 1.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: hasDownload
                  ? () => _launchPublicLink(PublicSiteContent.heroDownloadUrl)
                  : null,
              icon: const Icon(Icons.download_rounded),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF39D98A),
                foregroundColor: const Color(0xFF10233E),
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.14),
                disabledForegroundColor: const Color(0xFFD5E3F5),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              label: Text(
                hasDownload
                    ? PublicSiteContent.heroDownloadPrimaryButton
                    : 'APK disponibile a breve',
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            PublicSiteContent.heroDownloadSecondaryText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: const Color(0xFFB9CAE0),
              height: 1.5,
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
    if (isCompact) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _HighlightCard(
            icon: Icons.speaker_group_rounded,
            title: PublicSiteContent.highlight1Title,
            description: PublicSiteContent.highlight1Description,
            accent: Color(0xFF003B95),
          ),
          SizedBox(height: 20),
          _HighlightCard(
            icon: Icons.graphic_eq_rounded,
            title: PublicSiteContent.highlight2Title,
            description: PublicSiteContent.highlight2Description,
            accent: Color(0xFFB7410E),
          ),
          SizedBox(height: 20),
          _HighlightCard(
            icon: Icons.local_cafe_rounded,
            title: PublicSiteContent.highlight3Title,
            description: PublicSiteContent.highlight3Description,
            accent: Color(0xFF0E9F6E),
          ),
        ],
      );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: const [
          Expanded(
            child: _HighlightCard(
              icon: Icons.speaker_group_rounded,
              title: PublicSiteContent.highlight1Title,
              description: PublicSiteContent.highlight1Description,
              accent: Color(0xFF003B95),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: _HighlightCard(
              icon: Icons.graphic_eq_rounded,
              title: PublicSiteContent.highlight2Title,
              description: PublicSiteContent.highlight2Description,
              accent: Color(0xFFB7410E),
            ),
          ),
          SizedBox(width: 20),
          Expanded(
            child: _HighlightCard(
              icon: Icons.local_cafe_rounded,
              title: PublicSiteContent.highlight3Title,
              description: PublicSiteContent.highlight3Description,
              accent: Color(0xFF0E9F6E),
            ),
          ),
        ],
      ),
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isNarrow ? 22 : 26),
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
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;
    final isNarrow = width < 640;
    final statTiles = const [
      _StatTile(
        value: PublicSiteContent.stat1Value,
        label: PublicSiteContent.stat1Label,
      ),
      _StatTile(
        value: PublicSiteContent.stat2Value,
        label: PublicSiteContent.stat2Label,
      ),
      _StatTile(
        value: PublicSiteContent.stat3Value,
        label: PublicSiteContent.stat3Label,
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF10233E),
        borderRadius: BorderRadius.circular(isNarrow ? 24 : 32),
      ),
      child: isCompact
          ? Column(
              children: [
                for (var i = 0; i < statTiles.length; i++) ...[
                  statTiles[i],
                  if (i != statTiles.length - 1) const SizedBox(height: 20),
                ],
              ],
            )
          : Row(
              children: [
                for (var i = 0; i < statTiles.length; i++) ...[
                  Expanded(child: statTiles[i]),
                  if (i != statTiles.length - 1) const SizedBox(width: 20),
                ],
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return SizedBox(
      height: isNarrow ? 96 : 88,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 36,
            child: Center(
              child: Text(
                value,
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: isNarrow ? 26 : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: isNarrow ? 52 : 44,
            child: Center(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: const Color(0xFFC9D8EA),
                  fontSize: isNarrow ? 15 : null,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkflowSection extends StatelessWidget {
  const _WorkflowSection({required this.onActionPressed});

  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    final summaryCard = _PageIntroCard(
      eyebrow: PublicSiteContent.workflowEyebrow,
      title: PublicSiteContent.workflowTitle,
      description: PublicSiteContent.workflowDescription,
      actionLabel: PublicSiteContent.workflowActionLabel,
      onActionPressed: onActionPressed,
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
    this.description,
    this.descriptionLines,
    required this.actionLabel,
    required this.onActionPressed,
  }) : assert(
         description != null || descriptionLines != null,
         'Either description or descriptionLines must be provided.',
       );

  final String eyebrow;
  final String title;
  final String? description;
  final List<String>? descriptionLines;
  final String actionLabel;
  final VoidCallback onActionPressed;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isNarrow ? 22 : 28),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(isNarrow ? 24 : 30),
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
            style: (isNarrow
                    ? theme.textTheme.titleLarge
                    : theme.textTheme.headlineMedium)
                ?.copyWith(
              color: const Color(0xFF10233E),
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 14),
          if (descriptionLines != null)
            ...descriptionLines!.asMap().entries.map(
              (entry) => Padding(
                padding: EdgeInsets.only(bottom: entry.key == descriptionLines!.length - 1 ? 0 : 10),
                child: Text(
                  entry.value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: const Color(0xFF52657D),
                    height: 1.6,
                  ),
                ),
              ),
            )
          else
            Text(
              description!,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: const Color(0xFF52657D),
                height: 1.6,
              ),
            ),
          const SizedBox(height: 20),
          SizedBox(
            width: isNarrow ? double.infinity : null,
            child: ElevatedButton(
              onPressed: onActionPressed,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF003B95),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 16 : 20,
                  vertical: 14,
                ),
              ),
              child: Text(actionLabel),
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
    if (isCompact) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NarrativeCard(
            title: PublicSiteContent.story1Title,
            description: PublicSiteContent.story1Description,
          ),
          SizedBox(height: 20),
          _NarrativeCard(
            title: PublicSiteContent.story2Title,
            description: PublicSiteContent.story2Description,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: 560,
          child: const _NarrativeCard(
            title: PublicSiteContent.story1Title,
            description: PublicSiteContent.story1Description,
          ),
        ),
        SizedBox(
          width: 560,
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFFFFF), Color(0xFFF3F8FE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isNarrow ? 22 : 28),
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
    if (isCompact) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ValueTile(
            title: PublicSiteContent.value1Title,
            body: PublicSiteContent.value1Description,
          ),
          SizedBox(height: 20),
          _ValueTile(
            title: PublicSiteContent.value2Title,
            body: PublicSiteContent.value2Description,
          ),
          SizedBox(height: 20),
          _ValueTile(
            title: PublicSiteContent.value3Title,
            body: PublicSiteContent.value3Description,
          ),
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: [
        SizedBox(
          width: 360,
          child: const _ValueTile(
            title: PublicSiteContent.value1Title,
            body: PublicSiteContent.value1Description,
          ),
        ),
        SizedBox(
          width: 360,
          child: const _ValueTile(
            title: PublicSiteContent.value2Title,
            body: PublicSiteContent.value2Description,
          ),
        ),
        SizedBox(
          width: 360,
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 24),
      decoration: BoxDecoration(
        color: const Color(0xFF10233E),
        borderRadius: BorderRadius.circular(isNarrow ? 22 : 28),
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
    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < PublicSiteContent.pricingPlans.length; i++) ...[
            _PricingCard(
              title: PublicSiteContent.pricingPlans[i]['title'] as String,
              price: PublicSiteContent.pricingPlans[i]['price'] as String,
              cadence: PublicSiteContent.pricingPlans[i]['period'] as String,
              description: PublicSiteContent.pricingPlans[i]['description'] as String,
              accent: (PublicSiteContent.pricingPlans[i]['popular'] as bool)
                  ? const Color(0xFFB7410E)
                  : const Color(0xFF003B95),
              features: List<String>.from(
                PublicSiteContent.pricingPlans[i]['features'] as List,
              ),
              actionLabel: PublicSiteContent.pricingPlans[i]['cta'] as String,
              onActionPressed: onLoginPressed,
              highlighted: PublicSiteContent.pricingPlans[i]['popular'] as bool,
            ),
            if (i != PublicSiteContent.pricingPlans.length - 1)
              const SizedBox(height: 20),
          ],
        ],
      );
    }

    return Wrap(
      spacing: 20,
      runSpacing: 20,
      children: PublicSiteContent.pricingPlans.map((plan) {
        final isPopular = plan['popular'] as bool;
        return SizedBox(
          width: 360,
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 26),
      decoration: BoxDecoration(
        color: highlighted ? accent : Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(isNarrow ? 24 : 30),
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
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final faqs = PublicSiteContent.pricingFaqs;
    return Container(
      padding: EdgeInsets.all(isNarrow ? 22 : 28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isNarrow ? 24 : 30),
        border: Border.all(color: const Color(0xFFDDE8F5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: List.generate(faqs.length, (index) {
          final faq = faqs[index];
          return _FaqRow(
            question: faq['question']!,
            answer: faq['answer']!,
            isFirst: index == 0,
          );
        }),
      ),
    );
  }
}

class _ContactGrid extends StatelessWidget {
  const _ContactGrid();

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.of(context).size.width < 980;
    final categoryCards = <Widget>[
      if (PublicSiteContent.contactPhones.isNotEmpty)
        const _ContactCategoryCard(
          title: 'Numeri di telefono',
          icon: Icons.phone_in_talk_rounded,
          accent: Color(0xFF003B95),
          items: PublicSiteContent.contactPhones,
        ),
      if (PublicSiteContent.contactEmails.isNotEmpty)
        const _ContactCategoryCard(
          title: 'Email',
          icon: Icons.alternate_email_rounded,
          accent: Color(0xFF0E9F6E),
          items: PublicSiteContent.contactEmails,
        ),
      if (PublicSiteContent.contactSocials.isNotEmpty)
        const _ContactCategoryCard(
          title: 'Social',
          icon: Icons.campaign_rounded,
          accent: Color(0xFFB7410E),
          items: PublicSiteContent.contactSocials,
        ),
      const _ContactInfoCard(),
    ];

    if (isCompact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < categoryCards.length; i++) ...[
            categoryCards[i],
            if (i != categoryCards.length - 1) const SizedBox(height: 20),
          ],
        ],
      );
    }

    final rows = <Widget>[];
    for (var i = 0; i < categoryCards.length; i += 2) {
      final hasPair = i + 1 < categoryCards.length;
      if (!hasPair) {
        rows.add(categoryCards[i]);
        continue;
      }

      rows.add(
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: categoryCards[i]),
            const SizedBox(width: 20),
            Expanded(child: categoryCards[i + 1]),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i != rows.length - 1) const SizedBox(height: 20),
        ],
      ],
    );
  }
}

class _ContactCategoryCard extends StatelessWidget {
  const _ContactCategoryCard({
    required this.title,
    required this.icon,
    required this.accent,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color accent;
  final List<Map<String, String>> items;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 26),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isNarrow ? 22 : 28),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: const Color(0xFF10233E),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ContactActionTile(
                label: item['label'] ?? '',
                value: item['value'] ?? '',
                accent: accent,
                onTap: () => _launchPublicLink(item['url'] ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionTile extends StatelessWidget {
  const _ContactActionTile({
    required this.label,
    required this.value,
    required this.accent,
    required this.onTap,
  });

  final String label;
  final String value;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Ink(
          padding: EdgeInsets.all(isNarrow ? 16 : 18),
          decoration: BoxDecoration(
            color: const Color(0xFFF7FAFE),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFDDE8F5)),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: const Color(0xFF60738B),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      value,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF10233E),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded, color: accent),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactInfoCard extends StatelessWidget {
  const _ContactInfoCard();

  @override
  Widget build(BuildContext context) {
    final isNarrow = MediaQuery.of(context).size.width < 640;
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(isNarrow ? 20 : 26),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF10233E), Color(0xFF17345A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(isNarrow ? 22 : 28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            PublicSiteContent.contactInfoTitle,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            PublicSiteContent.contactInfoDescription,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: const Color(0xFFD7E4F5),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 20),
          const _FooterContactItem(
            icon: Icons.location_on_rounded,
            text: PublicSiteContent.footerAddress,
          ),
          const SizedBox(height: 12),
          const _FooterContactItem(
            icon: Icons.schedule_rounded,
            text: PublicSiteContent.footerHours,
          ),
        ],
      ),
    );
  }
}

class _FaqRow extends StatelessWidget {
  const _FaqRow({
    required this.question,
    required this.answer,
    this.isFirst = false,
  });

  final String question;
  final String answer;
  final bool isFirst;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        top: isFirst ? 4 : 20,
        bottom: 20,
      ),
      decoration: BoxDecoration(
        border: isFirst
            ? null
            : const Border(
                top: BorderSide(color: Color(0xFFE5EDF7)),
              ),
      ),
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
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({this.onSelectSection});

  final ValueChanged<PublicSiteSection>? onSelectSection;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isCompact = width < 900;
    final isNarrow = width < 640;

    return Container(
      color: const Color(0xFF10233E),
      padding: EdgeInsets.symmetric(
        horizontal: isCompact ? (isNarrow ? 16 : 20) : 40,
        vertical: isNarrow ? 28 : 40,
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
                    _FooterLinksSection(onSelectSection: onSelectSection),
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
                        Expanded(
                          child: _FooterLinksSection(
                            onSelectSection: onSelectSection,
                          ),
                        ),
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
    final isCompact = MediaQuery.of(context).size.width < 900;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment:
          isCompact ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      children: [
        Text(
          PublicSiteContent.brandName,
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          PublicSiteContent.brandTagline,
          textAlign: isCompact ? TextAlign.center : TextAlign.start,
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
    final hasFooterEmail = PublicSiteContent.footerEmail.trim().isNotEmpty;

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
        if (hasFooterEmail) ...[
          const SizedBox(height: 12),
          _FooterContactItem(
            icon: Icons.email_rounded,
            text: PublicSiteContent.footerEmail,
            centered: isCompact,
          ),
        ],
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
    final content = Text(
      text,
      textAlign: centered ? TextAlign.center : TextAlign.start,
      style: const TextStyle(
        color: Color(0xFFC9D8EA),
        fontSize: 14,
        height: 1.5,
      ),
    );

    return Row(
      mainAxisAlignment:
          centered ? MainAxisAlignment.center : MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: const Color(0xFF6BA3E5), size: 18),
        const SizedBox(width: 8),
        if (centered)
          Flexible(child: content)
        else
          Expanded(child: content),
      ],
    );
  }
}

class _FooterLinksSection extends StatelessWidget {
  const _FooterLinksSection({this.onSelectSection});

  final ValueChanged<PublicSiteSection>? onSelectSection;

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
              child: GestureDetector(
                onTap: () {
                  if (link['url'] == '/contact') {
                    onSelectSection?.call(PublicSiteSection.contact);
                    return;
                  }
                  _launchPublicLink(link['url'] ?? '');
                },
                child: Text(
                  link['label']!,
                  style: const TextStyle(
                    color: Color(0xFF6BA3E5),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                  ),
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          PublicSiteContent.footerText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF7A8FA8),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          PublicSiteContent.footerPoweredByText,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Color(0xFF90A1B6),
            fontSize: 11,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2,
          ),
        ),
      ],
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
