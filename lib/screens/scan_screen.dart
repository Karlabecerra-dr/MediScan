import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

// Pantalla de escaneo (código de barras / QR).
// Devuelve el valor detectado a la pantalla anterior con Navigator.pop(context, value).
class ScanScreen extends StatefulWidget {
  static const routeName = '/scan';

  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  // Controlador del escáner (maneja cámara, flash, etc.)
  final MobileScannerController _controller = MobileScannerController();

  // Flag para evitar múltiples pops cuando el escáner detecta varias veces seguidas
  bool _isHandlingResult = false;

  // Callback que recibe lo detectado por MobileScanner
  void _handleDetection(BarcodeCapture capture) {
    // Si ya estoy procesando un resultado, ignoro lo siguiente
    if (_isHandlingResult) return;

    // Lista de códigos detectados en este frame
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;

    // Me quedo con el primero (suficiente para este flujo)
    final value = barcodes.first.rawValue;
    if (value == null || value.isEmpty) return;

    // Marco como procesado y devuelvo el resultado
    _isHandlingResult = true;
    Navigator.pop(context, value);
  }

  @override
  void dispose() {
    // Libera cámara/recursos
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar simple para indicar el propósito de la pantalla
      appBar: AppBar(title: const Text('Escanear código')),
      body: Column(
        children: [
          // Área principal: cámara + detección
          Expanded(
            child: MobileScanner(
              controller: _controller,
              onDetect: _handleDetection,
            ),
          ),

          // Área inferior: instrucciones + cancelar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text(
                  'Apunta al código de barras o QR del medicamento.\n'
                  'Al detectar un código te devolveremos a la pantalla anterior.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),

                // Botón para salir sin escanear
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
