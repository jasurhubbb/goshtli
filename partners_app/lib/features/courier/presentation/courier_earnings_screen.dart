import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/format.dart';
import '../data/courier_models.dart';
import '../providers/courier_providers.dart';


/// Earnings tab — period picker (Kun / Hafta / Oy) + big totals + fl_chart trend line.
///
/// Reuses the /couriers/me/earnings/?period=... endpoint. The line chart uses `earnings_uzs` per
/// point and the day count under it. We render the totals big so the courier can glance-check
/// their week without doing math.
class CourierEarningsScreen extends ConsumerStatefulWidget {
  const CourierEarningsScreen({super.key});
  @override
  ConsumerState<CourierEarningsScreen> createState() => _CourierEarningsScreenState();
}

class _CourierEarningsScreenState extends ConsumerState<CourierEarningsScreen> {
  String _period = 'week';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final async = ref.watch(earningsProvider(_period));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(earningsProvider(_period)),
      child: ListView(padding: const EdgeInsets.all(16), children: [
        _PeriodTabs(period: _period, onChanged: (p) => setState(() => _period = p)),
        const SizedBox(height: 16),
        async.when(
          loading: () => const SizedBox(height: 280,
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Padding(padding: const EdgeInsets.all(24),
              child: Center(child: Text(e.toString(), style: TextStyle(color: cs.error)))),
          data: (r) => r == null ? const SizedBox.shrink() : _EarningsBody(result: r),
        ),
      ]),
    );
  }
}


class _PeriodTabs extends StatelessWidget {
  final String period;
  final ValueChanged<String> onChanged;
  const _PeriodTabs({required this.period, required this.onChanged});

  static const _opts = [('day', 'Kun'), ('week', 'Hafta'), ('month', 'Oy')];

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: cs.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999)),
      child: Row(children: _opts.map((o) {
        final selected = period == o.$1;
        return Expanded(child: GestureDetector(onTap: () => onChanged(o.$1),
          child: AnimatedContainer(duration: const Duration(milliseconds: 220),
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
                color: selected ? cs.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(999)),
            child: Center(child: Text(o.$2, style: TextStyle(
                color: selected ? cs.onPrimary : cs.onSurface,
                fontWeight: FontWeight.w800))))));
      }).toList()));
  }
}


class _EarningsBody extends StatelessWidget {
  final EarningsResult result;
  const _EarningsBody({required this.result});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final avgPerDelivery = result.totalDeliveries > 0
        ? result.totalEarningsUzs ~/ result.totalDeliveries
        : 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [cs.primary.withValues(alpha: 0.14),
                          cs.primary.withValues(alpha: 0.04)]),
            borderRadius: BorderRadius.circular(20)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Jami daromad', style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text("${formatSoum(result.totalEarningsUzs)} so'm",
              style: tt.displayMedium?.copyWith(color: cs.primary,
                  fontWeight: FontWeight.w900, letterSpacing: -1)),
          const SizedBox(height: 4),
          Text('${result.totalDeliveries} ta yetkazish',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ])),
      const SizedBox(height: 16),
      // Chart card — hides if the whole period is zero so we don't render a flat line at 0.
      if (result.series.isNotEmpty && result.totalEarningsUzs > 0)
        Container(padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
          decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: cs.outlineVariant)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Padding(padding: const EdgeInsets.only(left: 6),
              child: Text('Trend', style: tt.titleSmall?.copyWith(
                  color: cs.onSurfaceVariant, fontWeight: FontWeight.w800))),
            const SizedBox(height: 6),
            SizedBox(height: 200, child: _EarningsChart(series: result.series)),
          ])),
      const SizedBox(height: 16),
      // Row of KPI tiles beneath the chart — average per delivery, count, sample rate.
      Row(children: [
        Expanded(child: _StatTile(label: 'Bitta yetkazish uchun o\'rtacha',
            value: "${formatSoum(avgPerDelivery)} so'm",
            color: const Color(0xFF0D47A1))),
        const SizedBox(width: 12),
        Expanded(child: _StatTile(label: 'Yetkazishlar', value: '${result.totalDeliveries}',
            color: const Color(0xFFEF6C00))),
      ]),
      const SizedBox(height: 24),
      Text('Kunlar bo\'yicha', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w800)),
      const SizedBox(height: 8),
      Container(decoration: BoxDecoration(color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: cs.outlineVariant)),
        child: Column(children: result.series.reversed.map((p) =>
          Padding(padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Expanded(child: Text(p.date, style: tt.bodyMedium)),
              Text('${p.deliveries} ta',
                  style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
              const SizedBox(width: 14),
              Text("${formatSoum(p.earningsUzs)} so'm", style: tt.bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w800, color: cs.primary)),
            ]))).toList())),
    ]);
  }
}


class _StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatTile({required this.label, required this.value, required this.color});
  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.20))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: tt.labelSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: tt.titleMedium?.copyWith(
            color: color, fontWeight: FontWeight.w900)),
      ]));
  }
}


class _EarningsChart extends StatelessWidget {
  final List<EarningsSeriesPoint> series;
  const _EarningsChart({required this.series});
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final maxY = series.map((p) => p.earningsUzs).fold<int>(0, (a, b) => a > b ? a : b);
    final safeMaxY = maxY > 0 ? maxY.toDouble() * 1.15 : 100.0;
    return LineChart(LineChartData(
      minY: 0, maxY: safeMaxY,
      gridData: FlGridData(show: true, drawVerticalLine: false,
          getDrawingHorizontalLine: (_) =>
              FlLine(color: cs.outlineVariant, strokeWidth: 0.5)),
      titlesData: FlTitlesData(
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            reservedSize: 24, interval: (series.length / 4).ceilToDouble().clamp(1, 999),
            getTitlesWidget: (v, _) {
              final i = v.toInt();
              if (i < 0 || i >= series.length) return const SizedBox.shrink();
              final s = series[i].date;
              final short = s.length >= 5 ? s.substring(s.length - 5) : s;
              return Text(short, style: TextStyle(fontSize: 10,
                  color: cs.onSurfaceVariant));
            })),
        leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true,
            reservedSize: 46,
            getTitlesWidget: (v, _) => Text(_shortNumber(v.toInt()),
                style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)))),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [LineChartBarData(
        spots: [for (int i = 0; i < series.length; i++)
                FlSpot(i.toDouble(), series[i].earningsUzs.toDouble())],
        isCurved: true, curveSmoothness: 0.28,
        color: cs.primary, barWidth: 3,
        dotData: const FlDotData(show: false),
        belowBarData: BarAreaData(show: true,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [cs.primary.withValues(alpha: 0.30),
                          cs.primary.withValues(alpha: 0.02)])),
      )],
    ));
  }

  String _shortNumber(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000)    return '${(v / 1000).toStringAsFixed(0)}k';
    return '$v';
  }
}
