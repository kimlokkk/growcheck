import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class ManageKssStudentsPage extends StatefulWidget {
  final String teacherId;
  final String classId;
  final String className;

  const ManageKssStudentsPage({
    super.key,
    required this.teacherId,
    required this.classId,
    required this.className,
  });

  @override
  State<ManageKssStudentsPage> createState() =>
      _ManageKssStudentsPageState();
}

class _ManageKssStudentsPageState extends State<ManageKssStudentsPage> {
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _enrolled = [];
  List<Map<String, dynamic>> _available = [];
  final Set<String> _selected = {};
  bool _loading = true;
  bool _working = false;
  String? _error;
  int _maxStudents = 8;

  int get _remaining => _maxStudents - _enrolled.length;

  List<Map<String, dynamic>> get _filteredAvailable =>
      _filterStudents(_available);

  List<Map<String, dynamic>> _filterStudents(
    List<Map<String, dynamic>> students,
  ) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) return students;
    return students.where((student) {
      final searchable = [
        student['student_name'],
        student['student_id'],
        student['student_branch'],
      ].map((value) => (value ?? '').toString().toLowerCase()).join(' ');
      return searchable.contains(query);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, String> body,
  ) async {
    final response = await http.post(
      Uri.parse(ApiConfig.flutter(endpoint)),
      body: body,
    );
    final decoded = json.decode(response.body);
    if (response.statusCode != 200 ||
        decoded is! Map ||
        decoded['success'] != true) {
      throw Exception(decoded is Map
          ? (decoded['message'] ?? 'Unable to complete the request.').toString()
          : 'Unable to complete the request.');
    }
    return Map<String, dynamic>.from(decoded as Map);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final body = {'teacher_id': widget.teacherId, 'class_id': widget.classId};
      final responses = await Future.wait([
        _post('kss_class_students.php', body),
        _post('kss_available_students.php', body),
      ]);
      final classData = Map<String, dynamic>.from(responses[0]['data'] as Map);
      final availableData = Map<String, dynamic>.from(responses[1]['data'] as Map);
      if (!mounted) return;
      setState(() {
        _enrolled = (classData['students'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _available = (availableData['students'] as List? ?? [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList();
        _maxStudents = int.tryParse(
              (availableData['max_students'] ?? 8).toString(),
            ) ??
            8;
        _selected.clear();
      });
    } catch (error) {
      if (mounted) {
        setState(() =>
            _error = error.toString().replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggle(String id, bool selected) {
    setState(() {
      if (selected) {
        if (_selected.length < _remaining) _selected.add(id);
      } else {
        _selected.remove(id);
      }
    });
  }

  Future<void> _addSelected() async {
    if (_selected.isEmpty) return;
    setState(() => _working = true);
    try {
      await _post('kss_add_students.php', {
        'teacher_id': widget.teacherId,
        'class_id': widget.classId,
        'student_ids': json.encode(_selected.toList()),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Students added successfully.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  Future<void> _remove(Map<String, dynamic> student) async {
    final name = (student['student_name'] ?? 'this student').toString();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          'Remove $name from this class? Their GrowCheck profile and assessment history will not be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _working = true);
    try {
      await _post('kss_remove_student.php', {
        'teacher_id': widget.teacherId,
        'class_id': widget.classId,
        'student_id': student['student_id'].toString(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name removed from the class.')),
      );
      await _load();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Exception: ', '')),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Manage Students'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(onPressed: _loading || _working ? null : _load, icon: const Icon(Icons.refresh_rounded)),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final padding = width >= 1100 ? 36.0 : width >= 600 ? 24.0 : 16.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(padding, width >= 600 ? 24 : 16, padding, 32),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _summary(),
                    const SizedBox(height: 18),
                    if (_loading)
                      const Padding(padding: EdgeInsets.only(top: 48), child: Center(child: CircularProgressIndicator(color: Growkids.purpleFlo)))
                    else if (_error != null)
                      _errorCard()
                    else if (width >= 800)
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _enrolledPanel()),
                          const SizedBox(width: 16),
                          Expanded(child: _availablePanel()),
                        ],
                      )
                    else ...[
                      _enrolledPanel(),
                      const SizedBox(height: 16),
                      _availablePanel(),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _summary() => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Growkids.purpleFlo, Growkids.purpleBright]),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(children: [
          const Icon(Icons.groups_rounded, color: Colors.white, size: 38),
          const SizedBox(width: 14),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(widget.className, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)), const SizedBox(height: 4), Text('${_enrolled.length} / $_maxStudents students', style: const TextStyle(color: Color(0xFFEDE8FF)))])),
        ]),
      );

  Widget _searchField() => TextField(
        controller: _searchController,
        onChanged: (_) => setState(() {}),
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          hintText: 'Search available student by name or ID...',
          prefixIcon: const Icon(
            Icons.search_rounded,
            color: Growkids.purpleFlo,
          ),
          suffixIcon: _searchController.text.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear search',
                  onPressed: () {
                    _searchController.clear();
                    setState(() {});
                  },
                  icon: const Icon(Icons.close_rounded),
                ),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE9E8EF)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFE9E8EF)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Growkids.purpleFlo,
              width: 1.5,
            ),
          ),
        ),
      );

  Widget _panel(String title, Widget content) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0xFFE9E8EF))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)), const SizedBox(height: 12), content]),
      );

  Widget _enrolledPanel() => _panel(
        'Enrolled Students',
        _enrolled.isEmpty
            ? const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: Text('No students enrolled yet.')),
              )
            : Column(children: _enrolled.map((student) => ListTile(contentPadding: EdgeInsets.zero, leading: _avatar(student), title: Text((student['student_name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((student['student_branch'] ?? '').toString()), trailing: IconButton(tooltip: 'Remove', onPressed: _working ? null : () => _remove(student), icon: const Icon(Icons.person_remove_outlined, color: Colors.red)))).toList()),
      );

  Widget _availablePanel() => _panel(
        'Available Students',
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_remaining <= 0 ? 'Class is full.' : 'Select up to $_remaining student${_remaining == 1 ? '' : 's'}.', style: const TextStyle(color: Color(0xFF777486))),
          const SizedBox(height: 14),
          _searchField(),
          const SizedBox(height: 8),
          if (_filteredAvailable.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Text(
                  _searchController.text.isEmpty
                      ? 'No available students.'
                      : 'No available students match your search.',
                ),
              ),
            )
          else
            ..._filteredAvailable.map((student) {
              final id = student['student_id'].toString();
              final checked = _selected.contains(id);
              final disabled = _remaining <= 0 || (!checked && _selected.length >= _remaining);
              return CheckboxListTile(value: checked, onChanged: disabled ? null : (value) => _toggle(id, value == true), controlAffinity: ListTileControlAffinity.leading, contentPadding: EdgeInsets.zero, activeColor: Growkids.purpleFlo, secondary: _avatar(student), title: Text((student['student_name'] ?? '-').toString(), style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text((student['student_branch'] ?? '').toString()));
            }),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: _working || _selected.isEmpty ? null : _addSelected, icon: _working ? const SizedBox(width: 17, height: 17, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.person_add_alt_1_rounded), label: Text(_selected.isEmpty ? 'Add Students' : 'Add ${_selected.length} Student${_selected.length == 1 ? '' : 's'}'), style: FilledButton.styleFrom(backgroundColor: Growkids.purpleFlo, padding: const EdgeInsets.symmetric(vertical: 14))),
        ]),
      );

  Widget _avatar(Map<String, dynamic> student) {
    final name = (student['student_name'] ?? '?').toString();
    return CircleAvatar(backgroundColor: const Color(0xFFEDE8FF), child: Text(name.isEmpty ? '?' : name[0].toUpperCase(), style: const TextStyle(color: Growkids.purpleFlo, fontWeight: FontWeight.w800)));
  }

  Widget _errorCard() => _panel(
        'Unable to load students',
        Column(children: [Text(_error!, textAlign: TextAlign.center), const SizedBox(height: 14), FilledButton(onPressed: _load, child: const Text('Try Again'))]),
      );
}
