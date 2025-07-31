import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database
import 'dart:async';

import 'package:penyiraman_otomatis/firebase_options.dart'; // Import untuk StreamSubscription

// Definisikan palet warna agar mudah diubah
const Color primaryColor = Color(0xFF0A686A);
const Color lightBlueBgColor = Color(0xFFE3F2FD);
const Color sliderActiveColor = Color(0xFF29B6F6);
const Color textColor = Color(0xFF333333);

// MAIN FUNCTION - Modifikasi untuk inisialisasi Firebase
void main() async {
  // Pastikan Flutter binding sudah siap sebelum inisialisasi Firebase
  WidgetsFlutterBinding.ensureInitialized();
  // Inisialisasi Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Smart Garden UI',
      theme: ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: Colors.grey[100],
        fontFamily: 'Poppins',
      ),
      home: const HomeScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Nilai awal untuk slider
  double _moistureThreshold = 19.0;
  double _pumpDuration = 3.0;
  double _checkInterval = 1.0;

  // --- STATE BARU UNTUK DATA FIREBASE ---
  int _kelembaban = 0; // Untuk menyimpan nilai kelembaban
  String _statusPenyiraman = "OFF"; // Untuk menyimpan status pompa
  String _timestamp = "00:00:00"; // Untuk menyimpan timestamp
  late DatabaseReference _databaseReference; // Referensi ke node 'penyiram'
  StreamSubscription<DatabaseEvent>?
  _penyiramSubscription; // Listener untuk perubahan data

  @override
  void initState() {
    super.initState();
    // Inisialisasi referensi ke node 'penyiram' di Firebase
    _databaseReference = FirebaseDatabase.instance.ref('penyiram');

    // Mulai mendengarkan perubahan data pada node tersebut
    _listenToPenyiramData();
  }

  // Fungsi untuk mendengarkan data dari Firebase secara real-time
  void _listenToPenyiramData() {
    _penyiramSubscription = _databaseReference.onValue.listen(
      (event) {
        // Ambil data snapshot dari event
        final data = event.snapshot.value;

        if (data != null && data is Map) {
          // Konversi data ke Map
          final mapData = Map<String, dynamic>.from(data as Map);

          // Update state dengan data baru dari Firebase
          setState(() {
            // Nilai 'kelembaban' dari Firebase (misal: 2539) perlu dikonversi
            // ke persentase agar lebih mudah dibaca. Kita buat asumsi
            // sensor bekerja dari 4095 (kering) ke sekitar 1000 (sangat basah).
            _kelembaban = _convertKelembabanToPercentage(
              mapData['kelembaban'] ?? 0,
            );
            _statusPenyiraman = mapData['status_penyiraman'] ?? 'OFF';
            _timestamp = mapData['timestamp'] ?? 'N/A';
          });
        }
      },
      onError: (error) {
        // Handle jika terjadi error (misal: masalah koneksi atau permission)
        print("Error listening to Firebase: $error");
      },
    );
  }

  // Helper function untuk konversi nilai sensor kelembaban ke persentase
  // Anda bisa menyesuaikan nilai MIN dan MAX sesuai dengan sensor yang dipakai
  int _convertKelembabanToPercentage(int rawValue) {
    const int SENSOR_MIN = 1000; // Nilai saat sangat basah
    const int SENSOR_MAX = 4095; // Nilai saat sangat kering (udara)

    // Memastikan nilai tidak di luar rentang
    int clampedValue = rawValue.clamp(SENSOR_MIN, SENSOR_MAX);

    // Rumus untuk membalik nilai (semakin tinggi rawValue, semakin rendah persentase)
    // dan mengubahnya ke rentang 0-100
    double percentage =
        100 - ((clampedValue - SENSOR_MIN) / (SENSOR_MAX - SENSOR_MIN) * 100);

    return percentage.toInt();
  }

  @override
  void dispose() {
    // --- PENTING: Batalkan listener saat widget tidak lagi digunakan ---
    _penyiramSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Container(height: 50, color: primaryColor),
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMoistureChartCard(),
                    const SizedBox(height: 24),
                    _buildStatusIndicators(), // Widget ini akan di-update
                    const SizedBox(height: 32),
                    _buildControlSliders(),
                    const SizedBox(height: 32),
                    _buildWaterNowButton(),
                  ],
                ),
              ),
            ),
          ),
          Container(height: 30, color: primaryColor),
        ],
      ),
    );
  }

  Widget _buildMoistureChartCard() {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: lightBlueBgColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Kelembaban Tanah',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              // Menampilkan timestamp terakhir
              Text(
                'Update: $_timestamp',
                style: TextStyle(fontSize: 12, color: Colors.grey[700]),
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(height: 180, child: LineChart(_mainChartData())),
        ],
      ),
    );
  }

  // Widget untuk indikator status baterai, air, dan pompa
  Widget _buildStatusIndicators() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        // Indikator Baterai (masih data statis)
        _buildStatusItem(
          Icons.battery_charging_full,
          'Baterai',
          '75%',
          Colors.orange,
        ),
        // --- INDIKATOR DINAMIS DARI FIREBASE ---
        _buildStatusItem(
          Icons.water_drop,
          'Kelembaban',
          '$_kelembaban%', // Menampilkan nilai kelembaban dari Firebase
          Colors.blue,
        ),
        // --- INDIKATOR DINAMIS DARI FIREBASE ---
        _buildStatusItem(
          _statusPenyiraman == "ON" ? Icons.power : Icons.power_off,
          'Status Pompa',
          _statusPenyiraman, // Menampilkan status ON/OFF
          _statusPenyiraman == "ON" ? Colors.green : Colors.red,
        ),
      ],
    );
  }

  // Helper untuk membuat satu item status
  Widget _buildStatusItem(
    IconData icon,
    String label,
    String value,
    Color iconColor,
  ) {
    return Column(
      children: [
        Icon(icon, size: 45, color: iconColor),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
          ),
        ),
      ],
    );
  }

  // Widget untuk grup slider kontrol
  Widget _buildControlSliders() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // NOTE: Untuk fungsionalitas penuh, perubahan slider ini
        // seharusnya mengirim data KEMBALI ke Firebase.
        _buildSliderRow(
          label: 'Ambang Batas Kelembaban Tanah',
          value: _moistureThreshold,
          unit: '%',
          max: 100,
          onChanged: (val) => setState(() => _moistureThreshold = val),
        ),
        const SizedBox(height: 20),
        _buildSliderRow(
          label: 'Waktu Nyala Pompa',
          value: _pumpDuration,
          unit: ' detik',
          max: 10,
          onChanged: (val) => setState(() => _pumpDuration = val),
        ),
        const SizedBox(height: 20),
        _buildSliderRow(
          label: 'Waktu Pengecekan Berkala',
          value: _checkInterval,
          unit: ' hari',
          max: 7,
          onChanged: (val) => setState(() => _checkInterval = val),
        ),
      ],
    );
  }

  // Helper untuk membuat satu baris slider
  Widget _buildSliderRow({
    required String label,
    required double value,
    required String unit,
    required double max,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: textColor,
          ),
        ),
        Row(
          children: [
            Expanded(
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  activeTrackColor: sliderActiveColor,
                  inactiveTrackColor: sliderActiveColor.withOpacity(0.3),
                  thumbColor: sliderActiveColor,
                  overlayColor: sliderActiveColor.withOpacity(0.2),
                  trackHeight: 6.0,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 12.0,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 20.0,
                  ),
                ),
                child: Slider(
                  value: value,
                  min: 0,
                  max: max,
                  divisions: max.toInt(), // Membuat slider lebih presisi
                  onChanged: onChanged,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              '${value.toInt()}$unit',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Tombol "Siram Sekarang"
  Widget _buildWaterNowButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          // AKSI: Saat ditekan, idealnya ini mengirim perintah ke Firebase
          // Contoh: _databaseReference.update({'perintah_siram': 'ON'});
          print('Tombol Siram Sekarang ditekan!');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Perintah menyiram dikirim...')),
          );
        },
        child: Container(
          width: 250,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: LinearGradient(
              colors: [Colors.lightBlue.shade300, Colors.lightBlue.shade500],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.blue.withOpacity(0.3),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'Siram Sekarang',
              style: TextStyle(
                fontSize: 18,
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Data untuk Line Chart
  // NOTE: Chart ini masih menggunakan data statis. Untuk membuatnya dinamis,
  // Anda perlu menyimpan histori data kelembaban di Firebase (misalnya dalam bentuk List).
  LineChartData _mainChartData() {
    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) {
          return const FlLine(color: Colors.white, strokeWidth: 1);
        },
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 30,
            interval: 1,
            getTitlesWidget: bottomTitleWidgets,
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 10,
            getTitlesWidget: leftTitleWidgets,
            reservedSize: 42,
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      minX: 0,
      maxX: 4,
      minY: 0,
      maxY: 40,
      lineBarsData: [
        LineChartBarData(
          spots: const [
            FlSpot(0, 18),
            FlSpot(1, 27),
            FlSpot(2, 23),
            FlSpot(3, 33),
            FlSpot(4, 34),
          ],
          isCurved: true,
          gradient: const LinearGradient(
            colors: [Colors.greenAccent, Colors.green],
          ),
          barWidth: 5,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                Colors.greenAccent.withOpacity(0.3),
                Colors.green.withOpacity(0.0),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
    );
  }

  // Widget untuk label sumbu X (Bawah) pada grafik
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Colors.black54,
    );
    Widget text;
    switch (value.toInt()) {
      case 0:
        text = const Text('06.00', style: style);
        break;
      case 1:
        text = const Text('09.00', style: style);
        break;
      case 2:
        text = const Text('12.00', style: style);
        break;
      case 3:
        text = const Text('15.00', style: style);
        break;
      case 4:
        text = const Text('18.00', style: style);
        break;
      default:
        text = const Text('', style: style);
        break;
    }

    return SideTitleWidget(child: text, meta: meta);
  }

  // Widget untuk label sumbu Y (Kiri) pada grafik
  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(
      fontWeight: FontWeight.bold,
      fontSize: 12,
      color: Colors.black54,
    );
    String text;
    if (value.toInt() % 10 == 0 && value.toInt() <= 40) {
      text = '${value.toInt()}%';
    } else {
      return Container();
    }

    return Text(text, style: style, textAlign: TextAlign.left);
  }
}
