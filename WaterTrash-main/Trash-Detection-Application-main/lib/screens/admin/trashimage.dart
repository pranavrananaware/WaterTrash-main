import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';

class TrashImagesDetectedScreen extends StatefulWidget {
  @override
  _TrashImagesDetectedScreenState createState() =>
      _TrashImagesDetectedScreenState();
}

class _TrashImagesDetectedScreenState extends State<TrashImagesDetectedScreen> {
  bool _isDeleting = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _deleteTrashImage(String docId, String imageUrl) async {
    setState(() {
      _isDeleting = true;
    });

    try {
      await _firestore.collection('uploads').doc(docId).delete();
      if (imageUrl.isNotEmpty) {
        await FirebaseStorage.instance.refFromURL(imageUrl).delete();
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Trash image deleted successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error deleting image: $e')),
      );
    } finally {
      setState(() {
        _isDeleting = false;
      });
    }
  }

  void _openGoogleMaps(String location) async {
    final googleMapsSearchUrl =
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(location)}";
    if (await canLaunchUrl(Uri.parse(googleMapsSearchUrl))) {
      await launchUrl(Uri.parse(googleMapsSearchUrl));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Google Maps.')),
      );
    }
  }

  void _openFullImage(BuildContext context, String docId, String imageUrl,
      String username) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullImageScreen(
          docId: docId,
          imageUrl: imageUrl,
          username: username,
          onDelete: () {
            _deleteTrashImage(docId, imageUrl);
            Navigator.pop(context);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Trash Images Detected")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('uploads').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No trash images detected."));
          }

          var trashDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.all(10),
            itemCount: trashDocs.length,
            itemBuilder: (context, index) {
              var trashData = trashDocs[index].data() as Map<String, dynamic>;
              String docId = trashDocs[index].id;
              String rawImageUrl = trashData['image_url'] ?? '';
              String imageUrl = rawImageUrl.isNotEmpty
                  ? rawImageUrl
                  : 'https://via.placeholder.com/150';

              List<dynamic>? results = trashData['results'];
              String detectedObjects;

              if (results != null && results.isNotEmpty) {
                final classes = results
                    .where((r) =>
                        r is Map<String, dynamic> && r.containsKey('class'))
                    .map((r) => r['class'].toString())
                    .toSet()
                    .toList();
                detectedObjects =
                    classes.isNotEmpty ? classes.join(', ') : 'Unknown Trash';
              } else {
                detectedObjects = 'Unknown Trash';
              }

              // 🛠️ Extract and clean the address
              String location = "No Location Available";
              if (trashData.containsKey('address')) {
                var addrData = trashData['address'];
                if (addrData is String &&
                    addrData.trim().isNotEmpty &&
                    !addrData.contains(r'${')) {
                  location = addrData;
                }
              }

              String status = trashData['status'] ?? 'Pending Review';
              String username = trashData['username'] ?? 'Unknown User';

              return Card(
                elevation: 4.0,
                margin: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  contentPadding: const EdgeInsets.all(10),
                  leading: GestureDetector(
                    onTap: () =>
                        _openFullImage(context, docId, imageUrl, username),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        imageUrl,
                        width: 60,
                        height: 60,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image_not_supported,
                                  size: 40, color: Colors.grey),
                              Text("No image", style: TextStyle(fontSize: 10)),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                  title: Text(detectedObjects,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Captured by: $username',
                          style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue)),
                      GestureDetector(
                        onTap: () => _openGoogleMaps(location),
                        child: Text(
                          'Location: $location',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.blue,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                      Text('Status: $status',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: Colors.red)),
                    ],
                  ),
                  trailing: IconButton(
                    icon: _isDeleting
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => _deleteTrashImage(docId, imageUrl),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FullImageScreen extends StatelessWidget {
  final String docId;
  final String imageUrl;
  final String username;
  final VoidCallback onDelete;

  const FullImageScreen({
    required this.docId,
    required this.imageUrl,
    required this.username,
    required this.onDelete,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final safeImageUrl =
        imageUrl.startsWith("http") ? imageUrl : "https:$imageUrl";

    return Scaffold(
      appBar: AppBar(title: const Text("Trash Image Preview")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: InteractiveViewer(
                child: Image.network(
                  safeImageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.image_not_supported,
                            size: 100, color: Colors.grey),
                        Text("Image not available",
                            style: TextStyle(color: Colors.grey)),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.delete, color: Colors.white),
            label: const Text("Delete"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }
}