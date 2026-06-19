import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../core/network/providers.dart';
import '../../l10n/app_localizations.dart';


/// Qassob capacity calendar (F8). TableCalendar with per-day "X/Y" badges.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});
  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}


class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  DateTime _focused = DateTime.now();
  DateTime? _selected;
  Map<String, dynamic> _days = {};
  int _capacity = 10;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, 1);
    final to = DateTime(now.year, now.month + 2, 0);
    try {
      final r = await ref.read(apiClientProvider).dio.get(
        '/partner/qassob/calendar/?from=${_fmt(from)}&to=${_fmt(to)}');
      final m = r.data as Map;
      setState(() {
        _capacity = (m['daily_capacity_head'] as num?)?.toInt() ?? 10;
        _days = Map<String, dynamic>.from(m['days'] as Map);
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  String _fmt(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
                              '${d.month.toString().padLeft(2, '0')}-'
                              '${d.day.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    if (_loading) return const Center(child: CircularProgressIndicator());
    return RefreshIndicator(onRefresh: _load,
      child: ListView(children: [
        Padding(padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
          child: Text(t.scheduleTitle,
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w800))),
        TableCalendar(
          firstDay: DateTime.now().subtract(const Duration(days: 30)),
          lastDay: DateTime.now().add(const Duration(days: 90)),
          focusedDay: _focused,
          selectedDayPredicate: (d) => _selected != null
              && d.year == _selected!.year && d.month == _selected!.month
              && d.day == _selected!.day,
          onDaySelected: (selected, focused) {
            setState(() { _selected = selected; _focused = focused; });
          },
          calendarBuilders: CalendarBuilders(
            markerBuilder: (ctx, day, _) {
              final stats = _days[_fmt(day)] as Map?;
              if (stats == null) return null;
              final booked = stats['booked'] as int;
              return Positioned(bottom: 2,
                child: Text('$booked/$_capacity',
                  style: tt.labelSmall?.copyWith(
                      color: booked >= _capacity ? cs.error : cs.onSurfaceVariant,
                      fontSize: 10)));
            },
          ),
        ),
      ]));
  }
}
