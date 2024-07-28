import 'dart:async';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;
import 'package:qr_scanner_overlay/qr_scanner_overlay.dart';

class CameraScreen2 extends StatefulWidget {
  final CameraDescription camera;

  const CameraScreen2({required this.camera});

  @override
  _CameraScreen2State createState() => _CameraScreen2State();
}

class _CameraScreen2State extends State<CameraScreen2> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  Timer? _timer;
  bool isRecording = false;
  List<img.Image> images = [];
  List<String> qrCodes = [];
  List<img.Image> locatedQR = [];

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
      try {
        if (_controller.value.isInitialized) {
          await _controller.setFlashMode(FlashMode.off);
          final image = await _controller.takePicture();
          final bytes = await image.readAsBytes();
          processImage(bytes);
        }
      } catch (e) {
        print(e);
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

  void processImage(Uint8List bytes) async {
    final img.Image? image = img.decodeImage(bytes);
    if (image != null) {
      final img.Image resized = img.copyResize(image, width: 500, height: 480);
      final img.Image preprocessed = preprocessImage(resized);
      setState(() {
        images.add(preprocessed);
      });

      // Decode QR code using flutter_zxing
      final codeResult = await Zxing().readBarcode(preprocessed.getBytes(), DecodeParams(format: Format.qrCode));
      if (codeResult.isValid) {
        setState(() {
          locatedQR.add(preprocessed);
        });
      }
      if(locatedQR.isEmpty){
        print("list is empty");
      }
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
                  QRScannerOverlay(
                    scanAreaHeight: 300,
                    scanAreaWidth: 300,
                    overlayColor: Colors.black26,
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: startFrameCapture,
                  child: Text('Start Camera'),
                ),
                SizedBox(width: 20),
                ElevatedButton(
                  onPressed: stopFrameCapture,
                  child: Text('Stop Camera'),
                ),
              ],
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: images.length,
                itemBuilder: (context, index) {
                  return Container(
                    height: 100,
                    width: 200,
                    child: Image.memory(Uint8List.fromList(img.encodeJpg(images[index]))),
                  );
                },
              ),
            ),
            Expanded(
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: locatedQR.length,
                itemBuilder: (context, index) {
                  return Container(
                    height: 100,
                    width: 100,
                    child: Image.memory(Uint8List.fromList(img.encodeJpg(locatedQR[index]))),
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
