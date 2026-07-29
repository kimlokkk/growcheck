import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/core/config/api_config.dart';
import 'package:growcheck_app_v2/declaration/profile_declaration.dart'
    as profile;
import 'package:growcheck_app_v2/ui/colour.dart';
import 'package:http/http.dart' as http;
import 'package:sizer/sizer.dart';

bool _useDesktopChangePasswordLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class ChangePasswordPage extends StatefulWidget {
  final String staffId;
  final String staffNo;

  const ChangePasswordPage({
    super.key,
    required this.staffId,
    required this.staffNo,
  });

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final String _endpoint = ApiConfig.flutter('change_password.php');
  /*static const String _endpoint =
      'http://app-kizzu.test/growkids/flutter/change_password.php';*/

  final _formKey = GlobalKey<FormState>();
  final _currentPasswordCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();

  bool _saving = false;
  bool _hideCurrent = true;
  bool _hideNew = true;
  bool _hideConfirm = true;

  @override
  void dispose() {
    _currentPasswordCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _saving = true);

    try {
      final res = await http.post(
        Uri.parse(_endpoint),
        body: {
          'staff_id': widget.staffId,
          'staff_no': widget.staffNo,
          'current_password': _currentPasswordCtrl.text,
          'new_password': _newPasswordCtrl.text,
        },
      );

      final decoded = json.decode(res.body);
      final status = (decoded['status'] ?? '').toString().toLowerCase();
      final message =
          (decoded['message'] ?? 'Unable to update password.').toString();

      if (!mounted) return;

      if (res.statusCode == 200 && status == 'success') {
        profile.password = _newPasswordCtrl.text;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.green,
          ),
        );

        Navigator.pop(context, true);
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_useDesktopChangePasswordLayout(context)) {
      return _buildLegacy(context);
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Growkids.purpleBright,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = _useDesktopChangePasswordLayout(context);
            return SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 42 : 18,
                vertical: isDesktop ? 34 : 20,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - (isDesktop ? 68 : 40),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1080),
                    child: Form(
                      key: _formKey,
                      child: isDesktop ? _desktopLayout() : _mobileLayout(),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _desktopLayout() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 22, right: 56),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(staffNo: widget.staffNo, desktop: true),
                const SizedBox(height: 28),
                Text(
                  'Choose a strong password that you do not use elsewhere.',
                  style: TextStyle(
                    color: Colors.black.withValues(alpha: 0.58),
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
                const SizedBox(height: 24),
                const _SecurityTip(
                  icon: Icons.password_rounded,
                  text: 'Use at least 6 characters.',
                ),
                const SizedBox(height: 12),
                const _SecurityTip(
                  icon: Icons.visibility_off_outlined,
                  text: 'Never share your password with anyone.',
                ),
                const SizedBox(height: 12),
                const _SecurityTip(
                  icon: Icons.verified_user_outlined,
                  text: 'Use a password different from your current one.',
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 480,
          child: Column(
            children: [
              _passwordFormCard(),
              const SizedBox(height: 20),
              _saveButton(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _mobileLayout() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HeaderCard(staffNo: widget.staffNo),
          const SizedBox(height: 18),
          _passwordFormCard(),
          const SizedBox(height: 18),
          _saveButton(),
        ],
      ),
    );
  }

  Widget _passwordFormCard() {
    return _FormCard(
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Update your password',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 7),
            const Text(
              'Use your current password to confirm this change.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.black54,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 26),
            _PasswordField(
              controller: _currentPasswordCtrl,
              label: 'Current Password',
              hint: 'Enter current password',
              hidden: _hideCurrent,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.password],
              onToggle: () => setState(() => _hideCurrent = !_hideCurrent),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter current password';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _PasswordField(
              controller: _newPasswordCtrl,
              label: 'New Password',
              hint: 'Enter new password',
              hidden: _hideNew,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              onToggle: () => setState(() => _hideNew = !_hideNew),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter new password';
                }
                if (value.trim().length < 6) {
                  return 'Password must be at least 6 characters';
                }
                if (value == _currentPasswordCtrl.text) {
                  return 'New password must be different';
                }
                return null;
              },
            ),
            const SizedBox(height: 20),
            _PasswordField(
              controller: _confirmPasswordCtrl,
              label: 'Confirm Password',
              hint: 'Re-enter new password',
              hidden: _hideConfirm,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              onFieldSubmitted: (_) {
                if (!_saving) _save();
              },
              onToggle: () => setState(() => _hideConfirm = !_hideConfirm),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please confirm the new password';
                }
                if (value != _newPasswordCtrl.text) {
                  return 'Password confirmation does not match';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _saving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: Growkids.purpleBright,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              Growkids.purpleBright.withValues(alpha: 0.50),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
        ),
        child: _saving
            ? const SizedBox(
                height: 22,
                width: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Text(
                'Save Password',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
      ),
    );
  }

  Widget _buildLegacy(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: const Text(
          'Change Password',
          style: TextStyle(color: Colors.white),
        ),
        backgroundColor: Growkids.purpleBright,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(2.h),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _HeaderCard(staffNo: widget.staffNo),
                SizedBox(height: 2.h),
                _FormCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update your password',
                        style: TextStyle(
                          fontSize: 16.sp,
                          color: Colors.black87,
                        ),
                      ),
                      SizedBox(height: 0.8.h),
                      Text(
                        'Use your current password to confirm this change.',
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.black54,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      _PasswordField(
                        controller: _currentPasswordCtrl,
                        label: 'Current Password',
                        hint: 'Enter current password',
                        hidden: _hideCurrent,
                        onToggle: () =>
                            setState(() => _hideCurrent = !_hideCurrent),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter current password';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 1.6.h),
                      _PasswordField(
                        controller: _newPasswordCtrl,
                        label: 'New Password',
                        hint: 'Enter new password',
                        hidden: _hideNew,
                        onToggle: () => setState(() => _hideNew = !_hideNew),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter new password';
                          }
                          if (value.trim().length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          if (value == _currentPasswordCtrl.text) {
                            return 'New password must be different';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 1.6.h),
                      _PasswordField(
                        controller: _confirmPasswordCtrl,
                        label: 'Confirm Password',
                        hint: 'Re-enter new password',
                        hidden: _hideConfirm,
                        onToggle: () =>
                            setState(() => _hideConfirm = !_hideConfirm),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please confirm the new password';
                          }
                          if (value != _newPasswordCtrl.text) {
                            return 'Password confirmation does not match';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                SizedBox(height: 2.h),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Growkids.purpleBright,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: EdgeInsets.symmetric(vertical: 1.7.h),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: _saving
                        ? SizedBox(
                            height: 2.4.h,
                            width: 2.4.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Save Password',
                            style: TextStyle(fontSize: 13.sp),
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
}

class _HeaderCard extends StatelessWidget {
  final String staffNo;
  final bool desktop;

  const _HeaderCard({required this.staffNo, this.desktop = false});

  @override
  Widget build(BuildContext context) {
    final useDesktop = _useDesktopChangePasswordLayout(context);
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(useDesktop ? (desktop ? 28 : 20) : 2.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Growkids.purpleBright,
            Growkids.purpleBright.withValues(alpha: .72),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Growkids.purpleBright.withValues(alpha: 0.20),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.lock_person_rounded,
              color: Growkids.purpleBright,
              size: useDesktop ? 27 : 3.h,
            ),
          ),
          SizedBox(width: useDesktop ? 16 : 3.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Secure your account',
                  style: TextStyle(
                    fontSize: useDesktop ? (desktop ? 23 : 19) : 15.sp,
                    fontWeight:
                        useDesktop ? FontWeight.w700 : FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                SizedBox(height: useDesktop ? 5 : 0.5.h),
                Text(
                  staffNo.isEmpty
                      ? 'Update your login password safely.'
                      : 'Staff No: $staffNo',
                  style: TextStyle(
                    fontSize: useDesktop ? 13 : 11.sp,
                    color: Colors.white.withValues(alpha: 0.88),
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

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({required this.child});

  @override
  Widget build(BuildContext context) {
    final useDesktop = _useDesktopChangePasswordLayout(context);
    return Container(
      padding: EdgeInsets.all(useDesktop ? 26 : 2.h),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.black.withValues(alpha: 0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final bool hidden;
  final VoidCallback onToggle;
  final String? Function(String?) validator;
  final TextInputAction? textInputAction;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onFieldSubmitted;

  const _PasswordField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.hidden,
    required this.onToggle,
    required this.validator,
    this.textInputAction,
    this.autofillHints,
    this.onFieldSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    final useDesktop = _useDesktopChangePasswordLayout(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: useDesktop ? 14 : 12.sp,
            fontWeight: useDesktop ? FontWeight.w600 : FontWeight.normal,
            color: Growkids.purpleBright,
          ),
        ),
        SizedBox(height: useDesktop ? 9 : 0.8.h),
        TextFormField(
          controller: controller,
          obscureText: hidden,
          validator: validator,
          textInputAction: textInputAction,
          autofillHints: autofillHints,
          onFieldSubmitted: onFieldSubmitted,
          decoration: InputDecoration(
            hintText: hint,
            prefixIcon: const Icon(Icons.lock_outline_rounded,
                color: Growkids.purpleBright),
            suffixIcon: IconButton(
              onPressed: onToggle,
              icon: Icon(
                hidden
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                color: Growkids.purpleBright,
              ),
            ),
            filled: true,
            fillColor: Growkids.purpleBright.withValues(alpha: 0.06),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Growkids.purpleBright.withValues(alpha: 0.18)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                  color: Growkids.purpleBright.withValues(alpha: 0.18)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide:
                  const BorderSide(color: Growkids.purpleBright, width: 1.4),
            ),
          ),
        ),
      ],
    );
  }
}

class _SecurityTip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _SecurityTip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: Growkids.purpleBright.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Growkids.purpleBright, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: Colors.black.withValues(alpha: 0.62),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}
