import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../campaigns/presentation/pages/brand_home_page.dart';
import '../../../profile/presentation/pages/profile_page.dart';
import 'brand_search_page.dart';

class BrandMainPage extends StatefulWidget {
  const BrandMainPage({super.key});

  @override
  State<BrandMainPage> createState() => _BrandMainPageState();
}

class _BrandMainPageState extends State<BrandMainPage> {
  int _selectedIndex = 0;

  static const List<Widget> _tabs = <Widget>[
    BrandHomePage(),
    BrandSearchPage(),
    ProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      extendBody: true,
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: const Color(0xE0121A28),
          indicatorColor: const Color(0xFF8EC8FF).withValues(alpha: 0.23),
          labelTextStyle: WidgetStatePropertyAll<TextStyle>(
            GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((states) {
            if (states.contains(WidgetState.selected)) {
              return const IconThemeData(color: Color(0xFFEAF3FF));
            }
            return IconThemeData(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            );
          }),
        ),
        child: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            if (index == _selectedIndex) return;
            setState(() => _selectedIndex = index);
          },
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_rounded),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Cerca',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profilo',
            ),
          ],
        ),
      ),
    );
  }
}
