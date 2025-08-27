// import 'package:flutter/material.dart';
// import 'package:fl_chart/fl_chart.dart';
// import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
// import 'package:firebase_database/firebase_database.dart'; // Import Firebase Realtime Database
// import 'dart:async';

// import 'package:penyiraman_otomatis/firebase_options.dart'; // Sesuaikan dengan path file Anda

// // Definisikan palet warna agar mudah diubah
// const Color primaryColor = Color(0xFF0A686A);
// const Color lightBlueBgColor = Color(0xFFE3F2FD);
// const Color sliderActiveColor = Color(0xFF29B6F6);
// const Color textColor = Color(0xFF333333);

// // --- KONSTANTA UNTUK KONVERSI SENSOR ---
// const int SENSOR_MIN = 1000; // Nilai saat sangat basah
// const int SENSOR_MAX = 4095; // Nilai saat sangat kering (udara)

// // MAIN FUNCTION - Modifikasi untuk inisialisasi Firebase
// void main() async {
//   // Pastikan Flutter binding sudah siap sebelum inisialisasi Firebase
//   WidgetsFlutterBinding.ensureInitialized();
//   // Inisialisasi Firebase
//   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
//   runApp(const MyApp());
// }

// class MyApp extends StatelessWidget {
//   const MyApp({super.key});

//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       title: 'Smart Garden UI',
//       theme: ThemeData(
//         primaryColor: primaryColor,
//         scaffoldBackgroundColor: Colors.grey[100],
//         fontFamily: 'Poppins',
//       ),
//       home: const HomeScreen(),
//       debugShowCheckedModeBanner: false,
//     );
//   }
// }

// class HomeScreen extends StatefulWidget {
//   const HomeScreen({super.key});

//   @override
//   State<HomeScreen> createState() => _HomeScreenState();
// }

// class _HomeScreenState extends State<HomeScreen> {
//   // Nilai awal untuk UI (akan segera ditimpa oleh data Firebase)
//   double _moistureThreshold = 20.0;
//   double _pumpDuration = 5.0;
//   double _checkInterval = 10.0;

//   // --- STATE BARU UNTUK DATA FIREBASE ---
//   int _kelembaban = 0; // Untuk menyimpan nilai kelembaban
//   String _statusPenyiraman = "OFF"; // Untuk menyimpan status pompa
//   String _timestamp = "00:00:00"; // Untuk menyimpan timestamp

//   // Referensi ke Firebase
//   late DatabaseReference _statusRef;
//   late DatabaseReference _kontrolRef;
//   StreamSubscription<DatabaseEvent>? _statusSubscription;
//   StreamSubscription<DatabaseEvent>? _kontrolSubscription;

//   @override
//   void initState() {
//     super.initState();
//     // Inisialisasi referensi ke node 'status' dan 'kontrol' di Firebase
//     _statusRef = FirebaseDatabase.instance.ref('penyiram/status_penyiraman');
//     _kontrolRef = FirebaseDatabase.instance.ref('penyiram/kontrol');

//     // Mulai mendengarkan perubahan data pada kedua node
//     _listenToStatusData();
//     _listenToKontrolData();
//   }

//   // Fungsi untuk mendengarkan data dari node 'status'
//   void _listenToStatusData() {
//     _statusSubscription = _statusRef.onValue.listen(
//       (event) {
//         final data = event.snapshot.value;
//         if (data != null && data is Map) {
//           final mapData = Map<String, dynamic>.from(data);
//           setState(() {
//             _kelembaban = _convertKelembabanToPercentage(
//               mapData['kelembaban'] ?? 0,
//             );
//             _statusPenyiraman = mapData['status_penyiraman'] ?? 'OFF';
//             _timestamp = mapData['timestamp'] ?? 'N/A';
//           });
//         }
//       },
//       onError: (error) {
//         print("Error listening to status: $error");
//       },
//     );
//   }

//   // Fungsi untuk mendengarkan data dari node 'kontrol'
//   void _listenToKontrolData() {
//     _kontrolSubscription = _kontrolRef.onValue.listen(
//       (event) {
//         final data = event.snapshot.value;
//         if (data != null && data is Map) {
//           final mapData = Map<String, dynamic>.from(data);
//           setState(() {
//             // Konversi nilai mentah 'threshold' dari Firebase ke persentase untuk slider
//             _moistureThreshold =
//                 _convertKelembabanToPercentage(
//                   mapData['threshold'] ?? 0,
//                 ).toDouble();
//             // Konversi milidetik ke detik untuk slider
//             _pumpDuration = (mapData['durasi_nyala_pompa'] ?? 0) / 1000.0;
//             _checkInterval = (mapData['interval_pengecekan'] ?? 0) / 1000.0;
//           });
//         }
//       },
//       onError: (error) {
//         print("Error listening to kontrol: $error");
//       },
//     );
//   }

//   // --- HELPER FUNCTIONS UNTUK KONVERSI ---

//   // Konversi nilai sensor mentah ke persentase (0-100%)
//   int _convertKelembabanToPercentage(int rawValue) {
//     int clampedValue = rawValue.clamp(SENSOR_MIN, SENSOR_MAX);
//     double percentage =
//         100 - ((clampedValue - SENSOR_MIN) / (SENSOR_MAX - SENSOR_MIN) * 100);
//     return percentage.round();
//   }

//   // Konversi persentase dari slider ke nilai sensor mentah
//   int _convertPercentageToRaw(double percentage) {
//     double clampedPercentage = percentage.clamp(0.0, 100.0);
//     double rawValue =
//         SENSOR_MAX - (clampedPercentage / 100 * (SENSOR_MAX - SENSOR_MIN));
//     return rawValue.round();
//   }

//   @override
//   void dispose() {
//     // Batalkan semua listener saat widget tidak lagi digunakan
//     _statusSubscription?.cancel();
//     _kontrolSubscription?.cancel();
//     super.dispose();
//   }

//   // --- FUNGSI UNTUK MENGIRIM DATA KE FIREBASE ---

//   void _updateThreshold(double value) {
//     int rawValue = _convertPercentageToRaw(value);
//     _kontrolRef
//         .update({'threshold': rawValue})
//         .then((_) {
//           print('Threshold updated to: $rawValue');
//         })
//         .catchError((error) {
//           print('Failed to update threshold: $error');
//         });
//   }

//   void _updatePumpDuration(double value) {
//     int milliseconds = (value * 1000).toInt();
//     _kontrolRef
//         .update({'durasi_nyala_pompa': milliseconds})
//         .then((_) {
//           print('Pump duration updated to: $milliseconds ms');
//         })
//         .catchError((error) {
//           print('Failed to update pump duration: $error');
//         });
//   }

//   void _updateCheckInterval(double value) {
//     int milliseconds = (value * 1000).toInt();
//     _kontrolRef
//         .update({'interval_pengecekan': milliseconds})
//         .then((_) {
//           print('Check interval updated to: $milliseconds ms');
//         })
//         .catchError((error) {
//           print('Failed to update check interval: $error');
//         });
//   }

//   void _kirimPerintahSiram() {
//     _kontrolRef
//         .update({'perintah': 'ON'})
//         .then((_) {
//           print('Perintah SIRAM ON terkirim!');
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('Perintah menyiram dikirim...')),
//           );
//         })
//         .catchError((error) {
//           print('Gagal mengirim perintah: $error');
//           ScaffoldMessenger.of(context).showSnackBar(
//             SnackBar(content: Text('Gagal mengirim perintah: $error')),
//           );
//         });
//   }

//   @override
//   Widget build(BuildContext context) {
//     // (Struktur build widget tetap sama, tidak perlu diubah)
//     return Scaffold(
//       body: Column(
//         children: [
//           Container(height: 50, color: primaryColor),
//           Expanded(
//             child: SingleChildScrollView(
//               child: Padding(
//                 padding: const EdgeInsets.all(16.0),
//                 child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.stretch,
//                   children: [
//                     _buildMoistureChartCard(),
//                     const SizedBox(height: 24),
//                     _buildStatusIndicators(), // Widget ini akan di-update
//                     const SizedBox(height: 32),
//                     _buildControlSliders(),
//                     const SizedBox(height: 32),
//                     _buildWaterNowButton(),
//                   ],
//                 ),
//               ),
//             ),
//           ),
//           Container(height: 30, color: primaryColor),
//         ],
//       ),
//     );
//   }

//   Widget _buildMoistureChartCard() {
//     return Container(
//       padding: const EdgeInsets.all(16.0),
//       decoration: BoxDecoration(
//         color: lightBlueBgColor,
//         borderRadius: BorderRadius.circular(12),
//         boxShadow: [
//           BoxShadow(
//             color: Colors.black.withOpacity(0.1),
//             spreadRadius: 1,
//             blurRadius: 5,
//             offset: const Offset(0, 3),
//           ),
//         ],
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Row(
//             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//             children: [
//               const Text(
//                 'Kelembaban Tanah',
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.bold,
//                   color: textColor,
//                 ),
//               ),
//               // Menampilkan timestamp terakhir
//               Text(
//                 'Update: $_timestamp',
//                 style: TextStyle(fontSize: 12, color: Colors.grey[700]),
//               ),
//             ],
//           ),
//           const SizedBox(height: 20),
//           SizedBox(height: 180, child: LineChart(_mainChartData())),
//         ],
//       ),
//     );
//   }

//   // Widget untuk indikator status baterai, air, dan pompa
//   Widget _buildStatusIndicators() {
//     return Row(
//       mainAxisAlignment: MainAxisAlignment.spaceEvenly,
//       children: [
//         // Indikator Baterai (masih data statis)
//         _buildStatusItem(
//           Icons.battery_charging_full,
//           'Baterai',
//           '75%',
//           Colors.orange,
//         ),
//         // --- INDIKATOR DINAMIS DARI FIREBASE ---
//         _buildStatusItem(
//           Icons.water_drop,
//           'Kelembaban',
//           '$_kelembaban%', // Menampilkan nilai kelembaban dari Firebase
//           Colors.blue,
//         ),
//         // --- INDIKATOR DINAMIS DARI FIREBASE ---
//         _buildStatusItem(
//           _statusPenyiraman == "ON" ? Icons.power : Icons.power_off,
//           'Status Pompa',
//           _statusPenyiraman, // Menampilkan status ON/OFF
//           _statusPenyiraman == "ON" ? Colors.green : Colors.red,
//         ),
//       ],
//     );
//   }

//   // Helper untuk membuat satu item status
//   Widget _buildStatusItem(
//     IconData icon,
//     String label,
//     String value,
//     Color iconColor,
//   ) {
//     return Column(
//       children: [
//         Icon(icon, size: 45, color: iconColor),
//         const SizedBox(height: 8),
//         Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[700])),
//         const SizedBox(height: 4),
//         Text(
//           value,
//           style: const TextStyle(
//             fontSize: 28,
//             fontWeight: FontWeight.bold,
//             color: textColor,
//           ),
//         ),
//       ],
//     );
//   }

//   // Widget untuk grup slider kontrol
//   Widget _buildControlSliders() {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         _buildSliderRow(
//           label: 'Ambang Batas Kelembaban Tanah',
//           value: _moistureThreshold,
//           unit: '%',
//           max: 100,
//           onChanged: (val) => setState(() => _moistureThreshold = val),
//           onChangeEnd: (val) => _updateThreshold(val),
//         ),
//         const SizedBox(height: 20),
//         _buildSliderRow(
//           label: 'Waktu Nyala Pompa',
//           value: _pumpDuration,
//           unit: ' detik',
//           max: 20, // Sesuaikan max jika perlu
//           onChanged: (val) => setState(() => _pumpDuration = val),
//           onChangeEnd: (val) => _updatePumpDuration(val),
//         ),
//         const SizedBox(height: 20),
//         _buildSliderRow(
//           label: 'Waktu Pengecekan Berkala',
//           value: _checkInterval,
//           unit: ' detik', // DIUBAH DARI 'hari' MENJADI 'detik'
//           max: 60, // Sesuaikan max jika perlu
//           onChanged: (val) => setState(() => _checkInterval = val),
//           onChangeEnd: (val) => _updateCheckInterval(val),
//         ),
//       ],
//     );
//   }

//   // Helper untuk membuat satu baris slider
//   Widget _buildSliderRow({
//     required String label,
//     required double value,
//     required String unit,
//     required double max,
//     required ValueChanged<double> onChanged,
//     required ValueChanged<double> onChangeEnd, // Tambahkan callback ini
//   }) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Text(
//           label,
//           style: const TextStyle(
//             fontSize: 16,
//             fontWeight: FontWeight.w500,
//             color: textColor,
//           ),
//         ),
//         Row(
//           children: [
//             Expanded(
//               child: SliderTheme(
//                 data: SliderTheme.of(context).copyWith(
//                   activeTrackColor: sliderActiveColor,
//                   inactiveTrackColor: sliderActiveColor.withOpacity(0.3),
//                   thumbColor: sliderActiveColor,
//                   overlayColor: sliderActiveColor.withOpacity(0.2),
//                   trackHeight: 6.0,
//                   thumbShape: const RoundSliderThumbShape(
//                     enabledThumbRadius: 12.0,
//                   ),
//                   overlayShape: const RoundSliderOverlayShape(
//                     overlayRadius: 20.0,
//                   ),
//                 ),
//                 child: Slider(
//                   value: value,
//                   min: 0,
//                   max: max,
//                   divisions: max.toInt(), // Membuat slider lebih presisi
//                   onChanged: onChanged, // Untuk update UI saat digeser
//                   onChangeEnd:
//                       onChangeEnd, // Untuk kirim data ke Firebase setelah selesai
//                 ),
//               ),
//             ),
//             const SizedBox(width: 16),
//             Text(
//               '${value.toInt()}$unit',
//               style: const TextStyle(
//                 fontSize: 18,
//                 fontWeight: FontWeight.bold,
//                 color: textColor,
//               ),
//             ),
//           ],
//         ),
//       ],
//     );
//   }

//   // Tombol "Siram Sekarang"
//   Widget _buildWaterNowButton() {
//     return Center(
//       child: GestureDetector(
//         onTap: _kirimPerintahSiram, // Panggil fungsi pengirim perintah
//         child: Container(
//           width: 250,
//           padding: const EdgeInsets.symmetric(vertical: 16),
//           decoration: BoxDecoration(
//             borderRadius: BorderRadius.circular(30),
//             gradient: LinearGradient(
//               colors: [Colors.lightBlue.shade300, Colors.lightBlue.shade500],
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             boxShadow: [
//               BoxShadow(
//                 color: Colors.blue.withOpacity(0.3),
//                 spreadRadius: 2,
//                 blurRadius: 8,
//                 offset: const Offset(0, 4),
//               ),
//             ],
//           ),
//           child: const Center(
//             child: Text(
//               'Siram Sekarang',
//               style: TextStyle(
//                 fontSize: 18,
//                 color: Colors.white,
//                 fontWeight: FontWeight.bold,
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }

//   // (Bagian Chart tidak diubah, karena masih menggunakan data statis)
//   LineChartData _mainChartData() {
//     return LineChartData(
//       gridData: FlGridData(
//         show: true,
//         drawVerticalLine: false,
//         getDrawingHorizontalLine: (value) {
//           return const FlLine(color: Colors.white, strokeWidth: 1);
//         },
//       ),
//       titlesData: FlTitlesData(
//         show: true,
//         rightTitles: const AxisTitles(
//           sideTitles: SideTitles(showTitles: false),
//         ),
//         topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
//         bottomTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             reservedSize: 30,
//             interval: 1,
//             getTitlesWidget: bottomTitleWidgets,
//           ),
//         ),
//         leftTitles: AxisTitles(
//           sideTitles: SideTitles(
//             showTitles: true,
//             interval: 10,
//             getTitlesWidget: leftTitleWidgets,
//             reservedSize: 42,
//           ),
//         ),
//       ),
//       borderData: FlBorderData(show: false),
//       minX: 0,
//       maxX: 4,
//       minY: 0,
//       maxY: 40,
//       lineBarsData: [
//         LineChartBarData(
//           spots: const [
//             FlSpot(0, 18),
//             FlSpot(1, 27),
//             FlSpot(2, 23),
//             FlSpot(3, 33),
//             FlSpot(4, 34),
//           ],
//           isCurved: true,
//           gradient: const LinearGradient(
//             colors: [Colors.greenAccent, Colors.green],
//           ),
//           barWidth: 5,
//           isStrokeCapRound: true,
//           dotData: const FlDotData(show: false),
//           belowBarData: BarAreaData(
//             show: true,
//             gradient: LinearGradient(
//               colors: [
//                 Colors.greenAccent.withOpacity(0.3),
//                 Colors.green.withOpacity(0.0),
//               ],
//               begin: Alignment.topCenter,
//               end: Alignment.bottomCenter,
//             ),
//           ),
//         ),
//       ],
//     );
//   }

//   Widget bottomTitleWidgets(double value, TitleMeta meta) {
//     const style = TextStyle(
//       fontWeight: FontWeight.bold,
//       fontSize: 12,
//       color: Colors.black54,
//     );
//     Widget text;
//     switch (value.toInt()) {
//       case 0:
//         text = const Text('06.00', style: style);
//         break;
//       case 1:
//         text = const Text('09.00', style: style);
//         break;
//       case 2:
//         text = const Text('12.00', style: style);
//         break;
//       case 3:
//         text = const Text('15.00', style: style);
//         break;
//       case 4:
//         text = const Text('18.00', style: style);
//         break;
//       default:
//         text = const Text('', style: style);
//         break;
//     }
//     return SideTitleWidget(child: text, meta: meta);
//   }

//   Widget leftTitleWidgets(double value, TitleMeta meta) {
//     const style = TextStyle(
//       fontWeight: FontWeight.bold,
//       fontSize: 12,
//       color: Colors.black54,
//     );
//     String text;
//     if (value.toInt() % 10 == 0 && value.toInt() <= 40) {
//       text = '${value.toInt()}%';
//     } else {
//       return Container();
//     }
//     return Text(text, style: style, textAlign: TextAlign.left);
//   }
// }


import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const PenyiramApp());
}

class PenyiramApp extends StatelessWidget {
  const PenyiramApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Penyiram Tanaman',
      theme: ThemeData(primarySwatch: Colors.green),
      home: const PenyiramScreen(),
    );
  }
}

class PenyiramScreen extends StatefulWidget {
  const PenyiramScreen({super.key});

  @override
  State<PenyiramScreen> createState() => _PenyiramScreenState();
}

class _PenyiramScreenState extends State<PenyiramScreen> {
  late DatabaseReference _penyiramRef;
  Stream<DatabaseEvent>? _penyiramStream;

  int _kelembaban = 0;
  String _statusPenyiraman = "OFF";
  String _timestamp = "N/A";
  double _moistureThreshold = 50;
  String _mode = "otomatis";
  String _statusButton = "OFF";

  @override
  void initState() {
    super.initState();
    _penyiramRef = FirebaseDatabase.instance.ref("penyiram");
    _penyiramStream = _penyiramRef.onValue;
    _listenToData();
  }

  void _listenToData() {
    _penyiramStream?.listen((event) {
      final data = event.snapshot.value;
      if (data != null && data is Map) {
        final mapData = Map<String, dynamic>.from(data);
        setState(() {
          _kelembaban = _convertKelembabanToPercentage(mapData["kelembaban"] ?? 0);
          _statusPenyiraman = mapData["status_penyiraman"] ?? "OFF";
          _timestamp = mapData["timestamp"] ?? "N/A";
          _moistureThreshold =
              _convertKelembabanToPercentage(mapData["threshold"] ?? 0).toDouble();
          _mode = mapData["mode"] ?? "otomatis";
          _statusButton = mapData["status_button"] ?? "OFF";
        });
      }
    });
  }

  // 🔧 Konversi kelembaban (raw sensor → persen)
  int _convertKelembabanToPercentage(int rawValue) {
    int maxValue = 4095; // ADC ESP32 max
    int percentage = 100 - ((rawValue * 100) ~/ maxValue);
    return percentage.clamp(0, 100);
  }

  // 🔧 Konversi persen → raw sensor (buat threshold)
  int _convertPercentageToRaw(double percentage) {
    int maxValue = 4095;
    return ((100 - percentage) * maxValue ~/ 100).toInt();
  }

  void _updateThreshold(double value) {
    int rawValue = _convertPercentageToRaw(value);
    _penyiramRef.update({"threshold": rawValue});
  }

  void _updateMode(String mode) {
    _penyiramRef.update({"mode": mode});
  }

  void _updateStatusButton(String status) {
    _penyiramRef.update({"status_button": status});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Penyiram Tanaman Otomatis")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // 📊 Kelembaban
            Text("Kelembaban: $_kelembaban%",
                style: const TextStyle(fontSize: 20)),
            const SizedBox(height: 10),

            // ✅ Status penyiraman
            Text("Status Pompa: $_statusPenyiraman",
                style: TextStyle(
                    fontSize: 18,
                    color: _statusPenyiraman == "ON"
                        ? Colors.green
                        : Colors.red)),

            // 🕒 Timestamp
            Text("Update terakhir: $_timestamp"),

            const Divider(height: 30),

            // 🎚️ Threshold kelembaban
            Text("Threshold: ${_moistureThreshold.toInt()}%"),
            Slider(
              value: _moistureThreshold,
              min: 0,
              max: 100,
              divisions: 100,
              label: "${_moistureThreshold.toInt()}%",
              onChanged: (value) {
                setState(() => _moistureThreshold = value);
              },
              onChangeEnd: (value) {
                _updateThreshold(value);
              },
            ),

            const Divider(height: 30),

            // ⚙️ Mode kontrol
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text("Mode Kontrol:"),
                DropdownButton<String>(
                  value: _mode,
                  items: const [
                    DropdownMenuItem(
                        value: "otomatis", child: Text("Otomatis")),
                    DropdownMenuItem(value: "manual", child: Text("Manual")),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      setState(() => _mode = value);
                      _updateMode(value);
                    }
                  },
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 🖲️ Tombol manual (hanya muncul kalau mode = manual)
            if (_mode == "manual")
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Pompa Manual:"),
                  Switch(
                    value: _statusButton == "ON",
                    onChanged: (val) {
                      String newStatus = val ? "ON" : "OFF";
                      setState(() => _statusButton = newStatus);
                      _updateStatusButton(newStatus);
                    },
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
