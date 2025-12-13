// lib/services/medication_service.dart
//
// Servicio simple para operaciones directas sobre la colección
// de medicamentos en Firestore.

import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationService {
  // Referencia a la colección "medications" en Firestore
  static final _collection = FirebaseFirestore.instance.collection(
    'medications',
  );

  // Elimina un medicamento a partir de su ID
  static Future<void> deleteMedication(String id) async {
    await _collection.doc(id).delete();
  }

  // Marca un medicamento como tomado actualizando su estado
  static Future<void> markAsTaken(String id) async {
    await _collection.doc(id).update({'status': 'tomado'});
  }
}
