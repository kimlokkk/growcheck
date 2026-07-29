import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/student_hub/student_hub.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopHomeProgramAssignLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramAssignPage extends StatefulWidget {
  final String staffId;
  final UserRoleHub role;

  const HomeProgramAssignPage({
    super.key,
    required this.staffId,
    required this.role,
  });

  @override
  State<HomeProgramAssignPage> createState() => _HomeProgramAssignPageState();
}

class _HomeProgramAssignPageState extends State<HomeProgramAssignPage> {
  static final _materialsUrl = ApiConfig.flutter('program_get_materials.php');
  String get _studentsUrl {
    if (widget.role == UserRoleHub.teacher) {
      return ApiConfig.flutter('home_program_get_teacher_students.php');
    }

    return ApiConfig.flutter('home_program_get_official_students.php');
  }

  static final _assignUrl =
      ApiConfig.flutter('home_program_assign_material.php');

  /*static const _materialsUrl =
      'http://app-kizzu.test/growkids/flutter/program_get_materials.php';
  static const _studentsUrl =
      'http://app-kizzu.test/growkids/flutter/home_program_get_official_students.php';
  static const _assignUrl =
      'http://app-kizzu.test/growkids/flutter/home_program_assign_material.php';*/

  final _note = TextEditingController();

  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>> _students = [];
  Map<String, dynamic>? _selectedMaterial;
  Map<String, dynamic>? _selectedStudent;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final materialsRes = await http.get(Uri.parse(_materialsUrl));
      final studentsRes = await http.post(
        Uri.parse(_studentsUrl),
        body: widget.role == UserRoleHub.teacher
            ? {'teacher_id': widget.staffId}
            : {'therapist_id': widget.staffId},
      );

      final materialsJson = jsonDecode(materialsRes.body);
      final studentsJson = jsonDecode(studentsRes.body);

      if (materialsJson['status'] != 'success') {
        throw Exception(materialsJson['message'] ?? 'Failed to load materials');
      }
      if (studentsJson['status'] != 'success') {
        throw Exception(studentsJson['message'] ?? 'Failed to load students');
      }

      final materials = materialsJson['materials'];
      final students = studentsJson['students'];

      if (!mounted) return;
      setState(() {
        _materials = materials is List
            ? materials.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        _students = students is List
            ? students.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];
        _selectedMaterial = _materials.isNotEmpty ? _materials.first : null;
        _selectedStudent = _students.isNotEmpty ? _students.first : null;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _assign() async {
    if (_selectedMaterial == null || _selectedStudent == null) {
      _snack('Please select material and official student.');
      return;
    }

    setState(() => _saving = true);

    try {
      final res = await http.post(
        Uri.parse(_assignUrl),
        body: {
          'material_id': (_selectedMaterial!['id'] ?? '').toString(),
          'student_id': (_selectedStudent!['stud_id'] ?? '').toString(),
          'therapist_id': widget.staffId,
          'therapist_note': _note.text.trim(),
        },
      );
      final decoded = jsonDecode(res.body);

      if (decoded['status'] == 'success') {
        if (!mounted) return;
        _snack(decoded['message'] ?? 'Material assigned successfully.');
        Navigator.pop(context, true);
      } else {
        _snack(decoded['message'] ?? 'Failed to assign material.');
      }
    } catch (e) {
      _snack(e.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopHomeProgramAssignLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Assign Program'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: EdgeInsets.all(2.h),
                children: [
                  if (_error != null) ...[
                    _MessageCard(text: _error!, isError: true),
                    SizedBox(height: 1.h),
                  ],
                  _PickerCard(
                    title: 'Material',
                    subtitle: 'Choose document set to send',
                    emptyText: 'No materials uploaded yet.',
                    icon: Icons.folder_copy_rounded,
                    value: _selectedMaterial,
                    items: _materials,
                    labelBuilder: (item) =>
                        (item['title'] ?? 'Untitled material').toString(),
                    subtitleBuilder: (item) {
                      final category =
                          (item['category'] ?? 'General').toString();
                      final count = (item['file_count'] ?? '0').toString();
                      return '$category • $count file${count == '1' ? '' : 's'}';
                    },
                    onChanged: (item) =>
                        setState(() => _selectedMaterial = item),
                  ),
                  SizedBox(height: 1.h),
                  _PickerCard(
                    title: 'Official Student',
                    subtitle: 'Only official students are available',
                    emptyText: 'No official students found.',
                    icon: Icons.school_rounded,
                    value: _selectedStudent,
                    items: _students,
                    labelBuilder: (item) =>
                        (item['stud_name'] ?? 'Unnamed student').toString(),
                    subtitleBuilder: (item) =>
                        (item['stud_branch'] ?? 'Official').toString(),
                    onChanged: (item) =>
                        setState(() => _selectedStudent = item),
                  ),
                  SizedBox(height: 1.h),
                  TextField(
                    controller: _note,
                    minLines: 3,
                    maxLines: 5,
                    decoration: InputDecoration(
                      labelText: 'Therapist note',
                      hintText: 'Optional instructions for parent',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  SizedBox(height: 2.h),
                  SizedBox(
                    height: 6.h,
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _saving ? null : _assign,
                      icon: _saving
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.send_rounded),
                      label: Text(_saving ? 'Sending...' : 'Send to Parent',
                          style: TextStyle(fontSize: 14.sp)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Growkids.purpleFlo,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildDesktopPage() {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Assign Home Program',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: Growkids.purpleFlo),
            )
          : Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1280),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      _desktopAssignHero(),
                      const SizedBox(height: 18),
                      if (_error != null) ...[
                        _MessageCard(text: _error!, isError: true),
                        const SizedBox(height: 12),
                      ],
                      Expanded(
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: _DesktopPickerPanel(
                                title: '1. Select material',
                                subtitle:
                                    'Choose the resource to send to the family.',
                                icon: Icons.folder_copy_rounded,
                                items: _materials,
                                value: _selectedMaterial,
                                labelBuilder: (item) =>
                                    (item['title'] ?? 'Untitled material')
                                        .toString(),
                                detailBuilder: (item) {
                                  final category =
                                      (item['category'] ?? 'General')
                                          .toString();
                                  final count =
                                      (item['file_count'] ?? '0').toString();
                                  return '$category · $count files';
                                },
                                onChanged: (item) =>
                                    setState(() => _selectedMaterial = item),
                              ),
                            ),
                            const SizedBox(width: 18),
                            Expanded(
                              child: _DesktopPickerPanel(
                                title: '2. Select student',
                                subtitle:
                                    'Only students in your official caseload are shown.',
                                icon: Icons.school_rounded,
                                items: _students,
                                value: _selectedStudent,
                                labelBuilder: (item) =>
                                    (item['stud_name'] ?? 'Unnamed student')
                                        .toString(),
                                detailBuilder: (item) =>
                                    (item['stud_branch'] ?? 'Official')
                                        .toString(),
                                onChanged: (item) =>
                                    setState(() => _selectedStudent = item),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFE3E6EC)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _note,
                                minLines: 2,
                                maxLines: 3,
                                style: const TextStyle(fontSize: 11),
                                decoration: InputDecoration(
                                  labelText: 'Instructions for parent',
                                  hintText:
                                      'Add optional guidance for this activity...',
                                  filled: true,
                                  fillColor: const Color(0xFFF8F9FC),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(11),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFE0E3EA),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            ElevatedButton.icon(
                              onPressed: _saving ? null : _assign,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        color: Colors.white,
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.send_rounded, size: 18),
                              label: Text(
                                _saving ? 'Sending...' : 'Send to Parent',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Growkids.purpleFlo,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 22,
                                  vertical: 18,
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
            ),
    );
  }

  Widget _desktopAssignHero() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .76),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Row(
        children: [
          Icon(Icons.assignment_ind_rounded, color: Colors.white, size: 36),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NEW HOME PROGRAM',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Assign Activity to Student',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 23,
                    fontWeight: FontWeight.w900,
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

class _DesktopPickerPanel extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Map<String, dynamic>> items;
  final Map<String, dynamic>? value;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) detailBuilder;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _DesktopPickerPanel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.items,
    required this.value,
    required this.labelBuilder,
    required this.detailBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Growkids.purpleFlo.withValues(alpha: .09),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: Growkids.purpleFlo, size: 22),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF30323C),
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF8B8F9C),
                        fontSize: 8,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('No options available.'))
                : ListView.separated(
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, index) {
                      final item = items[index];
                      final selected = identical(item, value);
                      return InkWell(
                        onTap: () => onChanged(item),
                        borderRadius: BorderRadius.circular(11),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: selected
                                ? Growkids.purpleFlo.withValues(alpha: .09)
                                : const Color(0xFFF8F9FC),
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: selected
                                  ? Growkids.purpleFlo.withValues(alpha: .30)
                                  : const Color(0xFFE3E6EC),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                selected
                                    ? Icons.radio_button_checked_rounded
                                    : Icons.radio_button_off_rounded,
                                color: selected
                                    ? Growkids.purpleFlo
                                    : const Color(0xFF9A9EAA),
                                size: 18,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      labelBuilder(item),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Color(0xFF41444F),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      detailBuilder(item),
                                      style: const TextStyle(
                                        color: Color(0xFF8C909C),
                                        fontSize: 8,
                                      ),
                                    ),
                                  ],
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
}

class _PickerCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String emptyText;
  final IconData icon;
  final Map<String, dynamic>? value;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;
  final ValueChanged<Map<String, dynamic>> onChanged;

  const _PickerCard({
    required this.title,
    required this.subtitle,
    required this.emptyText,
    required this.icon,
    required this.value,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 3.h,
                backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.10),
                child: Icon(
                  icon,
                  color: Growkids.purpleFlo,
                  size: 3.h,
                ),
              ),
              SizedBox(width: 3.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 15.sp,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          SizedBox(height: 2.h),
          if (items.isEmpty)
            Text(
              emptyText,
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.58),
                fontSize: 14.sp,
              ),
            )
          else
            InkWell(
              onTap: () async {
                final picked = await showModalBottomSheet<Map<String, dynamic>>(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: const Color(0xFFF6F7FB),
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(22)),
                  ),
                  builder: (_) => _SearchPickerSheet(
                    title: title,
                    items: items,
                    labelBuilder: labelBuilder,
                    subtitleBuilder: subtitleBuilder,
                  ),
                );

                if (picked != null) {
                  onChanged(picked);
                }
              },
              borderRadius: BorderRadius.circular(14),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.all(2.h),
                decoration: BoxDecoration(
                  color: const Color(0xFFF6F7FB),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: value == null
                          ? Text(
                              'Select $title',
                              style: TextStyle(
                                color: Colors.black.withValues(alpha: 0.52),
                                fontSize: 14.sp,
                              ),
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  labelBuilder(value!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontSize: 14.sp),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  subtitleBuilder(value!),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.black.withValues(alpha: 0.54),
                                    fontSize: 12.sp,
                                  ),
                                ),
                              ],
                            ),
                    ),
                    Icon(
                      Icons.search_rounded,
                      color: Growkids.purpleFlo.withValues(alpha: 0.82),
                    ),
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

class _SearchPickerSheet extends StatefulWidget {
  final String title;
  final List<Map<String, dynamic>> items;
  final String Function(Map<String, dynamic>) labelBuilder;
  final String Function(Map<String, dynamic>) subtitleBuilder;

  const _SearchPickerSheet({
    required this.title,
    required this.items,
    required this.labelBuilder,
    required this.subtitleBuilder,
  });

  @override
  State<_SearchPickerSheet> createState() => _SearchPickerSheetState();
}

class _SearchPickerSheetState extends State<_SearchPickerSheet> {
  final _search = TextEditingController();
  late List<Map<String, dynamic>> _filtered;

  @override
  void initState() {
    super.initState();
    _filtered = widget.items;
    _search.addListener(_filter);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _filter() {
    final query = _search.text.trim().toLowerCase();
    setState(() {
      _filtered = widget.items.where((item) {
        final label = widget.labelBuilder(item).toLowerCase();
        final subtitle = widget.subtitleBuilder(item).toLowerCase();
        return label.contains(query) || subtitle.contains(query);
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      minChildSize: 0.42,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(2.h, 1.5.h, 2.h, 2.h),
            child: Column(
              children: [
                Container(
                  width: 4.h,
                  height: 0.5.h,
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                SizedBox(height: 2.h),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select ${widget.title}',
                        style: TextStyle(
                          fontSize: 16.sp,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                SizedBox(height: 1.h),
                TextField(
                  controller: _search,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Search ${widget.title.toLowerCase()}',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                SizedBox(height: 1.h),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            'No matching ${widget.title.toLowerCase()}',
                            style: TextStyle(
                              color: Colors.black.withValues(alpha: 0.58),
                              fontSize: 12.sp,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) {
                            final item = _filtered[index];
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              child: Material(
                                type: MaterialType.transparency,
                                child: ListTile(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  tileColor: Growkids.purpleFlo
                                      .withValues(alpha: 0.10),
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 1.h, horizontal: 2.h),
                                  onTap: () => Navigator.pop(context, item),
                                  title: Text(
                                    widget.labelBuilder(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(fontSize: 14.sp),
                                  ),
                                  subtitle: Text(
                                    widget.subtitleBuilder(item),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing:
                                      const Icon(Icons.chevron_right_rounded),
                                ),
                              ),
                            );
                          },
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

class _MessageCard extends StatelessWidget {
  final String text;
  final bool isError;

  const _MessageCard({required this.text, this.isError = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        color: isError ? const Color(0xFFFFEBEE) : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(text),
    );
  }
}
