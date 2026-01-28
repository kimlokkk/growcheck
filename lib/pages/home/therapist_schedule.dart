import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

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
  static const _url = 'https://app.kizzukids.com.my/growkids/flutter/screening_schedule.php';

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
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              _buildTopBar(),
              SizedBox(height: 1.h),
              _buildViewToggle(),
              SizedBox(height: 1.h),
              if (loading) ...[
                const SizedBox(height: 60),
                const Center(child: CircularProgressIndicator()),
                const SizedBox(height: 60),
              ] else ...[
                if (view == _ScheduleView.calendar) _buildCalendarView() else _buildListView(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        Text(
          'Schedule',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 16.sp,
              ),
        ),
        const Spacer(),
        IconButton(
          onPressed: _refresh,
          icon: Icon(
            Icons.refresh_rounded,
            size: 3.h,
          ),
          tooltip: 'Refresh',
        ),
      ],
    );
  }

  Widget _buildViewToggle() {
    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
          _EmptyState(text: 'No screening on this day.')
        else
          ..._selectedDayItems
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScheduleTile(data: s),
                  ))
              .toList(),
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
              currentMonth = DateTime(currentMonth.year, currentMonth.month - 1);
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
              currentMonth = DateTime(currentMonth.year, currentMonth.month + 1);
            });
          },
        ),
      ],
    );
  }

  Widget _buildCalendarCard() {
    final days = _daysInMonth(currentMonth);
    final firstWeekday = DateTime(currentMonth.year, currentMonth.month, 1).weekday;

    return Container(
      padding: EdgeInsets.all(1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
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
                        ? Growkids.purpleFlo.withOpacity(0.14)
                        : (isToday ? Colors.black.withOpacity(0.1) : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected
                        ? Border.all(color: Growkids.purpleFlo.withOpacity(0.35))
                        : Border.all(color: Colors.black.withOpacity(0.3)),
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
                            decoration: BoxDecoration(
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
                      color: Colors.black.withOpacity(0.55),
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
          _EmptyState(text: 'No schedule found.')
        else
          ..._listFiltered
              .map((s) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _ScheduleTile(data: s),
                  ))
              .toList(),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: EdgeInsets.all(0.5.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
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
            color: active ? Growkids.purpleFlo.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 2.5.h,
                color: active ? Growkids.purpleFlo : Colors.black.withOpacity(0.55),
              ),
              SizedBox(width: 1.w),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14.sp,
                  color: active ? Growkids.purpleFlo : Colors.black.withOpacity(0.55),
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
    final dateText = date == null ? '-' : DateFormat('EEE, d MMM yyyy').format(date);
    final time = (data['time'] ?? '-').toString();

    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black.withOpacity(0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 40,
            backgroundColor: Growkids.purpleFlo.withOpacity(0.12),
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
                        color: Colors.black.withOpacity(0.55),
                        fontSize: 12.sp,
                      ),
                ),
                SizedBox(height: 0.5.h),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 2.h,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      dateText,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.75),
                        fontSize: 12.sp,
                      ),
                    ),
                    SizedBox(width: 2.w),
                    Icon(
                      Icons.schedule_rounded,
                      size: 2.h,
                      color: Colors.black.withOpacity(0.55),
                    ),
                    SizedBox(width: 1.w),
                    Text(
                      time,
                      style: TextStyle(
                        color: Colors.black.withOpacity(0.75),
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
            color: active ? Growkids.purpleFlo.withOpacity(0.12) : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.sp,
                color: active ? Growkids.purpleFlo : Colors.black.withOpacity(0.6),
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
              color: Colors.black.withOpacity(0.55),
              fontSize: 14.sp,
            ),
      ),
    );
  }
}
