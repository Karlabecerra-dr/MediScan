class Medication {
  final String? id; // id del documento en Firestore
  final String name;
  final String dose;
  final String presentation;
  final List<String> days; // ["Lun", "Mar", "Mié", ...]
  final List<String> times; // ["08:00", "20:00"]

  /// Estado global (lo mantendremos por compatibilidad, pero ya casi no lo usaremos)
  final String status; // "pendiente", "tomado", "omitido"

  /// Mapa de tomas marcadas como "tomado" por día y hora.
  ///
  /// Clave con formato "YYYY-MM-DD_HH:MM", por ejemplo:
  ///   "2025-12-09_08:00": true
  ///
  /// Si una clave no existe o es false -> se considera pendiente.
  final Map<String, bool> taken;

  Medication({
    this.id,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    this.status = 'pendiente',
    Map<String, bool>? taken,
  }) : taken = taken ?? {};

  // Para guardar en Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dose': dose,
      'presentation': presentation,
      'days': days,
      'times': times,
      'status': status,
      // Nuevo campo (backwards compatible: si no existe, Firestore simplemente no lo usa)
      'taken': taken,
    };
  }

  // Para leer desde Firestore
  factory Medication.fromMap(Map<String, dynamic> map, {String? id}) {
    // Manejo cuidadoso de "taken" para no romper documentos antiguos
    final rawTaken = map['taken'];
    Map<String, bool> parsedTaken = {};

    if (rawTaken is Map) {
      parsedTaken = rawTaken.map(
        (key, value) => MapEntry(
          key.toString(),
          value == true, // cualquier cosa "truthy" la tomamos como true
        ),
      );
    }

    return Medication(
      id: id,
      name: map['name'] ?? '',
      dose: map['dose'] ?? '',
      presentation: map['presentation'] ?? '',
      days: List<String>.from(map['days'] ?? []),
      times: List<String>.from(map['times'] ?? []),
      status: map['status'] ?? 'pendiente',
      taken: parsedTaken,
    );
  }
}
