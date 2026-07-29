import 'dart:convert';
import 'dart:typed_data';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:printing/printing.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopHomeProgramLibraryLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramMaterialLibraryPage extends StatefulWidget {
  const HomeProgramMaterialLibraryPage({super.key});

  @override
  State<HomeProgramMaterialLibraryPage> createState() =>
      _HomeProgramMaterialLibraryPageState();
}

class _HomeProgramMaterialLibraryPageState
    extends State<HomeProgramMaterialLibraryPage> {
  static final _url = ApiConfig.flutter('program_get_materials.php');

  final _search = TextEditingController();
  Timer? _debounce;

  bool _loading = true;
  String? _error;

  List<Map<String, dynamic>> _materials = [];
  List<String> _categories = [];

  String _query = '';
  String _selectedCategory = 'All';

  int _page = 1;
  int _limit = 20;
  int _total = 0;

  int get _totalPages {
    if (_total <= 0) return 1;
    return (_total / _limit).ceil();
  }

  @override
  void initState() {
    super.initState();
    _search.addListener(_onSearchChanged);
    _load(page: 1);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounce?.cancel();

    _debounce = Timer(const Duration(milliseconds: 450), () {
      final nextQuery = _search.text.trim();

      if (nextQuery == _query) return;

      _query = nextQuery;
      _load(page: 1);
    });
  }

  int _toInt(dynamic value, int fallback) {
    return int.tryParse((value ?? '').toString()) ?? fallback;
  }

  Future<void> _load({int? page}) async {
    final nextPage = page ?? _page;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final uri = Uri.parse(_url).replace(
        queryParameters: {
          'page': nextPage.toString(),
          'limit': _limit.toString(),
          if (_query.isNotEmpty) 'q': _query,
          if (_selectedCategory != 'All') 'category': _selectedCategory,
        },
      );

      final res = await http.get(uri);
      final decoded = jsonDecode(res.body);

      if (decoded['status'] != 'success') {
        throw Exception(decoded['message'] ?? 'Failed to load materials');
      }

      final data = decoded['materials'];
      final categories = decoded['categories'];
      final pagination =
          decoded['pagination'] is Map ? decoded['pagination'] as Map : {};

      final nextCategories = categories is List
          ? categories
              .map((item) => item.toString().trim())
              .where((item) => item.isNotEmpty)
              .toSet()
              .toList()
          : _categories;

      nextCategories.sort(
        (a, b) => a.toLowerCase().compareTo(b.toLowerCase()),
      );

      if (!mounted) return;

      setState(() {
        _materials = data is List
            ? data.map((item) => Map<String, dynamic>.from(item)).toList()
            : [];

        _categories = nextCategories;
        _page = _toInt(pagination['page'], nextPage);
        _limit = _toInt(pagination['limit'], _limit);
        _total = _toInt(pagination['total'], 0);
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

  Future<void> _openCategoryFilter() async {
    final picked = _useDesktopHomeProgramLibraryLayout(context)
        ? await showDialog<String>(
            context: context,
            builder: (_) => _DesktopCategoryDialog(
              categories: ['All', ..._categories],
              selectedCategory: _selectedCategory,
            ),
          )
        : await showModalBottomSheet<String>(
            context: context,
            backgroundColor: const Color(0xFFF6F7FB),
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
            ),
            builder: (_) => _CategoryFilterSheet(
              categories: ['All', ..._categories],
              selectedCategory: _selectedCategory,
            ),
          );

    if (picked == null || picked == _selectedCategory) return;

    setState(() => _selectedCategory = picked);
    _load(page: 1);
  }

  void _clearFilters() {
    _debounce?.cancel();
    _search.clear();

    setState(() {
      _query = '';
      _selectedCategory = 'All';
    });

    _load(page: 1);
  }

  @override
  Widget build(BuildContext context) {
    final hasFilter = _query.isNotEmpty || _selectedCategory != 'All';

    if (_useDesktopHomeProgramLibraryLayout(context)) {
      return _buildDesktopPage(hasFilter);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Material Library'),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          _LibrarySearchPanel(
            searchController: _search,
            selectedCategory: _selectedCategory,
            total: _total,
            loading: _loading,
            hasFilter: hasFilter,
            onCategoryTap: _openCategoryFilter,
            onClear: _clearFilters,
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(page: _page),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(2.h, 1.h, 2.h, 2.h),
                children: [
                  if (_loading)
                    Padding(
                      padding: EdgeInsets.only(top: 20.h),
                      child: const Center(
                        child: CircularProgressIndicator(
                          color: Growkids.purpleFlo,
                        ),
                      ),
                    )
                  else if (_error != null)
                    _MessageCard(text: _error!, isError: true)
                  else if (_materials.isEmpty)
                    _MessageCard(
                      text: hasFilter
                          ? 'No material found. Try another search or category.'
                          : 'No materials uploaded yet.',
                    )
                  else ...[
                    _ResultSummary(
                      page: _page,
                      limit: _limit,
                      total: _total,
                    ),
                    SizedBox(height: 1.h),
                    ..._materials.map((item) => _MaterialCard(item: item)),
                    _PaginationBar(
                      page: _page,
                      totalPages: _totalPages,
                      onPrevious:
                          _page > 1 ? () => _load(page: _page - 1) : null,
                      onNext: _page < _totalPages
                          ? () => _load(page: _page + 1)
                          : null,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopPage(bool hasFilter) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FC),
      appBar: AppBar(
        toolbarHeight: 68,
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        centerTitle: true,
        title: const Text(
          'Material Library',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : () => _load(page: _page),
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1440),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 25, vertical: 19),
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
                      const Icon(
                        Icons.folder_copy_rounded,
                        color: Colors.white,
                        size: 35,
                      ),
                      const SizedBox(width: 15),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'HOME PROGRAM RESOURCES',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Material Library',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _loading ? 'Loading...' : '$_total materials',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFE3E6EC)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: TextField(
                            controller: _search,
                            style: const TextStyle(fontSize: 11),
                            decoration: InputDecoration(
                              hintText: 'Search material...',
                              prefixIcon:
                                  const Icon(Icons.search_rounded, size: 19),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FB),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(11),
                                borderSide: BorderSide.none,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      OutlinedButton.icon(
                        onPressed: _openCategoryFilter,
                        icon: const Icon(Icons.tune_rounded, size: 18),
                        label: Text(
                          _selectedCategory == 'All'
                              ? 'All categories'
                              : _selectedCategory,
                        ),
                      ),
                      if (hasFilter) ...[
                        const SizedBox(width: 8),
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Clear'),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                Expanded(
                  child: _loading
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Growkids.purpleFlo,
                          ),
                        )
                      : _error != null
                          ? _MessageCard(text: _error!, isError: true)
                          : _materials.isEmpty
                              ? _MessageCard(
                                  text: hasFilter
                                      ? 'No material found for this filter.'
                                      : 'No materials uploaded yet.',
                                )
                              : GridView.builder(
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 3,
                                    mainAxisExtent: 205,
                                    crossAxisSpacing: 14,
                                    mainAxisSpacing: 14,
                                  ),
                                  itemCount: _materials.length,
                                  itemBuilder: (_, index) =>
                                      _DesktopMaterialCard(
                                    item: _materials[index],
                                  ),
                                ),
                ),
                if (!_loading && _materials.isNotEmpty)
                  _PaginationBar(
                    page: _page,
                    totalPages: _totalPages,
                    onPrevious: _page > 1 ? () => _load(page: _page - 1) : null,
                    onNext: _page < _totalPages
                        ? () => _load(page: _page + 1)
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopMaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;
  const _DesktopMaterialCard({required this.item});

  List<_MaterialFile> _files() {
    final raw = item['files'] is List ? item['files'] as List : const [];
    final parsed = raw
        .whereType<Map>()
        .map((file) => _MaterialFile.fromMap(Map<String, dynamic>.from(file)))
        .where((file) => file.url.isNotEmpty)
        .toList();
    if (parsed.isNotEmpty) return parsed;
    final fallback = _MaterialFile.fromMap({
      'file_name': item['file_name'],
      'file_type': item['file_type'],
      'file_url': item['file_url'],
    });
    return fallback.url.isEmpty ? const [] : [fallback];
  }

  void _open(BuildContext context) {
    final files = _files();
    if (files.length == 1 && files.first.fileType == 'pdf') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => _HomeProgramPdfPreviewPage(file: files.first),
        ),
      );
      return;
    }
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 620),
          child: _MaterialFilesSheet(
            title: (item['title'] ?? 'Material').toString(),
            files: files,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = (item['title'] ?? 'Untitled material').toString();
    final category = (item['category'] ?? 'General').toString();
    final description = (item['description'] ?? '').toString();
    final files = _files();

    return InkWell(
      onTap: () => _open(context),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
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
                  child: Icon(
                    files.any((file) => file.fileType == 'pdf')
                        ? Icons.picture_as_pdf_rounded
                        : Icons.article_rounded,
                    color: Growkids.purpleFlo,
                    size: 22,
                  ),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${files.length} file${files.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                      color: Color(0xFF747986),
                      fontSize: 8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF30323C),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              category,
              style: TextStyle(
                color: Growkids.purpleFlo,
                fontSize: 8,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 9),
            Expanded(
              child: Text(
                description.isEmpty ? 'No description provided.' : description,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Color(0xFF858A97),
                  fontSize: 8,
                  height: 1.4,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Open material',
                  style: TextStyle(
                    color: Growkids.purpleFlo,
                    fontSize: 8,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.arrow_forward_rounded,
                  color: Growkids.purpleFlo,
                  size: 16,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopCategoryDialog extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  const _DesktopCategoryDialog({
    required this.categories,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter Category',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: categories.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (_, index) {
                    final category = categories[index];
                    final selected = category == selectedCategory;
                    return ListTile(
                      onTap: () => Navigator.pop(context, category),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                      tileColor: selected
                          ? Growkids.purpleFlo.withValues(alpha: .09)
                          : const Color(0xFFF7F8FB),
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: selected
                            ? Growkids.purpleFlo
                            : const Color(0xFF999DA9),
                      ),
                      title: Text(category),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MaterialCard extends StatelessWidget {
  final Map<String, dynamic> item;

  const _MaterialCard({required this.item});

  @override
  Widget build(BuildContext context) {
    final files = item['files'] is List ? item['files'] as List : const [];
    final fileCountRaw = (item['file_count'] ?? files.length).toString();
    final fileCount = int.tryParse(fileCountRaw) ?? files.length;
    final type = fileCount > 1
        ? '$fileCount FILES'
        : (item['file_type'] ?? '').toString().toUpperCase();
    final title = (item['title'] ?? 'Untitled material').toString();
    final category = (item['category'] ?? 'General').toString();
    final description = (item['description'] ?? '').toString();
    final uploadedByName = (item['uploaded_by_name'] ?? '').toString().trim();

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openFiles(context, title),
      child: Container(
        margin: EdgeInsets.only(bottom: 2.h),
        padding: EdgeInsets.all(2.h),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
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
              radius: 4.h,
              backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.10),
              child: Icon(
                Icons.description_rounded,
                color: Growkids.purpleFlo,
                size: 4.h,
              ),
            ),
            SizedBox(width: 2.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 14.sp)),
                  const SizedBox(height: 4),
                  Text(category,
                      style: TextStyle(
                          color: Colors.black.withValues(alpha: 0.55),
                          fontSize: 13.sp)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (uploadedByName.isNotEmpty)
                        _MetaChip(
                          icon: Icons.person_rounded,
                          text: uploadedByName,
                        ),
                      if (fileCount > 0)
                        _MetaChip(
                          icon: Icons.attach_file_rounded,
                          text:
                              '$fileCount file${fileCount == 1 ? '' : 's'} attached',
                        ),
                    ],
                  ),
                  if (description.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12.sp)),
                  ],
                ],
              ),
            ),
            SizedBox(width: 2.w),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(type,
                      style: const TextStyle(
                          color: Color(0xFF2563EB),
                          fontWeight: FontWeight.w800)),
                ),
                const SizedBox(height: 8),
                Icon(
                  Icons.visibility_rounded,
                  color: Growkids.purpleFlo.withValues(alpha: 0.72),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openFiles(BuildContext context, String title) {
    final files = _normalisedFiles();

    if (files.length == 1 && files.first.fileType == 'pdf') {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _HomeProgramPdfPreviewPage(file: files.first),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _MaterialFilesSheet(title: title, files: files),
    );
  }

  List<_MaterialFile> _normalisedFiles() {
    final files = item['files'] is List ? item['files'] as List : const [];
    final parsed = files
        .whereType<Map>()
        .map((file) => _MaterialFile.fromMap(Map<String, dynamic>.from(file)))
        .where((file) => file.url.isNotEmpty)
        .toList();

    if (parsed.isNotEmpty) return parsed;

    final fallback = _MaterialFile.fromMap({
      'file_name': item['file_name'],
      'file_type': item['file_type'],
      'file_url': item['file_url'],
    });

    return fallback.url.isEmpty ? const [] : [fallback];
  }
}

class _MaterialFilesSheet extends StatelessWidget {
  final String title;
  final List<_MaterialFile> files;

  const _MaterialFilesSheet({required this.title, required this.files});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 3.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
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
            if (files.isEmpty)
              Text(
                'No file found for this material.',
                style: TextStyle(color: Colors.black.withValues(alpha: 0.6)),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: files.length,
                  separatorBuilder: (_, __) => SizedBox(height: 1.h),
                  itemBuilder: (context, index) {
                    return _MaterialFileTile(file: files[index]);
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MaterialFileTile extends StatelessWidget {
  final _MaterialFile file;

  const _MaterialFileTile({required this.file});

  @override
  Widget build(BuildContext context) {
    final canPreview = file.fileType == 'pdf';

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () {
        if (!canPreview) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('DOCX preview is not available in app yet.'),
            ),
          );
          return;
        }

        Navigator.pop(context);
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _HomeProgramPdfPreviewPage(file: file),
          ),
        );
      },
      child: Container(
        padding: EdgeInsets.all(1.5.h),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F7FB),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: canPreview
                    ? Growkids.purpleFlo.withValues(alpha: 0.10)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                canPreview
                    ? Icons.picture_as_pdf_rounded
                    : Icons.article_rounded,
                color: canPreview
                    ? Growkids.purpleFlo
                    : Colors.black.withValues(alpha: 0.55),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canPreview ? 'Tap to preview' : 'Document file',
                    style: TextStyle(
                      color: Colors.black.withValues(alpha: 0.55),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              canPreview
                  ? Icons.visibility_rounded
                  : Icons.insert_drive_file_rounded,
              color: canPreview
                  ? Growkids.purpleFlo
                  : Colors.black.withValues(alpha: 0.45),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeProgramPdfPreviewPage extends StatelessWidget {
  final _MaterialFile file;

  const _HomeProgramPdfPreviewPage({required this.file});

  Future<Uint8List> _loadPdf() async {
    final res = await http.get(Uri.parse(file.url));
    if (res.statusCode != 200) {
      throw Exception('Failed to load PDF');
    }
    return res.bodyBytes;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: Text(
          file.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: PdfPreview(
        canChangeOrientation: false,
        canChangePageFormat: false,
        canDebug: false,
        build: (_) => _loadPdf(),
      ),
    );
  }
}

class _LibrarySearchPanel extends StatelessWidget {
  final TextEditingController searchController;
  final String selectedCategory;
  final int total;
  final bool loading;
  final bool hasFilter;
  final VoidCallback onCategoryTap;
  final VoidCallback onClear;

  const _LibrarySearchPanel({
    required this.searchController,
    required this.selectedCategory,
    required this.total,
    required this.loading,
    required this.hasFilter,
    required this.onCategoryTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.fromLTRB(2.h, 2.h, 2.h, 0),
      padding: EdgeInsets.all(1.6.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText: 'Search home program...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    filled: true,
                    fillColor: const Color(0xFFF6F7FB),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 1.h),
              InkWell(
                onTap: onCategoryTap,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  height: 52,
                  width: 52,
                  decoration: BoxDecoration(
                    color: Growkids.purpleFlo.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.tune_rounded,
                    color: Growkids.purpleFlo,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _SmallPill(
                      icon: Icons.category_rounded,
                      text: selectedCategory == 'All'
                          ? 'All categories'
                          : selectedCategory,
                    ),
                    _SmallPill(
                      icon: Icons.folder_copy_rounded,
                      text: loading ? 'Loading...' : '$total material',
                    ),
                  ],
                ),
              ),
              if (hasFilter)
                TextButton(
                  onPressed: onClear,
                  child: const Text('Clear'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CategoryFilterSheet extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;

  const _CategoryFilterSheet({
    required this.categories,
    required this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(2.h, 1.5.h, 2.h, 2.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 5,
              width: 44,
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
                    'Filter Category',
                    style: TextStyle(
                      fontSize: 16.sp,
                      fontWeight: FontWeight.w800,
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
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: categories.length,
                separatorBuilder: (_, __) => SizedBox(height: 0.8.h),
                itemBuilder: (context, index) {
                  final category = categories[index];
                  final selected = category == selectedCategory;

                  return InkWell(
                    onTap: () => Navigator.pop(context, category),
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 1.6.h,
                        vertical: 1.4.h,
                      ),
                      decoration: BoxDecoration(
                        color: selected
                            ? Growkids.purpleFlo.withValues(alpha: 0.12)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: selected
                              ? Growkids.purpleFlo.withValues(alpha: 0.30)
                              : Colors.black.withValues(alpha: 0.06),
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
                                : Colors.black.withValues(alpha: 0.38),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              category == 'All' ? 'All categories' : category,
                              style: TextStyle(
                                fontSize: 13.sp,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w500,
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
      ),
    );
  }
}

class _ResultSummary extends StatelessWidget {
  final int page;
  final int limit;
  final int total;

  const _ResultSummary({
    required this.page,
    required this.limit,
    required this.total,
  });

  @override
  Widget build(BuildContext context) {
    final start = total == 0 ? 0 : ((page - 1) * limit) + 1;
    final endRaw = page * limit;
    final end = endRaw > total ? total : endRaw;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.4.h, vertical: 1.h),
      decoration: BoxDecoration(
        color: Growkids.purpleFlo.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.auto_awesome_rounded,
            color: Growkids.purpleFlo,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Showing $start-$end of $total materials',
              style: TextStyle(
                color: Colors.black.withValues(alpha: 0.68),
                fontSize: 12.sp,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PaginationBar extends StatelessWidget {
  final int page;
  final int totalPages;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  const _PaginationBar({
    required this.page,
    required this.totalPages,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.only(top: 1.h),
      padding: EdgeInsets.all(1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left_rounded),
              label: const Text('Prev'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Growkids.purpleFlo,
                side: BorderSide(
                  color: Growkids.purpleFlo.withValues(alpha: 0.24),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 1.2.h),
            child: Text(
              '$page / $totalPages',
              style: TextStyle(
                fontSize: 12.sp,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: ElevatedButton.icon(
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
              label: const Text('Next'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Growkids.purpleFlo,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallPill extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SmallPill({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black.withValues(alpha: 0.55)),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontSize: 11.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _MaterialFile {
  final String name;
  final String fileType;
  final String url;

  const _MaterialFile({
    required this.name,
    required this.fileType,
    required this.url,
  });

  factory _MaterialFile.fromMap(Map<String, dynamic> map) {
    final name = (map['file_name'] ?? 'Material file').toString();
    final fileType = (map['file_type'] ?? '').toString().toLowerCase();
    final url = (map['file_url'] ?? '').toString();

    return _MaterialFile(name: name, fileType: fileType, url: url);
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.black.withValues(alpha: 0.55)),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontSize: 12.sp,
            ),
          ),
        ],
      ),
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
