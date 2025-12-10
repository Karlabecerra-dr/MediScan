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
  Future<void> _deleteMedication(
    BuildContext context,
    Medication medication,
  ) async {
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
      if (medication.id != null) {
        await NotificationService().cancelMedicationNotifications(
          medication.id!,
        );

        await FirebaseFirestore.instance
            .collection('medications')
            .doc(medication.id)
            .delete();
      }

      if (!context.mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${medication.name} eliminado correctamente'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );

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

  void _editMedication(BuildContext context, Medication medication) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(medication: medication),
      ),
    );
    // 👆 sin Navigator.pop en el then, así volvemos a esta pantalla
  }

  @override
  Widget build(BuildContext context) {
    // Si el medicamento no tiene id (caso raro), usamos la versión estática
    if (widget.medication.id == null) {
      return _buildScaffold(context, widget.medication);
    }

    final docRef = FirebaseFirestore.instance
        .collection('medications')
        .doc(widget.medication.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docRef.snapshots(),
      builder: (ctx, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.medication.name)),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return Scaffold(
            appBar: AppBar(title: Text(widget.medication.name)),
            body: const Center(child: Text('Este medicamento ya no existe.')),
          );
        }

        final data = snapshot.data!.data()!;
        final med = Medication.fromMap(data, id: snapshot.data!.id);

        return _buildScaffold(ctx, med);
      },
    );
  }

  Widget _buildScaffold(BuildContext context, Medication medication) {
    final theme = Theme.of(context);

    final String descriptionText;
    if (medication.description == null ||
        medication.description!.trim().isEmpty) {
      descriptionText = 'Sin descripción registrada';
    } else {
      descriptionText = medication.description!.trim();
    }

    // Texto que queremos mostrar para el ID de medicamento
    final String medIdText;
    final bool hasMedId =
        medication.medId != null && medication.medId!.trim().isNotEmpty;

    if (hasMedId) {
      medIdText = medication.medId!.trim();
    } else {
      medIdText = '—'; // cuadro “vacío” cuando no hay ID
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(medication.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Editar',
            onPressed: () => _editMedication(context, medication),
          ),
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
            // Dosis + presentación
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

            // Descripción
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

            const SizedBox(height: 16),

            // 🔹 ID de medicamento (MedID SIEMPRE visible, vacío si no hay)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'ID de medicamento',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      medIdText,
                      style: TextStyle(
                        fontSize: 14,
                        color: hasMedId ? Colors.black : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Días de la semana
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

            // Horarios
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

            // Estado
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
