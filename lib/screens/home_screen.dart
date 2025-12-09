import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'scan_screen.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  static const routeName = '/';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();

  /// Convierte weekday (1–7) a etiqueta "Lun", "Mar", ...
  String _weekdayLabel(int weekday) {
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
    return labels[weekday - 1];
  }

  /// Clave para el mapa `taken` de un medicamento
  /// Formato: YYYY-MM-DD_HH:MM
  String _takenKeyFor(DateTime day, String time) {
    final dateStr = DateFormat('yyyy-MM-dd').format(day);
    return '${dateStr}_$time';
  }

  /// Marca **solo ESTA TOMA** como "tomada" en Firestore usando el mapa `taken`
  Future<void> _markAsTaken(Medication med, String time) async {
    if (med.id == null) return;

    final key = _takenKeyFor(_selectedDay, time);

    await FirebaseFirestore.instance
        .collection('medications')
        .doc(med.id!)
        .update({
          'taken.$key': true, // Firestore: actualización puntual en el mapa
        });
  }

  /// Elimina un medicamento en Firestore Y cancela sus notificaciones
  Future<void> _deleteMedication(Medication med) async {
    if (med.id == null) return;

    final id = med.id!;

    // 1) Borrar el documento en Firestore
    await FirebaseFirestore.instance.collection('medications').doc(id).delete();

    // 2) Cancelar TODAS las notificaciones asociadas a este medicamento
    await NotificationService().cancelMedicationNotifications(id);
  }

  /// Confirmar y luego eliminar (para usar con Dismissible)
  Future<bool> _confirmAndDelete(Medication med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Eliminar medicamento'),
        content: const Text('¿Seguro que deseas eliminar este medicamento?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm != true) return false;

    try {
      await _deleteMedication(med);
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Medicamento eliminado')));
      return true;
    } catch (e) {
      if (!mounted) return false;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error al eliminar: $e')));
      return false;
    }
  }

  void _openAddMedication() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }

  void _openScan() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScanScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM', 'es').format(_selectedDay);
    final selectedDayLabel = _weekdayLabel(_selectedDay.weekday);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------------- HEADER ----------------
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/logo.png',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(
                          Icons.local_hospital,
                          size: 40,
                          color: Colors.blue,
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MediScan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),

                  // Botón de PRUEBA de notificaciones (puedes quitarlo después)
                  IconButton(
                    icon: const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.orange,
                    ),
                    tooltip: 'Probar notificaciones',
                    onPressed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            '🚀 Ejecutando pruebas de notificación...',
                          ),
                          duration: Duration(seconds: 2),
                        ),
                      );

                      await NotificationService().showImmediateTestNotification(
                        medicationId: 'test1',
                        name: 'Prueba Inmediata',
                      );

                      await NotificationService().scheduleTestNotification(
                        medicationId: 'test2',
                        name: 'Prueba 10 seg',
                        seconds: 10,
                      );
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ---------------- TIRA DE DÍAS ----------------
            DayStrip(
              selectedDay: _selectedDay,
              onDaySelected: (day) {
                setState(() => _selectedDay = day);
              },
            ),

            const SizedBox(height: 12),

            // ---------------- FECHA + BOTONES ----------------
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    dateLabel,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _openAddMedication,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: _openScan,
                    icon: const Icon(Icons.qr_code_scanner_rounded),
                    label: const Text('Escanear'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // ---------------- LISTA REACTIVA DESDE FIRESTORE ----------------
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('medications')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    return Center(
                      child: Text('Error al cargar: ${snapshot.error}'),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  final meds = docs
                      .map(
                        (d) => Medication.fromMap(
                          d.data() as Map<String, dynamic>,
                          id: d.id,
                        ),
                      )
                      .toList();

                  // Compatibilidad: etiquetas nuevas y antiguas
                  const legacyMap = {
                    'Lun': 'L',
                    'Mar': 'M',
                    'Mié': 'X',
                    'Jue': 'J',
                    'Vie': 'V',
                    'Sab': 'S',
                    'Sáb': 'S',
                    'Dom': 'D',
                  };
                  final legacyLabel =
                      legacyMap[selectedDayLabel] ?? selectedDayLabel;

                  final dosesToday = <_DoseItem>[];

                  for (final med in meds) {
                    // Si el medicamento no aplica para el día seleccionado, se salta
                    if (!med.days.contains(selectedDayLabel) &&
                        !med.days.contains(legacyLabel)) {
                      continue;
                    }

                    for (final t in med.times) {
                      final key = _takenKeyFor(_selectedDay, t);
                      final isTaken = med.taken[key] == true;

                      dosesToday.add(
                        _DoseItem(medication: med, time: t, isTaken: isTaken),
                      );
                    }
                  }

                  // Ordenar por hora "HH:MM"
                  dosesToday.sort((a, b) => a.time.compareTo(b.time));

                  // Ahora "pendiente" es por dosis, no por medicamento completo
                  final pendingCount = dosesToday
                      .where((d) => !d.isTaken)
                      .length;

                  final headerSubtitle = 'Hoy · $pendingCount tomas pendientes';

                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            headerSubtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey.shade700,
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: dosesToday.isEmpty
                            ? const Center(
                                child: Text(
                                  'No hay tomas para este día.\nPulsa "Agregar" para registrar un medicamento.',
                                  textAlign: TextAlign.center,
                                ),
                              )
                            : ListView.builder(
                                itemCount: dosesToday.length,
                                itemBuilder: (context, index) {
                                  final item = dosesToday[index];

                                  return Dismissible(
                                    key: Key(
                                      item.medication.id ??
                                          '${item.medication.name}-$index',
                                    ),
                                    direction: DismissDirection.endToStart,
                                    background: Container(
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 16),
                                      color: Colors.redAccent,
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    confirmDismiss: (_) =>
                                        _confirmAndDelete(item.medication),
                                    child: MedicationCard(
                                      medication: item.medication,
                                      time: item.time,
                                      isTaken: item.isTaken, // 👈 NUEVO
                                      onTap: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => AddMedicationScreen(
                                              medication: item.medication,
                                            ),
                                          ),
                                        );
                                      },
                                      onTaken: () async {
                                        await _markAsTaken(
                                          item.medication,
                                          item.time,
                                        );
                                      },
                                      onPostpone: () {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Recordatorio pospuesto 5 minutos',
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper interno para la lista de tomas del día
class _DoseItem {
  final Medication medication;
  final String time;
  final bool isTaken;

  _DoseItem({
    required this.medication,
    required this.time,
    required this.isTaken,
  });
}
