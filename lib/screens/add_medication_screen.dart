import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';

class AddMedicationScreen extends StatefulWidget {
  static const routeName = '/add-medication';

  const AddMedicationScreen({super.key});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _presentationCtrl = TextEditingController(text: 'Tableta');

  /// Días seleccionados (L = lunes, M = martes, M = miércoles, …)
  final List<String> _selectedDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];

  /// Horas de toma (inicialmente una a las 08:00)
  final List<TimeOfDay> _times = [const TimeOfDay(hour: 8, minute: 0)];

  // ---------- Pickers / helpers para la UI ----------

  Future<void> _pickTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _times[index],
    );
    if (selected != null) {
      setState(() => _times[index] = selected);
    }
  }

  void _addTime() {
    setState(() {
      _times.add(const TimeOfDay(hour: 12, minute: 0));
    });
  }

  void _removeTime(int index) {
    if (_times.length == 1) return; // siempre dejar al menos una hora
    setState(() {
      _times.removeAt(index);
    });
  }

  void _toggleDay(String label) {
    setState(() {
      if (_selectedDays.contains(label)) {
        _selectedDays.remove(label);
      } else {
        _selectedDays.add(label);
      }
    });
  }

  // ---------- Guardar en Firestore y devolver a la Home ----------

  Future<void> _saveMedicationToFirestore() async {
    if (!_formKey.currentState!.validate()) return;

    // Pasamos TimeOfDay -> "HH:MM"
    final timesAsString = _times.map((t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }).toList();

    // Objeto base (sin id todavía)
    final med = Medication(
      name: _nameCtrl.text.trim(),
      dose: _doseCtrl.text.trim(),
      presentation: _presentationCtrl.text.trim(),
      days: List.from(_selectedDays),
      times: timesAsString,
      status: 'pendiente',
    );

    try {
      // 1) Guardar en Firestore
      final docRef = await FirebaseFirestore.instance
          .collection('medications')
          .add(med.toMap());

      // 2) Crear una copia con el id del documento recien creado
      final medWithId = Medication(
        id: docRef.id,
        name: med.name,
        dose: med.dose,
        presentation: med.presentation,
        days: med.days,
        times: med.times,
        status: med.status,
      );

      // 3) Volver a la pantalla anterior devolviendo el medicamento
      if (mounted) {
        Navigator.pop(context, medWithId);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
      }
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    _presentationCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const dayLabels = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar medicamento')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                // --------- Nombre ---------
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nombre del medicamento *',
                    hintText: 'p. ej., Losartán',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa el nombre'
                      : null,
                ),
                const SizedBox(height: 12),

                // --------- Dosis ---------
                TextFormField(
                  controller: _doseCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosis *',
                    hintText: 'p. ej., 50 mg',
                  ),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Ingresa la dosis'
                      : null,
                ),
                const SizedBox(height: 12),

                // --------- Presentación ---------
                TextFormField(
                  controller: _presentationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Presentación',
                    hintText: 'Tableta, cápsula, jarabe…',
                  ),
                ),
                const SizedBox(height: 16),

                // --------- Días de la semana ---------
                const Text(
                  'Días de la semana',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  children: [
                    for (final label in dayLabels)
                      ChoiceChip(
                        label: Text(label),
                        selected: _selectedDays.contains(label),
                        onSelected: (_) => _toggleDay(label),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // --------- Horas de toma ---------
                const Text(
                  'Hora(s) de toma',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (var i = 0; i < _times.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_rounded),
                        title: Text(_times[i].format(context)),
                        onTap: () => _pickTime(i),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _times.length == 1
                              ? null
                              : () => _removeTime(i),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addTime,
                        icon: const Icon(Icons.add),
                        label: const Text('Agregar hora'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // --------- Botones ---------
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancelar'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _saveMedicationToFirestore,
                        child: const Text('Guardar'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
