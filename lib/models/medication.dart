// lib/models/medication.dart
import 'package:flutter/material.dart';

enum MedicationStatus { pending, taken, skipped }

class MedicationDose {
  final TimeOfDay time;
  MedicationStatus status;

  MedicationDose({required this.time, this.status = MedicationStatus.pending});
}

class Medication {
  final String id;
  String name;
  String dose;
  String presentation;
  List<int> weekdays; // 1=Lunes ... 7=Domingo
  List<MedicationDose> doses;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.presentation,
    required this.weekdays,
    required this.doses,
  });
}
