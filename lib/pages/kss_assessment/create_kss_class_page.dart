import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class CreateKssClassPage extends StatefulWidget {
  final String teacherId;

  const CreateKssClassPage({super.key, required this.teacherId});

  @override
  State<CreateKssClassPage> createState() => _CreateKssClassPageState();
}

class _CreateKssClassPageState extends State<CreateKssClassPage> {
  final _formKey = GlobalKey<FormState>();
  final _className = TextEditingController();
  final _academicYear = TextEditingController(
    text: DateTime.now().year.toString(),
  );
  final _optionsUrl = ApiConfig.flutter('kss_curriculum_options.php');
  final _createUrl = ApiConfig.flutter('kss_create_class.php');

  List<Map<String, dynamic>> _years = [];
  int? _selectedYear;
  String? _selectedCurriculumSubjectId;
  bool _loadingOptions = true;
  bool _saving = false;
  String? _error;

  int _asInt(dynamic value) => int.tryParse((value ?? '').toString()) ?? 0;

  List<Map<String, dynamic>> get _subjects {
    final matching = _years.where(
      (item) => _asInt(item['year_level']) == _selectedYear,
    );
    if (matching.isEmpty || matching.first['subjects'] is! List) return [];
    return (matching.first['subjects'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _loadOptions();
  }

  @override
  void dispose() {
    _className.dispose();
    _academicYear.dispose();
    super.dispose();
  }

  Future<void> _loadOptions() async {
    setState(() {
      _loadingOptions = true;
      _error = null;
    });
    try {
      final response = await http.post(Uri.parse(_optionsUrl));
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load curriculum options.')
                .toString()
            : 'Unable to load curriculum options.');
      }
      final raw = decoded['data'];
      final years = raw is List
          ? raw
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _years = years;
        if (years.length == 1) {
          _selectedYear = _asInt(years.first['year_level']);
        }
      });
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingOptions = false);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(_createUrl),
        body: {
          'teacher_id': widget.teacherId,
          'class_name': _className.text.trim(),
          'curriculum_subject_id': _selectedCurriculumSubjectId!,
          'academic_year': _academicYear.text.trim(),
        },
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to create the class.').toString()
            : 'Unable to create the class.');
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Class created successfully.')),
      );
      Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  InputDecoration _decoration(String label, IconData icon) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFE2E1E8)),
    );
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Growkids.purpleFlo),
      filled: true,
      fillColor: const Color(0xFFF9F9FC),
      border: border,
      enabledBorder: border,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Growkids.purpleFlo, width: 1.5),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('Create Class'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final horizontalPadding = width >= 1100
              ? 36.0
              : width >= 600
                  ? 24.0
                  : 16.0;
          final cardPadding = width >= 600 ? 24.0 : 18.0;
          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              horizontalPadding,
              width >= 600 ? 24 : 16,
              horizontalPadding,
              32,
            ),
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Container(
                  padding: EdgeInsets.all(cardPadding),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE9E8EF)),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x0A000000),
                        blurRadius: 18,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: _loadingOptions
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 48),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: Growkids.purpleFlo,
                            ),
                          ),
                        )
                      : _buildForm(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Class Details',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: Color(0xFF26233A),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose a curriculum and give your class a clear name.',
            style: TextStyle(color: Color(0xFF777486)),
          ),
          if (_error != null) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline_rounded,
                    color: Color(0xFFC63D3D),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFF9B2C2C)),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          TextFormField(
            controller: _className,
            maxLength: 150,
            textInputAction: TextInputAction.next,
            decoration: _decoration('Class Name', Icons.class_rounded),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter a class name.'
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            value: _selectedYear,
            decoration: _decoration(
              'Tahun',
              Icons.calendar_view_month_rounded,
            ),
            items: _years.map((item) {
              final year = _asInt(item['year_level']);
              return DropdownMenuItem(
                value: year,
                child: Text('Tahun $year'),
              );
            }).toList(),
            onChanged: (value) => setState(() {
              _selectedYear = value;
              _selectedCurriculumSubjectId = null;
            }),
            validator: (value) =>
                value == null ? 'Please select a year level.' : null,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            value: _selectedCurriculumSubjectId,
            decoration: _decoration('Subject', Icons.menu_book_rounded),
            items: _subjects
                .map(
                  (item) => DropdownMenuItem(
                    value: item['curriculum_subject_id'].toString(),
                    child: Text(item['subject_name'].toString()),
                  ),
                )
                .toList(),
            onChanged: _selectedYear == null
                ? null
                : (value) => setState(
                      () => _selectedCurriculumSubjectId = value,
                    ),
            validator: (value) =>
                value == null ? 'Please select a subject.' : null,
          ),
          const SizedBox(height: 18),
          TextFormField(
            controller: _academicYear,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: _decoration('Academic Year', Icons.event_rounded),
            validator: (value) {
              final year = int.tryParse(value ?? '');
              if (year == null ||
                  year < 2000 ||
                  year > DateTime.now().year + 5) {
                return 'Please enter a valid academic year.';
              }
              return null;
            },
          ),
          const SizedBox(height: 26),
          FilledButton.icon(
            onPressed: _saving || _years.isEmpty ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.add_rounded),
            label: Text(_saving ? 'Creating...' : 'Create Class'),
            style: FilledButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              disabledBackgroundColor:
                  Growkids.purpleFlo.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
          if (_years.isEmpty) ...[
            const SizedBox(height: 14),
            TextButton.icon(
              onPressed: _loadOptions,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Reload curriculum options'),
            ),
          ],
        ],
      ),
    );
  }
}
