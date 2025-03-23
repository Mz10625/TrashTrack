import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:vehicle_tracker/screens/location_tracking_screen.dart';
import 'package:vehicle_tracker/services/firestore_service.dart';

class QRScanScreen extends StatefulWidget {
  const QRScanScreen({Key? key}) : super(key: key);

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

  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }

  void _onQRCodeDetected(BarcodeCapture capture) {
    final List<Barcode> barcodes = capture.barcodes;

    // Process only if not already processing a code
    if (isLoading || !isScanning) return;

    for (final barcode in barcodes) {
      if (barcode.rawValue != null) {
        // Stop scanning to prevent multiple readings of the same QR code
        _pauseScanning();

        // Set the scanned value and process it
        setState(() {
          scannedVehicleNumber = barcode.rawValue!;
        });

        // Check if vehicle exists in Firestore
        _checkVehicleAndProceed(scannedVehicleNumber!);

        // Only process the first valid QR code
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
      // Resume scanning after error
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
                    Positioned(
                      bottom: 20,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: Text(
                          'Position QR Code in Frame',
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
            const SizedBox(height: 16),
            // TextButton(
            //   onPressed: isLoading ? null : () {
            //     // For manual entry
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

//
//
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:mobile_scanner/mobile_scanner.dart';
// import 'package:vehicle_tracker/screens/location_tracking_screen.dart';
// import 'package:vehicle_tracker/services/firestore_service.dart';
// import 'package:permission_handler/permission_handler.dart';
//
// class QRScanScreen extends StatefulWidget {
//   const QRScanScreen({Key? key}) : super(key: key);
//
//   @override
//   State<QRScanScreen> createState() => _QRScanScreenState();
// }
//
// class _QRScanScreenState extends State<QRScanScreen> {
//   final FirestoreService _firestoreService = FirestoreService();
//   String? scannedVehicleNumber;
//   bool isScanning = false;
//   bool isLoading = false;
//   bool isCheckingPermission = true;
//   MobileScannerController? _scannerController;
//   bool _torchEnabled = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _checkCameraPermission();
//   }
//
//   @override
//   void dispose() {
//     _scannerController?.dispose();
//     super.dispose();
//   }
//
//   Future<void> _checkCameraPermission() async {
//     setState(() {
//       isCheckingPermission = true;
//     });
//
//     PermissionStatus status = await Permission.camera.status;
//
//     if (status.isGranted) {
//       _initializeScanner();
//     } else if (status.isDenied) {
//       _requestCameraPermission();
//     } else if (status.isPermanentlyDenied) {
//       _showPermanentlyDeniedDialog();
//     }
//
//     setState(() {
//       isCheckingPermission = false;
//     });
//   }
//
//   Future<void> _requestCameraPermission() async {
//     PermissionStatus status = await Permission.camera.request();
//
//     if (status.isGranted) {
//       _initializeScanner();
//     } else {
//       _showPermissionDeniedDialog();
//     }
//   }
//
//   void _initializeScanner() {
//     _scannerController = MobileScannerController();
//     setState(() {
//       isScanning = true;
//     });
//     _scannerController!.start();
//   }
//
//   void _showPermissionDeniedDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: const Text('Camera Permission Required'),
//         content: const Text(
//           'The camera is needed to scan QR codes. Please grant camera permission to continue.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               _requestCameraPermission();
//             },
//             child: const Text('TRY AGAIN'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.pop(context); // Return to previous screen
//             },
//             child: const Text('CANCEL'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showPermanentlyDeniedDialog() {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => AlertDialog(
//         title: const Text('Camera Permission Required'),
//         content: const Text(
//           'The camera permission has been permanently denied. Please enable it in your device settings to use the QR scanner.',
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               openAppSettings();
//             },
//             child: const Text('OPEN SETTINGS'),
//           ),
//           TextButton(
//             onPressed: () {
//               Navigator.pop(context);
//               Navigator.pop(context); // Return to previous screen
//             },
//             child: const Text('CANCEL'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _onQRCodeDetected(BarcodeCapture capture) {
//     final List<Barcode> barcodes = capture.barcodes;
//
//     // Process only if not already processing a code
//     if (isLoading || !isScanning) return;
//
//     for (final barcode in barcodes) {
//       if (barcode.rawValue != null) {
//         // Stop scanning to prevent multiple readings of the same QR code
//         _pauseScanning();
//
//         // Set the scanned value and process it
//         setState(() {
//           scannedVehicleNumber = barcode.rawValue!;
//         });
//
//         // Check if vehicle exists in Firestore
//         _checkVehicleAndProceed(scannedVehicleNumber!);
//
//         // Only process the first valid QR code
//         break;
//       }
//     }
//   }
//
//   void _pauseScanning() {
//     setState(() {
//       isScanning = false;
//     });
//     _scannerController?.stop();
//   }
//
//   void _resumeScanning() {
//     setState(() {
//       isScanning = true;
//       scannedVehicleNumber = null;
//     });
//     _scannerController?.start();
//   }
//
//   Future<void> _checkVehicleAndProceed(String vehicleNumber) async {
//     setState(() {
//       isLoading = true;
//     });
//
//     try {
//       bool exists = await _firestoreService.checkVehicleExists(vehicleNumber);
//
//       setState(() {
//         isLoading = false;
//       });
//
//       if (exists) {
//         if (mounted) {
//           _showScanSuccessDialog();
//         }
//       } else {
//         if (mounted) {
//           _showVehicleNotFoundDialog();
//         }
//       }
//     } catch (e) {
//       setState(() {
//         isLoading = false;
//       });
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('Error checking vehicle: $e')),
//         );
//       }
//       // Resume scanning after error
//       _resumeScanning();
//     }
//   }
//
//   void _showScanSuccessDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         title: const Text('QR Code Scanned'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(
//               Icons.check_circle,
//               color: Colors.green,
//               size: 64,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Vehicle Number: $scannedVehicleNumber',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               Navigator.of(context).pushReplacement(
//                 MaterialPageRoute(
//                   builder: (context) => LocationTrackingScreen(
//                     vehicleNumber: scannedVehicleNumber!,
//                   ),
//                 ),
//               );
//             },
//             child: const Text('CONTINUE'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   void _showVehicleNotFoundDialog() {
//     showDialog(
//       context: context,
//       builder: (context) => AlertDialog(
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(16),
//         ),
//         title: const Text('Vehicle Not Found'),
//         content: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             const Icon(
//               Icons.error_outline,
//               color: Colors.red,
//               size: 64,
//             ),
//             const SizedBox(height: 16),
//             Text(
//               'Vehicle #$scannedVehicleNumber was not found in the database.',
//               textAlign: TextAlign.center,
//             ),
//           ],
//         ),
//         actions: [
//           TextButton(
//             onPressed: () {
//               Navigator.of(context).pop();
//               // Resume scanning after dismissing dialog
//               _resumeScanning();
//             },
//             child: const Text('TRY AGAIN'),
//           ),
//         ],
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Scan Vehicle QR Code'),
//         centerTitle: true,
//         backgroundColor: Theme.of(context).colorScheme.primary,
//         foregroundColor: Theme.of(context).colorScheme.onPrimary,
//         actions: [
//           if (isScanning)
//             IconButton(
//               icon: Icon(_torchEnabled ? Icons.flash_off : Icons.flash_on),
//               onPressed: () {
//                 setState(() {
//                   _torchEnabled = !_torchEnabled;
//                   _scannerController?.toggleTorch();
//                 });
//               },
//             ),
//           if (isScanning)
//             IconButton(
//               icon: const Icon(Icons.flip_camera_ios),
//               onPressed: () {
//                 _scannerController?.switchCamera();
//               },
//             ),
//         ],
//       ),
//       body: Container(
//         padding: const EdgeInsets.all(24),
//         child: Column(
//           mainAxisAlignment: MainAxisAlignment.center,
//           crossAxisAlignment: CrossAxisAlignment.stretch,
//           children: [
//             Container(
//               height: 300,
//               decoration: BoxDecoration(
//                 borderRadius: BorderRadius.circular(16),
//                 border: Border.all(
//                   color: Theme.of(context).colorScheme.primary,
//                   width: 2,
//                 ),
//               ),
//               clipBehavior: Clip.hardEdge,
//               child: isCheckingPermission
//                   ? const Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     CircularProgressIndicator(),
//                     SizedBox(height: 16),
//                     Text(
//                       'Checking camera permission...',
//                       style: TextStyle(fontSize: 16),
//                     ),
//                   ],
//                 ),
//               )
//                   : isLoading
//                   ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const CircularProgressIndicator(),
//                     const SizedBox(height: 16),
//                     Text(
//                       'Checking vehicle...',
//                       style: TextStyle(
//                         fontSize: 18,
//                         color: Theme.of(context).colorScheme.onSurface,
//                       ),
//                     ),
//                   ],
//                 ),
//               )
//                   : !isScanning && _scannerController == null
//                   ? Center(
//                 child: Column(
//                   mainAxisAlignment: MainAxisAlignment.center,
//                   children: [
//                     const Icon(
//                       Icons.no_photography,
//                       size: 64,
//                       color: Colors.grey,
//                     ),
//                     const SizedBox(height: 16),
//                     const Text(
//                       'Camera permission is required',
//                       style: TextStyle(fontSize: 18),
//                       textAlign: TextAlign.center,
//                     ),
//                     const SizedBox(height: 24),
//                     FilledButton(
//                       onPressed: _checkCameraPermission,
//                       child: const Text('Grant Permission'),
//                     ),
//                   ],
//                 ),
//               )
//                   : Stack(
//                 children: [
//                   if (_scannerController != null)
//                     MobileScanner(
//                       controller: _scannerController!,
//                       onDetect: _onQRCodeDetected,
//                     ),
//                   if (isScanning)
//                     Container(
//                       decoration: BoxDecoration(
//                         border: Border.all(
//                           color: Colors.white,
//                           width: 2,
//                         ),
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                       margin: const EdgeInsets.all(50),
//                     ),
//                   if (isScanning)
//                     Positioned(
//                       bottom: 20,
//                       left: 0,
//                       right: 0,
//                       child: Center(
//                         child: Text(
//                           'Position QR Code in Frame',
//                           style: TextStyle(
//                             fontSize: 16,
//                             color: Colors.white,
//                             backgroundColor: Colors.black54,
//                             fontWeight: FontWeight.bold,
//                           ),
//                           textAlign: TextAlign.center,
//                         ),
//                       ),
//                     ),
//                 ],
//               ),
//             ),
//             const SizedBox(height: 32),
//             if (!isScanning && _scannerController != null && !isLoading)
//               FilledButton.tonal(
//                 onPressed: _resumeScanning,
//                 style: FilledButton.styleFrom(
//                   padding: const EdgeInsets.symmetric(vertical: 16),
//                 ),
//                 child: const Text(
//                   'Scan Another QR Code',
//                   style: TextStyle(fontSize: 18),
//                 ),
//               ),
//             const SizedBox(height: 16),
//           ],
//         ),
//       ),
//     );
//   }
// }