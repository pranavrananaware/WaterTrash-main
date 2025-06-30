import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:trashhdetection/screens/user/detection_screen.dart';
import 'package:trashhdetection/screens/user/history_screen.dart';
import 'package:trashhdetection/screens/user/profile_screen.dart';
import 'package:trashhdetection/screens/user/camera_screen.dart';

class UserHome extends StatefulWidget {
  final String username;
  final String email;

  const UserHome({
    super.key,
    required this.username,
    required this.email,
  });

  @override
  State<UserHome> createState() => _UserHomeState();
}

class _UserHomeState extends State<UserHome> {
  String location = 'Fetching location...';
  double? _latitude;
  double? _longitude;
  GoogleMapController? _mapController;
  final List<Map<String, dynamic>> _detectionHistory = [];

  @override
  void initState() {
    super.initState();
    _fetchLocation();
  }

  Future<void> _fetchLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      permission = await Geolocator.requestPermission();
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      _latitude = position.latitude;
      _longitude = position.longitude;

      final placemarks = await placemarkFromCoordinates(_latitude!, _longitude!);
      final place = placemarks.first;
      setState(() {
        location = '${place.subLocality}, ${place.locality}, ${place.administrativeArea}';
      });
    } catch (e) {
      setState(() {
        location = 'Unable to get location';
      });
    }
  }

  void _onImageCaptured(List<Map<String, dynamic>> history) {
    setState(() {
      _detectionHistory.clear();
      _detectionHistory.addAll(history);
    });
  }

  Future<void> _openInGoogleMaps() async {
    if (_latitude != null && _longitude != null) {
      final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$_latitude,$_longitude';
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(Uri.parse(googleMapsUrl));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not launch Google Maps")),
        );
      }
    }
  }

  Widget _buildMapCard() {
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: (_latitude != null && _longitude != null)
            ? GestureDetector(
                onTap: _openInGoogleMaps,
                child: AbsorbPointer(
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(_latitude!, _longitude!),
                      zoom: 14,
                    ),
                    markers: {
                      Marker(
                        markerId: const MarkerId('user-location'),
                        position: LatLng(_latitude!, _longitude!),
                        infoWindow: const InfoWindow(title: 'You are here'),
                      ),
                    },
                    onMapCreated: (controller) => _mapController = controller,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                  ),
                ),
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  Widget _buildGridItem(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [
            BoxShadow(
              color: Colors.black26,
              offset: Offset(2, 2),
              blurRadius: 8,
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, color: Colors.white, size: 30),
            const SizedBox(height: 10),
            Text(
              label,
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(String value, String label, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 6),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.green.shade50,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FaIcon(icon, size: 24, color: Colors.green),
            const SizedBox(height: 6),
            Text(value, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.black54)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F9FD),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.water_drop, color: Colors.blueAccent, size: 50),
                const SizedBox(height: 10),
                Text(
                  'Water Trash\nDetection',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[900],
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: _openInGoogleMaps,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade100,
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.location_on, color: Colors.blueAccent),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            location,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.blue[800],
                            ),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(Icons.map, color: Colors.blueAccent),
                      ],
                    ),
                  ),
                ),
                _buildMapCard(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatCard("1.2 kg", "trash", FontAwesomeIcons.recycle),
                    _buildStatCard("0.8 g", "carbon", FontAwesomeIcons.leaf),
                    _buildStatCard("120", "points", FontAwesomeIcons.star),
                  ],
                ),
                const SizedBox(height: 20),
                GridView.count(
                  crossAxisCount: 2,
                  childAspectRatio: 1.2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  children: [
                    _buildGridItem(
                      'Camera',
                      FontAwesomeIcons.camera,
                      Colors.blueAccent,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CameraScreen(
                              onImageCaptured: _onImageCaptured,
                              username: widget.username,
                            ),
                          ),
                        );
                      },
                    ),
                    _buildGridItem(
                      'Detection',
                      FontAwesomeIcons.magnifyingGlassChart,
                      Colors.teal,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const DetectionScreen(),
                          ),
                        );
                      },
                    ),
                    _buildGridItem(
                      'Classification',
                      FontAwesomeIcons.clockRotateLeft,
                      Colors.orangeAccent,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HistoryScreen(
                              detectionHistory: _detectionHistory,
                              historyList: [],
                            ),
                          ),
                        );
                      },
                    ),
                    _buildGridItem(
                      'Profile',
                      FontAwesomeIcons.user,
                      Colors.deepPurple,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ProfileScreen(
                              username: widget.username,
                              email: widget.email,
                              profilePicUrl: '',
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black12,
                        blurRadius: 6,
                        offset: Offset(2, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.campaign, color: Colors.green),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          "You’ve detected 5% more trash than last week!",
                          style: GoogleFonts.poppins(fontSize: 14),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
