import 'package:flutter/material.dart';

import '../models.dart';
import '../scope.dart';
import '../widgets/incident_card.dart';
import 'detail_screen.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key, required this.mine});

  final bool mine;

  @override
  Widget build(BuildContext context) {
    final sos = SosScope.of(context);
    final items = mine ? sos.mine : sos.feed;
    return RefreshIndicator(
      onRefresh: mine ? sos.refreshMine : sos.refreshFeed,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          if (!mine) ...[
            const Text('Incidents other people have sent are listed here as soon as they are submitted.'),
            const SizedBox(height: 12),
            _CategoryRow(categories: sos.categories, selected: sos.selectedCategory, onSelected: sos.selectCategory),
            const SizedBox(height: 12),
          ] else ...[
            const Text('Incidents you have submitted.'),
            const SizedBox(height: 12),
          ],
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Text(
                mine ? 'You have not submitted an incident yet.' : 'No incidents in this category yet.',
                textAlign: TextAlign.center,
              ),
            )
          else
            ...items.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: IncidentCard(incident: incident, onTap: () => _open(context, incident)),
              ),
            ),
        ],
      ),
    );
  }

  void _open(BuildContext context, Incident incident) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DetailScreen(incident: incident)));
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.categories, required this.selected, required this.onSelected});

  final List<String> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[
      FilterChip(label: const Text('All'), selected: selected == null, onSelected: (_) => onSelected(null)),
      ...categories.map(
        (category) => FilterChip(
          label: Text(category),
          selected: selected == category,
          onSelected: (_) => onSelected(selected == category ? null : category),
        ),
      ),
    ];
    return Wrap(spacing: 8, runSpacing: 8, children: chips);
  }
}
