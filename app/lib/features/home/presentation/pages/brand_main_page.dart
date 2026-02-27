import 'dart:ui';

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
    final onSurface = theme.colorScheme.onSurface;
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _tabs),
      extendBody: true,
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFF9FC8F8).withValues(alpha: 0.18),
                ),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0x8A1B2638),
                    Color(0x7A111A2A),
                    Color(0x63202A3A),
                  ],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x88040A14),
                    blurRadius: 22,
                    offset: Offset(0, 12),
                  ),
                ],
              ),
              child: NavigationBarTheme(
                data: NavigationBarThemeData(
                  backgroundColor: Colors.transparent,
                  indicatorColor: const Color(
                    0xFF8EC8FF,
                  ).withValues(alpha: 0.23),
                  indicatorShape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: BorderSide(
                      color: const Color(0xFF9FC8F8).withValues(alpha: 0.22),
                    ),
                  ),
                  labelTextStyle: WidgetStateProperty.resolveWith<TextStyle>((
                    states,
                  ) {
                    final selected = states.contains(WidgetState.selected);
                    return GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: selected
                          ? const Color(0xFFEAF3FF)
                          : onSurface.withValues(alpha: 0.72),
                    );
                  }),
                  iconTheme: WidgetStateProperty.resolveWith<IconThemeData>((
                    states,
                  ) {
                    if (states.contains(WidgetState.selected)) {
                      return const IconThemeData(color: Color(0xFFEAF3FF));
                    }
                    return IconThemeData(
                      color: onSurface.withValues(alpha: 0.72),
                    );
                  }),
                ),
                child: NavigationBar(
                  height: 68,
                  backgroundColor: Colors.transparent,
                  labelBehavior: NavigationDestinationLabelBehavior.alwaysHide,
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
            ),
          ),
        ),
      ),
    );
  }
}
