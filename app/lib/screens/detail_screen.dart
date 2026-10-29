import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';
import '../widgets/incident_map.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(incident.category);
    return Scaffold(
      appBar: AppBar(title: Text(incident.category)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              incident.photoUrl,
              height: 240,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 240,
                color: const Color(0xFFE7E2D8),
                alignment: Alignment.center,
                child: const Text('Picture unavailable'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
              child: Text(incident.category, style: TextStyle(color: color, fontWeight: FontWeight.w700)),
            ),
          ),
          const SizedBox(height: 12),
          Text(incident.placeName, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          Text('${formatWhen(incident.createdAt)} · Reported by ${incident.reporterName}'),
          const SizedBox(height: 8),
          SelectableText(formatCoords(incident.latitude, incident.longitude)),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openExternalMap(context),
              icon: const Icon(Icons.map_outlined),
              label: const Text('Open in map'),
            ),
          ),
          IncidentMap(latitude: incident.latitude, longitude: incident.longitude),
          const SizedBox(height: 16),
          Text(incident.description, style: const TextStyle(fontSize: 16, height: 1.4)),
        ],
      ),
    );
  }

  Future<void> _openExternalMap(BuildContext context) async {
    final uri = Uri.parse(
      'https://www.openstreetmap.org/?mlat=${incident.latitude}&mlon=${incident.longitude}#map=16/${incident.latitude}/${incident.longitude}',
    );
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
      }
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the map.')));
      }
    }
  }
}
