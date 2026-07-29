import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

bool useDesktopOnboardingLayout(BuildContext context) {
  final desktopPlatform = switch (defaultTargetPlatform) {
    TargetPlatform.macOS ||
    TargetPlatform.windows ||
    TargetPlatform.linux =>
      true,
    _ => false,
  };
  return desktopPlatform && MediaQuery.sizeOf(context).width >= 900;
}

class ResponsiveOnboardLayout extends StatelessWidget {
  const ResponsiveOnboardLayout({
    super.key,
    required this.fadeAnimation,
    required this.slideAnimation,
    required this.scaleAnimation,
    required this.onGetStarted,
    this.isStarting = false,
    this.errorMessage,
  });

  final Animation<double> fadeAnimation;
  final Animation<Offset> slideAnimation;
  final Animation<double> scaleAnimation;
  final VoidCallback? onGetStarted;
  final bool isStarting;
  final String? errorMessage;

  static const _desktopBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF471AFF),
              Color(0xFF6C48FF),
              Color(0xFF9980FF),
            ],
          ),
        ),
        child: Stack(
          fit: StackFit.expand,
          children: [
            _decorativeCircle(
              top: -120,
              right: -90,
              size: 340,
              color: Colors.white.withValues(alpha: 0.06),
            ),
            _decorativeCircle(
              bottom: -170,
              left: -130,
              size: 390,
              color: Colors.white.withValues(alpha: 0.05),
            ),
            _decorativeCircle(
              top: 250,
              right: -70,
              size: 210,
              color: Growkids.pink.withValues(alpha: 0.10),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 48 : 24,
                      vertical: isDesktop ? 32 : 28,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight:
                            constraints.maxHeight - (isDesktop ? 64 : 56),
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child:
                              isDesktop ? _desktopContent() : _mobileContent(),
                        ),
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

  Widget _desktopContent() {
    return Row(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 64),
            child: _animated(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _logo(size: 150, padding: 30),
                  const SizedBox(height: 34),
                  _title(fontSize: 46, textAlign: TextAlign.left),
                  const SizedBox(height: 16),
                  _tagline(fontSize: 17),
                  const SizedBox(height: 22),
                  Text(
                    'A focused workspace for assessments, progress tracking, '
                    'and professional recommendations.',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.78),
                      fontSize: 16,
                      height: 1.55,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SizedBox(
          width: 430,
          child: _animated(
            child: Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.25),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.13),
                    blurRadius: 36,
                    offset: const Offset(0, 18),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Everything you need',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 20),
                  _features(compact: true),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 20),
                    _errorMessage(),
                  ],
                  const SizedBox(height: 28),
                  _getStartedButton(height: 58, fontSize: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _mobileContent() {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FadeTransition(
            opacity: fadeAnimation,
            child: ScaleTransition(
              scale: scaleAnimation,
              child: _logo(size: 105, padding: 22),
            ),
          ),
          const SizedBox(height: 24),
          _animated(
            child: Column(
              children: [
                _title(fontSize: 32, textAlign: TextAlign.center),
                const SizedBox(height: 12),
                _tagline(fontSize: 14),
              ],
            ),
          ),
          const SizedBox(height: 52),
          _animated(child: _getStartedButton(height: 56, fontSize: 16)),
          if (errorMessage != null) ...[
            const SizedBox(height: 16),
            _errorMessage(),
          ],
          const SizedBox(height: 30),
          _animated(child: _features()),
        ],
      ),
    );
  }

  Widget _animated({required Widget child}) {
    return SlideTransition(
      position: slideAnimation,
      child: FadeTransition(opacity: fadeAnimation, child: child),
    );
  }

  Widget _logo({required double size, required double padding}) {
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Growkids.pink.withValues(alpha: 0.30),
            blurRadius: 30,
            spreadRadius: 5,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Image.asset(
        'assets/Growcheck-logo.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _title({required double fontSize, required TextAlign textAlign}) {
    return Text(
      'GrowCheck App',
      textAlign: textAlign,
      style: TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
        shadows: [
          Shadow(
            color: Colors.black.withValues(alpha: 0.20),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
    );
  }

  Widget _tagline({required double fontSize}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white.withValues(alpha: 0.30)),
      ),
      child: Text(
        'Professional Child Development Assessment',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.95),
          fontSize: fontSize,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _getStartedButton({
    required double height,
    required double fontSize,
  }) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Growkids.pink.withValues(alpha: 0.40),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: isStarting ? null : onGetStarted,
          borderRadius: BorderRadius.circular(15),
          child: Ink(
            width: double.infinity,
            height: height,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFF538F), Color(0xFFFF6BA0)],
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (isStarting) ...[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.4,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Starting...', style: _buttonTextStyle(fontSize)),
                ] else ...[
                  Text('Get Started', style: _buttonTextStyle(fontSize)),
                  const SizedBox(width: 10),
                  Icon(
                    Icons.arrow_forward_rounded,
                    color: Colors.white,
                    size: fontSize + 5,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  TextStyle _buttonTextStyle(double fontSize) {
    return TextStyle(
      color: Colors.white,
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      letterSpacing: 1,
    );
  }

  Widget _features({bool compact = false}) {
    return Column(
      children: [
        _featureItem(
          Icons.assessment_outlined,
          'Comprehensive Assessments',
          compact: compact,
        ),
        const SizedBox(height: 12),
        _featureItem(
          Icons.analytics_outlined,
          'Detailed Progress Tracking',
          compact: compact,
        ),
        const SizedBox(height: 12),
        _featureItem(
          Icons.medical_services_outlined,
          'Professional Recommendations',
          compact: compact,
        ),
      ],
    );
  }

  Widget _featureItem(IconData icon, String text, {required bool compact}) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 16 : 18,
        vertical: compact ? 13 : 14,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: Growkids.pink.withValues(alpha: 0.30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.92),
                fontSize: compact ? 14 : 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Text(
        errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Colors.white, fontSize: 13),
      ),
    );
  }

  static Widget _decorativeCircle({
    double? top,
    double? right,
    double? bottom,
    double? left,
    required double size,
    required Color color,
  }) {
    return Positioned(
      top: top,
      right: right,
      bottom: bottom,
      left: left,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: color),
      ),
    );
  }
}
