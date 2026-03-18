import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/book/book_now_page_mobile.dart';
import 'package:soundimplosion/app/features/book/my_bookings_page_mobile.dart';

class BookingsScaffoldMobile extends StatelessWidget {
  const BookingsScaffoldMobile({
    super.key,
    this.initialTabIndex = 0,
    this.initialBookingIdToOpen,
  });

  final int initialTabIndex;
  final String? initialBookingIdToOpen;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final tabBar = TabBar(
      labelColor: colorScheme.onPrimary,
      unselectedLabelColor: colorScheme.onPrimary.withValues(
        alpha: 0.7,
      ),
      indicatorColor: colorScheme.secondary,
      tabs: const <Widget>[
        Tab(text: 'Prenotazioni', icon: Icon(Icons.history)),
        Tab(text: 'Prenota', icon: Icon(Icons.add_circle_outline)),
      ],
    );
    final tabBarView = TabBarView(
      children: <Widget>[
        MyBookingsPageMobile(
          initialBookingIdToOpen: initialBookingIdToOpen,
        ),
        const BookNowPageMobile(),
      ],
    );

    return DefaultTabController(
      initialIndex: initialTabIndex,
      length: 2,
      child: Navigator.of(context).canPop()
          ? Scaffold(
              appBar: AppBar(
                title: const Text('Prenotazioni'),
                bottom: tabBar,
              ),
              body: tabBarView,
            )
          : Column(
              children: <Widget>[
                Material(
                  color: colorScheme.primary,
                  child: tabBar,
                ),
                Expanded(
                  child: tabBarView,
                ),
              ],
            ),
    );
  }
}
