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

  final List<MedicationDose> _doses = [
    MedicationDose(time: const TimeOfDay(hour: 8, minute: 0)),
  ];
  List<int> _weekdays = [1, 2, 3, 4, 5, 6, 7];

  Future<void> _pickTime(int index) async {
    final selected = await showTimePicker(
      context: context,
      initialTime: _doses[index].time,
    );
    if (selected != null) {
      setState(() {
        _doses[index] = MedicationDose(
          time: selected,
          status: _doses[index].status,
        );
      });
    }
  }

  void _addDose() {
    setState(() {
      _doses.add(MedicationDose(time: const TimeOfDay(hour: 12, minute: 0)));
    });
  }

  void _removeDose(int index) {
    setState(() {
      _doses.removeAt(index);
    });
  }

  void _toggleWeekday(int weekday) {
    setState(() {
      if (_weekdays.contains(weekday)) {
        _weekdays.remove(weekday);
      } else {
        _weekdays.add(weekday);
      }
    });
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    final med = Medication(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      dose: _doseCtrl.text.trim(),
      presentation: _presentationCtrl.text.trim(),
      weekdays: _weekdays..sort(),
      doses: List.from(_doses),
    );

    Navigator.pop(context, med);
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
    final weekdayLabels = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

    return Scaffold(
      appBar: AppBar(title: const Text('Agregar medicamento')),
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
                  children: List.generate(7, (index) {
                    final weekday = index + 1;
                    final selected = _weekdays.contains(weekday);
                    return ChoiceChip(
                      label: Text(weekdayLabels[index]),
                      selected: selected,
                      onSelected: (_) => _toggleWeekday(weekday),
                    );
                  }),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Hora(s) de toma',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                Column(
                  children: [
                    for (var i = 0; i < _doses.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.access_time_rounded),
                        title: Text(_doses[i].time.format(context)),
                        onTap: () => _pickTime(i),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: _doses.length == 1
                              ? null
                              : () => _removeDose(i),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addDose,
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
                        onPressed: _save,
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
