import 'package:flutter/material.dart';

import '../format.dart';
import '../models.dart';
import '../theme.dart';

class IncidentCard extends StatelessWidget {
  const IncidentCard({super.key, required this.incident, required this.onTap});

  final Incident incident;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = categoryColor(incident.category);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  incident.photoUrl,
                  width: 76,
                  height: 76,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 76,
                    height: 76,
                    color: const Color(0xFFE7E2D8),
                    child: const Icon(Icons.image_not_supported_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        incident.category,
                        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 12),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(incident.placeName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(formatCoords(incident.latitude, incident.longitude)),
                    const SizedBox(height: 2),
                    Text(
                      '${formatWhen(incident.createdAt)} · ${incident.reporterName}',
                      style: const TextStyle(color: Color(0xFF5C675F)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
