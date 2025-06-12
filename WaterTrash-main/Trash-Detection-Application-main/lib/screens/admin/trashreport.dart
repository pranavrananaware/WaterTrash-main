import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class ManageTrashReportsScreen extends StatefulWidget {
  @override
  _ManageTrashReportsScreenState createState() => _ManageTrashReportsScreenState();
}

class _ManageTrashReportsScreenState extends State<ManageTrashReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> _fetchUsername(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        return userDoc.data()!['username'] ?? 'Unknown User';
      }
    } catch (e) {
      print('Error fetching username: $e');
    }
    return 'Unknown User';
  }

  Future<void> _generatePDF(BuildContext context, Map<String, dynamic> data, String username) async {
    try {
      final pdf = pw.Document();

      // Detected Object
      String detectedObject = 'Unknown';
      if (data['results'] != null) {
        final List<dynamic> results = data['results'];
        final classes = results
            .whereType<Map<String, dynamic>>()
            .where((r) => r.containsKey('class'))
            .map((r) => r['class'].toString())
            .toSet()
            .toList();
        detectedObject = classes.isNotEmpty ? classes.join(', ') : 'Unknown';
      }

      // Timestamp
      Timestamp? timestamp = data['timestamp'];
      String formattedDate = timestamp != null
          ? DateFormat.yMMMd().format(timestamp.toDate())
          : 'No Date Available';

      // Image
      String imageUrl = data['image_url'] ?? '';
      pw.Widget? imageWidget;
      if (imageUrl.isNotEmpty) {
        try {
          final image = await networkImage(imageUrl);
          imageWidget = pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text("Detected Image", style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Image(image, height: 250, fit: pw.BoxFit.cover),
            ],
          );
        } catch (e) {
          print("Image loading error: $e");
        }
      }

      // Location
      final latitude = data['latitude'];
      final longitude = data['longitude'];
      final address = data['address'];

      String locationLabel = "Not Available";
      String? mapsUrl;

      if (latitude != null && longitude != null) {
        locationLabel = "Lat: $latitude, Lng: $longitude";
        mapsUrl = "https://www.google.com/maps/search/?api=1&query=$latitude,$longitude";
      } else if (address != null && address.toString().isNotEmpty) {
        locationLabel = address;
        mapsUrl = "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(address)}";
      }

      // PDF Layout
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.all(32),
          build: (context) => pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text("Trash Detection Report",
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
              ),
              pw.SizedBox(height: 20),
              _buildSectionTitle("User Details"),
              _buildDetailRow("User", username),
              if (mapsUrl != null)
                pw.Padding(
                  padding: pw.EdgeInsets.symmetric(vertical: 4),
                  child: pw.Row(
                    children: [
                      pw.Text("Location: ", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                      pw.UrlLink(
                        destination: mapsUrl,
                        child: pw.Text(
                          locationLabel,
                          style: pw.TextStyle(
                            fontSize: 14,
                            color: PdfColors.blue,
                            decoration: pw.TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                _buildDetailRow("Location", locationLabel),
              pw.SizedBox(height: 10),
              _buildSectionTitle("Detection Details"),
              _buildDetailRow("Detected Object", detectedObject),
              _buildDetailRow("Timestamp", formattedDate),
              pw.SizedBox(height: 20),
              if (imageWidget != null) imageWidget,
            ],
          ),
        ),
      );

      final output = await getTemporaryDirectory();
      final filePath = "${output.path}/TrashReport_${DateTime.now().millisecondsSinceEpoch}.pdf";
      final file = File(filePath);
      await file.writeAsBytes(await pdf.save());

      if (await file.exists()) {
        OpenFile.open(filePath);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening PDF...")));
      } else {
        throw Exception("PDF not found.");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error generating PDF: $e")));
    }
  }

  pw.Widget _buildSectionTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
        pw.Divider(),
      ],
    );
  }

  pw.Widget _buildDetailRow(String label, String value) {
    return pw.Padding(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Text("$label: $value", style: pw.TextStyle(fontSize: 14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Manage Trash Reports")),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('uploads').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text("No Reports Found"));
          }

          final docs = snapshot.data!.docs;
          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;
              final userId = data['userId'] ?? '';
              final locationText = data['address'] ?? 'Unknown Location';
              final imageUrl = data['image_url'] ?? '';

              String detectedObject = 'Unknown';
              if (data['results'] != null) {
                final List<dynamic> results = data['results'];
                final classes = results
                    .whereType<Map<String, dynamic>>()
                    .where((r) => r.containsKey('class'))
                    .map((r) => r['class'].toString())
                    .toSet()
                    .toList();
                detectedObject = classes.isNotEmpty ? classes.join(', ') : 'Unknown';
              }

              return FutureBuilder<String>(
                future: _fetchUsername(userId),
                builder: (context, snapshot) {
                  final username = snapshot.data ?? 'Loading...';

                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    elevation: 4.0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: imageUrl.isNotEmpty
                            ? CachedNetworkImage(
                                imageUrl: imageUrl,
                                width: 60,
                                height: 60,
                                fit: BoxFit.cover,
                                placeholder: (context, url) => const CircularProgressIndicator(strokeWidth: 2),
                                errorWidget: (context, url, error) =>
                                    const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                              )
                            : const Icon(Icons.image_not_supported, size: 60, color: Colors.grey),
                      ),
                      title: Text(username, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("📍 Location: $locationText\n🔍 Detected: $detectedObject"),
                      trailing: IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.red),
                        onPressed: () => _generatePDF(context, data, username),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
