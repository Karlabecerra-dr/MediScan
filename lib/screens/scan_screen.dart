import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScanScreen extends StatefulWidget {
  static const routeName = '/scan';

  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  bool _isProcessing = false;

  void _onDetect(BarcodeCapture barcodes) {
    if (_isProcessing) return;

    final barcode = barcodes.barcodes.first;

    if (barcode.rawValue == null) return;

    _isProcessing = true;

    Navigator.pop(context, barcode.rawValue);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escanear código")),
      body: Stack(
        children: [
          MobileScanner(
            onDetect: _onDetect,
            controller: MobileScannerController(
              detectionSpeed: DetectionSpeed.normal,
              facing: CameraFacing.back,
              torchEnabled: false,
            ),
          ),

          // Cuadro visual de guía
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white, width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
