import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopHomeProgramUploadLayout(BuildContext context) {
  final platform = Theme.of(context).platform;
  return (platform == TargetPlatform.macOS ||
          platform == TargetPlatform.windows ||
          platform == TargetPlatform.linux) &&
      MediaQuery.sizeOf(context).width >= 900;
}

class HomeProgramUploadMaterialPage extends StatefulWidget {
  final String therapistId;
  final String therapistName;

  const HomeProgramUploadMaterialPage({
    super.key,
    required this.therapistId,
    required this.therapistName,
  });

  @override
  State<HomeProgramUploadMaterialPage> createState() =>
      _HomeProgramUploadMaterialPageState();
}

class _HomeProgramUploadMaterialPageState
    extends State<HomeProgramUploadMaterialPage> {
  static final _url = ApiConfig.flutter('home_program_upload_material.php');
  static final _materialsUrl = ApiConfig.flutter('program_get_materials.php');

  final _title = TextEditingController();
  final _category = TextEditingController();
  final _description = TextEditingController();

  List<PlatformFile> _files = [];
  List<String> _categoryOptions = [];
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCategoryOptions();
  }

  Future<void> _loadCategoryOptions() async {
    try {
      final res = await http.get(Uri.parse(_materialsUrl));
      final decoded = jsonDecode(res.body);
      final data = decoded['materials'];
      if (decoded['status'] != 'success' || data is! List) return;

      final categories = <String>{};
      for (final item in data) {
        if (item is! Map) continue;
        final category =
            _normalizeCategory((item['category'] ?? '').toString());
        if (category.isNotEmpty) categories.add(category);
      }

      if (!mounted) return;
      setState(() {
        _categoryOptions = categories.toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      });
    } catch (_) {
      // Category suggestions are optional. Keep upload usable if this fails.
    }
  }

  String _normalizeCategory(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    return trimmed[0].toUpperCase() + trimmed.substring(1);
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx'],
      withData: false,
      allowMultiple: true,
    );

    if (result == null || result.files.isEmpty) return;
    setState(() {
      final existingPaths = _files.map((file) => file.path).toSet();
      final newFiles = result.files.where((file) {
        return file.path != null && !existingPaths.contains(file.path);
      });
      _files = [..._files, ...newFiles];
    });
  }

  Future<void> _submit() async {
    if (_title.text.trim().isEmpty || _files.isEmpty) {
      _snack('Title and at least one file are required.');
      return;
    }

    setState(() => _saving = true);

    try {
      final request = http.MultipartRequest('POST', Uri.parse(_url))
        ..fields['title'] = _title.text.trim()
        ..fields['category'] = _normalizeCategory(_category.text)
        ..fields['description'] = _description.text.trim()
        ..fields['uploaded_by'] = widget.therapistId
        ..fields['uploaded_by_name'] = widget.therapistName.trim();

      for (final file in _files) {
        request.files.add(
          await http.MultipartFile.fromPath('files[]', file.path!),
        );
      }

      final streamed = await request.send();
      final body = await streamed.stream.bytesToString();
      final decoded = jsonDecode(body);

      if (decoded['status'] == 'success') {
        if (!mounted) return;
        _snack('Material uploaded successfully.');
        Navigator.pop(context, true);
      } else {
        _snack(decoded['message'] ?? 'Upload failed.');
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
  void dispose() {
    _title.dispose();
    _category.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopHomeProgramUploadLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        title: const Text('Upload Material'),
      ),
      body: ListView(
        padding: EdgeInsets.all(2.h),
        children: [
          _field(_title, 'Title'),
          SizedBox(height: 1.h),
          _field(
            _category,
            'Category',
            hintText: 'Type new category or choose below',
            prefixIcon: Icons.category_rounded,
            inputFormatters: const [_UppercaseFirstLetterFormatter()],
          ),
          SizedBox(height: 1.h),
          if (_categoryOptions.isNotEmpty) ...[
            _CategoryChips(
              categories: _categoryOptions,
              onSelected: (category) {
                _category.text = category;
                _category.selection = TextSelection.collapsed(
                  offset: _category.text.length,
                );
              },
            ),
            SizedBox(height: 1.h),
          ],
          SizedBox(height: 1.h),
          _field(_description, 'Description', maxLines: 4),
          const SizedBox(height: 12),
          InkWell(
            onTap: _saving ? null : _pickFiles,
            borderRadius: BorderRadius.circular(18),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 2.h, vertical: 2.2.h),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
              ),
              child: Row(
                children: [
                  Container(
                    height: 5.h,
                    width: 5.h,
                    decoration: BoxDecoration(
                      color: Growkids.purpleFlo.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.upload_file_rounded,
                      color: Growkids.purpleFlo,
                    ),
                  ),
                  SizedBox(width: 2.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'PDF or DOCX files',
                          style: TextStyle(
                            fontSize: 12.sp,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _files.isEmpty
                              ? 'No files selected'
                              : '${_files.length} file${_files.length == 1 ? '' : 's'} selected',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.black.withValues(alpha: 0.56),
                            fontSize: 10.sp,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.add_rounded, color: Growkids.purpleFlo),
                ],
              ),
            ),
          ),
          if (_files.isNotEmpty) ...[
            const SizedBox(height: 10),
            ..._files.map(
              (file) => _SelectedFileTile(
                name: file.name,
                onRemove: _saving
                    ? null
                    : () {
                        setState(() {
                          _files =
                              _files.where((item) => item != file).toList();
                        });
                      },
              ),
            ),
          ],
          SizedBox(height: 2.h),
          SizedBox(
            height: 6.h,
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _saving ? null : _submit,
              icon: _saving
                  ? SizedBox(
                      height: 6.h,
                      width: 5.h,
                      child: const CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.cloud_upload_rounded),
              label: Text(_saving ? 'Uploading...' : 'Upload Material',
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
          'Upload Material',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w900),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                _desktopUploadHero(),
                const SizedBox(height: 18),
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: _desktopSurface(
                          child: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _desktopSectionHeading(
                                  Icons.edit_document,
                                  'Material details',
                                  'Describe and organise this home-program resource.',
                                ),
                                const SizedBox(height: 18),
                                _desktopField(_title, 'Material title'),
                                const SizedBox(height: 13),
                                _desktopField(
                                  _category,
                                  'Category',
                                  hintText:
                                      'Type a category or choose an existing one',
                                  inputFormatters: const [
                                    _UppercaseFirstLetterFormatter(),
                                  ],
                                ),
                                if (_categoryOptions.isNotEmpty) ...[
                                  const SizedBox(height: 11),
                                  Wrap(
                                    spacing: 7,
                                    runSpacing: 7,
                                    children: _categoryOptions
                                        .map(
                                          (category) => ActionChip(
                                            label: Text(category),
                                            onPressed: () => setState(() =>
                                                _category.text = category),
                                            visualDensity:
                                                VisualDensity.compact,
                                            backgroundColor: Growkids.purpleFlo
                                                .withValues(alpha: .08),
                                            side: BorderSide(
                                              color: Growkids.purpleFlo
                                                  .withValues(alpha: .16),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                  ),
                                ],
                                const SizedBox(height: 13),
                                _desktopField(
                                  _description,
                                  'Description',
                                  maxLines: 6,
                                  hintText:
                                      'Add instructions or a short description...',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        flex: 4,
                        child: _desktopSurface(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _desktopSectionHeading(
                                Icons.attach_file_rounded,
                                'Files',
                                'Attach one or more PDF or DOCX files.',
                              ),
                              const SizedBox(height: 18),
                              InkWell(
                                onTap: _saving ? null : _pickFiles,
                                borderRadius: BorderRadius.circular(14),
                                child: Container(
                                  width: double.infinity,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 24),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF7F6FF),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: Growkids.purpleFlo
                                          .withValues(alpha: .22),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.cloud_upload_outlined,
                                        color: Growkids.purpleFlo,
                                        size: 34,
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'Choose files from computer',
                                        style: TextStyle(
                                          color: Color(0xFF444752),
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'PDF or DOCX',
                                        style: TextStyle(
                                          color: Color(0xFF9296A2),
                                          fontSize: 8,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 13),
                              Expanded(
                                child: _files.isEmpty
                                    ? const Center(
                                        child: Text(
                                          'No files selected',
                                          style: TextStyle(
                                            color: Color(0xFF9A9EAA),
                                            fontSize: 10,
                                          ),
                                        ),
                                      )
                                    : ListView(
                                        children: _files
                                            .map(
                                              (file) => _SelectedFileTile(
                                                name: file.name,
                                                onRemove: _saving
                                                    ? null
                                                    : () => setState(
                                                          () => _files = _files
                                                              .where((item) =>
                                                                  item != file)
                                                              .toList(),
                                                        ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 15),
                _desktopUploadActionBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopUploadHero() {
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
      child: const Row(
        children: [
          Icon(Icons.upload_file_rounded, color: Colors.white, size: 34),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ADD RESOURCE TO LIBRARY',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Upload Home Program Material',
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

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4E7ED)),
      ),
      child: child,
    );
  }

  Widget _desktopSectionHeading(
    IconData icon,
    String title,
    String subtitle,
  ) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: Growkids.purpleFlo.withValues(alpha: .09),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(icon, color: Growkids.purpleFlo, size: 21),
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
                style: const TextStyle(color: Color(0xFF8B8F9C), fontSize: 8),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _desktopField(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      style: const TextStyle(fontSize: 11),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        filled: true,
        fillColor: const Color(0xFFF8F9FC),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFE0E3EA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Growkids.purpleFlo, width: 1.4),
        ),
      ),
    );
  }

  Widget _desktopUploadActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 17, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E6EC)),
      ),
      child: Row(
        children: [
          Text(
            '${_files.length} file${_files.length == 1 ? '' : 's'} selected',
            style: const TextStyle(color: Color(0xFF7C818E), fontSize: 9),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.cloud_upload_rounded, size: 18),
            label: Text(_saving ? 'Uploading...' : 'Upload Material'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    TextEditingController controller,
    String label, {
    int maxLines = 1,
    TextInputType? keyboardType,
    String? hintText,
    String? helperText,
    IconData? prefixIcon,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        keyboardType: keyboardType,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          helperText: helperText,
          prefixIcon: prefixIcon == null
              ? null
              : Icon(prefixIcon, color: Growkids.purpleFlo),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _CategoryChips extends StatelessWidget {
  final List<String> categories;
  final ValueChanged<String> onSelected;

  const _CategoryChips({
    required this.categories,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(1.4.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.history_rounded,
                color: Colors.black.withValues(alpha: 0.45),
                size: 2.h,
              ),
              const SizedBox(width: 6),
              Text(
                'Existing categories',
                style: TextStyle(
                  color: Colors.black.withValues(alpha: 0.62),
                  fontSize: 12.sp,
                ),
              ),
            ],
          ),
          SizedBox(height: 1.h),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: categories
                .map(
                  (category) => ActionChip(
                    label: Text(category),
                    onPressed: () => onSelected(category),
                    backgroundColor: Growkids.purpleFlo.withValues(alpha: 0.08),
                    labelStyle: TextStyle(
                      color: Growkids.purpleFlo,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.sp,
                    ),
                    side: BorderSide(
                      color: Growkids.purpleFlo.withValues(alpha: 0.18),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _UppercaseFirstLetterFormatter extends TextInputFormatter {
  const _UppercaseFirstLetterFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    final formatted = text[0].toUpperCase() + text.substring(1);
    if (formatted == text) return newValue;

    return newValue.copyWith(
      text: formatted,
      selection: TextSelection.collapsed(
        offset: newValue.selection.baseOffset.clamp(0, formatted.length),
      ),
      composing: TextRange.empty,
    );
  }
}

class _SelectedFileTile extends StatelessWidget {
  final String name;
  final VoidCallback? onRemove;

  const _SelectedFileTile({
    required this.name,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.description_rounded,
            color: Growkids.purpleFlo,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: onRemove,
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
    );
  }
}
