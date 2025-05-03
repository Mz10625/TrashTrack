import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trash_track/screens/share_location_screen.dart';
import 'package:trash_track/services/firestore_service.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({super.key});

  @override
  State<QRScanScreen> createState() => _QRScanScreenState();
}

class _QRScanScreenState extends State<QRScanScreen> {
  final FirestoreService _firestoreService = FirestoreService();
  String? scannedVehicleNumber;
  bool isScanning = true;
  bool isLoading = false;
  final MobileScannerController _scannerController = MobileScannerController();
  bool _torchEnabled = false;
  late SharedPreferences pref;

  @override
  void initState() {
    super.initState();
    _initiaize();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _initiaize() async {
    pref = await SharedPreferences.getInstance();
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    if (isLoading || !isScanning) return;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        _pauseScanning();
        setState(() {
          scannedVehicleNumber = barcode.rawValue!;
        });

        _checkVehicleAndProceed(scannedVehicleNumber!);
        break;
      }
    }
  }

  void _pauseScanning() {
    setState(() {
      isScanning = false;
    });
    _scannerController.stop();
  }

  void _resumeScanning() {
    setState(() {
      isScanning = true;
      scannedVehicleNumber = null;
    });
    _scannerController.start();
  }

  Future<void> _checkVehicleAndProceed(String vehicleNumber) async {
    setState(() {
      isLoading = true;
    });

    try {
      bool exists = await _firestoreService.checkVehicleExists(vehicleNumber);

      setState(() {
        isLoading = false;
      });

      if (exists) {
        await pref.setString('vehicleNumber', vehicleNumber);
        if (mounted) {
          _showScanSuccessDialog();
        }
      } else {
        if (mounted) {
          _showVehicleNotFoundDialog();
        }
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error checking vehicle: $e')),
        );
      }
      _resumeScanning();
    }
  }

  void _showScanSuccessDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('QR Code Scanned'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle,
              color: Colors.green,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Vehicle Number: $scannedVehicleNumber',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => LocationTrackingScreen(
                    vehicleNumber: scannedVehicleNumber!,
                  ),
                ),
              );
            },
            child: const Text('CONTINUE'),
          ),
        ],
      ),
    );
  }

  void _showVehicleNotFoundDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: const Text('Vehicle Not Found'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Vehicle #$scannedVehicleNumber was not found in the database.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Resume scanning after dismissing dialog
              _resumeScanning();
            },
            child: const Text('TRY AGAIN'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Vehicle QR Code'),
        centerTitle: true,
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        actions: [
          IconButton(
            icon: Icon(_torchEnabled ? Icons.flash_off : Icons.flash_on),
            onPressed: () {
              setState(() {
                _torchEnabled = !_torchEnabled;
                _scannerController.toggleTorch();
              });
            },
          ),
          IconButton(
            icon: const Icon(Icons.flip_camera_ios),
            onPressed: () {
              _scannerController.switchCamera();
            },
          ),
        ],
      ),
      body: Container(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).colorScheme.primary,
                  width: 2,
                ),
                // overflow: Clip.hardEdge,
              ),
              clipBehavior: Clip.hardEdge,
              child: isLoading
                  ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      'Checking vehicle...',
                      style: TextStyle(
                        fontSize: 18,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ],
                ),
              )
                  : Stack(
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onQRCodeDetected,
                  ),
                  if (isScanning)
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.white,
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      margin: const EdgeInsets.all(50),
                    ),
                  if (isScanning)
                    const Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Position Vehicle QR Code in Frame',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                            backgroundColor: Colors.black54,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            if (!isScanning && !isLoading)
              FilledButton.tonal(
                onPressed: _resumeScanning,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text(
                  'Scan Another QR Code',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            // const SizedBox(height: 16),
            // TextButton(
            //   onPressed: isLoading ? null : () {
            //     _showManualEntryDialog();
            //   },
            //   child: const Text(
            //     'Enter Vehicle Number Manually',
            //     style: TextStyle(fontSize: 16),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  // void _showManualEntryDialog() {
  //   String enteredVehicleNumber = '';
  //
  //   showDialog(
  //     context: context,
  //     builder: (context) => AlertDialog(
  //       title: const Text('Enter Vehicle Number'),
  //       content: TextField(
  //         autofocus: true,
  //         keyboardType: TextInputType.number,
  //         inputFormatters: [FilteringTextInputFormatter.digitsOnly],
  //         decoration: const InputDecoration(
  //           hintText: 'e.g., 3908',
  //           border: OutlineInputBorder(),
  //         ),
  //         onChanged: (value) {
  //           enteredVehicleNumber = value;
  //         },
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () {
  //             Navigator.of(context).pop();
  //           },
  //           child: const Text('CANCEL'),
  //         ),
  //         FilledButton(
  //           onPressed: () {
  //             if (enteredVehicleNumber.isNotEmpty) {
  //               Navigator.of(context).pop();
  //               setState(() {
  //                 scannedVehicleNumber = enteredVehicleNumber;
  //               });
  //               _pauseScanning();
  //               _checkVehicleAndProceed(enteredVehicleNumber);
  //             }
  //           },
  //           child: const Text('SUBMIT'),
  //         ),
  //       ],
  //     ),
  //   );
  // }
}