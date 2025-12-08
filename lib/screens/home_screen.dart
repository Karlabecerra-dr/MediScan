import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/medication.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'scan_screen.dart';
import 'medication_detail_screen.dart';
import '../services/medication_service.dart'; // Servicio centralizado para Firestore

class HomeScreen extends StatefulWidget {
  static const routeName = '/';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  /// Día seleccionado en el calendario superior
  DateTime _selectedDay = DateTime.now();

  /// Devuelve etiqueta de 3 letras para el día de la semana
  String _weekdayLabel(int weekday) {
    const labels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];
    return labels[weekday - 1];
  }

  /// Marca un medicamento como "tomado" usando el servicio
  Future<void> _markAsTaken(Medication med) async {
    if (med.id == null) return;
    await MedicationService.markAsTaken(med.id!);
  }

  /// Abre la pantalla para agregar medicamento
  void _openAddMedication() async {
    final newMed = await Navigator.push<Medication>(
      context,
      MaterialPageRoute(builder: (context) => const AddMedicationScreen()),
    );

    // Por si la pantalla se cerró durante el await
    if (!mounted) return;

    if (newMed != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Medicamento guardado correctamente'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  /// Abre pantalla de escaneo (simulada por ahora)
  void _openScan() {
    Navigator.pushNamed(context, ScanScreen.routeName);
  }

  /// Pregunta al usuario y, si confirma, elimina el medicamento
  Future<bool> _confirmAndDelete(String? id) async {
    if (id == null || id.isEmpty) return false;

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
      await MedicationService.deleteMedication(id);

      if (!mounted) return true;

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

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat('EEE, d MMM', 'es').format(_selectedDay);
    final selectedDayLabel = _weekdayLabel(_selectedDay.weekday);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // ---------- Cabecera ----------
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

            // ---------- Tira de días ----------
            DayStrip(
              selectedDay: _selectedDay,
              onDaySelected: (day) {
                setState(() => _selectedDay = day);
              },
            ),

            const SizedBox(height: 12),

            // ---------- Fecha y botones de acción ----------
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

            // ---------- Lista reactiva desde Firestore ----------
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
                      child: Text('Error al cargar datos: ${snapshot.error}'),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];

                  // Convertimos los documentos de Firestore a objetos Medication
                  final meds = docs
                      .map(
                        (d) => Medication.fromMap(
                          d.data() as Map<String, dynamic>,
                          id: d.id,
                        ),
                      )
                      .toList();

                  // Construimos la lista de tomas para el día seleccionado
                  final dosesToday = <_DoseItem>[];

                  for (final med in meds) {
                    // Mapa para compatibilidad con el formato antiguo (L, M, X...)
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

                    if (!med.days.contains(selectedDayLabel) &&
                        !med.days.contains(legacyLabel)) {
                      continue;
                    }

                    for (final t in med.times) {
                      dosesToday.add(_DoseItem(medication: med, time: t));
                    }
                  }

                  // Ordenamos por hora (strings "HH:mm")
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

                                  // Cada tarjeta se puede deslizar para eliminar
                                  return Dismissible(
                                    key: Key(
                                      item.medication.id ?? index.toString(),
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
                                    confirmDismiss: (direction) =>
                                        _confirmAndDelete(item.medication.id),
                                    child: MedicationCard(
                                      medication: item.medication,
                                      time: item.time,
                                      onTap: () {
                                        Navigator.pushNamed(
                                          context,
                                          MedicationDetailScreen.routeName,
                                          arguments: item.medication,
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

/// Estructura interna para representar una "toma" concreta
class _DoseItem {
  final Medication medication;
  final String time;

  _DoseItem({required this.medication, required this.time});
}
