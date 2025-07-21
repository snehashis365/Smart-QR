import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:smart_qr/result_page.dart'; // We will create this next

class ScanPage extends StatefulWidget {
  const ScanPage({super.key});

  @override
  State<ScanPage> createState() => _ScanPageState();
}

class _ScanPageState extends State<ScanPage> {
  // Controller for the mobile scanner
  final MobileScannerController controller = MobileScannerController();
  bool isProcessing = false; // To prevent multiple navigations

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // The main camera scanner view
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              // Avoid processing if we're already on it
              if (isProcessing) return;

              final List<Barcode> barcodes = capture.barcodes;
              if (barcodes.isNotEmpty) {
                final String? code = barcodes.first.rawValue;
                if (code != null) {
                  setState(() {
                    isProcessing = true;
                  });

                  // Navigate to the result page with the scanned code
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ResultPage(scannedCode: code),
                    ),
                  ).then((_) {
                    // When we return from the result page, allow scanning again
                    setState(() {
                      isProcessing = false;
                    });
                  });
                }
              }
            },
          ),
          // A semi-transparent overlay with a square cutout for scanning
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Add logic to scan from an image file
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}