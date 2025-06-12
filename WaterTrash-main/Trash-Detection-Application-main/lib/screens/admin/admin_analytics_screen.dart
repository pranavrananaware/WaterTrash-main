import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminAnalyticsScreen extends StatefulWidget {
  @override
  _AdminAnalyticsScreenState createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  final List<String> dayOrder = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  Map<String, int> detectionsPerDay = {
    'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
  };

  Map<String, int> objectTypeCounts = {};
  bool isLoading = true;
  DateTime? startDate;
  DateTime? endDate;
  StreamSubscription<QuerySnapshot>? _subscription;

  final List<String> allowedLabels = ['Plastic', 'Paper', 'Metal', 'Cardboard', 'Glass'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    startDate = DateTime(now.year, now.month, 1);
    endDate = DateTime(now.year, now.month + 1, 0);
    subscribeToData();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  void subscribeToData() {
    _subscription?.cancel();
    setState(() => isLoading = true);

    final query = FirebaseFirestore.instance
        .collection('uploads')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate!))
        .where('timestamp', isLessThanOrEqualTo: Timestamp.fromDate(endDate!));

    _subscription = query.snapshots().listen((snapshot) {
      Map<String, int> newData = {
        'Mon': 0, 'Tue': 0, 'Wed': 0, 'Thu': 0, 'Fri': 0, 'Sat': 0, 'Sun': 0,
      };
      Map<String, int> newObjectTypeCounts = {};

      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        final timestamp = data['timestamp'] as Timestamp;
        final results = data['results'] as List<dynamic>? ?? [];

        // Count detections per weekday
        DateTime date = timestamp.toDate();
        String weekday = DateFormat('E').format(date);
        if (newData.containsKey(weekday)) {
          newData[weekday] = newData[weekday]! + 1;
        }

        // Count each class in the results[]
        for (var result in results) {
          final String? rawClass = result['class'];
          if (rawClass != null) {
            final parts = rawClass.split(' ');
            if (parts.length > 1) {
              final label = parts.sublist(1).join(' ').trim();
              if (allowedLabels.contains(label)) {
                newObjectTypeCounts[label] = (newObjectTypeCounts[label] ?? 0) + 1;
              }
            }
          }
        }
      }

      setState(() {
        detectionsPerDay = newData;
        objectTypeCounts = newObjectTypeCounts;
        isLoading = false;
      });
    }, onError: (error) {
      print('Error fetching real-time data: $error');
      setState(() => isLoading = false);
    });
  }

  Future<void> pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2022),
      lastDate: DateTime.now(),
      initialDateRange: DateTimeRange(start: startDate!, end: endDate!),
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });
      subscribeToData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final total = detectionsPerDay.values.fold(0, (a, b) => a + b);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Statistics & Analytics"),
        actions: [
          IconButton(
            icon: const Icon(Icons.date_range),
            onPressed: pickDateRange,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                children: [
                  const Text(
                    '📊 Weekly Detection Activity Chart',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'From ${DateFormat('dd MMM').format(startDate!)} to ${DateFormat('dd MMM yyyy').format(endDate!)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 10),
                  _buildBarChart(),
                  const SizedBox(height: 20),
                  _buildStatisticsCard(
                    title: 'Total Detections',
                    count: total.toString(),
                    icon: Icons.search,
                  ),
                  const SizedBox(height: 20),
                  _buildAnalyticsCard(
                    title: 'Filtered Notifications',
                    description: 'Tap calendar to change date range.',
                    onTap: pickDateRange,
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    '🧾 Detection Type Distribution',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  _buildPieChart(),
                ],
              ),
      ),
    );
  }

  Widget _buildBarChart() {
    final List<BarChartGroupData> barGroups = [];

    for (int i = 0; i < dayOrder.length; i++) {
      String day = dayOrder[i];
      int count = detectionsPerDay[day] ?? 0;

      barGroups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: count.toDouble(),
              color: Colors.primaries[i % Colors.primaries.length],
              width: 20,
              borderRadius: BorderRadius.circular(4),
            ),
          ],
        ),
      );
    }

    return AspectRatio(
      aspectRatio: 1.6,
      child: BarChart(
        BarChartData(
          maxY: (detectionsPerDay.values.reduce((a, b) => a > b ? a : b) + 2).toDouble(),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: true, reservedSize: 28),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, _) {
                  int index = value.toInt();
                  if (index >= 0 && index < dayOrder.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(dayOrder[index], style: TextStyle(fontSize: 12)),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          barGroups: barGroups,
          borderData: FlBorderData(show: false),
          barTouchData: BarTouchData(enabled: true),
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    if (objectTypeCounts.isEmpty) {
      return Center(child: Text('No detection type data found.'));
    }

    final total = objectTypeCounts.values.fold(0, (a, b) => a + b);
    int colorIndex = 0;
    List<Color> colors = [];
    final List<PieChartSectionData> sections = [];
    final List<Widget> legendItems = [];

    for (String label in allowedLabels) {
      final count = objectTypeCounts[label];
      if (count == null || count == 0) continue;

      final double percentage = (count / total) * 100;
      final color = Colors.primaries[colorIndex % Colors.primaries.length];
      colors.add(color);
      colorIndex++;

      sections.add(PieChartSectionData(
        color: color,
        value: percentage,
        title: '$label\n${percentage.toStringAsFixed(1)}%',
        radius: 55,
        titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
      ));

      legendItems.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(width: 14, height: 14, color: color),
              const SizedBox(width: 8),
              Flexible(child: Text('$label: $count', style: TextStyle(fontSize: 14))),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        AspectRatio(
          aspectRatio: 1.3,
          child: PieChart(
            PieChartData(
              sections: sections,
              centerSpaceRadius: 30,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: legendItems,
        ),
      ],
    );
  }

  Widget _buildStatisticsCard({
    required String title,
    required String count,
    required IconData icon,
  }) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        leading: Icon(icon, size: 45, color: Colors.blueAccent),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text('Count: $count', style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildAnalyticsCard({
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 8.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        subtitle: Text(description, style: const TextStyle(fontSize: 16)),
        trailing: const Icon(Icons.filter_alt, color: Colors.deepPurple),
        onTap: onTap,
      ),
    );
  }
}
