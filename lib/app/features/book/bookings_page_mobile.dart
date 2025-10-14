import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/book/book_now_page_mobile.dart';
import 'package:soundimplosion/app/features/profile/my_bookings_page_mobile.dart';

class BookingsPageMobile extends StatelessWidget {
  const BookingsPageMobile({super.key});

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
              unselectedLabelColor: colorScheme.onPrimary.withOpacity(0.7),
              indicatorColor: colorScheme.secondary,
              tabs: const <Widget>[
                Tab(
                  text: 'Prenota',
                  icon: Icon(Icons.add_circle_outline),
                ),
                Tab(
                  text: 'Le Mie Prenotazioni',
                  icon: Icon(Icons.history),
                ),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: <Widget>[
                BookNowPageMobile(),
                MyBookingsPageMobile(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
