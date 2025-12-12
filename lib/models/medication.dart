// lib/models/medication.dart

class Medication {
  final String? id; // id de Firestore
  final String? userId; // dueño del medicamento
  final String? medId; // ID escaneado (código de barras)
  final String name;
  final String dose;
  final String presentation;
  final List<String> days; // ['Lun', 'Mar', 'Mié', ...]
  final List<String> times; // ['08:00', '20:00', ...]
  final String status; // 'pendiente', 'tomado', etc.
  final String? description;
  final Map<String, bool> taken; // clave: "yyyy-MM-dd_HH:mm"

  Medication({
    this.id,
    this.userId,
    this.medId,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    required this.status,
    this.description,
    required this.taken,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
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
      userId: map['userId'] as String?,
      medId: map['medId'] as String?,
      name: map['name'] as String? ?? '',
      dose: map['dose'] as String? ?? '',
      presentation: map['presentation'] as String? ?? 'Tableta',
      days: List<String>.from(map['days'] ?? const []),
      times: List<String>.from(map['times'] ?? const []),
      status: map['status'] as String? ?? 'pendiente',
      description: map['description'] as String?,
      taken: Map<String, bool>.from(map['taken'] ?? {}),
    );
  }
}
