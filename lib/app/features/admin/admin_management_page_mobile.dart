import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_management_page_mobile.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_management_page_mobile.dart';
import 'package:soundimplosion/app/features/admin/admin_slot_management_page_mobile.dart';

class AdminManagementPageMobile extends StatelessWidget {
  const AdminManagementPageMobile({super.key, this.embedded = false});

  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final content = DefaultTabController(
      length: 3,
      child: Column(
        children: [
          Material(
            color:
                Theme.of(context).appBarTheme.backgroundColor ??
                Theme.of(context).colorScheme.primary,
            child: TabBar(
              labelColor: colorScheme.primary,
              unselectedLabelColor: colorScheme.onSurface.withValues(
                alpha: 0.6,
              ),
              indicatorColor: colorScheme.primary,
              tabs: const [
                Tab(icon: Icon(Icons.book_online), text: 'Prenotazioni'),
                Tab(icon: Icon(Icons.music_note), text: 'Jam'),
                Tab(icon: Icon(Icons.event_busy), text: 'Slot'),
              ],
            ),
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminBookingManagementPageMobile(embedded: true),
                AdminJamManagementPageMobile(embedded: true),
                AdminSlotManagementPageMobile(embedded: true),
              ],
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return content;
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Admin')),
      body: content,
    );
  }
}
