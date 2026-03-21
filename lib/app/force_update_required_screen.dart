import 'package:flutter/material.dart';
import 'package:soundimplosion/services/app_update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class ForceUpdateRequiredScreen extends StatelessWidget {
  const ForceUpdateRequiredScreen({
    super.key,
    required this.status,
    required this.onRetry,
  });

  final AppUpdateStatus status;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final policy = status.policy;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.system_update_alt,
                  size: 72,
                  color: colorScheme.primary,
                ),
                const SizedBox(height: 20),
                Text(
                  policy?.title ?? 'Aggiornamento richiesto',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  policy?.message ??
                      'Per continuare a usare SoundImplosion devi aggiornare l\'app.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Versione installata: ${status.currentVersionLabel}'),
                      if (policy?.latestVersionLabel.isNotEmpty == true)
                        Text(
                          'Versione richiesta: ${policy!.latestVersionLabel}',
                        ),
                      if (policy != null)
                        Text(
                          'Build minima richiesta: ${policy.minimumBuildNumber}',
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: policy == null || policy.updateUrl.isEmpty
                      ? null
                      : () => _openUpdateUrl(policy.updateUrl),
                  icon: const Icon(Icons.download_outlined),
                  label: const Text('Aggiorna ora'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () {
                    onRetry();
                  },
                  child: const Text('Riprova verifica'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openUpdateUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}