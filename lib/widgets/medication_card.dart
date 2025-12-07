import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final MedicationDose dose;
  final VoidCallback onTap;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.dose,
    required this.onTap,
    required this.onTaken,
    required this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    String statusText;
    Color statusColor;
    switch (dose.status) {
      case MedicationStatus.taken:
        statusText = 'Tomado';
        statusColor = Colors.green;
        break;
      case MedicationStatus.skipped:
        statusText = 'Omitido';
        statusColor = Colors.grey;
        break;
      case MedicationStatus.pending:
        //default:
        statusText = 'Pendiente';
        statusColor = Colors.orange;
        break;
    }

    final timeLabel = dose.time.format(context);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [Color(0xFF26C6DA), Color(0xFF1E88E5)],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$timeLabel · ${medication.name}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${medication.dose} · ${medication.presentation}',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      statusText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: statusColor,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      TextButton(
                        onPressed: onPostpone,
                        child: const Text('Posponer'),
                      ),
                      const SizedBox(width: 4),
                      FilledButton(
                        onPressed: onTaken,
                        child: const Text('Tomado'),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
