import 'package:flutter/material.dart';
import '../models/medication.dart';

// Card que representa UNA toma (medicamento + hora específica).
// El estado "tomado" se maneja por toma (isTaken), no por medicamento completo.
class MedicationCard extends StatelessWidget {
  // Datos del medicamento
  final Medication medication;

  // Hora de la toma en formato "HH:mm"
  final String time;

  // Estado de esta toma específica (true = tomada)
  final bool isTaken;

  // Acciones del card
  final VoidCallback onTap; // abre detalle
  final VoidCallback onTaken; // marca como tomada
  final VoidCallback onPostpone; // pospone recordatorio

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

    // Estado visual (texto + colores) según si esta toma ya fue marcada
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
        // Permite efecto ripple manteniendo bordes redondeados
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // -------------------------
              // Fila principal
              // -------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Punto de color (marca visual rápida)
                  Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(top: 4, right: 12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                  ),

                  // Bloque de texto: hora + nombre + detalle (dosis/presentación)
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Hora · Nombre (nombre con 2 líneas + ellipsis)
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

                        // Dosis + presentación
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

                  // Columna derecha: chip de estado + botón principal
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

                      // Botón de acción (se deshabilita si ya fue tomado)
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

              // -------------------------
              // Acción secundaria: posponer
              // -------------------------
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
