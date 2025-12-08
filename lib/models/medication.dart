class Medication {
  final String? id; // id del documento en Firestore
  final String name;
  final String dose;
  final String presentation;
  final List<String> days; // ["L", "M", "X", ...]
  final List<String> times; // ["08:00", "20:00"]
  final String status; // "pendiente", "tomado", "omitido"

  Medication({
    this.id,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    this.status = 'pendiente',
  });

  // Para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dose': dose,
      'presentation': presentation,
      'days': days,
      'times': times,
      'status': status,
    };
  }

  // Para leer desde Firestore
  factory Medication.fromMap(Map<String, dynamic> map, {String? id}) {
    return Medication(
      id: id,
      name: map['name'] ?? '',
      dose: map['dose'] ?? '',
      presentation: map['presentation'] ?? '',
      days: List<String>.from(map['days'] ?? []),
      times: List<String>.from(map['times'] ?? []),
      status: map['status'] ?? 'pendiente',
    );
  }
}
