// add_daily_progress.dart
// ignore_for_file: use_build_context_synchronously

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:sizer/sizer.dart';

bool _useDesktopAddJournalLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class AddDailyProgressPage extends StatefulWidget {
  final String studId;
  final String studentName;
  final String teacherId;

  final bool isEdit;
  final String? progressId;
  final String? existingTitle;
  final String? existingContent;
  final String? existingLogDate;
  final List<String>? existingAttachments;

  const AddDailyProgressPage({
    super.key,
    required this.studId,
    required this.studentName,
    required this.teacherId,
    this.isEdit = false,
    this.progressId,
    this.existingTitle,
    this.existingContent,
    this.existingLogDate,
    this.existingAttachments,
  });

  @override
  State<AddDailyProgressPage> createState() => _AddDailyProgressPageState();
}

class _AddDailyProgressPageState extends State<AddDailyProgressPage> {
  final _formKey = GlobalKey<FormState>();
  bool _saving = false;

  DateTime _logDate = DateTime.now();

  final TextEditingController _titleCtrl = TextEditingController();
  final TextEditingController _contentCtrl = TextEditingController();

  final List<PlatformFile> _attachments = [];
  List<String> _existingAttachments = [];
  final List<String> _removedExistingAttachments = [];

  final ImagePicker _imagePicker = ImagePicker();

  static final String _journalBaseUrl =
      ApiConfig.journal(''); // Base URL for journal attachments

  static final String _saveEndpoint =
      ApiConfig.flutter('add_daily_progress.php');

  static final String _updateEndpoint =
      ApiConfig.flutter('update_daily_progress.php');

  /*static const String _journalBaseUrl =
      "http://app-kizzu.test/growkids/journal/";*/
  /*static const String _saveEndpoint =
      "http://app-kizzu.test/growkids/flutter/add_daily_progress.php";
  static const String _updateEndpoint =
      "http://app-kizzu.test/growkids/flutter/update_daily_progress.php";*/

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    super.dispose();
  }

  // --- FUNGSI PILIH FILE ---
  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'jpeg', 'pdf', 'doc', 'docx'],
      );

      if (result != null && mounted) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } on PlatformException catch (error) {
      _showError(
        error.code == 'ENTITLEMENT_NOT_FOUND'
            ? 'File permission is not active. Stop the app completely and run it again.'
            : 'Unable to open file picker: ${error.message ?? error.code}',
      );
    }
  }

  Future<void> _pickDesktopImages() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: kIsWeb,
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'gif'],
        dialogTitle: 'Select journal photos',
      );

      if (result != null && mounted) {
        setState(() {
          _attachments.addAll(result.files);
        });
      }
    } on PlatformException catch (error) {
      _showError(
        error.code == 'ENTITLEMENT_NOT_FOUND'
            ? 'Photo permission is not active. Stop the app completely and run it again.'
            : 'Unable to open photo picker: ${error.message ?? error.code}',
      );
    }
  }

  // --- FUNGSI BUANG FILE DARI LIST ---
  void _removeFile(PlatformFile file) {
    setState(() {
      _attachments.remove(file);
    });
  }

  void _removeExistingAttachment(String attachment) {
    setState(() {
      _existingAttachments.remove(attachment);
      if (!_removedExistingAttachments.contains(attachment)) {
        _removedExistingAttachments.add(attachment);
      }
    });
  }

  bool _isImageAttachment(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif');
  }

  String _attachmentUrl(String value) {
    final normalized = value.trim();
    if (normalized.startsWith('http://app-kizzu.test/growkids/journal/')) {
      return normalized.replaceFirst(
        'http://app-kizzu.test/growkids/journal/',
        _journalBaseUrl,
      );
    }

    if (normalized.startsWith('http://app-kizzu.test/growkids/')) {
      return normalized.replaceFirst(
        'http://app-kizzu.test/growkids/',
        'https://app.kizzukids.com.my/growkids/',
      );
    }

    if (normalized.startsWith('http://app.kizzukids.com.my/growkids/')) {
      return normalized.replaceFirst(
        'http://app.kizzukids.com.my/growkids/',
        'https://app.kizzukids.com.my/growkids/',
      );
    }

    if (normalized.startsWith('http://') || normalized.startsWith('https://')) {
      return normalized;
    }

    return '$_journalBaseUrl$normalized';
  }

  String _attachmentStorageName(String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return normalized;
    final uri = Uri.tryParse(normalized);
    if (uri != null && uri.pathSegments.isNotEmpty) {
      return uri.pathSegments.last;
    }
    return normalized.split('/').last;
  }

  void _previewAttachment(String attachment) {
    if (!_isImageAttachment(attachment)) return;

    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: EdgeInsets.all(2.h),
        child: InteractiveViewer(
          child: Image.network(
            _attachmentUrl(attachment),
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              color: Colors.grey[200],
              alignment: Alignment.center,
              child: Icon(Icons.broken_image, size: 6.h),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickFromGallery() async {
    try {
      final List<XFile> images = await _imagePicker.pickMultiImage();

      if (images.isNotEmpty) {
        final selectedImages = await Future.wait(
          images.map((img) async {
            final bytes = kIsWeb ? await img.readAsBytes() : null;
            return PlatformFile(
              name: img.name,
              path: kIsWeb ? null : img.path,
              size: bytes?.length ?? await img.length(),
              bytes: bytes,
            );
          }),
        );

        if (!mounted) return;
        setState(() {
          _attachments.addAll(selectedImages);
        });
      }
    } catch (e) {
      _showError('Failed to open gallery: $e');
      print(e);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _logDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Growkids.purpleFlo),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => _logDate = picked);
  }

  Future<void> _showAttachmentOptions() async {
    if (_useDesktopAddJournalLayout(context)) {
      await showDialog<void>(
        context: context,
        barrierColor: Colors.black.withValues(alpha: 0.48),
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 480,
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 28,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Growkids.purpleFlo.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.attach_file_rounded,
                        color: Growkids.purpleFlo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add attachment',
                            style: TextStyle(
                              color: Color(0xFF292B35),
                              fontSize: 18,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Choose photos or browse files from your computer.',
                            style: TextStyle(
                              color: Color(0xFF7D8290),
                              fontSize: 10,
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
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _desktopAttachmentOption(
                        icon: Icons.photo_library_rounded,
                        title: 'Photo Gallery',
                        subtitle: 'Select one or more images',
                        color: const Color(0xFF8057E8),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _pickDesktopImages();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _desktopAttachmentOption(
                        icon: Icons.folder_open_rounded,
                        title: 'Browse Files',
                        subtitle: 'Images, PDF or documents',
                        color: const Color(0xFF3478F6),
                        onTap: () {
                          Navigator.pop(dialogContext);
                          _pickFiles();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.photo_library_rounded,
                        color: Growkids.purpleFlo),
                    title: const Text('Open Gallery'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickFromGallery();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.attach_file_rounded,
                        color: Growkids.purpleFlo),
                    title: const Text('Browse Files'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickFiles();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- FUNGSI SAVE (MULTIPART REQUEST) ---
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isEdit &&
        (widget.progressId == null || widget.progressId!.trim().isEmpty)) {
      _showError('Missing progress ID for edit');
      return;
    }

    setState(() => _saving = true);

    try {
      final endpoint = widget.isEdit ? _updateEndpoint : _saveEndpoint;

      var request = http.MultipartRequest('POST', Uri.parse(endpoint));

      request.fields['stud_id'] = widget.studId;
      request.fields['teacher_id'] = widget.teacherId;
      request.fields['log_date'] = DateFormat('yyyy-MM-dd').format(_logDate);
      request.fields['title'] = _titleCtrl.text.trim();
      request.fields['content'] = _contentCtrl.text.trim();
      request.fields['status'] = 'draft';

      if (widget.isEdit) {
        request.fields['progress_id'] = widget.progressId!.trim();
        // Backend uses this list to remove selected existing attachments.
        request.fields['removed_attachments'] = jsonEncode(
          _removedExistingAttachments.map(_attachmentStorageName).toList(),
        );
      }

      if (_attachments.isNotEmpty) {
        for (var file in _attachments) {
          if (file.bytes != null) {
            request.files.add(
              http.MultipartFile.fromBytes(
                'attachments[]',
                file.bytes!,
                filename: file.name,
              ),
            );
          } else if (file.path != null && file.path!.isNotEmpty) {
            request.files.add(
              await http.MultipartFile.fromPath(
                'attachments[]',
                file.path!,
                filename: file.name,
              ),
            );
          }
        }
      }

      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);

        if (jsonResponse['status'] == 'success') {
          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.isEdit
                    ? 'Journal updated successfully!'
                    : 'Journal saved successfully!',
              ),
              backgroundColor: Colors.green,
            ),
          );

          Navigator.pop(context, true);
        } else {
          _showError(jsonResponse['message'] ?? 'Failed to save');
        }
      } else {
        _showError('Server Error: ${response.statusCode}');
      }
    } catch (e) {
      _showError('Error: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  void _prefillEditData() {
    if (!widget.isEdit) return;

    _titleCtrl.text = widget.existingTitle ?? '';
    _contentCtrl.text = widget.existingContent ?? '';

    if (widget.existingLogDate != null &&
        widget.existingLogDate!.trim().isNotEmpty) {
      try {
        _logDate = DateTime.parse(widget.existingLogDate!.trim());
      } catch (_) {}
    }

    _existingAttachments = List<String>.from(widget.existingAttachments ?? []);
  }

  Widget _buildExistingAttachmentTile(String attachment) {
    final fileLabel = attachment.toString().split('/').last;
    final isImage = _isImageAttachment(attachment);

    return Stack(
      children: [
        InkWell(
          onTap: isImage ? () => _previewAttachment(attachment) : null,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: 28.w,
            constraints: BoxConstraints(minHeight: 11.h),
            padding: EdgeInsets.all(1.h),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03), blurRadius: 8)
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    width: double.infinity,
                    height: 9.h,
                    child: Container(
                      color: Colors.grey[100],
                      child: isImage
                          ? Image.network(
                              _attachmentUrl(attachment),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Center(
                                child: Icon(Icons.broken_image,
                                    size: 4.h, color: Colors.grey[500]),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.insert_drive_file_rounded,
                                  size: 4.h, color: Growkids.purpleFlo),
                            ),
                    ),
                  ),
                ),
                SizedBox(height: 0.8.h),
                Text(
                  fileLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 9.5.sp, color: Colors.black87),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          top: 6,
          right: 6,
          child: InkWell(
            onTap: () => _removeExistingAttachment(attachment),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.close_rounded,
                  size: 18, color: Colors.redAccent),
            ),
          ),
        ),
      ],
    );
  }

  @override
  void initState() {
    super.initState();
    _prefillEditData();
  }

  @override
  Widget build(BuildContext context) {
    if (_useDesktopAddJournalLayout(context)) {
      return _buildDesktopPage();
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          widget.isEdit ? 'Edit Journal' : 'Add Journal',
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        // ✅ TIADA LAGI ACTION BUTTON DI SINI
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(2.h),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Info
              _HeaderJournal(widget.studentName),
              SizedBox(height: 2.h),

              // Date Picker
              _sectionTitle('Date'),
              InkWell(
                onTap: _pickDate,
                child: _card(
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          color: Growkids.purpleFlo),
                      SizedBox(width: 3.w),
                      Text(DateFormat('EEEE, d MMMM yyyy').format(_logDate),
                          style: TextStyle(fontSize: 12.sp)),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 2.h),

              // Title Input
              _sectionTitle('Title'),
              _card(
                child: TextFormField(
                  controller: _titleCtrl,
                  decoration: _inputDeco(
                      hint: 'e.g., Sensory Activity Progress',
                      icon: Icons.title_rounded),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? 'Please enter a title' : null,
                ),
              ),
              SizedBox(height: 2.h),

              // Content Input
              _sectionTitle('Content'),
              _card(
                child: TextFormField(
                  controller: _contentCtrl,
                  minLines: 6,
                  maxLines: 14,
                  decoration: _inputDeco(
                      hint: 'Write journal details here...',
                      icon: Icons.notes_rounded),
                ),
              ),
              SizedBox(height: 2.h),

              // --- ATTACHMENT SECTION ---
              _sectionTitle('Attachments', subtitle: ' (Photos/Files)'),

              InkWell(
                onTap: _showAttachmentOptions,
                borderRadius: BorderRadius.circular(15),
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(1.5.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(
                        color: Growkids.purpleFlo.withValues(alpha: 0.3),
                        style: BorderStyle.solid),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10)
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined,
                          color: Growkids.purpleFlo),
                      SizedBox(width: 2.w),
                      Text(
                        "Add Attachment",
                        style: TextStyle(
                          color: Growkids.purpleFlo,
                          fontWeight: FontWeight.bold,
                          fontSize: 11.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 1.5.h),

              // File List (Chips)
              // Existing attachments
              if (_existingAttachments.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    'Existing attachments',
                    style: TextStyle(fontSize: 11.sp, color: Colors.black54),
                  ),
                ),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: _existingAttachments
                      .map(_buildExistingAttachmentTile)
                      .toList(),
                ),
                SizedBox(height: 1.2.h),
              ],

// Newly selected attachments
              if (_attachments.isNotEmpty) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _attachments.map((file) {
                    return Container(
                      padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
                      decoration: BoxDecoration(
                        color: Colors.blueAccent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: Colors.blueAccent.withValues(alpha: 0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.insert_drive_file_rounded,
                              size: 14.sp, color: Colors.blueAccent),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 40.w),
                            child: Text(
                              file.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 10.sp, color: Colors.blue[800]),
                            ),
                          ),
                          const SizedBox(width: 5),
                          InkWell(
                            onTap: () => _removeFile(file),
                            child: const Icon(Icons.close_rounded,
                                size: 18, color: Colors.redAccent),
                          )
                        ],
                      ),
                    );
                  }).toList(),
                ),
                SizedBox(height: 1.2.h),
              ],

              SizedBox(height: 4.h), // Jarak sebelum butang submit

              // --- ✅ SUBMIT BUTTON DI BAWAH ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Growkids.purpleFlo,
                    disabledBackgroundColor:
                        Growkids.purpleFlo.withValues(alpha: 0.6),
                    padding: EdgeInsets.symmetric(vertical: 1.8.h),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                    shadowColor: Growkids.purpleFlo.withValues(alpha: 0.4),
                  ),
                  child: _saving
                      ? SizedBox(
                          width: 2.5.h,
                          height: 2.5.h,
                          child: const CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3),
                        )
                      : Text(
                          widget.isEdit ? "Update Journal" : "Submit Journal",
                          style: TextStyle(
                            fontSize: 13.sp,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),

              SizedBox(height: 5.h), // Extra padding bawah sekali
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopPage() {
    final pageTitle = widget.isEdit ? 'Edit Journal' : 'Add Journal';
    final attachmentCount = _existingAttachments.length + _attachments.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6FB),
      appBar: AppBar(
        toolbarHeight: 68,
        title: Text(
          pageTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w800,
          ),
        ),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1380),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(30, 28, 30, 28),
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  _desktopHero(attachmentCount),
                  const SizedBox(height: 20),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(flex: 6, child: _desktopEntryForm()),
                        const SizedBox(width: 20),
                        Expanded(flex: 4, child: _desktopAttachmentPanel()),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _desktopActionBar(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _desktopHero(int attachmentCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 21),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: 0.76),
          ],
        ),
        borderRadius: BorderRadius.circular(21),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleFlo.withValues(alpha: 0.18),
            blurRadius: 22,
            offset: const Offset(0, 9),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Text(
              widget.studentName.isEmpty
                  ? '?'
                  : widget.studentName[0].toUpperCase(),
              style: const TextStyle(
                color: Growkids.purpleFlo,
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
                Text(
                  widget.isEdit ? 'EDIT JOURNAL ENTRY' : 'NEW JOURNAL ENTRY',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  widget.studentName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 25,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Student ID ${widget.studId}  •  Record progress and observations',
                  style: const TextStyle(color: Colors.white70, fontSize: 11),
                ),
              ],
            ),
          ),
          _desktopHeroMetric(
            Icons.calendar_today_outlined,
            DateFormat('d MMM').format(_logDate),
            'Journal date',
          ),
          const SizedBox(width: 12),
          _desktopHeroMetric(
            Icons.attach_file_rounded,
            attachmentCount.toString(),
            'Attachments',
          ),
        ],
      ),
    );
  }

  Widget _desktopHeroMetric(IconData icon, String value, String label) {
    return Container(
      constraints: const BoxConstraints(minWidth: 120),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
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
                  fontSize: 15,
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

  Widget _desktopEntryForm() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Journal details',
            style: TextStyle(
              color: Color(0xFF242631),
              fontSize: 19,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Add the date, a clear title and your observation.',
            style: TextStyle(color: Color(0xFF777C8D), fontSize: 11),
          ),
          const SizedBox(height: 20),
          _desktopFieldLabel('Journal date'),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFFF8F9FC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE0E3EA)),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    color: Growkids.purpleFlo,
                    size: 19,
                  ),
                  const SizedBox(width: 11),
                  Text(
                    DateFormat('EEEE, d MMMM yyyy').format(_logDate),
                    style: const TextStyle(
                      color: Color(0xFF3B3E48),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFF9A9EAA),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          _desktopFieldLabel('Title'),
          TextFormField(
            controller: _titleCtrl,
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Please enter a title'
                : null,
            style: const TextStyle(fontSize: 12),
            decoration: _desktopInputDecoration(
              hint: 'e.g. Sensory Activity Progress',
              icon: Icons.title_rounded,
            ),
          ),
          const SizedBox(height: 18),
          _desktopFieldLabel('Observation / Progress'),
          Expanded(
            child: TextFormField(
              controller: _contentCtrl,
              expands: true,
              minLines: null,
              maxLines: null,
              textAlignVertical: TextAlignVertical.top,
              style: const TextStyle(fontSize: 12, height: 1.5),
              decoration: _desktopInputDecoration(
                hint: 'Write journal details here...',
                icon: Icons.notes_rounded,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAttachmentPanel() {
    return _desktopSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Attachments',
                      style: TextStyle(
                        color: Color(0xFF242631),
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'Photos, PDF or document files.',
                      style: TextStyle(
                        color: Color(0xFF777C8D),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filled(
                tooltip: 'Add attachment',
                onPressed: _showAttachmentOptions,
                style: IconButton.styleFrom(
                  backgroundColor: Growkids.purpleFlo,
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          const SizedBox(height: 17),
          Expanded(
            child: _existingAttachments.isEmpty && _attachments.isEmpty
                ? _desktopAttachmentEmpty()
                : ListView(
                    children: [
                      if (_existingAttachments.isNotEmpty) ...[
                        _desktopFieldLabel('Existing files'),
                        ..._existingAttachments.map(
                          _desktopExistingAttachment,
                        ),
                        const SizedBox(height: 12),
                      ],
                      if (_attachments.isNotEmpty) ...[
                        _desktopFieldLabel('New files'),
                        ..._attachments.map(_desktopNewAttachment),
                      ],
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showAttachmentOptions,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 18),
              label: const Text('Add attachment'),
              style: OutlinedButton.styleFrom(
                foregroundColor: Growkids.purpleFlo,
                padding: const EdgeInsets.symmetric(vertical: 13),
                side: BorderSide(
                  color: Growkids.purpleFlo.withValues(alpha: 0.40),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopExistingAttachment(String attachment) {
    final isImage = _isImageAttachment(attachment);
    final label = _attachmentStorageName(attachment);
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFE3E5EC)),
      ),
      child: Row(
        children: [
          InkWell(
            onTap: isImage ? () => _previewAttachment(attachment) : null,
            borderRadius: BorderRadius.circular(8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 46,
                height: 46,
                child: isImage
                    ? Image.network(
                        _attachmentUrl(attachment),
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            const Icon(Icons.broken_image_outlined),
                      )
                    : Container(
                        color: Growkids.purpleFlo.withValues(alpha: 0.10),
                        child: const Icon(
                          Icons.insert_drive_file_rounded,
                          color: Growkids.purpleFlo,
                        ),
                      ),
              ),
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF4D515E),
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeExistingAttachment(attachment),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFDC3545),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopNewAttachment(PlatformFile file) {
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFEFF5FF),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: const Color(0xFFD7E5FF)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.insert_drive_file_rounded,
            color: Color(0xFF3478F6),
            size: 21,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF315D9E),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${(file.size / 1024).toStringAsFixed(0)} KB',
                  style: const TextStyle(
                    color: Color(0xFF7293C4),
                    fontSize: 8,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            onPressed: () => _removeFile(file),
            icon: const Icon(
              Icons.close_rounded,
              color: Color(0xFFDC3545),
              size: 19,
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAttachmentEmpty() {
    return Container(
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE1E4EB)),
      ),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_upload_outlined,
            color: Color(0xFF9A9EAA),
            size: 38,
          ),
          SizedBox(height: 10),
          Text(
            'No attachments added',
            style: TextStyle(
              color: Color(0xFF555966),
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add photos or supporting documents.',
            style: TextStyle(color: Color(0xFF9296A2), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _desktopActionBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFFE3E5EC)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            color: Color(0xFF7C8190),
            size: 18,
          ),
          const SizedBox(width: 9),
          const Text(
            'Review the journal details before saving.',
            style: TextStyle(color: Color(0xFF7C8190), fontSize: 10),
          ),
          const Spacer(),
          OutlinedButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            child: const Text('Cancel'),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 17,
                    height: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Icon(
                    widget.isEdit ? Icons.save_outlined : Icons.send_rounded,
                    size: 18,
                  ),
            label: Text(
              widget.isEdit ? 'Update Journal' : 'Submit Journal',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Growkids.purpleFlo,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _desktopAttachmentOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.22)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Color(0xFF343640),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF858A98),
                fontSize: 8,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _desktopFieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF555966),
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }

  InputDecoration _desktopInputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9A9EAA), fontSize: 11),
      prefixIcon: Icon(icon, color: const Color(0xFF858A98), size: 20),
      filled: true,
      fillColor: const Color(0xFFF8F9FC),
      contentPadding: const EdgeInsets.all(15),
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
    );
  }

  Widget _desktopSurface({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E5EC)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }

  // --- UI HELPERS ---
  Widget _sectionTitle(String title, {String? subtitle}) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 6),
      child: Text(
        title,
        style: TextStyle(fontSize: 14.sp, color: Colors.black87),
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 1.5.h, vertical: 1.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4))
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDeco({required String hint, required IconData icon}) {
    return InputDecoration(
      border: InputBorder.none,
      icon: Icon(icon, color: Colors.grey[400]),
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 12.sp),
    );
  }
}

class _HeaderJournal extends StatelessWidget {
  final String studName;
  const _HeaderJournal(this.studName);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleFlo,
            Growkids.purpleFlo.withValues(alpha: .70)
          ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.black.withValues(alpha: 0.06)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 16,
              offset: const Offset(0, 8)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 3.h,
            backgroundColor: Colors.white,
            child:
                Icon(Icons.book_rounded, color: Growkids.purpleFlo, size: 3.h),
          ),
          SizedBox(width: 2.w),
          Expanded(
            child: Text(studName,
                style: TextStyle(fontSize: 16.sp, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
