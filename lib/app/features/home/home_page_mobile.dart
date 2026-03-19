import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/home/feed_repository.dart';
import 'package:soundimplosion/app/features/home/home_feed_controller.dart';
import 'package:soundimplosion/app/features/jam/find_jam_page_mobile.dart';

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
          if (_controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (_controller.error != null) {
            return Center(
              child: Text('Errore caricamento feed: ${_controller.error}'),
            );
          }

          if (_controller.items.isEmpty) {
            return const Center(child: Text('Nessun aggiornamento nel feed.'));
          }

          return ListView.builder(
            itemCount: _controller.items.length,
            itemBuilder: (context, index) {
              final item = _controller.items[index];
              if (item.isJamPublished) {
                return _buildJamPostCard(item);
              }
              return const SizedBox.shrink();
            },
          );
        },
      ),
    );
  }

  // Widget per mostrare una nuova JAM nel feed
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
