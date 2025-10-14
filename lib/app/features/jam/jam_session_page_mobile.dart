import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/jam/organize_jam_page_mobile.dart';
import 'package:soundimplosion/app/features/jam/find_jam_page_mobile.dart';

class JamSessionPageMobile extends StatelessWidget {
  const JamSessionPageMobile({super.key});

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
              unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.5),
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
          const Expanded(
            child: TabBarView(
              children: <Widget>[
                FindJamPageMobile(),
                OrganizeJamPageMobile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
