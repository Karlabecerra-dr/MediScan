import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/medication.dart';
import '../widgets/day_strip.dart';
import '../widgets/medication_card.dart';
import 'add_medication_screen.dart';
import 'scan_screen.dart';
import 'medication_detail_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _selectedDay = DateTime.now();
  final List<Medication> _medications = [];

  @override
  void initState() {
    super.initState();
    _seedDemoData();
  }

  void _seedDemoData() {
    if (_medications.isNotEmpty) return;
    _medications.add(
      Medication(
        id: '1',
        name: 'Losartán',
        dose: '50 mg',
        presentation: 'Tableta',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        doses: [
          MedicationDose(time: const TimeOfDay(hour: 8, minute: 0)),
          MedicationDose(time: const TimeOfDay(hour: 20, minute: 0)),
        ],
      ),
    );
    _medications.add(
      Medication(
        id: '2',
        name: 'Metformina',
        dose: '850 mg',
        presentation: 'Tableta',
        weekdays: [1, 2, 3, 4, 5, 6, 7],
        doses: [MedicationDose(time: const TimeOfDay(hour: 12, minute: 0))],
      ),
    );
  }

  List<(Medication, MedicationDose)> _getDosesForSelectedDay() {
    final weekday = _selectedDay.weekday;
    final result = <(Medication, MedicationDose)>[];
    for (final m in _medications) {
      if (!m.weekdays.contains(weekday)) continue;
      for (final d in m.doses) {
        result.add((m, d));
      }
    }
    result.sort(
      (a, b) => a.$2.time.hour.compareTo(b.$2.time.hour) != 0
          ? a.$2.time.hour.compareTo(b.$2.time.hour)
          : a.$2.time.minute.compareTo(b.$2.time.minute),
    );
    return result;
  }

  void _openAddMedication() async {
    final newMed =
        await Navigator.pushNamed(context, AddMedicationScreen.routeName)
            as Medication?;
    if (newMed != null) {
      setState(() {
        _medications.add(newMed);
      });
    }
  }

  void _openScan() async {
    final scannedMed =
        await Navigator.pushNamed(context, ScanScreen.routeName) as Medication?;
    if (scannedMed != null) {
      setState(() {
        _medications.add(scannedMed);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final dosesToday = _getDosesForSelectedDay();
    final pendingCount = dosesToday
        .where((tuple) => tuple.$2.status == MedicationStatus.pending)
        .length;

    final dateLabel = DateFormat('EEE, d MMM', 'es').format(_selectedDay);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MediScan',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Hoy · $pendingCount tomas pendientes',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade700,
                        ),
                      ),
                    ],
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
            DayStrip(
              selectedDay: _selectedDay,
              onDaySelected: (day) {
                setState(() => _selectedDay = day);
              },
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
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
            Expanded(
              child: dosesToday.isEmpty
                  ? const Center(
                      child: Text(
                        'No hay tomas para este día.\nPulsa “Agregar” para registrar un medicamento.',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : ListView.builder(
                      itemCount: dosesToday.length,
                      itemBuilder: (context, index) {
                        final (med, dose) = dosesToday[index];
                        return MedicationCard(
                          medication: med,
                          dose: dose,
                          onTap: () {
                            Navigator.pushNamed(
                              context,
                              MedicationDetailScreen.routeName,
                              arguments: med,
                            );
                          },
                          onTaken: () {
                            setState(() {
                              dose.status = MedicationStatus.taken;
                            });
                          },
                          onPostpone: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Recordatorio pospuesto 5 minutos',
                                ),
                              ),
                            );
                          },
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
