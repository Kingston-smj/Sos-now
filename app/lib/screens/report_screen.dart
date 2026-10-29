import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';

import '../api.dart';
import '../models.dart';
import '../scope.dart';
import '../widgets/incident_map.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key, required this.onCreated});

  final ValueChanged<Incident> onCreated;

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final _place = TextEditingController();
  final _description = TextEditingController();
  final _latitude = TextEditingController();
  final _longitude = TextEditingController();
  String? _category;
  Uint8List? _photo;
  String _filename = 'scene.jpg';
  bool _locating = false;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _place.dispose();
    _description.dispose();
    _latitude.dispose();
    _longitude.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sos = SosScope.of(context);
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    final hasPoint = lat != null && lng != null && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('The report is shared with other signed-in users as soon as you send it.'),
        const SizedBox(height: 16),
        const Text('Category', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final category in sos.categories)
              ChoiceChip(
                label: Text(category),
                selected: _category == category,
                onSelected: (_) => setState(() => _category = category),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _place,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Place',
            hintText: 'Ikeja Along, Lagos',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'What is happening?',
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 16),
        const Text('Picture', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (_photo != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.memory(_photo!, height: 180, width: double.infinity, fit: BoxFit.cover),
          ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            if (!kIsWeb)
              OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.camera),
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('Camera'),
              ),
            OutlinedButton.icon(
              onPressed: () => _pick(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Gallery'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        const Text('Location', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _latitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Latitude'),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _longitude,
                keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                decoration: const InputDecoration(labelText: 'Longitude'),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ],
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _locating ? null : _locate,
            icon: _locating
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location),
            label: const Text('Use my location'),
          ),
        ),
        if (hasPoint) ...[
          const SizedBox(height: 8),
          IncidentMap(latitude: lat, longitude: lng, height: 180),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: const TextStyle(color: Color(0xFFB42318))),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.send),
          label: Text(_submitting ? 'Sending...' : 'Submit incident'),
        ),
      ],
    );
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final file = await ImagePicker().pickImage(source: source, imageQuality: 70, maxWidth: 1600);
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (!mounted) return;
      setState(() {
        _photo = bytes;
        _filename = file.name.isEmpty ? 'scene.jpg' : file.name;
        _error = null;
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not open that picture.');
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() => _error = 'Location permission was denied. Type the latitude and longitude instead.');
        }
        return;
      }
      final position = await Geolocator.getCurrentPosition();
      if (!mounted) return;
      setState(() {
        _latitude.text = position.latitude.toStringAsFixed(6);
        _longitude.text = position.longitude.toStringAsFixed(6);
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not read your location. Type the latitude and longitude instead.');
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    final category = _category;
    final lat = double.tryParse(_latitude.text.trim());
    final lng = double.tryParse(_longitude.text.trim());
    final place = _place.text.trim();
    final description = _description.text.trim();
    String? error;
    if (category == null) {
      error = 'Choose a category.';
    } else if (place.length < 2) {
      error = 'Enter the place, such as a street and city.';
    } else if (description.length < 10) {
      error = 'Describe the incident in at least 10 characters.';
    } else if (_photo == null) {
      error = 'Add a picture of the incident.';
    } else if (lat == null || lng == null || lat < -90 || lat > 90 || lng < -180 || lng > 180) {
      error = 'Enter a valid latitude and longitude.';
    }
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final created = await SosScope.of(context).submit(
        category: category!,
        description: description,
        latitude: lat!,
        longitude: lng!,
        placeName: place,
        photo: _photo!,
        filename: _filename,
      );
      if (!mounted) return;
      _place.clear();
      _description.clear();
      setState(() {
        _photo = null;
        _category = null;
      });
      widget.onCreated(created);
    } on ApiException catch (err) {
      if (mounted) setState(() => _error = err.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
