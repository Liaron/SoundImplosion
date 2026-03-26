import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:soundimplosion/app/features/book/booking_repository.dart';
import 'package:soundimplosion/app/features/book/bookings_scaffold_mobile.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';
import 'package:soundimplosion/app/features/home/home_feed_controller.dart';
import 'package:soundimplosion/app/features/jam/find_jam_page_mobile.dart';
import 'package:soundimplosion/models/models.dart';

class HomePageMobile extends StatefulWidget {
  const HomePageMobile({super.key});

  @override
  State<HomePageMobile> createState() => _HomePageMobileState();
}

class _HomePageMobileState extends State<HomePageMobile> {
  final HomeFeedController _controller = HomeFeedController();

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

  Future<void> _openJamDetails(HomeFeedItem item) async {
    final jamId = item.jamId;
    if (jamId == null || jamId.isEmpty) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Dettagli jam non disponibili per questo aggiornamento.',
          ),
        ),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => FindJamPageMobile(
          initialJamToOpen: {
            'key': jamId,
            'jam_id': jamId,
            'creator_id': item.creatorId,
            'data': item.date,
            'ora_inizio': item.startTime,
            'descrizione': item.description,
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Builder(
        builder: (context) {
          final visibleJamItems = _controller.items
              .where((item) => item.isJamPublished)
              .toList();

          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null) {
            return Center(
              child: Text('Errore caricamento feed: ${_controller.error}'),
            );
          }

          if (visibleJamItems.isEmpty && _controller.bookings.isEmpty) {
            return const Center(
              child: Text(
                'Nessun aggiornamento.\n'
                'Le tue prenotazioni o le jam pubblicate verranno visualizzate qui.',
                textAlign: TextAlign.center,
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(top: 12, bottom: 16),
            children: [
              if (_controller.bookings.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.event_available,
                  title: 'Prenotazioni',
                  subtitle: 'Le tue prenotazioni e quelle dei tuoi gruppi',
                ),
                ..._controller.bookings.map(_buildBookingCard),
                const SizedBox(height: 12),
              ],
              if (visibleJamItems.isNotEmpty) ...[
                _buildSectionHeader(
                  icon: Icons.music_note_rounded,
                  title: 'Jam Nel Feed',
                  subtitle: 'Ultimi aggiornamenti pubblicati',
                ),
                ...visibleJamItems.map(_buildJamPostCard),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBookingDetails(BookingListItem item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BookingsScaffoldMobile(
          initialTabIndex: 0,
          initialBookingIdToOpen: item.id,
        ),
      ),
    );
  }

  String _formatDateLabel(String rawDate) {
    try {
      final parsed = DateTime.parse(rawDate);
      final label = DateFormat('EEEE d MMMM yyyy').format(parsed);
      return label[0].toUpperCase() + label.substring(1);
    } catch (_) {
      return rawDate;
    }
  }

  Color _statusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confermata:
        return Colors.green.shade100;
      case BookingStatus.inElaborazione:
        return Colors.orange.shade100;
      case BookingStatus.annullata:
        return Colors.red.shade100;
      case BookingStatus.sospesa:
        return Colors.blueGrey.shade100;
      case BookingStatus.superata:
        return Colors.grey.shade300;
    }
  }

  Color _statusTextColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.confermata:
        return Colors.green.shade900;
      case BookingStatus.inElaborazione:
        return Colors.orange.shade900;
      case BookingStatus.annullata:
        return Colors.red.shade900;
      case BookingStatus.sospesa:
        return Colors.blueGrey.shade900;
      case BookingStatus.superata:
        return Colors.grey.shade800;
    }
  }

  Widget _buildBookingCard(BookingListItem item) {
    final booking = item.booking;
    final groupText = item.groupLabel;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      elevation: 2,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openBookingDetails(item),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      _formatDateLabel(booking.data),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Chip(
                    label: Text(
                      item.statusLabel,
                      style: TextStyle(
                        color: _statusTextColor(booking.stato),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    backgroundColor: _statusColor(booking.stato),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metaChip(
                    Icons.schedule,
                    '${booking.oraInizio} - ${booking.oraFine}',
                  ),
                  _metaChip(
                    Icons.group_outlined,
                    '${booking.numeroUtenti} persone',
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                groupText,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              if (booking.attrezzatura.trim().isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Attrezzatura: ${booking.attrezzatura.trim()}'),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _metaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(label)],
      ),
    );
  }

  Widget _buildJamPostCard(HomeFeedItem item) {
    final date = item.date ?? 'N/A';
    final startTime = item.startTime ?? 'N/A';
    final title = item.title?.trim().isNotEmpty == true
        ? item.title!.trim()
        : 'Nuova Jam Session';
    final description = item.description ?? '';
    // Potremmo recuperare il nickname del creatore, ma per ora teniamolo semplice
    // final creatorId = item['creator_id'];

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.music_note_rounded,
                  color: Colors.purple,
                  size: 24,
                ),
                const SizedBox(width: 8),
                const Text(
                  "Nuova Jam Session!",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '"$description"',
              style: TextStyle(
                fontSize: 16,
                fontStyle: FontStyle.italic,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Quando? Il $date alle ore $startTime',
              style: TextStyle(
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton(
                onPressed: () => _openJamDetails(item),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.purple[100],
                  foregroundColor: Colors.purple[900],
                ),
                child: const Text("Vedi dettagli"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget per aggiornamenti dello staff (da implementare)
  // Widget _buildStaffPostCard(Map<String, dynamic> item) {
  //   // ...
  // }
}
