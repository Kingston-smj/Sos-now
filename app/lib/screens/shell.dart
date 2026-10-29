import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import 'alerts_screen.dart';
import 'detail_screen.dart';
import 'feed_screen.dart';
import 'report_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final sos = SosScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('SOS Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if (sos.name != null)
              Text(sos.name!, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Log out',
            onPressed: _logout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          if (sos.error != null)
            MaterialBanner(
              content: Text(sos.error!),
              actions: [
                TextButton(onPressed: sos.refreshAll, child: const Text('Retry')),
              ],
            ),
          if (sos.liveMessage != null)
            MaterialBanner(
              backgroundColor: const Color(0xFFFFF4E5),
              content: Text(sos.liveMessage!),
              actions: [
                TextButton(onPressed: _openLive, child: const Text('View')),
                TextButton(onPressed: sos.dismissLive, child: const Text('Dismiss')),
              ],
            ),
          Expanded(
            child: IndexedStack(
              index: _index,
              children: [
                const FeedScreen(mine: false),
                ReportScreen(onCreated: _openCreated),
                const AlertsScreen(),
                const FeedScreen(mine: true),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.list_alt), label: 'Incidents'),
          const NavigationDestination(icon: Icon(Icons.add_box_outlined), selectedIcon: Icon(Icons.add_box), label: 'Report'),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: sos.unread > 0,
              label: Text('${sos.unread}'),
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: const Icon(Icons.notifications),
            label: 'Alerts',
          ),
          const NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Mine'),
        ],
      ),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              onPressed: () => setState(() => _index = 1),
              icon: const Icon(Icons.add),
              label: const Text('Report'),
            )
          : null,
    );
  }

  Future<void> _openCreated(Incident incident) async {
    setState(() => _index = 0);
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(incident: incident)));
  }

  Future<void> _openLive() async {
    final sos = SosScope.of(context);
    final id = sos.liveIncidentId;
    sos.dismissLive();
    if (id == null) {
      setState(() => _index = 2);
      return;
    }
    try {
      final incident = await sos.fetchIncident(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(incident: incident)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _index = 2);
    }
  }

  Future<void> _logout() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out?'),
        content: const Text('You can log in again with the same phone number.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Log out')),
        ],
      ),
    );
    if (yes == true && mounted) {
      await SosScope.of(context).logout();
    }
  }
}
