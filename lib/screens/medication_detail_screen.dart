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
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dosis: ${medication.dose}'),
            const SizedBox(height: 4),
            Text('Presentación: ${medication.presentation}'),
            const SizedBox(height: 16),
            const Text(
              'Horarios',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ...medication.doses.map(
              (d) => ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(d.time.format(context)),
                subtitle: Text(
                  d.status == MedicationStatus.taken
                      ? 'Tomado'
                      : d.status == MedicationStatus.skipped
                      ? 'Omitido'
                      : 'Pendiente',
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  // Más adelante: eliminar desde Home con callback
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.arrow_back),
                label: const Text('Volver'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
