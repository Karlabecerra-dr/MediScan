import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';

class ScanScreen extends StatelessWidget {
  static const routeName = '/scan';

  const ScanScreen({super.key});

  Future<void> _simulateSuccess(BuildContext context) async {
    // Aquí normalmente vendrían los datos del escaneo.
    // Por ahora simulamos un medicamento genérico.
    final med = Medication(
      name: 'Losartán 50 mg (Genérico)',
      dose: '50 mg',
      presentation: 'Tableta',
       days: ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'],
      times: ['08:00', '20:00'],
      status: 'pendiente',
    );

    await FirebaseFirestore.instance.collection('medications').add(med.toMap());

    if (context.mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Escanear código')),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 220,
                  height: 220,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade400, width: 2),
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Apunta al código de barras o QR',
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 32),
                FilledButton(
                  onPressed: () => _simulateSuccess(context),
                  child: const Text('Simular escaneo exitoso'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
