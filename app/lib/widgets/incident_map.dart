import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class IncidentMap extends StatelessWidget {
  const IncidentMap({super.key, required this.latitude, required this.longitude, this.height = 220});

  final double latitude;
  final double longitude;
  final double height;

  @override
  Widget build(BuildContext context) {
    final point = LatLng(latitude, longitude);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all),
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                  userAgentPackageName: 'ng.sosnow.sos_now',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 44,
                      height: 44,
                      child: const Icon(Icons.location_pin, color: Color(0xFFB42318), size: 44),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Text('Map data © OpenStreetMap', style: TextStyle(fontSize: 12, color: Color(0xFF5C675F))),
      ],
    );
  }
}
