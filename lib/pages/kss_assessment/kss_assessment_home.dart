import 'package:flutter/material.dart';
import 'package:growcheck_app_v2/ui/colour.dart';

class KssAssessmentHome extends StatefulWidget {
  final String teacherId;

  const KssAssessmentHome({
    super.key,
    required this.teacherId,
  });

  @override
  State<KssAssessmentHome> createState() => _KssAssessmentHomeState();
}

class _KssAssessmentHomeState extends State<KssAssessmentHome> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('KSS Assessment'),
        backgroundColor: Growkids.purpleFlo,
        foregroundColor: Colors.white,
        // ✅ TIADA LAGI ACTION BUTTON DI SINI
      ),
      body: Center(
        child: Text('Teacher ID: ${widget.teacherId}'),
      ),
    );
  }
}
