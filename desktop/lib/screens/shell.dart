import "package:flutter/material.dart";
import "package:provider/provider.dart";
import "../providers/auth_provider.dart";
import "../theme/app_theme.dart";
import "dashboard/dashboard_screen.dart";
import "reservations/reservations_screen.dart";
import "calendar/calendar_screen.dart";
import "services/services_screen.dart";
import "hairdressers/hairdressers_screen.dart";
import "salons/salons_screen.dart";
import "verification/verification_screen.dart";
import "reference/reference_screen.dart";
import "reports/reports_screen.dart";

class AppShell extends StatefulWidget {
  const AppShell({super.key});
  @override
  State<AppShell> createState() => _AppShellState();
}

class _NavItem {
  final String label;
  final IconData icon;
  final Widget screen;
  final bool adminOnly;
  const _NavItem(this.label, this.icon, this.screen, {this.adminOnly = false});
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _allItems = [
    _NavItem("Dashboard", Icons.dashboard_outlined, DashboardScreen()),
    _NavItem("Rezervacije", Icons.event_note_outlined, ReservationsScreen()),
    _NavItem("Kalendar", Icons.calendar_month_outlined, CalendarScreen()),
    _NavItem("Saloni", Icons.store_outlined, SalonsScreen(), adminOnly: true),
    _NavItem("Usluge", Icons.content_cut, ServicesScreen()),
    _NavItem("Frizeri", Icons.people_outline, HairdressersScreen()),
    _NavItem("Verifikacija", Icons.verified_outlined, VerificationScreen(),
        adminOnly: true),
    _NavItem("Referentni podaci", Icons.storage_outlined, ReferenceScreen(),
        adminOnly: true),
    _NavItem("Izvjestaji", Icons.picture_as_pdf_outlined, ReportsScreen()),
  ];

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final isAdmin = user?.roles.contains("Administrator") ?? false;
    final items = _allItems
        .where((it) => !it.adminOnly || isAdmin)
        .toList();
    if (_index >= items.length) _index = 0;
    return Scaffold(
      body: Row(
        children: [
          // Sidebar
          Container(
            width: 240,
            color: AppColors.sidebar,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
                  child: Row(
                    children: [
                      const Icon(Icons.content_cut, color: Colors.white),
                      const SizedBox(width: 10),
                      Text("RezervisiMe",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final selected = i == _index;
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 2),
                        child: Material(
                          color: selected
                              ? AppColors.primary
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(10),
                            onTap: () => setState(() => _index = i),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 12),
                              child: Row(
                                children: [
                                  Icon(items[i].icon,
                                      size: 20,
                                      color: selected
                                          ? Colors.white
                                          : Colors.white70),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(items[i].label,
                                        style: TextStyle(
                                            color: selected
                                                ? Colors.white
                                                : Colors.white70,
                                            fontWeight: selected
                                                ? FontWeight.w600
                                                : FontWeight.normal)),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const Divider(color: Colors.white24, height: 1),
                // Korisnik + odjava
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          (user?.firstName.isNotEmpty ?? false)
                              ? user!.firstName[0].toUpperCase()
                              : "?",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user?.fullName ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13)),
                            Text(user?.roles.join(", ") ?? "",
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    color: Colors.white54, fontSize: 11)),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: "Odjava",
                        icon: const Icon(Icons.logout,
                            color: Colors.white70, size: 20),
                        onPressed: () =>
                            context.read<AuthProvider>().logout(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Sadrzaj
          Expanded(
            child: Container(
              color: AppColors.background,
              padding: const EdgeInsets.all(28),
              child: IndexedStack(
                index: _index,
                children: items.map((e) => e.screen).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
