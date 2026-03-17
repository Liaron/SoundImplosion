import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_controller.dart';
import 'package:soundimplosion/app/features/jam/jam_repository.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_page_mobile.dart';

class AdminJamManagementPageMobile extends StatefulWidget {
  const AdminJamManagementPageMobile({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<AdminJamManagementPageMobile> createState() =>
      _AdminJamManagementPageMobileState();
}

class _AdminJamManagementPageMobileState
    extends State<AdminJamManagementPageMobile> {
  final AdminJamController _controller = AdminJamController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_handleControllerChanged);
    _controller.initialize();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _approveJam(String jamId) async {
    try {
      await _controller.approveJam(jamId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Jam approvata e pubblicata nel feed')),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _rejectJam(String jamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rifiuta jam'),
        content: const Text(
          'Vuoi rifiutare questa jam e liberare gli slot riservati?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Rifiuta'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.rejectJam(jamId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jam rifiutata')));
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Errore: ${e.toString().replaceAll('Exception: ', '')}',
          ),
        ),
      );
    }
  }

  Future<void> _rescheduleJam(JamListItem item) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => OrganizeJamPageMobile(initialJam: item),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jam riprogrammata')));
    }
  }

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null) {
      return Center(child: Text('Errore caricamento: ${_controller.error}'));
    }

    if (_controller.pendingJams.isEmpty) {
      return const Center(
        child: Text('Non ci sono jam in attesa di approvazione.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _controller.pendingJams.length,
      itemBuilder: (context, index) {
        final item = _controller.pendingJams[index];
        return _PendingJamCard(
          item: item,
          isSubmitting: _controller.isSubmitting,
          onApprove: () => _approveJam(item.id),
          onReject: () => _rejectJam(item.id),
          onReschedule: () => _rescheduleJam(item),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    if (widget.embedded) {
      return body;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Jam')),
      body: body,
    );
  }
}

class _PendingJamCard extends StatelessWidget {
  const _PendingJamCard({
    required this.item,
    required this.isSubmitting,
    required this.onApprove,
    required this.onReject,
    required this.onReschedule,
  });

  final JamListItem item;
  final bool isSubmitting;
  final VoidCallback onApprove;
  final VoidCallback onReject;
  final VoidCallback onReschedule;

  @override
  Widget build(BuildContext context) {
    final jam = item.jam;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    jam.descrizione.isEmpty
                        ? 'Jam senza descrizione'
                        : jam.descrizione,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(item.statusLabel),
                  backgroundColor: Colors.orange[100],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Data: ${item.dateLabel}'),
            Text('Orario: ${item.timeRangeLabel}'),
            Text('Creatore: ${jam.creatorNickname ?? jam.creatorId}'),
            Text('Pagamento: ${item.paymentLabel}'),
            Text(
              'Partecipanti: ${jam.personePresenti} presenti, ${jam.personeRichieste} richiesti',
            ),
            if (jam.attrezzatura.isNotEmpty)
              Text('Attrezzatura: ${jam.attrezzatura}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                OutlinedButton(
                  onPressed: isSubmitting ? null : onReject,
                  child: const Text('Rifiuta'),
                ),
                OutlinedButton(
                  onPressed: isSubmitting ? null : onReschedule,
                  child: const Text('Riprogramma'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting ? null : onApprove,
                  child: const Text('Conferma'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
