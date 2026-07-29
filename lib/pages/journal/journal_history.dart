import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/journal/add_daily_progress.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopJournalHistoryLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class JournalHistoryPage extends StatefulWidget {
  final String teacherId;

  const JournalHistoryPage({
    super.key,
    required this.teacherId,
  });

  @override
  State<JournalHistoryPage> createState() => _JournalHistoryPageState();
}

class _JournalHistoryPageState extends State<JournalHistoryPage> {
  static final String _url =
      ApiConfig.flutter('get_teacher_journal_history.php');
  /*static const String _url =
      'http://app-kizzu.test/growkids/flutter/get_teacher_journal_history.php';*/

  bool _loading = true;
  String? _error;

  List<_JournalItem> _data = [];
  List<_JournalItem> _filtered = [];

  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.post(
        Uri.parse(_url),
        body: {'teacher_id': widget.teacherId},
      );

      debugPrint('STATUS CODE: ${res.statusCode}');
      debugPrint('RAW BODY: ${res.body}');

      final decoded = jsonDecode(res.body);
      debugPrint('DECODED: $decoded');

      if (decoded is! Map || decoded['success'] != true) {
        throw Exception(decoded['message'] ?? "Invalid response");
      }

      final List list = decoded['data'];
      final out = list.map((e) => _JournalItem.fromJson(e)).toList();

      setState(() {
        _data = out;
        _filtered = List.from(out);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _filter(String q) {
    final query = q.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _filtered = List.from(_data));
      return;
    }

    setState(() {
      _filtered = _data
          .where((x) =>
              x.title.toLowerCase().contains(query) ||
              x.content.toLowerCase().contains(query) ||
              x.studentName.toLowerCase().contains(query))
          .toList();
    });
  }

  Future<void> _open(_JournalItem item) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.48),
      builder: (_) => _useDesktopJournalHistoryLayout(context)
          ? _DesktopJournalDetailsDialog(
              item: item,
              teacherId: widget.teacherId,
              onEdited: _load,
            )
          : _JournalDetailsDialog(
              item: item,
              teacherId: widget.teacherId,
              onEdited: _load,
            ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopJournalHistoryLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Journal History'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          )
        ],
      ),
      body: Column(
        children: [
          const _Header(),
          SizedBox(height: 1.h),
          Padding(
            padding: EdgeInsets.fromLTRB(2.h, 8, 2.h, 12),
            child: TextField(
              controller: _searchCtrl,
              onChanged: _filter,
              decoration: InputDecoration(
                hintText: 'Search journal...',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide:
                      BorderSide(color: Colors.black.withValues(alpha: .06)),
                ),
              ),
            ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.fromLTRB(2.h, 0, 2.h, 10),
              child: _ErrorBanner(text: _error!),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _filtered.isEmpty
                    ? Center(
                        child: Text(
                          "No journal records",
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.black.withValues(alpha: .6)),
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.fromLTRB(2.h, 0, 2.h, 24),
                        itemCount: _filtered.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (_, i) {
                          return _JournalCard(
                            item: _filtered[i],
                            onTap: () => _open(_filtered[i]),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }

  Widget _buildDesktopPage() {
    final mediaCount =
        _data.fold<int>(0, (total, item) => total + item.attachments.length);
    final studentCount = _data.map((item) => item.studId).toSet().length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          'Journal History',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 18),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1480),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
            child: Column(
              children: [
                _desktopHero(studentCount, mediaCount),
                const SizedBox(height: 22),
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Journal entries',
                            style: TextStyle(
                              color: Color(0xFF242631),
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Review observations and attached student media.',
                            style: TextStyle(
                              color: Color(0xFF777C8D),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 400,
                      height: 46,
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: _filter,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Search student, title or content...',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 21),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E3EA)),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide:
                                const BorderSide(color: Color(0xFFE0E3EA)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                              color: Growkids.purpleFlo,
                              width: 1.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _desktopErrorBanner(_error!),
                ],
                const SizedBox(height: 18),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _filtered.isEmpty
                          ? _desktopEmptyState()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final columns =
                                    constraints.maxWidth >= 1100 ? 3 : 2;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: columns,
                                    mainAxisSpacing: 14,
                                    crossAxisSpacing: 14,
                                    mainAxisExtent: 220,
                                  ),
                                  itemCount: _filtered.length,
                                  itemBuilder: (context, index) {
                                    final item = _filtered[index];
                                    return _desktopJournalCard(item);
                                  },
                                );
                              },
                            ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHero(int studentCount, int mediaCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 70,
            height: 70,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(19),
            ),
            child: const Icon(
              Icons.history_rounded,
              color: Growkids.purpleFlo,
              size: 36,
            ),
          ),
          const SizedBox(width: 20),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'STUDENT JOURNAL',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                  ),
                ),
                SizedBox(height: 5),
                Text(
                  'Journal History',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 27,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 6),
                Text(
                  'A complete timeline of progress notes and observations.',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
          _desktopMetric(
            Icons.menu_book_outlined,
            _data.length.toString(),
            'Entries',
          ),
          const SizedBox(width: 12),
          _desktopMetric(
            Icons.people_alt_outlined,
            studentCount.toString(),
            'Students',
          ),
          const SizedBox(width: 12),
          _desktopMetric(
            Icons.image_outlined,
            mediaCount.toString(),
            'Media',
          ),
        ],
      ),
    );
  }

  Widget _desktopMetric(IconData icon, String value, String label) {
    return Container(
      width: 116,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(color: Colors.white70, fontSize: 9),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopJournalCard(_JournalItem item) {
    final date = DateTime.tryParse(item.logDate);
    final dateLabel =
        date == null ? item.logDate : DateFormat('d MMM yyyy').format(date);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _open(item),
        borderRadius: BorderRadius.circular(17),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(17),
            border: Border.all(color: const Color(0xFFE3E5EC)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          date == null ? '—' : DateFormat('dd').format(date),
                          style: const TextStyle(
                            color: Growkids.purpleFlo,
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          date == null ? '' : DateFormat('MMM').format(date),
                          style: const TextStyle(
                            color: Growkids.purpleFlo,
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF30323C),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$dateLabel  •  ID ${item.studId}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF858A98),
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.arrow_forward_rounded,
                    color: Color(0xFF8C62E8),
                    size: 19,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF292B35),
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 7),
              Expanded(
                child: Text(
                  item.content,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF707584),
                    fontSize: 10,
                    height: 1.45,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                    item.attachments.isEmpty
                        ? Icons.notes_rounded
                        : Icons.attach_file_rounded,
                    color: item.attachments.isEmpty
                        ? const Color(0xFF9A9EAA)
                        : const Color(0xFF3478F6),
                    size: 15,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    item.attachments.isEmpty
                        ? 'No media'
                        : '${item.attachments.length} media',
                    style: TextStyle(
                      color: item.attachments.isEmpty
                          ? const Color(0xFF8A8E9A)
                          : const Color(0xFF3478F6),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '#${item.progressId}',
                    style: const TextStyle(
                      color: Color(0xFF9A9EAA),
                      fontSize: 9,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopEmptyState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.menu_book_outlined,
            color: Color(0xFF9A9EAA),
            size: 42,
          ),
          SizedBox(height: 12),
          Text(
            'No journal records',
            style: TextStyle(
              color: Color(0xFF343640),
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopErrorBanner(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F1),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFF2C5C9)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFCF3948),
            size: 19,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                color: Color(0xFF9A2934),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

//////////////////////////////////////////////////////////
// MODEL
//////////////////////////////////////////////////////////

class _JournalItem {
  final String progressId;
  final String studId;
  final String logDate;
  final String title;
  final String content;
  final String studentName;
  final List<String> attachments;

  const _JournalItem({
    required this.progressId,
    required this.studId,
    required this.logDate,
    required this.title,
    required this.content,
    required this.studentName,
    required this.attachments,
  });

  factory _JournalItem.fromJson(Map json) {
    List<String> parsedAttachments = [];

    if (json['attachments'] is List) {
      parsedAttachments =
          (json['attachments'] as List).map((e) => e.toString()).toList();
    } else if (json['attachment'] != null &&
        json['attachment'].toString().isNotEmpty) {
      try {
        final decoded = jsonDecode(json['attachment']);
        if (decoded is List) {
          parsedAttachments = decoded.map((e) => e.toString()).toList();
        }
      } catch (_) {}
    }

    return _JournalItem(
      progressId: json['progress_id'].toString(),
      studId: (json['stud_id'] ?? json['student_id'] ?? '').toString(),
      logDate: json['log_date'].toString(),
      title: json['title'].toString(),
      content: json['content'].toString(),
      studentName: json['student_name'].toString(),
      attachments: parsedAttachments,
    );
  }
}
//////////////////////////////////////////////////////////
// CARD UI (copy style student version)
//////////////////////////////////////////////////////////

class _JournalCard extends StatelessWidget {
  final _JournalItem item;
  final VoidCallback onTap;

  const _JournalCard({
    required this.item,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(item.logDate);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.black.withValues(alpha: .06)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .04),
              blurRadius: 14,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 1.h),
              decoration: BoxDecoration(
                color: Growkids.purpleFlo.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: Growkids.purpleFlo.withValues(alpha: 0.18)),
              ),
              child: Column(
                children: [
                  Text(
                    dt == null ? '-' : DateFormat('dd').format(dt),
                    style:
                        TextStyle(fontSize: 14.sp, color: Growkids.purpleFlo),
                  ),
                  Text(
                    dt == null ? '' : DateFormat('MMM').format(dt),
                    style: TextStyle(
                        fontSize: 12.sp,
                        color: Growkids.purpleFlo.withValues(alpha: .75)),
                  ),
                ],
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style:
                        TextStyle(fontSize: 14.sp, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 0.5.h),
                  Text(
                    item.studentName,
                    style: TextStyle(
                      fontSize: 12.sp,
                      color: Colors.black.withValues(alpha: .6),
                    ),
                  ),
                  if (item.attachments.isNotEmpty) ...[
                    SizedBox(height: 0.8.h),
                    Row(
                      children: [
                        Icon(
                          Icons.attach_file_rounded,
                          size: 14.sp,
                          color: Colors.blueAccent,
                        ),
                        SizedBox(width: 1.w),
                        Text(
                          '${item.attachments.length} media attached',
                          style: TextStyle(
                            fontSize: 10.sp,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =======================================================
// HEADER
// =======================================================

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 0),
      child: Container(
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Growkids.purpleFlo,
              Growkids.purpleFlo.withValues(alpha: .8)
            ],
          ),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .05),
              blurRadius: 18,
              offset: const Offset(0, 10),
            )
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 3.h,
              backgroundColor: Colors.white,
              child: Icon(
                Icons.menu_book_rounded,
                color: Growkids.purpleFlo,
                size: 3.h,
              ),
            ),
            SizedBox(width: 2.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Journal History',
                    style: TextStyle(
                        fontSize: 16.sp,
                        color: Colors.white.withValues(alpha: .9))),
              ],
            )
          ],
        ),
      ),
    );
  }
}

//////////////////////////////////////////////////////////
// DIALOG
//////////////////////////////////////////////////////////

class _DesktopJournalDetailsDialog extends StatelessWidget {
  final _JournalItem item;
  final String teacherId;
  final Future<void> Function() onEdited;

  const _DesktopJournalDetailsDialog({
    required this.item,
    required this.teacherId,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(item.logDate);
    final date = parsedDate == null
        ? item.logDate
        : DateFormat('EEEE, d MMMM yyyy').format(parsedDate);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 980, maxHeight: 760),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FC),
            borderRadius: BorderRadius.circular(22),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.20),
                blurRadius: 34,
                offset: const Offset(0, 16),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Growkids.purpleFlo,
                      Growkids.purpleFlo.withValues(alpha: 0.78),
                    ],
                  ),
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(22)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Growkids.purpleFlo,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.studentName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$date  •  Journal #${item.progressId}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3E5EC)),
                          ),
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'JOURNAL ENTRY',
                                  style: TextStyle(
                                    color: Color(0xFF8A8E9A),
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  item.title,
                                  style: const TextStyle(
                                    color: Color(0xFF292B35),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  item.content,
                                  style: const TextStyle(
                                    color: Color(0xFF555A68),
                                    fontSize: 13,
                                    height: 1.65,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: Container(
                          padding: const EdgeInsets.all(17),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFE3E5EC)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Attachments',
                                      style: TextStyle(
                                        color: Color(0xFF30323C),
                                        fontSize: 15,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF2FF),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      '${item.attachments.length} media',
                                      style: const TextStyle(
                                        color: Color(0xFF3478F6),
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),
                              Expanded(
                                child: item.attachments.isEmpty
                                    ? const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons
                                                  .image_not_supported_outlined,
                                              color: Color(0xFFA0A4AF),
                                              size: 34,
                                            ),
                                            SizedBox(height: 9),
                                            Text(
                                              'No media attached',
                                              style: TextStyle(
                                                color: Color(0xFF858A98),
                                                fontSize: 10,
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : GridView.builder(
                                        gridDelegate:
                                            const SliverGridDelegateWithFixedCrossAxisCount(
                                          crossAxisCount: 2,
                                          crossAxisSpacing: 9,
                                          mainAxisSpacing: 9,
                                        ),
                                        itemCount: item.attachments.length,
                                        itemBuilder: (context, index) {
                                          final imageUrl =
                                              item.attachments[index];
                                          return InkWell(
                                            onTap: () => _showDesktopImage(
                                                context, imageUrl),
                                            borderRadius:
                                                BorderRadius.circular(11),
                                            child: ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(11),
                                              child: Image.network(
                                                imageUrl,
                                                fit: BoxFit.cover,
                                                loadingBuilder: (
                                                  context,
                                                  child,
                                                  progress,
                                                ) =>
                                                    progress == null
                                                        ? child
                                                        : const Center(
                                                            child:
                                                                CircularProgressIndicator(),
                                                          ),
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color:
                                                      const Color(0xFFEEF0F4),
                                                  child: const Icon(
                                                    Icons.broken_image_outlined,
                                                    color: Color(0xFF9A9EAA),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius:
                      BorderRadius.vertical(bottom: Radius.circular(22)),
                  border: Border(top: BorderSide(color: Color(0xFFE3E5EC))),
                ),
                child: Row(
                  children: [
                    Text(
                      'Student ID ${item.studId}',
                      style: const TextStyle(
                        color: Color(0xFF858A98),
                        fontSize: 10,
                      ),
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                      child: const Text('Close'),
                    ),
                    const SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final navigator = Navigator.of(context);
                        navigator.pop();
                        final updated = await navigator.push(
                          MaterialPageRoute(
                            builder: (_) => AddDailyProgressPage(
                              studId: item.studId,
                              studentName: item.studentName,
                              teacherId: teacherId,
                              isEdit: true,
                              progressId: item.progressId,
                              existingTitle: item.title,
                              existingContent: item.content,
                              existingLogDate: item.logDate,
                              existingAttachments: item.attachments,
                            ),
                          ),
                        );
                        if (updated == true) await onEdited();
                      },
                      icon: const Icon(Icons.edit_outlined, size: 18),
                      label: const Text('Edit journal'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(11),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDesktopImage(BuildContext context, String imageUrl) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.82),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(40),
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.network(
                  imageUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 0,
              right: 0,
              child: IconButton.filled(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JournalDetailsDialog extends StatelessWidget {
  final _JournalItem item;
  final String teacherId;
  final Future<void> Function() onEdited;

  const _JournalDetailsDialog({
    required this.item,
    required this.teacherId,
    required this.onEdited,
  });

  @override
  Widget build(BuildContext context) {
    final dt = DateTime.tryParse(item.logDate);
    final date =
        dt == null ? item.logDate : DateFormat('EEE, d MMM yyyy').format(dt);
    final maxH = MediaQuery.of(context).size.height * 0.85;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      child: Container(
        constraints: BoxConstraints(maxHeight: maxH),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .18),
              blurRadius: 30,
              offset: const Offset(0, 18),
            )
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 14),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Growkids.purpleFlo,
                    Growkids.purpleFlo.withValues(alpha: .75)
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(22)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 2.h,
                    backgroundColor: Colors.white,
                    child: Icon(
                      Icons.description_rounded,
                      color: Growkids.purpleFlo,
                      size: 2.h,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.studentName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style:
                              TextStyle(fontSize: 14.sp, color: Colors.white),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          date,
                          style: TextStyle(
                              fontSize: 12.sp,
                              color: Colors.white.withValues(alpha: .9)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 2.h,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(2.h),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      style: TextStyle(fontSize: 14.sp),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      item.content,
                      style: TextStyle(
                        fontSize: 13.sp,
                        height: 1.35,
                        color: Colors.black.withValues(alpha: .78),
                      ),
                    ),
                    if (item.attachments.isNotEmpty) ...[
                      SizedBox(height: 2.h),
                      Text(
                        'Attachments',
                        style: TextStyle(
                          fontSize: 12.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 1.h),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: item.attachments.length,
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 2.w,
                          mainAxisSpacing: 1.h,
                          childAspectRatio: 1,
                        ),
                        itemBuilder: (context, index) {
                          final imageUrl = item.attachments[index];
                          print('IMAGE URL USED: $imageUrl');

                          return ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => Dialog(
                                    backgroundColor: Colors.black,
                                    insetPadding: EdgeInsets.all(2.h),
                                    child: InteractiveViewer(
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          alignment: Alignment.center,
                                          child: Icon(Icons.broken_image,
                                              size: 5.h),
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                color: Colors.grey[100],
                                child: Image.network(
                                  imageUrl,
                                  fit: BoxFit.cover,
                                  loadingBuilder:
                                      (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: CircularProgressIndicator(
                                        color: Growkids.purpleFlo,
                                      ),
                                    );
                                  },
                                  errorBuilder: (_, __, ___) => Container(
                                    color: Colors.grey[200],
                                    alignment: Alignment.center,
                                    child: Icon(Icons.broken_image, size: 4.h),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.all(1.h),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 5.h,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(
                              color:
                                  Growkids.purpleFlo.withValues(alpha: 0.35)),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Close",
                          style: TextStyle(
                            color: Growkids.purpleFlo,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: SizedBox(
                      height: 5.h,
                      child: ElevatedButton(
                        onPressed: () async {
                          Navigator.pop(context);

                          final updated = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => AddDailyProgressPage(
                                studId: item.studId,
                                studentName: item.studentName,
                                teacherId: teacherId,
                                isEdit: true,
                                progressId: item.progressId,
                                existingTitle: item.title,
                                existingContent: item.content,
                                existingLogDate: item.logDate,
                                existingAttachments: item.attachments,
                              ),
                            ),
                          );

                          if (updated == true) {
                            await onEdited();
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          "Edit",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14.sp,
                          ),
                        ),
                      ),
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

//////////////////////////////////////////////////////////
// ERROR BANNER
//////////////////////////////////////////////////////////

class _ErrorBanner extends StatelessWidget {
  final String text;
  const _ErrorBanner({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded,
              color: Colors.red.withValues(alpha: 0.8)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(fontSize: 12.sp)),
          ),
        ],
      ),
    );
  }
}
