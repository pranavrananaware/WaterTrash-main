import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';

class HistoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> detectionHistory;

   HistoryScreen({required this.detectionHistory, Key? key, required List historyList})
      : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteItem(int index, String? docId, String? imageUrl) async {
    setState(() {
      widget.detectionHistory.removeAt(index);
    });

    if (docId != null) {
      try {
        await _firestore.collection('uploads').doc(docId).delete();
      } catch (e) {
        print("Error deleting document: $e");
      }
    }

    if (imageUrl != null && imageUrl.startsWith('http')) {
      try {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      } catch (e) {
        print("Error deleting image from Firebase Storage: $e");
      }
    }
  }

  void _openFullScreenImage(String imagePath) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullScreenImageScreen(imagePath: imagePath, imageUrl: '',),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Classification History')),
      body: widget.detectionHistory.isEmpty
          ? const Center(child: Text('No classification available'))
          : ListView.builder(
              itemCount: widget.detectionHistory.length,
              itemBuilder: (context, index) {
                var item = widget.detectionHistory[index];
                String imagePath = item['imagePath'] ?? "";
                String? imageUrl = item['imageUrl'];
                String? docId = item['docId'];
                String username = item['username'] ?? 'Unknown User';
                List<dynamic>? results = item['results'];

                String detectedObjects = "No objects detected";
                if (results != null && results.isNotEmpty) {
                  final classes = results
                      .where((r) => r is Map<String, dynamic> && r.containsKey('class'))
                      .map((r) => r['class'].toString())
                      .toSet()
                      .toList();
                  if (classes.isNotEmpty) {
                    detectedObjects = classes.join(', ');
                  }
                }

                Widget imageWidget;

                if (imageUrl != null && imageUrl.isNotEmpty) {
                  imageWidget = Stack(
                    children: [
                      Image.network(
                        imageUrl,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator()),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return const SizedBox(
                            height: 200,
                            child: Center(
                                child: Icon(Icons.broken_image,
                                    size: 60, color: Colors.grey)),
                          );
                        },
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: DetectionBoxPainter(results)),
                      ),
                    ],
                  );
                } else if (imagePath.isNotEmpty && File(imagePath).existsSync()) {
                  imageWidget = Stack(
                    children: [
                      Image.file(
                        File(imagePath),
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      ),
                      Positioned.fill(
                        child: CustomPaint(painter: DetectionBoxPainter(results)),
                      ),
                    ],
                  );
                } else {
                  imageWidget = Container(
                    height: 200,
                    color: Colors.grey[300],
                    child: const Center(
                      child: Icon(Icons.image_not_supported,
                          size: 80, color: Colors.grey),
                    ),
                  );
                }

                return Card(
                  margin: const EdgeInsets.all(10),
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      GestureDetector(
                        onTap: () => _openFullScreenImage(imageUrl ?? imagePath),
                        child: ClipRRect(
                          borderRadius:
                              const BorderRadius.vertical(top: Radius.circular(10)),
                          child: imageWidget,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Timestamp: ${item['timestamp'] ?? 'No Timestamp'}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Classified Trash: $detectedObjects',
                              style: const TextStyle(
                                  fontSize: 14, color: Colors.blue),
                            ),
                            const SizedBox(height: 5),
                            
                          ],
                        ),
                      ),
                      ButtonBar(
                        alignment: MainAxisAlignment.end,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () =>
                                _deleteItem(index, docId, imageUrl),
                            tooltip: 'Delete this entry',
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class FullScreenImageScreen extends StatelessWidget {
  final String imagePath;

  const FullScreenImageScreen({Key? key, required this.imagePath, required String imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    bool isNetworkImage = imagePath.startsWith('http');

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Full Screen Image'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: isNetworkImage
            ? Image.network(
                imagePath,
                fit: BoxFit.contain,
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const CircularProgressIndicator();
                },
                errorBuilder: (context, error, stackTrace) {
                  return const Icon(Icons.broken_image,
                      size: 100, color: Colors.white);
                },
              )
            : File(imagePath).existsSync()
                ? Image.file(File(imagePath), fit: BoxFit.contain)
                : const Text("Image not found",
                    style: TextStyle(color: Colors.white, fontSize: 18)),
      ),
    );
  }
}

class DetectionBoxPainter extends CustomPainter {
  final List<dynamic>? results;

  DetectionBoxPainter(this.results);

  @override
  void paint(Canvas canvas, Size size) {
    if (results == null) return;

    final paint = Paint()
      ..color = Colors.red.withOpacity(0.6)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final textStyle = TextStyle(
      color: Colors.white,
      fontSize: 12,
      backgroundColor: Colors.red.withOpacity(0.7),
    );

    for (var result in results!) {
      if (result is Map<String, dynamic> && result.containsKey('box')) {
        final List<dynamic> box = result['box'];
        final String label = result['class'] ?? 'Object';

        double x = (box[0] as num).toDouble();
        double y = (box[1] as num).toDouble();
        double w = (box[2] as num).toDouble();
        double h = (box[3] as num).toDouble();

        double scaleX = size.width / 640;
        double scaleY = size.height / 640;

        Rect rect = Rect.fromLTWH(x * scaleX, y * scaleY, w * scaleX, h * scaleY);
        canvas.drawRect(rect, paint);

        final textSpan = TextSpan(text: label, style: textStyle);
        final textPainter = TextPainter(
          text: textSpan,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: w * scaleX);

        textPainter.paint(canvas, Offset(x * scaleX, y * scaleY - textPainter.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
