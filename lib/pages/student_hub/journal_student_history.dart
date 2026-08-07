import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart';
import 'package:growcheck_app_v2/pages/journal/add_daily_progress.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';
import 'package:intl/intl.dart';
import 'package:growcheck_app_v2/ui/colour.dart'; // Pastikan path betul

bool _useDesktopStudentJournalLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class StudentJournalPage extends StatefulWidget {
  final String studentId;
  final String studentName;
  final String teacherId;

  const StudentJournalPage({
    super.key,
    required this.studentId,
    required this.studentName,
    required this.teacherId,
  });

  @override
  State<StudentJournalPage> createState() => _StudentJournalPageState();
}

class _StudentJournalPageState extends State<StudentJournalPage> {
  static final String _journalBaseUrl = ApiConfig.journal('');
  //'http://app-kizzu.test/growkids/journal/';

  bool _isLoading = true;
  List<dynamic> _journals = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchJournals();
  }

  Future<void> _fetchJournals() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final url = Uri.parse(ApiConfig.flutter('journal_fetch_student.php'));
    /*final url = Uri.parse(
        'http://app-kizzu.test/growkids/flutter/journal_fetch_student.php');*/

    try {
      final res = await http.post(url, body: {'stud_id': widget.studentId});

      if (res.statusCode == 200) {
        final jsonResponse = json.decode(res.body);
        if (jsonResponse['status'] == 'success') {
          setState(() {
            _journals = jsonResponse['data'];
            _isLoading = false;
          });
        } else {
          setState(() {
            _isLoading = false;
            _error = "Tiada data dijumpai";
          });
        }
      } else {
        throw Exception("Server Error");
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _error = e.toString();
      });
    }
  }

  // Backend attachment format is not always consistent.
  // This parser accepts:
  // - List<String>
  // - JSON string array
  // - Single URL/path string
  // - Comma-separated string
  List<String> _parseAttachments(dynamic rawValue) {
    if (rawValue == null) return [];

    if (rawValue is List) {
      return rawValue
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    if (rawValue is! String) return [];

    final value = rawValue.trim();
    if (value.isEmpty) return [];

    try {
      final decoded = json.decode(value);
      if (decoded is List) {
        return decoded
            .map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList();
      }

      if (decoded is String && decoded.trim().isNotEmpty) {
        return [decoded.trim()];
      }
    } catch (_) {
      // Fall back to plain string parsing below.
    }

    if (value.contains(',')) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }

    return [value];
  }

  String _normalizeAttachmentUrl(String value) {
    var trimmed = value.trim().replaceAll('\\', '/');
    if (trimmed.isEmpty) return '';

    trimmed = trimmed.replaceFirst(RegExp(r'^(\.\./)+'), '');

    if (trimmed.startsWith('http://app-kizzu.test/growkids/journal/')) {
      return trimmed.replaceFirst(
        'http://app-kizzu.test/growkids/journal/',
        _journalBaseUrl,
      );
    }

    if (trimmed.startsWith('http://app-kizzu.test/growkids/')) {
      return trimmed.replaceFirst(
        'http://app-kizzu.test/growkids/',
        'https://app.kizzukids.com.my/growkids/',
      );
    }

    if (trimmed.startsWith('http://app.kizzukids.com.my/growkids/')) {
      return trimmed.replaceFirst(
        'http://app.kizzukids.com.my/growkids/',
        'https://app.kizzukids.com.my/growkids/',
      );
    }

    if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
      return trimmed;
    }

    if (trimmed.startsWith('/growkids/')) {
      return ApiConfig.url(trimmed);
    }

    if (trimmed.startsWith('growkids/')) {
      return ApiConfig.url('/$trimmed');
    }

    if (trimmed.startsWith('/journal/')) {
      return ApiConfig.growkids(trimmed.substring(1));
    }

    if (trimmed.startsWith('journal/')) {
      return ApiConfig.growkids(trimmed);
    }

    return '$_journalBaseUrl${Uri.encodeComponent(trimmed.split('/').last)}';
  }

  String _attachmentDedupKey(String value) {
    final normalized = _normalizeAttachmentUrl(value);
    if (normalized.isEmpty) return '';

    final uri = Uri.tryParse(normalized);
    if (uri == null) return normalized;

    final lastSegment =
        uri.pathSegments.isNotEmpty ? uri.pathSegments.last : normalized;
    return lastSegment.toLowerCase();
  }

  // Some API responses use `attachment`, others use `attachments`.
  // Normalize and dedupe both sources so one image does not appear twice
  // as both a raw filename and a full URL.
  List<String> _extractAttachments(Map<String, dynamic> item) {
    final merged = <String>[
      ..._parseAttachments(item['attachments']),
      ..._parseAttachments(item['attachment']),
    ];
    final unique = <String, String>{};

    for (final raw in merged) {
      final normalized = _normalizeAttachmentUrl(raw);
      final key = _attachmentDedupKey(raw);

      if (normalized.isEmpty || key.isEmpty) continue;
      unique.putIfAbsent(key, () => normalized);
    }

    return unique.values.toList();
  }

  void _showImagePreview(List<String> imageUrls, int initialIndex) {
    if (_useDesktopStudentJournalLayout(context)) {
      _showDesktopImagePreview(imageUrls, initialIndex);
      return;
    }

    final controller = PageController(initialPage: initialIndex);

    showDialog(
      context: context,
      builder: (_) {
        var currentIndex = initialIndex;

        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.black,
              insetPadding: EdgeInsets.all(2.h),
              child: Stack(
                children: [
                  PageView.builder(
                    controller: controller,
                    itemCount: imageUrls.length,
                    onPageChanged: (index) {
                      setModalState(() => currentIndex = index);
                    },
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.8,
                        maxScale: 4,
                        child: Image.network(
                          imageUrls[index],
                          fit: BoxFit.contain,
                          loadingBuilder: (context, child, loadingProgress) {
                            if (loadingProgress == null) return child;
                            return const Center(
                              child: CircularProgressIndicator(
                                  color: Growkids.purpleFlo),
                            );
                          },
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey[200],
                            alignment: Alignment.center,
                            child: Icon(Icons.broken_image, size: 6.h),
                          ),
                        ),
                      );
                    },
                  ),
                  Positioned(
                    top: 12,
                    right: 12,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon:
                          const Icon(Icons.close_rounded, color: Colors.white),
                    ),
                  ),
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.55),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${currentIndex + 1} / ${imageUrls.length}',
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- FUNCTION UNTUK TUNJUK DIALOG (POPUP) ---
  void _showJournalDetail(Map<String, dynamic> item) {
    if (_useDesktopStudentJournalLayout(context)) {
      _showDesktopJournalDetail(item);
      return;
    }

    final title = item['title'] ?? 'Tiada Tajuk';
    final content = item['content'] ?? 'Tiada isi kandungan.';
    final dateStr = item['log_date'] ?? '';
    final attachments = _extractAttachments(item);

    // Format tarikh cantik sikit untuk dialog
    String formattedDate = dateStr;
    try {
      final date = DateTime.parse(dateStr);
      formattedDate = DateFormat('EEEE, d MMMM yyyy').format(date);
    } catch (_) {}

    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.white,
          child: Container(
            padding: EdgeInsets.all(2.h),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxHeight: 80.h),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Keep the dialog scrollable so journals with many images
                  // remain usable on smaller screens.
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  formattedDate,
                                  style: TextStyle(
                                      fontSize: 12.sp, color: Colors.grey[600]),
                                ),
                              ),
                              InkWell(
                                onTap: () => Navigator.pop(context),
                                child: Icon(
                                  Icons.close_rounded,
                                  color: Colors.grey[400],
                                  size: 2.h,
                                ),
                              )
                            ],
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            title,
                            style: TextStyle(
                                fontSize: 16.sp, color: Colors.black87),
                          ),
                          SizedBox(height: 1.h),
                          Text(
                            content,
                            style: TextStyle(
                                fontSize: 12.sp,
                                color: Colors.black54,
                                height: 1.5),
                          ),
                          if (attachments.isNotEmpty) ...[
                            SizedBox(height: 1.5.h),
                            Text(
                              "Attachments",
                              style: TextStyle(
                                  fontSize: 12.sp, color: Colors.black87),
                            ),
                            SizedBox(height: 1.h),
                            // Render every attachment as a thumbnail so multiple
                            // uploaded images can be browsed from one journal.
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: attachments.length,
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 2.w,
                                mainAxisSpacing: 1.h,
                                childAspectRatio: 1,
                              ),
                              itemBuilder: (context, index) {
                                final imageUrl = attachments[index];

                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: InkWell(
                                    onTap: () =>
                                        _showImagePreview(attachments, index),
                                    child: Container(
                                      color: Colors.grey[100],
                                      child: Image.network(
                                        imageUrl,
                                        fit: BoxFit.cover,
                                        loadingBuilder:
                                            (context, child, loadingProgress) {
                                          if (loadingProgress == null) {
                                            return child;
                                          }
                                          return const Center(
                                            child: CircularProgressIndicator(
                                                color: Growkids.purpleFlo),
                                          );
                                        },
                                        errorBuilder: (_, __, ___) => Container(
                                          color: Colors.grey[200],
                                          alignment: Alignment.center,
                                          child: Icon(Icons.broken_image,
                                              size: 4.h),
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
                  SizedBox(height: 2.h),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Growkids.purpleFlo,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          padding: EdgeInsets.symmetric(vertical: 1.2.h)),
                      onPressed: () => Navigator.pop(context),
                      child: Text("Close",
                          style:
                              TextStyle(color: Colors.white, fontSize: 14.sp)),
                    ),
                  )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // Helper Tarikh Kotak
  Widget _buildDateBox(String dateStr) {
    DateTime date;
    try {
      date = DateTime.parse(dateStr);
    } catch (e) {
      date = DateTime.now();
    }

    final day = DateFormat('dd').format(date);
    final month = DateFormat('MMM').format(date).toUpperCase();

    return Container(
      width: 8.h,
      padding: EdgeInsets.all(1.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Growkids.purpleFlo.withValues(alpha: 0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(day,
              style: TextStyle(fontSize: 16.sp, color: Growkids.purpleFlo)),
          Text(month,
              style: TextStyle(fontSize: 12.sp, color: Colors.grey[600])),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopStudentJournalLayout(context)) {
      return _buildDesktop();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Journal History',
            style: TextStyle(color: Colors.white)),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      floatingActionButton: FloatingActionButton.large(
        backgroundColor: Growkids.purpleFlo,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => AddDailyProgressPage(
                studentName: widget.studentName,
                teacherId: id,
                studId: widget.studentId,
              ),
            ),
          );
        },
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo))
          : _error != null
              ? const Center(
                  child: Text("Error downloading data",
                      style: TextStyle(color: Colors.red)))
              : _journals.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.menu_book_rounded,
                              size: 10.h, color: Colors.grey[300]),
                          SizedBox(height: 2.h),
                          Text("No journal record",
                              style: TextStyle(
                                  fontSize: 16.sp, color: Colors.grey)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: EdgeInsets.all(2.h),
                      itemCount: _journals.length,
                      separatorBuilder: (ctx, i) => SizedBox(height: 1.5.h),
                      itemBuilder: (ctx, i) {
                        final item = _journals[i];
                        final attachments = _extractAttachments(
                            Map<String, dynamic>.from(item));

                        return InkWell(
                          onTap: () => _showJournalDetail(
                              Map<String, dynamic>.from(item)),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: EdgeInsets.all(1.5.h),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4))
                              ],
                            ),
                            child: Row(
                              children: [
                                // 1. Date Box
                                _buildDateBox(item['log_date'] ?? ''),

                                SizedBox(width: 3.w),

                                // 2. Content Preview
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item['title'] ?? 'No Title',
                                        style: TextStyle(fontSize: 14.sp),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      SizedBox(height: 0.5.h),
                                      Text(
                                        item['content'] ?? '',
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                            fontSize: 12.sp,
                                            color: Colors.grey[600],
                                            height: 1.4),
                                      ),
                                      if (attachments.isNotEmpty)
                                        Padding(
                                          padding: EdgeInsets.only(top: 1.h),
                                          child: Row(
                                            children: [
                                              Icon(Icons.attach_file_rounded,
                                                  size: 14.sp,
                                                  color: Colors.blueAccent),
                                              SizedBox(width: 1.w),
                                              Text(
                                                attachments.length > 1
                                                    ? '${attachments.length} media attached'
                                                    : '1 media attached',
                                                style: TextStyle(
                                                    color: Colors.blueAccent,
                                                    fontSize: 10.sp),
                                              ),
                                            ],
                                          ),
                                        )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
    );
  }

  Widget _buildDesktop() {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F5FA),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 8,
        title: const Text(
          'Journal History',
          style: TextStyle(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w700,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh journals',
            onPressed: _fetchJournals,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : _error != null
              ? _desktopError()
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1320),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _desktopHeader(),
                          const SizedBox(height: 20),
                          if (_journals.isEmpty)
                            _desktopEmpty()
                          else
                            _desktopJournalGrid(),
                        ],
                      ),
                    ),
                  ),
                ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        onPressed: _openAddJournal,
        icon: const Icon(Icons.add_rounded),
        label: const Text(
          'Add journal',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _desktopHeader() {
    final initial = widget.studentName.trim().isEmpty
        ? '?'
        : widget.studentName.trim().substring(0, 1).toUpperCase();
    final mediaCount = _journals.fold<int>(0, (total, raw) {
      final item = Map<String, dynamic>.from(raw as Map);
      return total + _extractAttachments(item).length;
    });

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.72),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x253F2A91),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 62,
            height: 62,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Text(
              initial,
              style: const TextStyle(
                color: Growkids.purple,
                fontSize: 25,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'STUDENT JOURNAL',
                  style: TextStyle(
                    color: Color(0xCCFFFFFF),
                    fontSize: 11,
                    letterSpacing: 1.1,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.studentName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                const Text(
                  'Daily progress, observations, and attached media.',
                  style: TextStyle(color: Color(0xD9FFFFFF), fontSize: 13),
                ),
              ],
            ),
          ),
          _desktopMetric('Entries', _journals.length, Icons.menu_book_outlined),
          const SizedBox(width: 12),
          _desktopMetric('Media', mediaCount, Icons.image_outlined),
        ],
      ),
    );
  }

  Widget _desktopMetric(String label, int count, IconData icon) {
    return Container(
      width: 112,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 9),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                label,
                style: const TextStyle(
                  color: Color(0xD9FFFFFF),
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _desktopJournalGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        const columns = 2;
        const spacing = 16.0;
        final width =
            (constraints.maxWidth - (spacing * (columns - 1))) / columns;

        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: _journals.map((raw) {
            final item = Map<String, dynamic>.from(raw as Map);
            return SizedBox(width: width, child: _desktopJournalCard(item));
          }).toList(),
        );
      },
    );
  }

  Widget _desktopJournalCard(Map<String, dynamic> item) {
    final attachments = _extractAttachments(item);
    final date = DateTime.tryParse((item['log_date'] ?? '').toString());
    final day = date == null ? '--' : DateFormat('dd').format(date);
    final month =
        date == null ? '---' : DateFormat('MMM').format(date).toUpperCase();

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _showJournalDetail(item),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE2E5ED)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0D0E1635),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 56,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Growkids.purple.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: Growkids.purple.withValues(alpha: 0.14),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      day,
                      style: const TextStyle(
                        color: Growkids.purple,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      month,
                      style: const TextStyle(
                        color: Color(0xFF777C8B),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (item['title'] ?? 'No Title').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF292C39),
                        fontSize: 15,
                        height: 1.3,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      (item['content'] ?? '').toString(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF717685),
                        fontSize: 12,
                        height: 1.45,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (attachments.isNotEmpty) ...[
                          const Icon(
                            Icons.attach_file_rounded,
                            size: 15,
                            color: Color(0xFF3D7AF5),
                          ),
                          const SizedBox(width: 5),
                          Text(
                            '${attachments.length} media',
                            style: const TextStyle(
                              color: Color(0xFF3D7AF5),
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ] else
                          const Text(
                            'No attachment',
                            style: TextStyle(
                              color: Color(0xFF9A9EAA),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F2F6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.arrow_forward_rounded,
                  size: 17,
                  color: Color(0xFF858A99),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _desktopEmpty() {
    return Container(
      height: 340,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E5ED)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.menu_book_outlined, size: 58, color: Color(0xFFD0D3DC)),
          SizedBox(height: 14),
          Text(
            'No journal record',
            style: TextStyle(
              color: Color(0xFF777C8B),
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopError() {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2E5ED)),
        ),
        child: const Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.red),
            SizedBox(width: 12),
            Expanded(child: Text('Error downloading data')),
          ],
        ),
      ),
    );
  }

  void _openAddJournal() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddDailyProgressPage(
          studentName: widget.studentName,
          teacherId: id,
          studId: widget.studentId,
        ),
      ),
    );
  }

  Future<void> _showDesktopJournalDetail(Map<String, dynamic> item) {
    final attachments = _extractAttachments(item);
    final parsedDate = DateTime.tryParse((item['log_date'] ?? '').toString());
    final date = parsedDate == null
        ? (item['log_date'] ?? '-').toString()
        : DateFormat('EEEE, d MMMM yyyy').format(parsedDate);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820, maxHeight: 720),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x260E1635),
                  blurRadius: 32,
                  offset: Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            date,
                            style: const TextStyle(
                              color: Color(0xFF858A99),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            (item['title'] ?? 'No Title').toString(),
                            style: const TextStyle(
                              color: Color(0xFF242735),
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const Divider(height: 28, color: Color(0xFFE7E9F0)),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (item['content'] ?? 'No content.').toString(),
                          style: const TextStyle(
                            color: Color(0xFF555967),
                            fontSize: 14,
                            height: 1.55,
                          ),
                        ),
                        if (attachments.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Row(
                            children: [
                              const Text(
                                'Attachments',
                                style: TextStyle(
                                  color: Color(0xFF292C39),
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color:
                                      Growkids.purple.withValues(alpha: 0.09),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${attachments.length}',
                                  style: const TextStyle(
                                    color: Growkids.purple,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: attachments.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.35,
                            ),
                            itemBuilder: (context, index) => ClipRRect(
                              borderRadius: BorderRadius.circular(13),
                              child: InkWell(
                                onTap: () =>
                                    _showImagePreview(attachments, index),
                                child: Image.network(
                                  attachments[index],
                                  fit: BoxFit.cover,
                                  loadingBuilder: (context, child, progress) =>
                                      progress == null
                                          ? child
                                          : const Center(
                                              child: CircularProgressIndicator(
                                                color: Growkids.purpleFlo,
                                              ),
                                            ),
                                  errorBuilder: (_, __, ___) =>
                                      const ColoredBox(
                                    color: Color(0xFFF0F1F5),
                                    child: Center(
                                      child: Icon(Icons.broken_image_outlined),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: SizedBox(
                    width: 110,
                    height: 42,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('Close'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _showDesktopImagePreview(
    List<String> imageUrls,
    int initialIndex,
  ) {
    final controller = PageController(initialPage: initialIndex);

    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        var currentIndex = initialIndex;
        return StatefulBuilder(
          builder: (context, setModalState) => Dialog(
            backgroundColor: Colors.black,
            insetPadding: const EdgeInsets.all(36),
            child: Stack(
              children: [
                PageView.builder(
                  controller: controller,
                  itemCount: imageUrls.length,
                  onPageChanged: (index) =>
                      setModalState(() => currentIndex = index),
                  itemBuilder: (context, index) => InteractiveViewer(
                    minScale: 0.8,
                    maxScale: 4,
                    child: Center(
                      child: Image.network(
                        imageUrls[index],
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) =>
                            progress == null
                                ? child
                                : const CircularProgressIndicator(
                                    color: Growkids.purpleFlo,
                                  ),
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.broken_image_outlined,
                          color: Colors.white54,
                          size: 54,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  right: 14,
                  child: IconButton.filled(
                    onPressed: () => Navigator.pop(dialogContext),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ),
                Positioned(
                  bottom: 18,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.65),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        '${currentIndex + 1} / ${imageUrls.length}',
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
