import 'package:flutter/material.dart';

import '../models/medication.dart';

class MedicationDetailScreen extends StatelessWidget {
  static const routeName = '/medication-detail';

  final Medication medication;

  const MedicationDetailScreen({super.key, required this.medication});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(medication.name)),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            Text(
              medication.dose,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Presentación: ${medication.presentation}'),
            const SizedBox(height: 16),
            Text('Días: ${medication.days.join(', ')}'),
            const SizedBox(height: 8),
            Text('Horas: ${medication.times.join(', ')}'),
            const SizedBox(height: 16),
            Text('Estado actual: ${medication.status}'),
          ],
        ),
      ),
    );
  }
}
