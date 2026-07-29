import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopTherapistScheduleLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

enum _ScheduleView { calendar, list }

class TherapistSchedulePage extends StatefulWidget {
  final String therapistId;
  final bool startInListView;
  final int initialTabIndex; // 0 = today, 1 = upcoming, 2 = past

  const TherapistSchedulePage({
    super.key,
    required this.therapistId,
    this.startInListView = false,
    this.initialTabIndex = 0,
  });

  @override
  State<TherapistSchedulePage> createState() => TherapistSchedulePageState();
}

class TherapistSchedulePageState extends State<TherapistSchedulePage> {
  static final String _url = ApiConfig.flutter('screening_schedule.php');
  /*static const _url =
      'http://app-kizzu.test/growkids/flutter/screening_schedule.php';*/

  // data
  List<Map<String, dynamic>> all = [];
  bool loading = true;

  // view state
  _ScheduleView view = _ScheduleView.calendar;

  // calendar state
  DateTime currentMonth = DateTime.now();
  DateTime selectedDay = DateTime.now();

  // list state
  int tabIndex = 0; // 0 today, 1 upcoming, 2 past

  // ✅ METHOD yang HomeV2 akan panggil
  void jumpToListToday() {
    setState(() {
      view = _ScheduleView.list; // ✅ force list view
      tabIndex = 0; // ✅ today tab
    });
  }

  @override
  void initState() {
    super.initState();
    view = widget.startInListView ? _ScheduleView.list : _ScheduleView.calendar;
    tabIndex = widget.initialTabIndex.clamp(0, 2);

    _fetchSchedule();
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _fetchSchedule() async {
    try {
      final res = await http.post(
        Uri.parse(_url),
        body: {'therapist_id': widget.therapistId},
      );

      if (!mounted) return;

      if (res.statusCode != 200) {
        setState(() => loading = false);
        return;
      }

      final decoded = json.decode(res.body);
      final List data = decoded is List ? decoded : [];

      setState(() {
        all = List<Map<String, dynamic>>.from(data);
        loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  Future<void> _refresh() async {
    setState(() => loading = true);
    await _fetchSchedule();
  }

  // ========= CALENDAR derived =========

  bool _hasEvent(DateTime day) {
    return all.any((s) {
      final d = DateTime.tryParse((s['date'] ?? '').toString());
      if (d == null) return false;
      return _day(d) == _day(day);
    });
  }

  List<Map<String, dynamic>> get _selectedDayItems {
    final list = all.where((s) {
      final d = DateTime.tryParse((s['date'] ?? '').toString());
      if (d == null) return false;
      return _day(d) == _day(selectedDay);
    }).toList();

    list.sort((a, b) {
      final ta = (a['time'] ?? '').toString();
      final tb = (b['time'] ?? '').toString();
      return ta.compareTo(tb);
    });

    return list;
  }

  List<DateTime> _daysInMonth(DateTime month) {
    final last = DateTime(month.year, month.month + 1, 0);
    return List.generate(
      last.day,
      (i) => DateTime(month.year, month.month, i + 1),
    );
  }

  // ========= LIST derived =========

  List<Map<String, dynamic>> get _listFiltered {
    final today = _day(DateTime.now());

    final list = all.where((s) {
      final d = DateTime.tryParse((s['date'] ?? '').toString());
      if (d == null) return false;

      final day = _day(d);

      if (tabIndex == 0) return day == today;
      if (tabIndex == 1) return day.isAfter(today);
      return day.isBefore(today);
    }).toList();

    list.sort((a, b) {
      final da = (a['date'] ?? '').toString();
      final db = (b['date'] ?? '').toString();
      final c = da.compareTo(db);
      if (c != 0) return c;
      final ta = (a['time'] ?? '').toString();
      final tb = (b['time'] ?? '').toString();
      return ta.compareTo(tb);
    });

    return list;
  }

  // ========= UI =========

  @override
  Widget build(BuildContext context) {
    if (_useDesktopTherapistScheduleLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        leading: const BackButton(
          color: Colors.white,
        ),
        centerTitle: true,
        title: const Text(
          'Schedule',
          style: TextStyle(
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            icon: Icon(
              Icons.refresh_rounded,
              size: 2.h,
              color: Colors.white,
            ),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(18),
          children: [
            _buildViewToggle(),
            SizedBox(height: 1.h),
            if (loading) ...[
              const SizedBox(height: 60),
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 60),
            ] else ...[
              if (view == _ScheduleView.calendar)
                _buildCalendarView()
              else
                _buildListView(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final today = _day(DateTime.now());
    final todayCount = all.where((item) {
      final date = DateTime.tryParse((item['date'] ?? '').toString());
      return date != null && _day(date) == today;
    }).length;
    final upcomingCount = all.where((item) {
      final date = DateTime.tryParse((item['date'] ?? '').toString());
      return date != null && _day(date).isAfter(today);
    }).length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Schedule',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _refresh,
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1500),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 24, 28, 26),
            child: Column(
              children: [
                _desktopScheduleHero(todayCount, upcomingCount),
                const SizedBox(height: 17),
                Expanded(
                  child: loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Growkids.purpleFlo,
                          ),
                        )
                      : view == _ScheduleView.calendar
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: _desktopCalendarPanel(),
                                ),
                                const SizedBox(width: 17),
                                Expanded(
                                  flex: 4,
                                  child: _desktopDayAgenda(),
                                ),
                              ],
                            )
                          : _desktopScheduleList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopScheduleHero(int todayCount, int upcomingCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 19),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .76),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(
              Icons.calendar_month_rounded,
              color: Growkids.purpleFlo,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SCREENING APPOINTMENTS',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Therapist Schedule',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Review today’s screenings and upcoming appointments.',
                  style: TextStyle(color: Colors.white70, fontSize: 9),
                ),
              ],
            ),
          ),
          _desktopScheduleMetric('Today', todayCount),
          const SizedBox(width: 8),
          _desktopScheduleMetric('Upcoming', upcomingCount),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              children: [
                _desktopViewButton(
                  Icons.calendar_month_rounded,
                  'Calendar',
                  view == _ScheduleView.calendar,
                  () => setState(() => view = _ScheduleView.calendar),
                ),
                _desktopViewButton(
                  Icons.view_list_rounded,
                  'List',
                  view == _ScheduleView.list,
                  () => setState(() => view = _ScheduleView.list),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopScheduleMetric(String label, int value) {
    return Container(
      width: 86,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        children: [
          Text(
            '$value',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 7),
          ),
        ],
      ),
    );
  }

  Widget _desktopViewButton(
    IconData icon,
    String label,
    bool active,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: active ? Growkids.purpleFlo : Colors.white70,
            ),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: active ? Growkids.purpleFlo : Colors.white70,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopCalendarPanel() {
    final days = _daysInMonth(currentMonth);
    final firstWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday;

    return _desktopSurface(
      child: Column(
        children: [
          Row(
            children: [
              Text(
                DateFormat('MMMM yyyy').format(currentMonth),
                style: const TextStyle(
                  color: Color(0xFF30323C),
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              IconButton(
                onPressed: () => setState(() {
                  currentMonth =
                      DateTime(currentMonth.year, currentMonth.month - 1);
                }),
                icon: const Icon(Icons.chevron_left_rounded),
              ),
              IconButton(
                onPressed: () => setState(() {
                  currentMonth =
                      DateTime(currentMonth.year, currentMonth.month + 1);
                }),
                icon: const Icon(Icons.chevron_right_rounded),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              for (final day in [
                'Mon',
                'Tue',
                'Wed',
                'Thu',
                'Fri',
                'Sat',
                'Sun'
              ])
                Expanded(
                  child: Center(
                    child: Text(day, style: _DesktopScheduleText.header),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Expanded(
            child: GridView.builder(
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 7,
                crossAxisSpacing: 7,
                childAspectRatio: 1.25,
              ),
              itemCount: days.length + firstWeekday - 1,
              itemBuilder: (_, index) {
                if (index < firstWeekday - 1) return const SizedBox();
                final day = days[index - firstWeekday + 1];
                final selected = _day(day) == _day(selectedDay);
                final today = _day(day) == _day(DateTime.now());
                final dayItems = all.where((item) {
                  final date =
                      DateTime.tryParse((item['date'] ?? '').toString());
                  return date != null && _day(date) == _day(day);
                }).length;
                return InkWell(
                  onTap: () => setState(() => selectedDay = day),
                  borderRadius: BorderRadius.circular(11),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: selected
                          ? Growkids.purpleFlo
                          : today
                              ? Growkids.purpleFlo.withValues(alpha: .07)
                              : const Color(0xFFF8F9FC),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: selected
                            ? Growkids.purpleFlo
                            : const Color(0xFFE4E7ED),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${day.day}',
                          style: TextStyle(
                            color: selected
                                ? Colors.white
                                : const Color(0xFF474A55),
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const Spacer(),
                        if (dayItems > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? Colors.white.withValues(alpha: .20)
                                  : Growkids.purpleFlo.withValues(alpha: .10),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '$dayItems',
                              style: TextStyle(
                                color: selected
                                    ? Colors.white
                                    : Growkids.purpleFlo,
                                fontSize: 7,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopDayAgenda() {
    final items = _selectedDayItems;
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            DateFormat('EEEE, d MMMM').format(selectedDay),
            style: const TextStyle(
              color: Color(0xFF30323C),
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${items.length} appointment${items.length == 1 ? '' : 's'}',
            style: const TextStyle(color: Color(0xFF8B8F9C), fontSize: 8),
          ),
          const SizedBox(height: 15),
          Expanded(
            child: items.isEmpty
                ? const _DesktopScheduleEmpty(
                    text: 'No screening on this day.',
                  )
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 9),
                    itemBuilder: (_, index) =>
                        _DesktopScheduleCard(data: items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopScheduleList() {
    final items = _listFiltered;
    return _desktopSurface(
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Screening appointments',
                  style: TextStyle(
                    color: Color(0xFF30323C),
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              for (var index = 0; index < 3; index++)
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: ChoiceChip(
                    label: Text(['Today', 'Upcoming', 'Past'][index]),
                    selected: tabIndex == index,
                    onSelected: (_) => setState(() => tabIndex = index),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 15),
          Expanded(
            child: items.isEmpty
                ? const _DesktopScheduleEmpty(text: 'No schedule found.')
                : GridView.builder(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisExtent: 118,
                      crossAxisSpacing: 12,
                      mainAxisSpacing: 12,
                    ),
                    itemCount: items.length,
                    itemBuilder: (_, index) =>
                        _DesktopScheduleCard(data: items[index]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(19),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: child,
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _SegBtn(
            label: 'Calendar',
            active: view == _ScheduleView.calendar,
            icon: Icons.calendar_month_rounded,
            onTap: () => setState(() => view = _ScheduleView.calendar),
          ),
          const SizedBox(width: 6),
          _SegBtn(
            label: 'List',
            active: view == _ScheduleView.list,
            icon: Icons.view_list_rounded,
            onTap: () => setState(() => view = _ScheduleView.list),
          ),
        ],
      ),
    );
  }

  // ===== Calendar view =====

  Widget _buildCalendarView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildMonthHeader(),
        SizedBox(height: 1.h),
        _buildCalendarCard(),
        SizedBox(height: 2.h),
        Text(
          DateFormat('EEE, d MMM yyyy').format(selectedDay),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14.sp,
              ),
        ),
        const SizedBox(height: 10),
        if (_selectedDayItems.isEmpty)
          const _EmptyState(text: 'No screening on this day.')
        else
          ..._selectedDayItems.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleTile(data: s),
              )),
      ],
    );
  }

  Widget _buildMonthHeader() {
    return Row(
      children: [
        Text(
          DateFormat('MMMM yyyy').format(currentMonth),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontSize: 14.sp,
              ),
        ),
        const Spacer(),
        IconButton(
          icon: Icon(
            Icons.chevron_left_rounded,
            size: 3.h,
          ),
          onPressed: () {
            setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month - 1);
            });
          },
        ),
        IconButton(
          icon: Icon(
            Icons.chevron_right_rounded,
            size: 3.h,
          ),
          onPressed: () {
            setState(() {
              currentMonth =
                  DateTime(currentMonth.year, currentMonth.month + 1);
            });
          },
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final days = _daysInMonth(currentMonth);
    final firstWeekday =
        DateTime(currentMonth.year, currentMonth.month, 1).weekday;

    return Container(
      padding: EdgeInsets.all(1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildWeekHeader(),
          SizedBox(height: 1.h),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: days.length + firstWeekday - 1,
            itemBuilder: (_, i) {
              if (i < firstWeekday - 1) return const SizedBox();

              final day = days[i - (firstWeekday - 1)];
              final isSelected = _day(day) == _day(selectedDay);
              final hasEvent = _hasEvent(day);
              final isToday = _day(day) == _day(DateTime.now());

              return GestureDetector(
                onTap: () => setState(() => selectedDay = day),
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Growkids.purpleFlo.withValues(alpha: 0.14)
                        : (isToday
                            ? Colors.black.withValues(alpha: 0.1)
                            : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(
                            color: Growkids.purpleFlo.withValues(alpha: 0.35))
                        : Border.all(
                            color: Colors.black.withValues(alpha: 0.3)),
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Text(
                        '${day.day}',
                        style: TextStyle(
                          fontSize: 14.sp,
                          color: isSelected ? Growkids.purpleFlo : Colors.black,
                        ),
                      ),
                      if (hasEvent)
                        Positioned(
                          bottom: 15,
                          child: Container(
                            width: 15,
                            height: 15,
                            decoration: const BoxDecoration(
                              color: Growkids.purpleFlo,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildWeekHeader() {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return Row(
      children: days
          .map((d) => Expanded(
                child: Center(
                  child: Text(
                    d,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.sp,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ),
              ))
          .toList(),
    );
  }

  // ===== List view =====

  Widget _buildListView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTabs(),
        const SizedBox(height: 14),
        if (_listFiltered.isEmpty)
          const _EmptyState(text: 'No schedule found.')
        else
          ..._listFiltered.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _ScheduleTile(data: s),
              )),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: EdgeInsets.all(0.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          _TabButton(
            label: 'Today',
            active: tabIndex == 0,
            onTap: () => setState(() => tabIndex = 0),
          ),
          _TabButton(
            label: 'Upcoming',
            active: tabIndex == 1,
            onTap: () => setState(() => tabIndex = 1),
          ),
          _TabButton(
            label: 'Past',
            active: tabIndex == 2,
            onTap: () => setState(() => tabIndex = 2),
          ),
        ],
      ),
    );
  }
}

// ========================
// Small components
// ========================

class _SegBtn extends StatelessWidget {
  final String label;
  final bool active;
  final IconData icon;
  final VoidCallback onTap;

  const _SegBtn({
    required this.label,
    required this.active,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          decoration: BoxDecoration(
            color: active
                ? Growkids.purpleFlo.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 2.5.h,
                color: active
                    ? Growkids.purpleFlo
                    : Colors.black.withValues(alpha: 0.55),
              ),
              SizedBox(width: 1.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: active
                      ? Growkids.purpleFlo
                      : Colors.black.withValues(alpha: 0.55),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ScheduleTile({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse((data['date'] ?? '').toString());
    final dateText =
        date == null ? '-' : DateFormat('EEE, d MMM yyyy').format(date);
    final time = (data['time'] ?? '-').toString();

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.12),
            child: Icon(
              Icons.fact_check_rounded,
              color: Growkids.purpleFlo,
              size: 3.h,
            ),
          ),
          SizedBox(width: 1.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (data['stud_name'] ?? '-').toString(),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 14.sp,
                      ),
                ),
                SizedBox(height: 1.h),
                Text(
                  (data['stud_branch'] ?? '').toString(),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.black.withValues(alpha: 0.55),
                        fontSize: 12.sp,
                      ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 2.h,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      dateText,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.75),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.schedule_rounded,
                      size: 2.h,
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.black.withValues(alpha: 0.75),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _TabButton({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: 1.h),
          decoration: BoxDecoration(
            color: active
                ? Growkids.purpleFlo.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.sp,
                color: active
                    ? Growkids.purpleFlo
                    : Colors.black.withValues(alpha: 0.6),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String text;
  const _EmptyState({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      alignment: Alignment.center,
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Colors.black.withValues(alpha: 0.55),
              fontSize: 14.sp,
            ),
      ),
    );
  }
}

class _DesktopScheduleCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _DesktopScheduleCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.tryParse((data['date'] ?? '').toString());
    final dateText = date == null ? '-' : DateFormat('d MMM yyyy').format(date);
    final time = (data['time'] ?? '-').toString();
    final name = (data['stud_name'] ?? '-').toString();
    final branch = (data['stud_branch'] ?? '').toString();

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: Row(
        children: [
          Container(
            width: 43,
            height: 43,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Growkids.purpleFlo.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              Icons.fact_check_rounded,
              color: Growkids.purpleFlo,
              size: 21,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF3E414C),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                if (branch.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(
                    branch,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF8B8F9C),
                      fontSize: 7,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '$dateText · $time',
                  style: TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DesktopScheduleEmpty extends StatelessWidget {
  final String text;
  const _DesktopScheduleEmpty({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.event_busy_rounded,
            color: Color(0xFFB0B4BF),
            size: 42,
          ),
          const SizedBox(height: 10),
          Text(
            text,
            style: const TextStyle(color: Color(0xFF8B8F9C), fontSize: 10),
          ),
        ],
      ),
    );
  }
}

abstract final class _DesktopScheduleText {
  static const header = TextStyle(
    color: Color(0xFF7A7F8C),
    fontSize: 8,
    fontWeight: FontWeight.w800,
  );
}
