class Incident {
  Incident({
    required this.id,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.placeName,
    required this.photoUrl,
    required this.createdAt,
    required this.reporterName,
    required this.mine,
  });

  final int id;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String placeName;
  final String photoUrl;
  final DateTime createdAt;
  final String reporterName;
  final bool mine;

  factory Incident.fromJson(Map<String, dynamic> json) {
    return Incident(
      id: json['id'] as int,
      category: json['category'] as String,
      description: json['description'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      placeName: json['place_name'] as String,
      photoUrl: json['photo_url'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      reporterName: json['reporter_name'] as String,
      mine: json['mine'] as bool,
    );
  }
}

class AlertNote {
  AlertNote({
    required this.id,
    required this.message,
    required this.read,
    required this.createdAt,
    required this.incidentId,
    required this.category,
    required this.placeName,
  });

  final int id;
  final String message;
  final bool read;
  final DateTime createdAt;
  final int incidentId;
  final String category;
  final String placeName;

  factory AlertNote.fromJson(Map<String, dynamic> json) {
    return AlertNote(
      id: json['id'] as int,
      message: json['message'] as String,
      read: json['read'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      incidentId: json['incident_id'] as int,
      category: json['category'] as String,
      placeName: json['place_name'] as String,
    );
  }
}

class Account {
  Account({required this.id, required this.phone, required this.name});

  final int id;
  final String phone;
  final String name;

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] as int,
      phone: json['phone'] as String,
      name: json['name'] as String,
    );
  }
}

const defaultCategories = [
  'Accident',
  'Fighting',
  'Rioting',
  'Robbery',
  'Fire',
  'Medical',
  'Flood',
  'Kidnapping',
  'Other',
];
