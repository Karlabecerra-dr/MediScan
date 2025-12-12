import 'package:flutter/material.dart';
import '../models/medication.dart';

class MedicationCard extends StatelessWidget {
  final Medication medication;
  final String time; // "HH:MM"
  final bool isTaken; // estado de ESTA toma
  final VoidCallback onTap;
  final VoidCallback onTaken;
  final VoidCallback onPostpone;

  const MedicationCard({
    super.key,
    required this.medication,
    required this.time,
    required this.isTaken,
    required this.onTap,
    required this.onTaken,
    required this.onPostpone,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- Chip de estado (colores) ---
    final String statusLabel = isTaken ? 'Tomado' : 'Pendiente';
    final Color statusBg = isTaken
        ? Colors.green.shade100
        : Colors.orange.shade100;
    final Color statusFg = isTaken
        ? Colors.green.shade800
        : Colors.orange.shade800;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ---------------- PRIMERA FILA ----------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Punto de color
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4, right: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),

                  // Texto principal (hora + nombre + dosis)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hora + nombre (con espacio para que no se corte tan feo)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              time,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Text('·'),
                            const SizedBox(width: 4),
                            // Nombre del medicamento con 2 líneas y ellipsis
                            Expanded(
                              child: Text(
                                medication.name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
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

                  // Chip de estado + botón principal
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      // Chip "Pendiente / Tomado"
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusBg,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          statusLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: statusFg,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: 110,
                        child: FilledButton(
                          onPressed: isTaken ? null : onTaken,
                          child: Text(
                            isTaken ? 'Tomado' : 'Tomar',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // ---------------- FILA POSPONER ----------------
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onPostpone,
                  child: const Text('Posponer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
