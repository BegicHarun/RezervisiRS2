import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/notifications_provider.dart";
import "../theme/app_theme.dart";
import "home/home_screen.dart";
import "reservations/my_reservations_screen.dart";
import "history/history_screen.dart";
import "notifications/notifications_screen.dart";
import "profile/profile_screen.dart";

class RootScaffold extends StatefulWidget {
  const RootScaffold({super.key});
  @override
  State<RootScaffold> createState() => _RootScaffoldState();
}

class _RootScaffoldState extends State<RootScaffold> {
  int _index = 0;

  final _screens = const [
    HomeScreen(),
    MyReservationsScreen(),
    HistoryScreen(),
    NotificationsScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Startaj polling notifikacija (auto-refresh badge).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<NotificationsProvider>().startPolling();
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = context.watch<NotificationsProvider>().unread;

    return Scaffold(
      body: IndexedStack(index: _index, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          const NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Pocetna"),
          const NavigationDestination(
              icon: Icon(Icons.event_note_outlined),
              selectedIcon: Icon(Icons.event_note),
              label: "Rezervacije"),
          const NavigationDestination(
              icon: Icon(Icons.history),
              selectedIcon: Icon(Icons.history),
              label: "Historija"),
          NavigationDestination(
              icon: _BadgeIcon(
                  icon: Icons.notifications_outlined, count: unread),
              selectedIcon:
                  _BadgeIcon(icon: Icons.notifications, count: unread),
              label: "Obavijesti"),
          const NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: "Profil"),
        ],
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  final IconData icon;
  final int count;
  const _BadgeIcon({required this.icon, required this.count});

  @override
  Widget build(BuildContext context) {
    if (count == 0) return Icon(icon);
    return Badge(
      label: Text(count > 9 ? "9+" : "$count"),
      backgroundColor: AppColors.cancelled,
      child: Icon(icon),
    );
  }
}
