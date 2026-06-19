import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// F3 — Daromad tab. Period tabs + line chart + breakdown rows + PDF export trigger (F10).
class EarningsScreen extends ConsumerStatefulWidget {
  const EarningsScreen({super.key});
  @override
  ConsumerState<EarningsScreen> createState() => _EarningsScreenState();
}


class _EarningsScreenState extends ConsumerState<EarningsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() { _tabCtrl.dispose(); super.dispose(); }

  String get _period {
    switch (_tabCtrl.index) {
      case 1: return 'week';
      case 2: return 'month';
      default: return 'day';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await ref.read(apiClientProvider).dio.get(
        '/partner/earnings/?period=$_period');
      setState(() { _data = Map<String, dynamic>.from(r.data as Map); _loading = false; });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(children: [
      TabBar(controller: _tabCtrl, tabs: [
        Tab(text: t.earningsPeriodDay),
        Tab(text: t.earningsPeriodWeek),
        Tab(text: t.earningsPeriodMonth),
      ]),
      Expanded(child: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
            if (_data != null) ...[
              Text(t.earningsTotalLabel,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(height: 4),
              Text('${_data!['total_revenue']} so\'m',
                  style: tt.displaySmall?.copyWith(
                      color: cs.primary, fontWeight: FontWeight.w900)),
              const SizedBox(height: 18),
              SizedBox(height: 180, child: _Chart(
                chartData: ((_data!['chart'] as List?) ?? [])
                            .cast<Map<String, dynamic>>())),
              const SizedBox(height: 18),
              _Row(label: t.earningsOrdersLabel, value: '${_data!['order_count']}'),
              _Row(label: t.earningsAvgTicketLabel, value: '${_data!['avg_ticket']} so\'m'),
              if (_data!['top_product'] != null)
                _Row(label: t.earningsTopProductLabel, value: '${_data!['top_product']}'),
              const SizedBox(height: 24),
              OutlinedButton.icon(onPressed: () {},
                icon: const Icon(Icons.picture_as_pdf_rounded),
                label: Text(t.earningsExportPdf)),
            ],
          ])),
    ]);
  }
}


class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Padding(padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(children: [
        Expanded(child: Text(label,
            style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant))),
        Text(value, style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
      ]));
  }
}


class _Chart extends StatelessWidget {
  final List<Map<String, dynamic>> chartData;
  const _Chart({required this.chartData});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    if (chartData.isEmpty) return Center(child: Text('—',
        style: TextStyle(color: cs.onSurfaceVariant)));
    final spots = <FlSpot>[];
    for (var i = 0; i < chartData.length; i++) {
      final v = double.tryParse(chartData[i]['value']?.toString() ?? '') ?? 0;
      spots.add(FlSpot(i.toDouble(), v));
    }
    return LineChart(LineChartData(
      gridData: const FlGridData(show: false),
      titlesData: const FlTitlesData(show: false),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(
        spots: spots,
        isCurved: true,
        color: cs.primary,
        barWidth: 3,
        belowBarData: BarAreaData(show: true,
            color: cs.primary.withValues(alpha: 0.15)),
        dotData: const FlDotData(show: false),
      )],
    ));
  }
}
