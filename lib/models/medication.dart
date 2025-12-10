class Medication {
  final String? id; // ID del doc en Firestore (interno)
  final String? medId; // ID de escaneo / código de barras (opcional)
  final String name;
  final String dose;
  final String presentation;
  final List<String> days; // ["Lun", "Mar", ...]
  final List<String> times; // ["08:00", "20:00"]
  final String status; // "pendiente", "tomado", "omitido"
  final String? description; // Texto libre opcional

  /// Mapa de tomas realizadas por fecha y hora:
  /// clave: "YYYY-MM-DD_HH:MM" -> true si ya fue tomada
  final Map<String, bool> taken;

  Medication({
    this.id,
    this.medId,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    this.status = 'pendiente',
    this.description,
    this.taken = const {},
  });

  Map<String, dynamic> toMap() {
    return {
      'medId': medId,
      'name': name,
      'dose': dose,
      'presentation': presentation,
      'days': days,
      'times': times,
      'status': status,
      'description': description,
      'taken': taken,
    };
  }

  factory Medication.fromMap(Map<String, dynamic> map, {String? id}) {
    return Medication(
      id: id,
      medId: map['medId'] as String?,
      name: map['name'] ?? '',
      dose: map['dose'] ?? '',
      presentation: map['presentation'] ?? '',
      days: List<String>.from(map['days'] ?? []),
      times: List<String>.from(map['times'] ?? []),
      status: map['status'] ?? 'pendiente',
      description: map['description'] as String?,
      taken: Map<String, bool>.from(map['taken'] ?? {}),
    );
  }
}
