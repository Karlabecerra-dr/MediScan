import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/notification_service.dart';
import 'add_medication_screen.dart';

class MedicationDetailScreen extends StatelessWidget {
  static const routeName = '/medication-detail';

  final Medication medication;

  const MedicationDetailScreen({super.key, required this.medication});

  Future<void> _deleteMedication(BuildContext context) async {
    // Mostrar diálogo de confirmación
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar medicamento?'),
        content: Text(
          '¿Estás seguro de que deseas eliminar "${medication.name}"? '
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      // 1️⃣ PRIMERO: Cancelar TODAS las notificaciones programadas
      debugPrint('🗑️ Cancelando notificaciones de: ${medication.name}');
      await NotificationService().cancelMedicationNotifications(medication.id!);

      // 2️⃣ DESPUÉS: Eliminar de Firestore
      debugPrint('🗑️ Eliminando de Firestore: ${medication.id}');
      await FirebaseFirestore.instance
          .collection('medications')
          .doc(medication.id)
          .delete();

      if (!context.mounted) return;

      // Mostrar confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medication.name} eliminado correctamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Volver a la pantalla anterior
      Navigator.pop(context);
    } catch (e) {
      debugPrint('❌ Error al eliminar medicamento: $e');

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  void _editMedication(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(medication: medication),
      ),
    ).then((_) {
      // Cuando regresamos de editar, volvemos al home para refrescar
      Navigator.pop(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        actions: [
          // Botón de editar
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => _editMedication(context),
          ),
          // Botón de eliminar
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () => _deleteMedication(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // Card con información principal
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dosis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      medication.dose,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.medication,
                          size: 20,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          medication.presentation,
                          style: const TextStyle(fontSize: 16),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card con horarios
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 20,
                          color: Colors.grey,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Días de toma',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: medication.days.map((day) {
                        return Chip(
                          label: Text(day),
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: Theme.of(
                              context,
                            ).colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card con horas
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.access_time, size: 20, color: Colors.grey),
                        SizedBox(width: 8),
                        Text(
                          'Horarios',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...medication.times.map((time) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.alarm,
                              size: 18,
                              color: Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Card con estado
            Card(
              color: _getStatusColor(medication.status),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      _getStatusIcon(medication.status),
                      color: Colors.white,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Estado: ${_getStatusText(medication.status)}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'tomado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'pospuesto':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'tomado':
        return Icons.check_circle;
      case 'pendiente':
        return Icons.pending;
      case 'pospuesto':
        return Icons.schedule;
      default:
        return Icons.info;
    }
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'tomado':
        return 'Tomado';
      case 'pendiente':
        return 'Pendiente';
      case 'pospuesto':
        return 'Pospuesto';
      default:
        return status;
    }
  }
}
