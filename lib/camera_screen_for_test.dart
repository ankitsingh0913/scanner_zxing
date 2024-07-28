import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

class CameraScreenTest extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreenTest({required this.camera});

  @override
  _CameraScreenTestState createState() => _CameraScreenTestState();
}

class _CameraScreenTestState extends State<CameraScreenTest> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Timer? _timer;
  bool isRecording = false;
  bool isProcessingImage = false; // Add this flag
  List<img.Image> images = [];
  List<String> qrCodes = [];
  List<dynamic> qrResults = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void startFrameCapture() {
    if (isRecording) return;
    setState(() {
      isRecording = true;
    });
    _timer = Timer.periodic(Duration(seconds: 1), (timer) async {
      if (isProcessingImage) return; // Skip if an image is already being processed
      try {
        if (_controller.value.isInitialized) {
          isProcessingImage = true; // Set the flag before taking the picture
          await _controller.setFlashMode(FlashMode.off);
          final image = await _controller.takePicture();
          final bytes = await image.readAsBytes();
          await processImage(bytes); // Wait for the image to be processed
          isProcessingImage = false; // Reset the flag after processing
        }
      } catch (e) {
        print(e);
        isProcessingImage = false; // Reset the flag if there's an error
      }
    });
  }

  void stopFrameCapture() {
    if (!isRecording) return;
    setState(() {
      isRecording = false;
    });
    _timer?.cancel();
  }

  Future<void> processImage(Uint8List bytes) async {
    try {
      final img.Image? image = img.decodeImage(bytes);
      if (image != null) {
        final img.Image resized = img.copyResize(image, width: 300, height: 300);
        setState(() {
          images.add(resized);
        });

        final barcodeResult = await BarcodeCapture(image: resized.getBytes()).barcodes.first.rawValue; // Use MobileScanner to detect the barcode
        if (barcodeResult != null) {
          setState(() {
            qrResults.add(resized);
          });
        } else {
          print("No QR Code Detected");
        }
        if (qrResults.isEmpty){
          print("list is empty");
        } else{
          print("list is not empty");
        }
      }
    } catch (e) {
      print('Error processing image: $e');
    }
  }

  img.Image preprocessImage(img.Image image) {
    final grayscale = img.grayscale(image);
    final preProcessed = img.adjustColor(grayscale, contrast: 1.5);
    return preProcessed;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          title: Text('QR Scanner'),
          backgroundColor: Colors.blue,
        ),
        body: Column(
          children: [
            Expanded(
              flex: 2,
              child: Stack(
                children: [
                  Container(
                    height: double.infinity / 2,
                    width: double.infinity,
                    child: FutureBuilder<void>(
                      future: _initializeControllerFuture,
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.done) {
                          return CameraPreview(_controller);
                        } else {
                          return Center(child: CircularProgressIndicator());
                        }
                      },
                    ),
                  ),
                  CustomPaint(
                    painter: QRPainter(qrResults),
                    child: Container(),
                  ),
                  QRScannerOverlay(
                    scanAreaHeight: 300,
                    scanAreaWidth: 300,
                    overlayColor: Colors.black26,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton.icon(
                  onPressed: startFrameCapture,
                  icon: Icon(Icons.camera_alt),
                  label: Text('Start Camera'),
                ),
                ElevatedButton.icon(
                  onPressed: stopFrameCapture,
                  icon: Icon(Icons.stop),
                  label: Text('Stop Camera'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 10.0),
                    child: Container(
                      height: 100,
                      width: 200,
                      child: Image.memory(Uint8List.fromList(img.encodeJpg(images[index]))),
                    ),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: qrResults.length,
                itemBuilder: (context, index) {
                  return ListTile(
                    leading: qrResults.isNotEmpty
                        ? Image.memory(Uint8List.fromList(img.encodeJpg(qrResults[index])))
                        : null,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QRPainter extends CustomPainter {
  final List<dynamic> results;

  QRPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.red
      ..strokeWidth = 4
      ..style = PaintingStyle.stroke;

    for (var result in results) {
      final points = result.points.map((e) => Offset(e.x.toDouble(), e.y.toDouble())).toList();
      if (points.length == 4) {
        final path = Path()
          ..moveTo(points[0].dx, points[0].dy)
          ..lineTo(points[1].dx, points[1].dy)
          ..lineTo(points[2].dx, points[2].dy)
          ..lineTo(points[3].dx, points[3].dy)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
