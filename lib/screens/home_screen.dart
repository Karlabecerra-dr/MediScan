import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'scan_screen.dart';

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
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];
    return labels[weekday - 1];
  }

  /// Marca un medicamento como tomado en Firestore
  Future<void> _markAsTaken(Medication med) async {
    if (med.id == null) return;
    await FirebaseFirestore.instance
        .collection('medications')
        .doc(med.id!)
        .update({'status': 'tomado'});
  }

  /// Elimina un medicamento en Firestore (ya confirmado)
  Future<void> _deleteMedication(Medication med) async {
    if (med.id == null) return;
    await FirebaseFirestore.instance
        .collection('medications')
        .doc(med.id!)
        .delete();
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

  /// Abrir pantalla para AGREGAR medicamento
  void _openAddMedication() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicationScreen()),
    );
  }

  /// Abrir pantalla de escaneo (simulada)
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
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'MediScan',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {},
                    icon: const Icon(Icons.notifications_none_rounded),
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
                      dosesToday.add(_DoseItem(medication: med, time: t));
                    }
                  }

                  // Ordenar por hora "HH:MM"
                  dosesToday.sort((a, b) => a.time.compareTo(b.time));

                  final pendingCount = dosesToday
                      .where((d) => d.medication.status == 'pendiente')
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
                                      // TAP -> EDITAR
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
                                        await _markAsTaken(item.medication);
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

/// Item auxiliar: un medicamento + una hora específica
class _DoseItem {
  final Medication medication;
  final String time;

  _DoseItem({required this.medication, required this.time});
}
