import 'package:flutter/material.dart';
import 'package:soundimplosion/web/features/about_us/about_us_page_web.dart';
import 'package:soundimplosion/web/features/book/book_now_page_web.dart';
import 'package:soundimplosion/web/features/contact_us/contact_us_page_web.dart';
import 'package:soundimplosion/web/features/home/home_page_web.dart';
import 'package:soundimplosion/web/features/profile/profile_details_page_web.dart';

class WebScaffoldWeb extends StatefulWidget {
  const WebScaffoldWeb({super.key});

  @override
  State<WebScaffoldWeb> createState() => _WebScaffoldWebState();
}

class _WebScaffoldWebState extends State<WebScaffoldWeb> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    const HomePageWeb(title: 'Home'),
    const AboutUsPageWeb(),
    const BookNowPageWeb(),
    const ProfileDetailsPageWeb(),
    const ContactUsPageWeb(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (int index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home),
                label: Text('Home'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.info_outline),
                selectedIcon: Icon(Icons.info),
                label: Text('Chi siamo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.book_outlined),
                selectedIcon: Icon(Icons.book),
                label: Text('Prenota'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.person_outline),
                selectedIcon: Icon(Icons.person),
                label: Text('Profilo'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.contact_mail_outlined),
                selectedIcon: Icon(Icons.contact_mail),
                label: Text('Contattaci'),
              ),
            ],
          ),
          const VerticalDivider(thickness: 1, width: 1),
          // This is the main content.
          Expanded(child: _pages[_selectedIndex]),
        ],
      ),
    );
  }
}
