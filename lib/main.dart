import 'dart:collection';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:penyiraman_otomatis/firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const PenyiramApp());
}

class PenyiramApp extends StatelessWidget {
  const PenyiramApp({super.key});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
      useMaterial3: true,
    );
    return MaterialApp(
      title: 'Smart Garden UI',
      theme: baseTheme.copyWith(
        textTheme: baseTheme.textTheme.apply(fontFamily: 'Roboto'),
        cardTheme: const CardThemeData(
          elevation: 1.5,
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
        ),
      ),
      home: const PenyiramScreen(),
      debugShowCheckedModeBanner: false,
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

  // State data
  int _kelembaban = 0; // %
  String _statusPenyiraman = 'OFF';
  String _timestamp = 'N/A';
  double _moistureThreshold = 50; // %
  String _mode = 'otomatis';
  String _statusButton = 'OFF';

  // History (terbatas agar ringan)
  final Queue<FlSpot> _history = ListQueue();
  static const int _maxHistory = 60; // ~1 menit jika update /s

  // Trend
  double? _prevValue;

  @override
  void initState() {
    super.initState();
    _penyiramRef = FirebaseDatabase.instance.ref('penyiram');
    _penyiramStream = _penyiramRef.onValue;
    _listenToData();
  }

  void _listenToData() {
    _penyiramStream?.listen((event) {
      final data = event.snapshot.value;
      if (data == null || data is! Map) return;
      final mapData = Map<String, dynamic>.from(data as Map);

      final kelembabanRaw = mapData['kelembaban'] ?? 0;
      final thresholdRaw = mapData['threshold'] ?? 0;

      final kelembaban = _convertKelembabanToPercentage(kelembabanRaw);
      final thresholdPct =
          _convertKelembabanToPercentage(thresholdRaw).toDouble();

      setState(() {
        _prevValue = _kelembaban.toDouble();
        _kelembaban = kelembaban;
        _statusPenyiraman = mapData['status_penyiraman'] ?? 'OFF';
        _timestamp = mapData['timestamp'] ?? 'N/A';
        _moistureThreshold = thresholdPct;
        _mode = mapData['mode'] ?? 'otomatis';
        _statusButton = mapData['status_button'] ?? 'OFF';

        // Update history
        final nextX = _history.isEmpty ? 0.0 : (_history.last.x + 1);
        _history.add(FlSpot(nextX, _kelembaban.toDouble()));
        while (_history.length > _maxHistory) {
          _history.removeFirst();
        }
      });
    });
  }

  // 🔧 Konversi kelembaban (raw sensor → persen)
  int _convertKelembabanToPercentage(int rawValue) {
    const int maxValue = 4095; // ADC ESP32 max
    final percentage = 100 - ((rawValue * 100) ~/ maxValue);
    return percentage.clamp(0, 100);
  }

  // 🔧 Konversi persen → raw sensor (buat threshold)
  int _convertPercentageToRaw(double percentage) {
    const int maxValue = 4095;
    return ((100 - percentage) * maxValue ~/ 100).toInt();
  }

  Future<void> _updateThreshold(double value) async {
    final rawValue = _convertPercentageToRaw(value);
    await _penyiramRef.update({'threshold': rawValue});
  }

  Future<void> _updateMode(String mode) async {
    await _penyiramRef.update({'mode': mode});
  }

  Future<void> _updateStatusButton(String status) async {
    await _penyiramRef.update({'status_button': status});
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDry = _kelembaban < _moistureThreshold;
    final isPumping = _statusPenyiraman == 'ON';
    final trend = _computeTrend();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Penyiram Tanaman Otomatis'),
        actions: [
          IconButton(
            tooltip: 'Segarkan dari Cloud',
            onPressed: () => _penyiramRef.keepSynced(true),
            icon: const Icon(Icons.cloud_sync_outlined),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ========= HERO STATS (responsive) =========
                // ========= HERO STATS (responsive, tanpa Expanded di Column) =========
                LayoutBuilder(
                  builder: (context, cons) {
                    final isNarrow = cons.maxWidth < 560; // breakpoint

                    final leftCard = _MetricCard(
                      title: 'Kelembaban',
                      subtitle: 'Terukur saat ini',
                      value: '${_kelembaban}%',
                      progress: _kelembaban / 100,
                      accent: isDry ? cs.error : cs.primary,
                      trailing: _TrendChip(trend: trend),
                    );

                    final rightCard = _MetricCard(
                      title: 'Threshold',
                      subtitle: 'Batas penyiraman',
                      value: '${_moistureThreshold.toInt()}%',
                      progress: _moistureThreshold / 100,
                      accent: cs.tertiary,
                      trailing: _StatusChip(
                        label: _mode == 'otomatis' ? 'Otomatis' : 'Manual',
                        icon:
                            _mode == 'otomatis'
                                ? Icons.autorenew
                                : Icons.touch_app,
                        color: _mode == 'otomatis' ? cs.primary : cs.secondary,
                      ),
                    );

                    if (isNarrow) {
                      // >>> Column TIDAK BOLEH berisi Expanded saat di dalam ScrollView
                      return Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          leftCard,
                          const SizedBox(height: 12),
                          rightCard,
                        ],
                      );
                    } else {
                      // >>> Row boleh pakai Expanded karena arahnya horizontal (lebar bounded)
                      return Row(
                        children: [
                          Expanded(child: leftCard),
                          const SizedBox(width: 12),
                          Expanded(child: rightCard),
                        ],
                      );
                    }
                  },
                ),
                const SizedBox(height: 12),

                // ========= STATUS BAR =========
                _StatusBar(
                  timestamp: _timestamp,
                  pumpOn: isPumping,
                  mode: _mode,
                  statusButton: _statusButton,
                ),
                const SizedBox(height: 12),

                // ========= CHART =========
                _ChartCard(
                  history: _history.toList(growable: false),
                  threshold: _moistureThreshold,
                ),
                const SizedBox(height: 20),

                // ========= CONTROLS =========
                _ControlsCard(
                  mode: _mode,
                  onModeChanged: (m) async {
                    setState(() => _mode = m);
                    await _updateMode(m);
                  },
                  threshold: _moistureThreshold,
                  onThresholdChanged:
                      (v) => setState(() => _moistureThreshold = v),
                  onThresholdChangeEnd: (v) => _updateThreshold(v),
                  statusButton: _statusButton,
                  onManualSwitch: (on) {
                    final newStatus = on ? 'ON' : 'OFF';
                    setState(() => _statusButton = newStatus);
                    _updateStatusButton(newStatus);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int _computeTrend() {
    if (_prevValue == null) return 0; // 0: flat, -1: down, +1: up
    final diff = _kelembaban - _prevValue!;
    if (diff.abs() <= 0.5) return 0;
    return diff > 0 ? 1 : -1;
  }
}

// =================== WIDGETS ===================

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.progress,
    required this.accent,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final String value;
  final double progress;
  final Color accent;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, cons) {
        final isTight = cons.maxWidth < 320;
        final ringSize = isTight ? 52.0 : 64.0;

        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // progress ring
                SizedBox(
                  width: ringSize,
                  height: ringSize,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CircularProgressIndicator(
                        value: progress.clamp(0, 1),
                        strokeWidth: isTight ? 6 : 8,
                        color: accent,
                        backgroundColor: cs.surfaceVariant,
                      ),
                      Text(
                        value,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // teks utama: bisa mengambil sisa ruang
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                // trailing: jangan paksa lebar, scale down jika sempit
                if (trailing != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: trailing!,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({
    required this.timestamp,
    required this.pumpOn,
    required this.mode,
    required this.statusButton,
  });

  final String timestamp;
  final bool pumpOn;
  final String mode;
  final String statusButton;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: LayoutBuilder(
          builder: (context, cons) {
            final isNarrow = cons.maxWidth < 480;
            return isNarrow
                ? Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    _StatusChip(
                      label: pumpOn ? 'Pompa: ON' : 'Pompa: OFF',
                      icon: pumpOn ? Icons.water : Icons.water_drop_outlined,
                      color: pumpOn ? cs.primary : cs.error,
                    ),
                    _StatusChip(
                      label:
                          mode == 'otomatis' ? 'Mode Otomatis' : 'Mode Manual',
                      icon:
                          mode == 'otomatis'
                              ? Icons.autorenew
                              : Icons.touch_app,
                      color: mode == 'otomatis' ? cs.primary : cs.secondary,
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.schedule,
                          size: 18,
                          color: cs.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Update: $timestamp',
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ],
                )
                : Row(
                  children: [
                    _StatusChip(
                      label: pumpOn ? 'Pompa: ON' : 'Pompa: OFF',
                      icon: pumpOn ? Icons.water : Icons.water_drop_outlined,
                      color: pumpOn ? cs.primary : cs.error,
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(
                      label:
                          mode == 'otomatis' ? 'Mode Otomatis' : 'Mode Manual',
                      icon:
                          mode == 'otomatis'
                              ? Icons.autorenew
                              : Icons.touch_app,
                      color: mode == 'otomatis' ? cs.primary : cs.secondary,
                    ),
                    const Spacer(),
                    Icon(Icons.schedule, size: 18, color: cs.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Update: $timestamp',
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                );
          },
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.icon,
    required this.color,
  });
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: color.withOpacity(0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(color: cs.onSurface),
          ),
        ],
      ),
    );
  }
}

class _TrendChip extends StatelessWidget {
  const _TrendChip({required this.trend});
  final int trend; // -1, 0, +1

  @override
  Widget build(BuildContext context) {
    final map = {
      -1: ('Turun', Icons.south_east, Colors.blueGrey),
      0: ('Stabil', Icons.remove_rounded, Colors.grey),
      1: ('Naik', Icons.north_east, Colors.green),
    };
    final (label, icon, color) = map[trend]!;
    return _StatusChip(label: 'Trend $label', icon: icon, color: color);
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.history, required this.threshold});
  final List<FlSpot> history;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header pakai Wrap agar tidak overflow
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  'Grafik Kelembaban Tanah',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: cs.primaryContainer,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Live',
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                ),
                _LegendDot(color: cs.primary, label: 'Kelembaban'),
                const SizedBox(width: 12),
                _LegendDot(color: cs.error, label: 'Threshold'),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 220,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 100,
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine:
                        (v) =>
                            FlLine(strokeWidth: 0.6, color: cs.outlineVariant),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 34,
                        interval: 20,
                        getTitlesWidget:
                            (value, meta) => Text('${value.toInt()}%'),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        interval: (history.length / 6).clamp(1, 10).toDouble(),
                        getTitlesWidget:
                            (value, meta) => Text(
                              meta.formattedValue,
                              style: const TextStyle(fontSize: 10),
                            ),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(color: cs.outlineVariant),
                  ),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: threshold,
                        color: cs.error,
                        strokeWidth: 1.5,
                        dashArray: const [6, 6],
                        label: HorizontalLineLabel(
                          show: true,
                          alignment: Alignment.topRight,
                          style: TextStyle(
                            color: cs.error,
                            fontWeight: FontWeight.w600,
                          ),
                          labelResolver:
                              (_) => 'Threshold ${threshold.toInt()}%',
                        ),
                      ),
                    ],
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: history.isEmpty ? [const FlSpot(0, 0)] : history,
                      isCurved: true,
                      barWidth: 3,
                      color: cs.primary,
                      dotData: FlDotData(
                        show: true,
                        getDotPainter: (s, p, b, i) {
                          final isLast =
                              history.isNotEmpty && s == history.last;
                          return FlDotCirclePainter(
                            radius: isLast ? 3.6 : 0,
                            strokeWidth: 1.2,
                            color: cs.primary,
                            strokeColor: Colors.white,
                          );
                        },
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        gradient: LinearGradient(
                          colors: [
                            cs.primary.withOpacity(0.25),
                            Colors.transparent,
                          ],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _ControlsCard extends StatelessWidget {
  const _ControlsCard({
    required this.mode,
    required this.onModeChanged,
    required this.threshold,
    required this.onThresholdChanged,
    required this.onThresholdChangeEnd,
    required this.statusButton,
    required this.onManualSwitch,
  });

  final String mode;
  final ValueChanged<String> onModeChanged;
  final double threshold;
  final ValueChanged<double> onThresholdChanged;
  final ValueChanged<double> onThresholdChangeEnd;
  final String statusButton;
  final ValueChanged<bool> onManualSwitch;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kontrol', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),

            // Mode segmented (Wrap agar tidak overflow)
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _Segmented(
                  value: mode,
                  onChanged: onModeChanged,
                  items: const [
                    ('otomatis', Icons.autorenew, 'Otomatis'),
                    ('manual', Icons.touch_app, 'Manual'),
                  ],
                ),
                if (mode == 'manual')
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(width: 8),
                      const Text('Pompa'),
                      Switch(
                        value: statusButton == 'ON',
                        onChanged: onManualSwitch,
                      ),
                    ],
                  ),
              ],
            ),

            const SizedBox(height: 16),
            Text(
              'Threshold (${threshold.toInt()}%)',
              style: Theme.of(context).textTheme.labelLarge,
            ),
            Slider(
              value: threshold,
              min: 0,
              max: 100,
              divisions: 100,
              label: '${threshold.toInt()}%',
              onChanged: onThresholdChanged,
              onChangeEnd: onThresholdChangeEnd,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text('0%'),
                Text('25%'),
                Text('50%'),
                Text('75%'),
                Text('100%'),
              ],
            ),

            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.surfaceVariant.withOpacity(0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: cs.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Jika kelembaban turun di bawah threshold dan mode Otomatis aktif, pompa akan menyala.',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.value,
    required this.onChanged,
    required this.items,
  });

  final String value;
  final ValueChanged<String> onChanged;
  final List<(String, IconData, String)> items;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children:
          items.map((it) {
            final (val, icon, label) = it;
            final selected = value == val;
            return InkWell(
              borderRadius: BorderRadius.circular(100),
              onTap: () => onChanged(val),
              child: Container(
                constraints: const BoxConstraints(minHeight: 36),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: selected ? cs.primary.withOpacity(0.12) : cs.surface,
                  border: Border.all(
                    color: selected ? cs.primary : cs.outlineVariant,
                  ),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 16,
                      color: selected ? cs.primary : cs.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 140),
                      child: Text(
                        label,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: selected ? cs.primary : cs.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
    );
  }
}
