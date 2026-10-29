import 'package:flutter/material.dart';

import '../api.dart';
import '../format.dart';
import '../scope.dart';
import '../theme.dart';
import 'detail_screen.dart';

class AlertsScreen extends StatelessWidget {
  const AlertsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final sos = SosScope.of(context);
    return RefreshIndicator(
      onRefresh: () => sos.refreshAlerts(announce: false),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              const Expanded(child: Text('You are notified when another person submits an incident.')),
              if (sos.unread > 0)
                TextButton(onPressed: sos.markAllRead, child: const Text('Mark all read')),
            ],
          ),
          const SizedBox(height: 8),
          if (sos.alerts.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Text('No alerts yet.', textAlign: TextAlign.center),
            )
          else
            ...sos.alerts.map((note) {
              final color = categoryColor(note.category);
              return Card(
                child: ListTile(
                  leading: Icon(note.read ? Icons.notifications_none : Icons.notifications_active, color: color),
                  title: Text(note.message, style: TextStyle(fontWeight: note.read ? FontWeight.w500 : FontWeight.w800)),
                  subtitle: Text('${note.category} · ${formatWhen(note.createdAt)}'),
                  onTap: () => _open(context, note.incidentId, note.id),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context, int incidentId, int noteId) async {
    final sos = SosScope.of(context);
    try {
      await sos.markRead(noteId);
      final incident = await sos.fetchIncident(incidentId);
      if (!context.mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(incident: incident)));
    } on ApiException catch (err) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err.message)));
    }
  }
}
