import 'package:flutter/material.dart';
import 'package:soundimplosion/app/features/admin/admin_booking_management_page_mobile.dart';
import 'package:soundimplosion/app/features/admin/admin_jam_management_page_mobile.dart';

class AdminManagementPageMobile extends StatelessWidget {
  const AdminManagementPageMobile({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin'),
          bottom: TabBar(
            labelColor: colorScheme.onPrimary,
            unselectedLabelColor: colorScheme.onPrimary.withValues(alpha: 0.7),
            indicatorColor: colorScheme.secondary,
            tabs: const [
              Tab(icon: Icon(Icons.book_online), text: 'Prenotazioni'),
              Tab(icon: Icon(Icons.music_note), text: 'Jam'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            AdminBookingManagementPageMobile(embedded: true),
            AdminJamManagementPageMobile(embedded: true),
          ],
        ),
      ),
    );
  }
}