import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';
import '../services/notification_service.dart';
import 'add_medication_screen.dart';

class MedicationDetailScreen extends StatefulWidget {
  static const routeName = '/medication-detail';

  final Medication medication;

  const MedicationDetailScreen({super.key, required this.medication});

  @override
  State<MedicationDetailScreen> createState() => _MedicationDetailScreenState();
}

class _MedicationDetailScreenState extends State<MedicationDetailScreen> {
  // Confirma con el usuario y, si acepta, elimina el medicamento en Firestore
  // y cancela todas las notificaciones asociadas.
  Future<void> _deleteMedication(
    BuildContext context,
    Medication medication,
  ) async {
    // 1) Confirmación (usa ctx para cerrar SOLO el diálogo)
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

    if (confirmed != true) return;
    if (!mounted) return;

    // 2) Capturamos "dependencias" ANTES de los await (para evitar el lint)
    // ignore: use_build_context_synchronously
    final messenger = ScaffoldMessenger.of(context);
    // ignore: use_build_context_synchronously
    final navigator = Navigator.of(context);

    try {
      // Solo se puede borrar si existe un id real en Firestore
      final id = medication.id;
      if (id == null) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text('No se puede eliminar: medicamento sin ID'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      // Primero cancelo notificaciones (no deja recordatorios huérfanos)
      await NotificationService().cancelMedicationNotifications(id);

      // Luego elimino el documento
      await FirebaseFirestore.instance
          .collection('medications')
          .doc(id)
          .delete();

      if (!mounted) return;

      // Feedback de éxito
      messenger.showSnackBar(
        SnackBar(
          content: Text('${medication.name} eliminado correctamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

      // Volver a la pantalla anterior (cerrar MedicationDetailScreen)
      navigator.pop(true);
    } catch (e) {
      debugPrint('Error al eliminar medicamento: $e');
      if (!mounted) return;

      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al eliminar: $e'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Abre la pantalla de edición reutilizando AddMedicationScreen.
  // Al volver, no se fuerza recarga acá porque la lista principal se refresca en Home.
  Future<void> _editMedication(
    BuildContext context,
    Medication medication,
  ) async {
    final updated = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(medication: medication),
      ),
    );

    if (updated == true && mounted) {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final medication = widget.medication;
    final theme = Theme.of(context);

    // Texto de descripción con fallback si viene vacío
    final String descriptionText;
    if (medication.description == null ||
        medication.description!.trim().isEmpty) {
      descriptionText = 'Sin descripción registrada';
    } else {
      descriptionText = medication.description!.trim();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        actions: [
          // Editar medicamento
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => _editMedication(context, medication),
          ),

          // Eliminar medicamento
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Eliminar',
            onPressed: () => _deleteMedication(context, medication),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            // -------------------------
            // Dosis + presentación
            // -------------------------
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

            // -------------------------
            // Descripción
            // -------------------------
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Descripción',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      descriptionText,
                      style: TextStyle(
                        fontSize: 14,
                        color: descriptionText == 'Sin descripción registrada'
                            ? Colors.grey[600]
                            : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // -------------------------
            // ID escaneado (si existe)
            // -------------------------
            if (medication.medId != null &&
                medication.medId!.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.qr_code_2, size: 22, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'ID de medicamento: ${medication.medId}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            // -------------------------
            // Días de la semana
            // -------------------------
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
                          'Días de la semana',
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
                          backgroundColor: theme.colorScheme.primaryContainer,
                          labelStyle: TextStyle(
                            color: theme.colorScheme.onPrimaryContainer,
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // -------------------------
            // Horarios
            // -------------------------
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
                    }),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // -------------------------
            // Estado
            // -------------------------
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

  // Color asociado al estado del medicamento
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

  // Ícono asociado al estado del medicamento
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

  // Texto "bonito" para mostrar el estado
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
