import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/find_jam_page_mobile.dart';

class JamSessionPageMobile extends StatelessWidget {
  final Map<String, dynamic>? initialJamToOpen;

  const JamSessionPageMobile({super.key, this.initialJamToOpen});

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Column(
        children: <Widget>[
          Material(
            color: colorScheme.primary,
            child: TabBar(
              labelColor: colorScheme.onPrimary,
              unselectedLabelColor: colorScheme.onPrimary.withAlpha(128), // Metodo corretto per opacità
              indicatorColor: colorScheme.secondary,
              tabs: const <Widget>[
                Tab(
                  text: 'Cerca Jam',
                  icon: Icon(Icons.search),
                ),
                Tab(
                  text: 'Organizza Jam',
                  icon: Icon(Icons.add_circle_outline),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              children: <Widget>[
                // Passiamo il parametro alla pagina Cerca Jam
                FindJamPageMobile(initialJamToOpen: initialJamToOpen),
                const OrganizeJamPageMobile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
