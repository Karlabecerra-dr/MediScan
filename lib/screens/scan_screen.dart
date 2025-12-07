import 'package:flutter/material.dart';
import '../models/medication.dart';

class ScanScreen extends StatelessWidget {
  static const routeName = '/scan';

  const ScanScreen({super.key});

  void _simulateSuccess(BuildContext context) {
    final med = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: 'Losartán 50 mg (Genérico)',
      dose: '50 mg',
      presentation: 'Tableta',
      weekdays: [1, 2, 3, 4, 5, 6, 7],
      doses: [
        MedicationDose(time: const TimeOfDay(hour: 8, minute: 0)),
        MedicationDose(time: const TimeOfDay(hour: 20, minute: 0)),
      ],
    );
    Navigator.pop(context, med);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: Column(
        children: [
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.grey.shade500, width: 2),
                ),
                child: const Center(
                  child: Text('Apunta al código de barras o QR'),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => _simulateSuccess(context),
                    child: const Text('Simular escaneo exitoso'),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
