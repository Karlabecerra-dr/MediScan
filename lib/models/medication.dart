// lib/models/medication.dart
//
// Modelo que representa un medicamento dentro de la app.
// Se utiliza para mapear datos entre Firestore y la aplicación.

class Medication {
  // ID del documento en Firestore
  final String? id;

  // ID del usuario dueño del medicamento
  final String? userId;

  // ID obtenido desde el escaneo (por ejemplo, código de barras)
  final String? medId;

  // ✅ ID del perfil dueño del medicamento (perfil dentro de la cuenta)
  final String? profileId;

  // Nombre del medicamento
  final String name;

  // Dosis del medicamento (ej: "500 mg")
  final String dose;

  // Presentación del medicamento (ej: Tableta, Jarabe, Cápsula)
  final String presentation;

  // Días en los que se debe tomar el medicamento
  // Ejemplo: ['Lun', 'Mar', 'Mié']
  final List<String> days;

  // Horarios de toma del medicamento
  // Ejemplo: ['08:00', '20:00']
  final List<String> times;

  // Estado actual del medicamento
  // Ejemplo: 'pendiente', 'tomado'
  final String status;

  // Descripción opcional del medicamento
  final String? description;

  // Registro de tomas realizadas
  // Clave: "yyyy-MM-dd_HH:mm", Valor: true/false
  final Map<String, bool> taken;

  // Constructor principal del modelo
  Medication({
    this.id,
    this.userId,
    this.medId,
    this.profileId,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    required this.status,
    this.description,
    this.taken = const {},
  });

  // Convierte el objeto Medication a un Map para guardarlo en Firestore
  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'profileId': profileId,
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

  // ============================
  //  Helpers de parseo seguros
  // ============================

  // Convierte cualquier lista dinámica a List<String>
  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return const [];
  }

  // Convierte el mapa `taken` a Map<String,bool> de forma segura
  static Map<String, bool> _takenMap(dynamic value) {
    if (value is Map) {
      final result = <String, bool>{};
      value.forEach((k, v) {
        final key = k.toString();

        // Lo normal: ya viene bool
        if (v is bool) {
          result[key] = v;
          return;
        }

        // Por si llega como 1/0 o "true"/"false" (por cambios antiguos)
        if (v is num) {
          result[key] = v != 0;
          return;
        }
        if (v is String) {
          result[key] = v.toLowerCase() == 'true';
          return;
        }

        // Default: si viene algo raro, lo tratamos como false
        result[key] = false;
      });
      return result;
    }
    return const {};
  }

  // Crea una instancia de Medication a partir de un Map de Firestore
  factory Medication.fromMap(Map<String, dynamic> map, {String? id}) {
    return Medication(
      id: id,
      userId: map['userId'] as String?,
      profileId: map['profileId'] as String?, // ✅ perfil
      medId: map['medId'] as String?,

      name: (map['name'] as String?) ?? '',
      dose: (map['dose'] as String?) ?? '',
      presentation: (map['presentation'] as String?) ?? 'Tableta',

      days: _stringList(map['days']),
      times: _stringList(map['times']),

      status: (map['status'] as String?) ?? 'pendiente',
      description: map['description'] as String?,

      taken: _takenMap(map['taken']),
    );
  }
}
