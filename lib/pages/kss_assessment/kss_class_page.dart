import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_curriculum_browser.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_student_progress.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/manage_kss_students_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssClassPage extends StatefulWidget {
  final String teacherId;
  final Map<String, dynamic> initialClass;

  const KssClassPage({
    super.key,
    required this.teacherId,
    required this.initialClass,
  });

  @override
  State<KssClassPage> createState() => _KssClassPageState();
}

class _KssClassPageState extends State<KssClassPage> {
  late Map<String, dynamic> _classData;
  List<Map<String, dynamic>> _students = [];
  bool _loading = true;
  String? _error;
  int _selectedTab = 1;

  String get _classId => widget.initialClass['class_id'].toString();

  @override
  void initState() {
    super.initState();
    _classData = Map<String, dynamic>.from(widget.initialClass);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(ApiConfig.flutter('kss_class_students.php')),
        body: {'teacher_id': widget.teacherId, 'class_id': _classId},
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load the class.').toString()
            : 'Unable to load the class.');
      }
      final data = Map<String, dynamic>.from(decoded['data'] as Map);
      final students = data['students'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _classData = Map<String, dynamic>.from(data['class'] as Map);
        _students = students
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
      });
    } catch (error) {
      if (mounted) {
        setState(
            () => _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _manageStudents() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ManageKssStudentsPage(
          teacherId: widget.teacherId,
          classId: _classId,
          className: (_classData['class_name'] ?? '').toString(),
        ),
      ),
    );
    await _load();
  }

  Future<Map<String, dynamic>> _classAction(
    String endpoint,
    Map<String, String> values,
  ) async {
    final response = await http.post(
      Uri.parse(ApiConfig.flutter(endpoint)),
      body: {
        'teacher_id': widget.teacherId,
        'class_id': _classId,
        ...values,
      },
    );
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Unable to complete the request.').toString()
          : 'Unable to complete the request.');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> _editClassName() async {
    final controller = TextEditingController(
      text: (_classData['class_name'] ?? '').toString(),
    );
    final formKey = GlobalKey<FormState>();
    final newName = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Edit class name'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            maxLength: 150,
            decoration: const InputDecoration(
              labelText: 'Class Name',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Class name is required.'
                : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, controller.text.trim());
              }
            },
            style: FilledButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
            ),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null) return;
    setState(() => _loading = true);
    try {
      await _classAction('kss_update_class.php', {'class_name': newName});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class name updated.')),
      );
      await _load();
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  Future<void> _archiveClass() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Archive class?'),
        content: const Text(
          'This class will be removed from My Classes. Student profiles and assessment history will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _loading = true);
    try {
      await _classAction('kss_archive_class.php', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class archived successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.toString().replaceFirst('Exception: ', '')),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('KSS Class'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded)),
          PopupMenuButton<String>(
            tooltip: 'Class options',
            enabled: !_loading,
            onSelected: (value) {
              if (value == 'edit') _editClassName();
              if (value == 'archive') _archiveClass();
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'edit',
                child: ListTile(
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit class name'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'archive',
                child: ListTile(
                  leading: Icon(Icons.archive_outlined, color: Colors.red),
                  title: Text('Archive class'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final padding = width >= 1100
              ? 36.0
              : width >= 600
                  ? 24.0
                  : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
                padding, width >= 600 ? 24 : 16, padding, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1500),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _header(width < 600),
                    const SizedBox(height: 12),
                    _tabs(),
                    const SizedBox(height: 22),
                    if (_loading)
                      const Padding(
                        padding: EdgeInsets.only(top: 48),
                        child: Center(
                            child: CircularProgressIndicator(
                                color: Growkids.purpleFlo)),
                      )
                    else if (_error != null)
                      _message(Icons.error_outline_rounded,
                          'Unable to load class', _error!, _load)
                    else
                      _tabContent(),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _header(bool compact) {
    return Container(
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E1E8)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final details = Row(children: [
            Container(
              width: compact ? 42 : 48,
              height: compact ? 42 : 48,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FF),
                  borderRadius: BorderRadius.circular(13)),
              child:
                  const Icon(Icons.school_rounded, color: Growkids.purpleFlo),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text((_classData['class_name'] ?? '-').toString(),
                      style: TextStyle(
                          fontSize: compact ? 18 : 20,
                          fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text(
                    '${_classData['subject_name'] ?? widget.initialClass['subject_name'] ?? '-'} • Tahun ${_classData['year_level'] ?? widget.initialClass['year_level'] ?? '-'} • ${_classData['academic_year'] ?? ''}',
                    maxLines: compact ? 2 : 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF777486)),
                  ),
                ],
              ),
            ),
          ]);
          final count = Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
                color: const Color(0xFFF3F2F7),
                borderRadius: BorderRadius.circular(20)),
            child: Text(
                '${_students.length}/${_classData['max_students'] ?? widget.initialClass['max_students'] ?? 8} students',
                style:
                    const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                details,
                const SizedBox(height: 12),
                Align(alignment: Alignment.centerLeft, child: count),
              ],
            );
          }
          return Row(children: [
            Expanded(child: details),
            const SizedBox(width: 12),
            count
          ]);
        },
      ),
    );
  }

  Widget _tabs() {
    const labels = ['Assessment', 'Students', 'Progress'];
    const icons = [
      Icons.fact_check_outlined,
      Icons.groups_rounded,
      Icons.insights_rounded
    ];
    final phone = MediaQuery.sizeOf(context).width < 430;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
          color: const Color(0xFFECEBF1),
          borderRadius: BorderRadius.circular(14)),
      child: Row(
          children: List.generate(labels.length, (index) {
        final selected = _selectedTab == index;
        return Expanded(
          child: TextButton.icon(
            onPressed: () => setState(() => _selectedTab = index),
            icon: Icon(icons[index], size: 19),
            label: phone ? const SizedBox.shrink() : Text(labels[index]),
            style: TextButton.styleFrom(
              foregroundColor:
                  selected ? Growkids.purpleFlo : const Color(0xFF777486),
              backgroundColor: selected ? Colors.white : Colors.transparent,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        );
      })),
    );
  }

  Widget _tabContent() {
    if (_selectedTab == 0) {
      return KssCurriculumBrowser(
        teacherId: widget.teacherId,
        classId: _classId,
      );
    }
    if (_selectedTab == 2) {
      return KssStudentProgress(
        teacherId: widget.teacherId,
        classId: _classId,
      );
    }
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E8EF))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                  child: Text('Students',
                      style: TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w800))),
              FilledButton.icon(
                  onPressed: _manageStudents,
                  icon: const Icon(Icons.manage_accounts_rounded),
                  label: const Text('Manage'),
                  style: FilledButton.styleFrom(
                      backgroundColor: Growkids.purpleFlo)),
            ],
          ),
          const SizedBox(height: 12),
          if (_students.isEmpty)
            const Padding(
                padding: EdgeInsets.symmetric(vertical: 26),
                child: Center(
                    child: Text('No students enrolled yet.',
                        style: TextStyle(color: Color(0xFF777486)))))
          else
            ..._students.map((student) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                      backgroundColor: const Color(0xFFEDE8FF),
                      child: Text(
                          (student['student_name'] ?? '?')
                              .toString()[0]
                              .toUpperCase(),
                          style: const TextStyle(
                              color: Growkids.purpleFlo,
                              fontWeight: FontWeight.w800))),
                  title: Text((student['student_name'] ?? '-').toString(),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text((student['student_branch'] ?? '').toString()),
                )),
        ],
      ),
    );
  }

  Widget _message(
      IconData icon, String title, String text, VoidCallback? action) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE9E8EF))),
      child: Column(children: [
        Icon(icon, color: Growkids.purpleFlo, size: 42),
        const SizedBox(height: 12),
        Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777486))),
        if (action != null) ...[
          const SizedBox(height: 16),
          FilledButton(onPressed: action, child: const Text('Try Again'))
        ]
      ]),
    );
  }
}
