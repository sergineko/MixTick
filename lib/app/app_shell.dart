import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../shared/models/app_module.dart';
import 'localization/generated/app_localizations.dart';

class AppShell extends StatelessWidget {
  const AppShell({required this.navigationShell, super.key});
  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context);
    final titles = [
      strings.community,
      strings.recipes,
      strings.cookToday,
      strings.shopping,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[navigationShell.currentIndex]),
        actions: [
          IconButton(
            tooltip: strings.profile,
            onPressed: () => context.push('/profile'),
            icon: const Icon(Icons.person_outline),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          NavigationDestination(
            key: ValueKey(AppModule.community),
            icon: const Icon(Icons.people_outline),
            selectedIcon: const Icon(Icons.people),
            label: strings.community,
            tooltip: strings.community,
          ),
          NavigationDestination(
            key: ValueKey(AppModule.recipes),
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: strings.recipes,
            tooltip: strings.recipes,
          ),
          NavigationDestination(
            key: ValueKey(AppModule.cookToday),
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: strings.cookTodayNav,
            tooltip: strings.cookToday,
          ),
          NavigationDestination(
            key: ValueKey(AppModule.shopping),
            icon: const Icon(Icons.checklist_outlined),
            selectedIcon: const Icon(Icons.checklist),
            label: strings.shoppingNav,
            tooltip: strings.shopping,
          ),
        ],
      ),
    );
  }
}
