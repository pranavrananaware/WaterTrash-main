// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as path;
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class CameraScreen extends StatefulWidget {
  final Function(List<Map<String, dynamic>>) onImageCaptured;
  final String username;

  const CameraScreen({
    required this.onImageCaptured,
    required this.username,
    super.key,
  });

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver {
  CameraController? _controller;
  bool _isCameraInitialized = false;
  bool _isUploading = false;

  late Interpreter _interpreter;
  late List<String> _labels;

  final int inputSize = 224;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBarController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
  }

  Future<void> _init() async {
    await _requestPermissions();
    await _initializeCamera();
    await _loadModelAndLabels();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    _interpreter.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _controller?.dispose();
      _controller = null;
      setState(() => _isCameraInitialized = false);
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _requestPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.locationWhenInUse,
      Permission.storage,
    ].request();

    if (!statuses[Permission.camera]!.isGranted) {
      _showMessage('Camera permission is required.');
    }
    if (!statuses[Permission.locationWhenInUse]!.isGranted) {
      _showMessage('Location permission is required.');
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showMessage('No cameras available on device.');
        return;
      }

      _controller = CameraController(
        cameras[0],
        ResolutionPreset.max,
        enableAudio: false,
      );
      await _controller!.initialize();
      await Future.delayed(const Duration(milliseconds: 300));
      await _controller!.setFocusMode(FocusMode.auto);
      if (!mounted) return;

      if (_controller!.value.hasError) {
        _showMessage('Camera error: ${_controller!.value.errorDescription}');
        return;
      }

      setState(() => _isCameraInitialized = true);
    } catch (e) {
      _showMessage('Error initializing camera: $e');
    }
  }

  Future<void> _loadModelAndLabels() async {
    try {
      final interpreterOptions = InterpreterOptions();
      _interpreter = await Interpreter.fromAsset('assets/model_unquant.tflite', options: interpreterOptions);
      final rawLabels = await rootBundle.loadString('assets/wastelabels.txt');
      _labels = rawLabels.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    } catch (e) {
      _showMessage('Error loading model or labels: $e');
    }
  }

  Uint8List _preprocessImage(File file) {
    final imageBytes = file.readAsBytesSync();
    final img.Image? image = img.decodeImage(imageBytes);
    if (image == null) throw Exception('Failed to decode image');

    final img.Image resizedImage = img.copyResize(image, width: inputSize, height: inputSize);
    final Float32List input = Float32List(inputSize * inputSize * 3);

    int pixelIndex = 0;
    for (int y = 0; y < inputSize; y++) {
      for (int x = 0; x < inputSize; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[pixelIndex++] = pixel.r / 255.0;
        input[pixelIndex++] = pixel.g / 255.0;
        input[pixelIndex++] = pixel.b / 255.0;
      }
    }
    return input.buffer.asUint8List();
  }

  Future<List<Map<String, dynamic>>> _runInference(File imageFile) async {
    try {
      final input = _preprocessImage(imageFile);
      final inputTensor = input.buffer.asFloat32List();
      final output = List.filled(_labels.length, 0.0).reshape([1, _labels.length]);

      _interpreter.run(inputTensor.reshape([1, inputSize, inputSize, 3]), output);

      List<Map<String, dynamic>> results = [];
      for (int i = 0; i < _labels.length; i++) {
        if (output[0][i] > 0.01) {
          results.add({
            'class': _labels[i],
            'score': output[0][i],
          });
        }
      }
      results.sort((a, b) => (b['score'] as double).compareTo(a['score'] as double));
      return results.take(5).toList();
    } catch (e) {
      _showMessage('Inference error: $e');
      return [];
    }
  }

  Future<Position?> _determinePosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return null;
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.deniedForever) return null;
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
  }

  Future<String> _getAddressFromPosition(Position position) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(position.latitude, position.longitude);
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}';
      }
    } catch (e) {
      _showMessage('Failed to get address: $e');
    }
    return 'Unknown Location';
  }

  Future<void> _uploadImageAndResults(File imageFile, List<Map<String, dynamic>> results, String address) async {
    setState(() => _isUploading = true);
    try {
      final fileName = path.basename(imageFile.path);
      final storageRef = FirebaseStorage.instance.ref().child('uploads/$fileName');
      final snapshot = await storageRef.putFile(imageFile);
      final imageUrl = await snapshot.ref.getDownloadURL();

      final docRef = await FirebaseFirestore.instance.collection('uploads').add({
        'username': widget.username,
        'image_url': imageUrl,
        'results': results,
        'address': address,
        'timestamp': FieldValue.serverTimestamp(),
      });

      widget.onImageCaptured([
        {
          'docId': docRef.id,
          'imageUrl': imageUrl,
          'results': results,
          'address': address,
          'timestamp': DateTime.now().toIso8601String(),
        }
      ]);

      _hideMessage();
      _showMessage('✅ Successfully uploaded');

      // ✅ Navigate to detection screen with arguments
      await Navigator.pushNamed(
        context,
        '/detection',
        arguments: {
          'imageUrl': imageUrl,
          'detectedObjects': results,
        },
      );

    } catch (e) {
      _hideMessage();
      _showMessage('Upload failed: $e');
    } finally {
      setState(() => _isUploading = false);
    }
  }

  Future<void> _captureImage() async {
    if (_controller == null || !_controller!.value.isInitialized) {
      _showMessage("Camera is not initialized.");
      return;
    }
    if (_controller!.value.isTakingPicture) {
      _showMessage("Still processing last capture. Please wait.");
      return;
    }

    try {
      final XFile file = await _controller!.takePicture();
      final imageFile = File(file.path);
      _showMessage("📸 Image captured, running inference...", persistent: true);

      final results = await _runInference(imageFile);
      final position = await _determinePosition();
      final address = position != null ? await _getAddressFromPosition(position) : 'Unknown Location';

      await _uploadImageAndResults(imageFile, results, address);
    } catch (e) {
      _hideMessage();
      _showMessage('Error capturing image: $e');
    }
  }

  Future<void> _pickImageFromGallery() async {
    try {
      final XFile? pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (pickedFile == null) return;

      final File imageFile = File(pickedFile.path);
      _showMessage("🖼️ Image selected, running inference...", persistent: true);

      final results = await _runInference(imageFile);
      final position = await _determinePosition();
      final address = position != null ? await _getAddressFromPosition(position) : 'Unknown Location';

      await _uploadImageAndResults(imageFile, results, address);
    } catch (e) {
      _hideMessage();
      _showMessage('Failed to pick or process image: $e');
    }
  }

  void _showMessage(String message, {bool persistent = false}) {
    if (!mounted) return;
    _snackBarController?.close();
    final snackBar = SnackBar(
      content: Text(message),
      duration: persistent ? const Duration(days: 1) : const Duration(seconds: 3),
    );
    _snackBarController = ScaffoldMessenger.of(context).showSnackBar(snackBar);
  }

  void _hideMessage() {
    _snackBarController?.close();
    _snackBarController = null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _isCameraInitialized
          ? Stack(
              children: [
                Positioned.fill(child: CameraPreview(_controller!)),
                Align(
                  alignment: Alignment.bottomCenter,
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          icon: const Icon(Icons.camera_alt),
                          label: const Text('Capture Image'),
                          onPressed: _isUploading ? null : _captureImage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.upload),
                          label: const Text('Upload from Gallery'),
                          onPressed: _isUploading ? null : _pickImageFromGallery,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14.0, horizontal: 24.0),
                            textStyle: const TextStyle(fontSize: 18),
                          ),
                        ),
                        if (_isUploading)
                          const Padding(
                            padding: EdgeInsets.only(top: 10),
                            child: CircularProgressIndicator(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator()),
    );
  }
}