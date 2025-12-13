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
    required this.name,
    required this.dose,
    required this.presentation,
    required this.days,
    required this.times,
    required this.status,
    this.description,
    required this.taken,
  });

  // Convierte el objeto Medication a un Map
  // para poder guardarlo en Firestore
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

  // Crea una instancia de Medication a partir de un Map
  // obtenido desde Firestore
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
