import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/create_kss_class_page.dart';
import 'package:growcheck_app_v2/pages/kss_assessment/kss_class_page.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;

class KssAssessmentHome extends StatefulWidget {
  final String teacherId;

  const KssAssessmentHome({super.key, required this.teacherId});

  @override
  State<KssAssessmentHome> createState() => _KssAssessmentHomeState();
}

class _KssAssessmentHomeState extends State<KssAssessmentHome> {
  final _url = ApiConfig.flutter('kss_classes.php');
  List<Map<String, dynamic>> _classes = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadClasses();
  }

  Future<void> _loadClasses() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final response = await http.post(
        Uri.parse(_url),
        body: {'teacher_id': widget.teacherId},
      );
      final decoded = json.decode(response.body);
      if (response.statusCode != 200 ||
          decoded is! Map ||
          decoded['success'] != true) {
        throw Exception(decoded is Map
            ? (decoded['message'] ?? 'Unable to load classes.').toString()
            : 'Unable to load classes.');
      }
      final raw = decoded['data'];
      final classes = raw is List
          ? raw
              .map((item) => Map<String, dynamic>.from(item as Map))
              .toList()
          : <Map<String, dynamic>>[];
      if (mounted) setState(() => _classes = classes);
    } catch (error) {
      if (mounted) {
        setState(() {
          _classes = [];
          _error = error.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreateClass() async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => CreateKssClassPage(teacherId: widget.teacherId),
      ),
    );
    if (created == true) await _loadClasses();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text('KSS Assessment'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _loadClasses,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      floatingActionButton: _classes.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: _openCreateClass,
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Create Class'),
            ),
      body: RefreshIndicator(
        onRefresh: _loadClasses,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontalPadding = width >= 1100
                ? 36.0
                : width >= 600
                    ? 24.0
                    : 16.0;
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                width >= 600 ? 24 : 16,
                horizontalPadding,
                96,
              ),
              child: Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1280),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Hero(compact: width < 600),
                      const SizedBox(height: 24),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'My Classes',
                              style: Theme.of(context)
                                  .textTheme
                                  .headlineSmall
                                  ?.copyWith(
                                    color: const Color(0xFF26233A),
                                    fontWeight: FontWeight.w800,
                                  ),
                            ),
                          ),
                          if (_classes.isNotEmpty)
                            Text(
                              '${_classes.length} ${_classes.length == 1 ? 'class' : 'classes'}',
                              style: const TextStyle(color: Color(0xFF777486)),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _content(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _content() {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.only(top: 70),
        child: Center(
          child: CircularProgressIndicator(color: Growkids.purpleFlo),
        ),
      );
    }
    if (_error != null) {
      return _MessageCard(
        icon: Icons.cloud_off_rounded,
        title: 'Unable to load classes',
        message: _error!,
        label: 'Try Again',
        onPressed: _loadClasses,
      );
    }
    if (_classes.isEmpty) {
      return _MessageCard(
        icon: Icons.school_outlined,
        title: 'No KSS classes yet.',
        message: 'Create your first class to begin organising assessments.',
        label: 'Create First Class',
        onPressed: _openCreateClass,
      );
    }
    return LayoutBuilder(
      builder: (_, constraints) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _classes.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: constraints.maxWidth >= 1120
              ? 3
              : constraints.maxWidth >= 650
                  ? 2
                  : 1,
          crossAxisSpacing: 14,
          mainAxisSpacing: 14,
          mainAxisExtent: 154,
        ),
        itemBuilder: (_, index) => _ClassCard(
          data: _classes[index],
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => KssClassPage(
                  teacherId: widget.teacherId,
                  initialClass: _classes[index],
                ),
              ),
            );
            await _loadClasses();
          },
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  final bool compact;

  const _Hero({required this.compact});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 18 : 24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Growkids.purpleFlo, Growkids.purpleBright],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.22),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: [
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'KSS Assessment',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  'Manage your classes and classroom assessments.',
                  style: TextStyle(color: Color(0xFFEDE8FF), fontSize: 14),
                ),
              ],
            ),
          ),
          SizedBox(width: compact ? 10 : 16),
          Icon(
            Icons.auto_stories_rounded,
            color: Colors.white,
            size: compact ? 36 : 48,
          ),
        ],
      ),
    );
  }
}

class _ClassCard extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onTap;
  const _ClassCard({required this.data, required this.onTap});

  int _number(String key) => int.tryParse((data[key] ?? 0).toString()) ?? 0;

  @override
  Widget build(BuildContext context) {
    final count = _number('student_count');
    final maximum = _number('max_students');
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFFE9E8EF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x0A000000),
                blurRadius: 14,
                offset: Offset(0, 7),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFEDE8FF),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.class_rounded,
                  color: Growkids.purpleFlo,
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      (data['class_name'] ?? '-').toString(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF26233A),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${data['subject_name'] ?? '-'} • Tahun ${data['year_level'] ?? '-'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF777486)),
                    ),
                    const SizedBox(height: 9),
                    Text(
                      '$count / $maximum Students • ${data['academic_year'] ?? ''}',
                      style: const TextStyle(
                        color: Growkids.purpleFlo,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: Color(0xFFAAA7B5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MessageCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String label;
  final VoidCallback onPressed;

  const _MessageCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 42),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9E8EF)),
      ),
      child: Column(
        children: [
          Container(
            width: 68,
            height: 68,
            decoration: const BoxDecoration(
              color: Color(0xFFEDE8FF),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Growkids.purpleFlo, size: 34),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Color(0xFF26233A),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF777486)),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.add_rounded),
            label: Text(label),
            style: FilledButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}
