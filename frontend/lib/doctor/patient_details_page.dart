import 'package:flutter/material.dart';

import 'package:flutter_frontend/doctor/models/doctor_models.dart';

import 'dispense_medicine_page.dart';
import 'medical_examination_history_page.dart';

class PatientDetailsPage extends StatelessWidget {
  final DoctorAppointment appointment;

  static final Color _accentColor = Colors.lightGreen[100]!;

  const PatientDetailsPage({super.key, required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('ผู้ป่วย', style: TextStyle(color: Colors.black)),
        backgroundColor: _accentColor,
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.black),
            onPressed: () {},
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoCard(),
                  const SizedBox(height: 16),
                  _buildNotesCard(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(context),
        ],
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('name:', appointment.patientName),
            _buildInfoRow('age:', _formatAge(appointment.patientAge)),
            _buildInfoRow(
              'height:',
              _formatNumber(appointment.patientHeightCm, 'cm'),
            ),
            _buildInfoRow(
              'weight:',
              _formatNumber(appointment.patientWeightKg, 'kg'),
            ),
            _buildInfoRow('status:', appointment.statusLabel),
            const Divider(height: 24),
            const Text(
              'Medical History:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(appointment.medicalHistory),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(
            width: 80,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard() {
    return Card(
      elevation: 2,
      color: const Color(0xFFE8F5E9),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'อาการของการป่วย',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(appointment.notes),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DispenseMedicinePage(
                        patientId: appointment.patientId,
                        patientName: appointment.patientName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('สั่งยา'),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MedicalExaminationHistoryPage(
                        patientId: appointment.patientId,
                        patientName: appointment.patientName,
                      ),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentColor,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('ประวัติการตรวจ'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge(int? age) {
    if (age == null || age <= 0) {
      return '-';
    }
    return '$age year';
  }

  String _formatNumber(double? value, String unit) {
    if (value == null || value <= 0) {
      return '-';
    }
    return '${value.toStringAsFixed(1)} $unit';
  }
}
