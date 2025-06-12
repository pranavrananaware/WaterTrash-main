import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DetectionScreen extends StatefulWidget {
  const DetectionScreen({Key? key}) : super(key: key);

  @override
  State<DetectionScreen> createState() => _DetectionScreenState();
}

class _DetectionScreenState extends State<DetectionScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  List<Map<String, dynamic>> detectionList = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchDetectionData();
  }

  Future<void> _fetchDetectionData() async {
    try {
      final querySnapshot = await _firestore
          .collection('uploads')
          .orderBy('timestamp', descending: true)
          .get();

      setState(() {
        detectionList = querySnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'imageUrl': data['image_url'] ?? '',
            'results': data['results'] ?? [],
          };
        }).toList();
        isLoading = false;
      });
    } catch (e) {
      print('❌ Error fetching detection data: $e');
      setState(() => isLoading = false);
    }
  }

  Color _getColorForClass(String className) {
    switch (className.toLowerCase()) {
      case 'plastic':
        return Colors.blueAccent;
      case 'cardboard':
        return Colors.orange;
      case 'paper':
        return Colors.green;
      case 'glass':
        return Colors.teal;
      case 'metal':
        return Colors.grey;
      default:
        return Colors.redAccent;
    }
  }

  List<Widget> _generateFakeBoxes(List<dynamic> results) {
    final List<Widget> boxes = [];
    final Random random = Random();

    for (int i = 0; i < results.length; i++) {
      final obj = results[i];
      final String label = obj['class'] ?? 'Unknown';
      final double score = (obj['score'] ?? 0.0) as double;
      final Color color = _getColorForClass(label);

      final double left = 30.0 + random.nextInt(140);
      final double top = 30.0 + random.nextInt(100);
      final double width = 100.0 + random.nextInt(50);
      final double height = 100.0 + random.nextInt(50);

      boxes.add(Positioned(
        left: left,
        top: top,
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: color, width: 3),
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            Positioned(
              top: -22,
              left: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  "$label (${(score * 100).toStringAsFixed(1)}%)",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ));
    }

    return boxes;
  }

  void _openFullScreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FullScreenImage(imageUrl: imageUrl),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detection Results'),
        backgroundColor: Colors.green[700],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : detectionList.isEmpty
              ? const Center(child: Text('No detection data available'))
              : ListView.builder(
                  itemCount: detectionList.length,
                  itemBuilder: (context, index) {
                    final item = detectionList[index];
                    final imageUrl = item['imageUrl'];
                    final results = item['results'];

                    return Card(
                      margin: const EdgeInsets.all(12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          imageUrl.isNotEmpty
                              ? GestureDetector(
                                  onTap: () => _openFullScreen(imageUrl),
                                  child: ClipRRect(
                                    borderRadius: const BorderRadius.vertical(
                                        top: Radius.circular(12)),
                                    child: SizedBox(
                                      height: 300,
                                      child: Stack(
                                        children: [
                                          Positioned.fill(
                                            child: Image.network(
                                              imageUrl,
                                              fit: BoxFit.cover,
                                              loadingBuilder:
                                                  (context, child, progress) {
                                                return progress == null
                                                    ? child
                                                    : const Center(
                                                        child:
                                                            CircularProgressIndicator(),
                                                      );
                                              },
                                              errorBuilder: (context, error, stackTrace) =>
                                                  const Center(
                                                child: Icon(
                                                    Icons.broken_image,
                                                    size: 60),
                                              ),
                                            ),
                                          ),
                                          ..._generateFakeBoxes(results),
                                        ],
                                      ),
                                    ),
                                  ),
                                )
                              : const SizedBox(
                                  height: 300,
                                  child: Center(
                                      child: Text('Image not available')),
                                ),
                          Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Detected Objects',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                results.isEmpty
                                    ? const Text('No objects detected.')
                                    : Column(
                                        children: results.map<Widget>((obj) {
                                          final label =
                                              obj['class'] ?? 'Unknown';
                                          final score =
                                              (obj['score'] ?? 0.0) as double;
                                          return ListTile(
                                            leading: Icon(Icons.search,
                                                color:
                                                    _getColorForClass(label)),
                                            title: Text(label),
                                            subtitle: Text(
                                              'Confidence: ${(score * 100).toStringAsFixed(2)}%',
                                            ),
                                          );
                                        }).toList(),
                                      ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

// ✅ FullScreenImage widget

class FullScreenImage extends StatelessWidget {
  final String imageUrl;

  const FullScreenImage({Key? key, required this.imageUrl}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
      body: Center(
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          loadingBuilder: (context, child, loadingProgress) {
            return loadingProgress == null
                ? child
                : const CircularProgressIndicator();
          },
          errorBuilder: (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 80, color: Colors.white),
        ),
      ),
    );
  }
}