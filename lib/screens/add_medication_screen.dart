import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/medication.dart';

class AddMedicationScreen extends StatefulWidget {
  static const routeName = '/add-medication';

  /// Si viene null -> estamos creando un medicamento nuevo.
  /// Si viene con datos -> estamos editando ese medicamento.
  final Medication? medication;

  const AddMedicationScreen({super.key, this.medication});

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _presentationCtrl = TextEditingController(text: 'Tableta');

  // Días seleccionados (Lun, Mar, Mié, ...)
  late List<String> _selectedDays;

  // Lista de horas de toma
  late List<TimeOfDay> _times;

  bool get _isEditing => widget.medication != null;

  @override
  void initState() {
    super.initState();

    const allDays = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sab', 'Dom'];

    final med = widget.medication;

    if (med != null) {
      // ----- MODO EDICIÓN -----
      _nameCtrl.text = med.name;
      _doseCtrl.text = med.dose;
      _presentationCtrl.text = med.presentation;

      // Si en Firestore no hay días, por si acaso dejamos todos marcados
      _selectedDays = med.days.isNotEmpty
          ? List<String>.from(med.days)
          : List.from(allDays);

      // Convertimos ["08:00", "20:30"] -> List<TimeOfDay>
      if (med.times.isNotEmpty) {
        _times = med.times.map(_parseTime).toList();
      } else {
        _times = [const TimeOfDay(hour: 8, minute: 0)];
      }
    } else {
      // ----- MODO CREACIÓN -----
      _selectedDays = List.from(allDays);
      _times = [const TimeOfDay(hour: 8, minute: 0)];
    }
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    final hour = int.tryParse(parts[0]) ?? 0;
    final minute = int.tryParse(parts[1]) ?? 0;
    return TimeOfDay(hour: hour, minute: minute);
  }

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
    if (_times.length == 1) return;
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

  Future<void> _saveMedicationToFirestore() async {
    if (!_formKey.currentState!.validate()) return;

    // Lista de horas en formato "HH:MM"
    final timesAsString = _times.map((t) {
      final h = t.hour.toString().padLeft(2, '0');
      final m = t.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }).toList();

    final med = Medication(
      id: widget.medication?.id, // si estamos editando, mantenemos el id
      name: _nameCtrl.text.trim(),
      dose: _doseCtrl.text.trim(),
      presentation: _presentationCtrl.text.trim(),
      days: List.from(_selectedDays),
      times: timesAsString,
      // si estoy editando, mantengo el status actual; si no, parte como 'pendiente'
      status: widget.medication?.status ?? 'pendiente',
    );

    final collection = FirebaseFirestore.instance.collection('medications');

    if (med.id != null) {
      // ----- EDITAR: update al doc existente -----
      await collection.doc(med.id!).update(med.toMap());
    } else {
      // ----- CREAR: nuevo documento -----
      await collection.add(med.toMap());
    }

    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing
              ? 'Medicamento actualizado correctamente'
              : 'Medicamento guardado correctamente',
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    Navigator.pop(context);
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
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar medicamento' : 'Agregar medicamento'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
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
                TextFormField(
                  controller: _presentationCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Presentación',
                    hintText: 'Tableta, cápsula, jarabe…',
                  ),
                ),
                const SizedBox(height: 16),
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
                        child: Text(_isEditing ? 'Guardar cambios' : 'Guardar'),
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
