// lib/services/medication_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class MedicationService {
  static final _collection = FirebaseFirestore.instance.collection(
    'medications',
  );

  /// Elimina un medicamento por ID
  static Future<void> deleteMedication(String id) async {
    await _collection.doc(id).delete();
  }

  /// Marca un medicamento como tomado
  static Future<void> markAsTaken(String id) async {
    await _collection.doc(id).update({'status': 'tomado'});
  }
}
