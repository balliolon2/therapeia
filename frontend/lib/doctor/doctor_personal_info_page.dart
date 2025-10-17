import 'package:flutter/material.dart';
import 'package:flutter_frontend/api_service.dart';

import 'edit_doctor_personal_info_page.dart';
import 'models/schedule.dart';

class DoctorPersonalInfoPage extends StatefulWidget {
  final String email;

  const DoctorPersonalInfoPage({Key? key, required this.email})
    : super(key: key);

  @override
  State<DoctorPersonalInfoPage> createState() => _DoctorPersonalInfoPageState();
}

class _DoctorPersonalInfoPageState extends State<DoctorPersonalInfoPage> {
  static final Color _accentColor = Colors.lightGreen[100]!;
  final ApiService _apiService = ApiService();

  bool _isLoading = true;
  bool _isSavingProfile = false;
  String? _errorMessage;

  late String _currentEmail;
  String _doctorId = '';

  String doctorName = '-';
  String department = '-';
  String position = '-';
  String email = '-';
  String phone = '-';
  String citizenId = '-';
  String medicalLicense = '-';

  List<ScheduleEntry> scheduleEntries = [];

  @override
  void initState() {
    super.initState();
    _currentEmail = widget.email;
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await _apiService.getDoctorProfile(_currentEmail);
      final firstName = profile['first_name'] as String? ?? '';
      final lastName = profile['last_name'] as String? ?? '';
      final scheduleData = profile['schedule'] as List<dynamic>? ?? <dynamic>[];

      setState(() {
        _doctorId = profile['user_id'] as String? ?? _doctorId;
        _currentEmail = profile['email'] as String? ?? _currentEmail;
        doctorName = _composeFullName(firstName, lastName);
        department = _fallbackDash(profile['department'] as String?);
        position = _fallbackDash(profile['position'] as String?);
        email = _fallbackDash(profile['email'] as String?);
        phone = _fallbackDash(profile['phone'] as String?);
        citizenId = profile['citizen_id'] as String? ?? '-';
        medicalLicense = _fallbackDash(profile['mln'] as String?);
        scheduleEntries = _buildScheduleEntries(scheduleData);
        _errorMessage = null;
        _isLoading = false;
      });
    } catch (error) {
      setState(() {
        _errorMessage = 'ไม่สามารถโหลดข้อมูลแพทย์ได้';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(appBar: _buildAppBar(), body: _buildBody());
  }

  AppBar _buildAppBar() {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('ข้อมูลส่วนตัว', style: TextStyle(color: Colors.black)),
      backgroundColor: _accentColor,
      actions: [
        IconButton(
          icon: const Icon(Icons.notifications_none, color: Colors.black),
          onPressed: () {},
        ),
      ],
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Text(
          _errorMessage!,
          style: const TextStyle(fontSize: 16, color: Colors.redAccent),
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          child: Container(
            color: Colors.white,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPersonalInfoCard(),
                  const SizedBox(height: 24),
                  _buildScheduleSection(),
                ],
              ),
            ),
          ),
        ),
        _buildEditButton(),
      ],
    );
  }

  Widget _buildPersonalInfoCard() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              doctorName,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              department,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              position,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              email,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              phone,
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Citizen ID: $citizenId',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Text(
              'Medical License: $medicalLicense',
              style: const TextStyle(fontSize: 14, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ตารางงาน',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        const SizedBox(height: 16),
        if (scheduleEntries.isEmpty)
          const Text(
            'ไม่มีข้อมูลตารางงาน',
            style: TextStyle(fontSize: 14, color: Colors.black54),
          )
        else
          ...scheduleEntries.map((entry) => _buildDaySchedule(entry)),
      ],
    );
  }

  Widget _buildDaySchedule(ScheduleEntry entry) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(
          child: Text(
            entry.day,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 12),
        ...entry.timeSlots.map((slot) => _buildTimeSlotCard(slot)),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildTimeSlotCard(TimeSlot slot) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _accentColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade200,
            blurRadius: 1,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    slot.time,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    slot.location,
                    style: const TextStyle(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEditButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      child: ElevatedButton(
        onPressed: _isSavingProfile || _isLoading
            ? null
            : () async {
                final result = await Navigator.push<Map<String, dynamic>>(
                  context,
                  MaterialPageRoute(
                    builder: (context) => EditDoctorPersonalInfoPage(
                      doctorName: doctorName,
                      department: department,
                      position: position,
                      email: email,
                      phone: phone,
                      scheduleEntries: scheduleEntries,
                    ),
                  ),
                );

                if (!mounted || result == null) {
                  return;
                }

                await _submitProfileChanges(result);
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: _accentColor,
          foregroundColor: Colors.black,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
            side: BorderSide(color: Colors.grey.shade300),
          ),
          elevation: 0,
        ),
        child: _isSavingProfile
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text(
                'แก้ไขข้อมูล',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
      ),
    );
  }

  List<ScheduleEntry> _buildScheduleEntries(List<dynamic> scheduleData) {
    final Map<String, List<TimeSlot>> scheduleByDay = {};

    for (final slot in scheduleData) {
      if (slot is Map<String, dynamic>) {
        final day = slot['day_name'] as String? ?? 'Unknown';
        final start = slot['start_time'] as String? ?? '';
        final end = slot['end_time'] as String? ?? '';
        final place = slot['place_name'] as String? ?? '-';

        final timeRange = [
          start,
          end,
        ].where((part) => part.isNotEmpty).join(' - ');

        scheduleByDay
            .putIfAbsent(day, () => <TimeSlot>[])
            .add(
              TimeSlot(
                time: timeRange.isEmpty ? '-' : timeRange,
                location: place,
              ),
            );
      }
    }

    return scheduleByDay.entries
        .map((entry) => ScheduleEntry(day: entry.key, timeSlots: entry.value))
        .toList();
  }

  Future<void> _submitProfileChanges(Map<String, dynamic> result) async {
    if (_doctorId.isEmpty) {
      _showSnackBar('ไม่พบข้อมูลแพทย์');
      return;
    }

    final updatedName = (result['doctorName'] as String? ?? doctorName).trim();
    final nameParts = _splitFullName(updatedName);
    final updatedEmailRaw = (result['email'] as String? ?? email).trim();
    final updatedPhoneRaw = (result['phone'] as String? ?? phone).trim();
    final updatedDepartmentRaw = result['department'] as String?;
    final updatedPositionRaw = result['position'] as String?;
    final updatedScheduleEntries =
        (result['scheduleEntries'] as List<ScheduleEntry>?) ?? scheduleEntries;

    final schedulePayload = _buildSchedulePayload(updatedScheduleEntries);

    setState(() {
      _isSavingProfile = true;
    });

    try {
      final response = await _apiService.updateDoctorProfile(
        userId: _doctorId,
        firstName: nameParts[0],
        lastName: nameParts[1],
        email: updatedEmailRaw,
        phone: updatedPhoneRaw,
        department: _normalizeOptional(updatedDepartmentRaw),
        position: _normalizeOptional(updatedPositionRaw),
        medicalLicense: medicalLicense == '-' ? null : medicalLicense,
        schedule: schedulePayload,
      );

      final scheduleData = response['schedule'] as List<dynamic>? ?? [];
      final updatedEmail = (response['email'] as String? ?? updatedEmailRaw)
          .trim();
      final updatedPhone = (response['phone'] as String? ?? updatedPhoneRaw)
          .trim();

      setState(() {
        doctorName = _composeFullName(
          response['first_name'] as String?,
          response['last_name'] as String?,
        );
        department = _fallbackDash(response['department'] as String?);
        position = _fallbackDash(response['position'] as String?);
        email = _fallbackDash(updatedEmail);
        phone = _fallbackDash(updatedPhone);
        medicalLicense = _fallbackDash(response['mln'] as String?);
        scheduleEntries = _buildScheduleEntries(scheduleData);
        _currentEmail = updatedEmail;
        _isSavingProfile = false;
      });

      _showSnackBar('บันทึกข้อมูลเรียบร้อย');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isSavingProfile = false;
      });
      _showSnackBar('ไม่สามารถบันทึกข้อมูลได้: ${_formatErrorMessage(error)}');
    }
  }

  List<Map<String, dynamic>> _buildSchedulePayload(
    List<ScheduleEntry> entries,
  ) {
    final List<Map<String, dynamic>> payload = [];
    for (final entry in entries) {
      final dayIndex = _mapDayNameToIndex(entry.day);
      if (dayIndex == null) {
        continue;
      }

      for (final slot in entry.timeSlots) {
        final times = _parseTimeRange(slot.time);
        final placeName = slot.location.trim();
        if (times == null || placeName.isEmpty) {
          continue;
        }

        payload.add(<String, dynamic>{
          'day_of_week': dayIndex,
          'start_time': times[0],
          'end_time': times[1],
          'place_name': placeName,
        });
      }
    }
    return payload;
  }

  int? _mapDayNameToIndex(String dayName) {
    switch (dayName) {
      case 'วันอาทิตย์':
        return 0;
      case 'วันจันทร์':
        return 1;
      case 'วันอังคาร':
        return 2;
      case 'วันพุธ':
        return 3;
      case 'วันพฤหัสบดี':
        return 4;
      case 'วันศุกร์':
        return 5;
      case 'วันเสาร์':
        return 6;
      default:
        return null;
    }
  }

  List<String>? _parseTimeRange(String value) {
    final parts = value.split('-');
    if (parts.length != 2) {
      return null;
    }
    final start = _normalizeTimeFragment(parts[0]);
    final end = _normalizeTimeFragment(parts[1]);
    if (start == null || end == null) {
      return null;
    }
    return <String>[start, end];
  }

  String? _normalizeTimeFragment(String raw) {
    final cleaned = raw.trim().replaceAll('.', ':');
    final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(cleaned);
    if (match == null) {
      return null;
    }
    final hour = int.parse(match.group(1)!);
    final minute = int.parse(match.group(2)!);
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return null;
    }
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  List<String> _splitFullName(String name) {
    final parts = name
        .split(RegExp(r'\s+'))
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return <String>['', ''];
    }
    if (parts.length == 1) {
      return <String>[parts.first, ''];
    }
    final first = parts.first;
    final last = parts.sublist(1).join(' ');
    return <String>[first, last];
  }

  String _composeFullName(String? first, String? last) {
    final parts = <String>[
      if (first != null && first.trim().isNotEmpty) first.trim(),
      if (last != null && last.trim().isNotEmpty) last.trim(),
    ];
    return parts.isEmpty ? '-' : parts.join(' ');
  }

  String _fallbackDash(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? '-' : trimmed;
  }

  String? _normalizeOptional(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  String _formatErrorMessage(Object error) {
    final text = error.toString();
    const prefix = 'Exception: ';
    if (text.startsWith(prefix)) {
      return text.substring(prefix.length);
    }
    return text;
  }
}
