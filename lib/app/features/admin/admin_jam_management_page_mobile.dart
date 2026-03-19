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
        builder: (_) => OrganizeJamPageMobile(
          initialJam: item,
          onEditSubmit: ({
            required DateTime selectedDate,
            required List<String> selectedSlots,
            String? groupId,
            required String title,
            required int presentPeople,
            required int requiredPeople,
            required String description,
            required String payment,
            required String equipment,
          }) {
            return _controller.proposeJamUpdate(
              jamId: item.id,
              selectedDate: selectedDate,
              selectedSlots: selectedSlots,
              groupId: groupId,
              title: title,
              presentPeople: presentPeople,
              requiredPeople: requiredPeople,
              description: description,
              payment: payment,
              equipment: equipment,
            );
          },
          editAppBarTitle: 'Proponi modifica jam',
          editSubmitLabel: 'INVIA PROPOSTA',
          editSuccessTitle: 'Proposta inviata',
          editSuccessMessage:
              'La proposta di modifica e stata inviata al creatore della jam.',
        ),
      ),
    );

    if (result == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Proposta di modifica inviata')));
    }
  }

  Future<void> _deleteJam(String jamId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Elimina jam'),
        content: const Text('Vuoi eliminare questa jam gia approvata?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annulla'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Elimina'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }

    try {
      await _controller.deleteJam(jamId);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Jam eliminata')));
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

  Widget _buildBody() {
    if (_controller.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_controller.error != null) {
      return Center(child: Text('Errore caricamento: ${_controller.error}'));
    }

    return DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const TabBar(
            tabs: [
              Tab(text: 'Proposte'),
              Tab(text: 'Approvate'),
            ],
          ),
          Expanded(
            child: TabBarView(
              children: [
                _buildJamList(items: _controller.pendingJams, approved: false),
                _buildJamList(items: _controller.approvedJams, approved: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJamList({
    required List<JamListItem> items,
    required bool approved,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          approved
              ? 'Non ci sono jam gia approvate.'
              : 'Non ci sono jam in attesa di approvazione.',
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return _PendingJamCard(
          item: item,
          approved: approved,
          isSubmitting: _controller.isSubmitting,
          onApprove: approved ? null : () => _approveJam(item.id),
          onReject: approved ? null : () => _rejectJam(item.id),
          onReschedule: () => _rescheduleJam(item),
          onDelete: approved ? () => _deleteJam(item.id) : null,
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
    required this.approved,
    required this.isSubmitting,
    this.onApprove,
    this.onReject,
    this.onReschedule,
    this.onDelete,
  });

  final JamListItem item;
  final bool approved;
  final bool isSubmitting;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onReschedule;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final jam = item.jam;
    final jamTitle = jam.titolo.trim().isEmpty
        ? 'Jam senza titolo'
        : jam.titolo.trim();
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
                    jamTitle,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    item.statusLabel,
                    style: const TextStyle(color: Colors.black87),
                  ),
                  backgroundColor: approved
                      ? Colors.green[100]
                      : Colors.orange[100],
                  side: BorderSide.none,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('Titolo jam: $jamTitle'),
            Text('Data: ${item.dateLabel}'),
            Text('Orario: ${item.timeRangeLabel}'),
            Text('Creatore: ${jam.creatorNickname ?? jam.creatorId}'),
            if (jam.descrizione.trim().isNotEmpty)
              Text('Descrizione: ${jam.descrizione.trim()}'),
            Text('Pagamento: ${item.paymentLabel}'),
            Text('Partecipanti richiesti: ${jam.personeRichieste}'),
            Text('Partecipanti confermati: ${jam.personePresenti}'),
            if (jam.attrezzatura.isNotEmpty)
              Text('Attrezzatura: ${jam.attrezzatura}'),
            const SizedBox(height: 12),
            if (!approved) ...[
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onReject,
                      child: const Text('Rifiuta'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onReschedule,
                      child: const Text('Riprogramma'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: isSubmitting ? null : onApprove,
                  child: const Text('Approva jam'),
                ),
              ),
            ] else
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: isSubmitting ? null : onReschedule,
                      child: const Text('Proponi modifica'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: isSubmitting ? null : onDelete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Elimina'),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
