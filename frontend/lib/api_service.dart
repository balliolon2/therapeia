import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:flutter_frontend/doctor/models/doctor_models.dart';

class ApiService {
  static const String _baseUrl = 'http://127.0.0.1:8000/api';
  static const Map<String, String> _jsonHeaders = {
    'Content-Type': 'application/json; charset=UTF-8',
  };

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required String citizenId,
    required String role,
    String? hn,
    String? mln,
  }) async {
    try {
      print('Attempting to register user...');
      final Map<String, String> body = <String, String>{
        'email': email,
        'password': password,
        'first_name': firstName,
        'last_name': lastName,
        'phone': phone,
        'citizen_id': citizenId,
        'role': role,
      };

      if (hn != null && hn.trim().isNotEmpty) {
        body['hn'] = hn.trim();
      }

      if (mln != null && mln.trim().isNotEmpty) {
        body['mln'] = mln.trim();
      }

      final response = await http.post(
        Uri.parse('$_baseUrl/auth/register'),
        headers: _jsonHeaders,
        body: jsonEncode(body),
      );
      if (response.statusCode == 201) {
        return jsonDecode(response.body);
      } else {
        print(response.body);
        throw Exception('Failed to register.');
      }
    } catch (e) {
      print('Caught exception: ' + e.toString());
      throw Exception('Failed to connect to the server.');
    }
  }

  Future<Map<String, dynamic>> login(
    String email,
    String password, {
    String? role,
  }) async {
    final payload = <String, String>{'email': email, 'password': password};

    if (role != null && role.trim().isNotEmpty) {
      payload['role'] = role.trim().toUpperCase();
    }

    final response = await http.post(
      Uri.parse('$_baseUrl/auth/login'),
      headers: _jsonHeaders,
      body: jsonEncode(payload),
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to login.');
    }
  }

  Future<Map<String, dynamic>> getPatientProfile(String email) async {
    final uri = Uri.parse(
      '$_baseUrl/profiles/patient',
    ).replace(queryParameters: <String, String>{'email': email});
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load patient profile.');
    }
  }

  Future<Map<String, dynamic>> getDoctorProfile(String email) async {
    final uri = Uri.parse(
      '$_baseUrl/profiles/doctor',
    ).replace(queryParameters: <String, String>{'email': email});
    final response = await http.get(uri);

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to load doctor profile.');
    }
  }

  Future<Map<String, dynamic>> updateDoctorProfile({
    required String userId,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    String? department,
    String? position,
    String? medicalLicense,
    required List<Map<String, dynamic>> schedule,
  }) async {
    final body = <String, dynamic>{
      'user_id': userId,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'phone': phone,
      'department': department,
      'position': position,
      'mln': medicalLicense,
      'schedule': schedule,
    };

    final response = await http.put(
      Uri.parse('$_baseUrl/profiles/doctor'),
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      return _decodeJsonMap(response.body);
    } else {
      final message = response.body.isNotEmpty
          ? response.body
          : 'Failed to update doctor profile.';
      throw Exception(message);
    }
  }

  Future<List<dynamic>> getAppointments() async {
    // Legacy placeholder for patient appointment screen; TODO: replace with real API.
    return <dynamic>[];
  }

  Future<List<DoctorAppointment>> getDoctorAppointments({
    required String email,
    DateTime? start,
    DateTime? end,
  }) async {
    final params = <String, String>{'email': email};
    if (start != null) {
      params['start'] = _dateOnly(start);
    }
    if (end != null) {
      params['end'] = _dateOnly(end);
    }

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/appointments/doctor',
      ).replace(queryParameters: params),
    );

    if (response.statusCode == 200) {
      return _decodeJsonList(
        response.body,
      ).map(DoctorAppointment.fromJson).toList();
    } else if (response.statusCode == 404) {
      throw Exception('ไม่พบข้อมูลสำหรับแพทย์ที่ระบุ');
    } else {
      throw Exception('Failed to load doctor appointments.');
    }
  }

  Future<List<DiagnosisEntry>> getPatientDiagnoses(String patientId) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/diagnoses/patient',
      ).replace(queryParameters: <String, String>{'patient_id': patientId}),
    );

    if (response.statusCode == 200) {
      return _decodeJsonList(
        response.body,
      ).map(DiagnosisEntry.fromJson).toList();
    } else {
      throw Exception('Failed to load medical history.');
    }
  }

  Future<List<PrescriptionItem>> getPatientPrescriptions(
    String patientId,
  ) async {
    final response = await http.get(
      Uri.parse(
        '$_baseUrl/prescriptions/patient',
      ).replace(queryParameters: <String, String>{'patient_id': patientId}),
    );

    if (response.statusCode == 200) {
      return _decodeJsonList(
        response.body,
      ).map(PrescriptionItem.fromJson).toList();
    } else {
      throw Exception('Failed to load prescriptions.');
    }
  }

  Future<PrescriptionItem> createPrescription({
    required String patientId,
    required int medicineId,
    required String dosage,
    required int amount,
    required bool onGoing,
    String? doctorComment,
  }) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/prescriptions'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'patient_id': patientId,
        'medicine_id': medicineId,
        'dosage': dosage,
        'amount': amount,
        'on_going': onGoing,
        'doctor_comment': doctorComment,
      }),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      return PrescriptionItem.fromJson(_decodeJsonMap(response.body));
    } else {
      throw Exception('Failed to create prescription.');
    }
  }

  Future<PrescriptionItem> updatePrescription({
    required int prescriptionId,
    required String patientId,
    required int medicineId,
    required String dosage,
    required int amount,
    required bool onGoing,
    String? doctorComment,
  }) async {
    final response = await http.put(
      Uri.parse('$_baseUrl/prescriptions/$prescriptionId'),
      headers: _jsonHeaders,
      body: jsonEncode(<String, dynamic>{
        'patient_id': patientId,
        'medicine_id': medicineId,
        'dosage': dosage,
        'amount': amount,
        'on_going': onGoing,
        'doctor_comment': doctorComment,
      }),
    );

    if (response.statusCode == 200) {
      return PrescriptionItem.fromJson(_decodeJsonMap(response.body));
    } else if (response.statusCode == 404) {
      throw Exception('Prescription not found.');
    } else {
      throw Exception('Failed to update prescription.');
    }
  }

  Future<void> deletePrescription(int prescriptionId) async {
    final response = await http.delete(
      Uri.parse('$_baseUrl/prescriptions/$prescriptionId'),
    );

    if (response.statusCode != 204) {
      if (response.statusCode == 404) {
        throw Exception('Prescription not found.');
      }
      throw Exception('Failed to delete prescription.');
    }
  }

  Future<List<MedicineItem>> getMedicines({String? keyword, int? limit}) async {
    final params = <String, String>{};
    if (keyword != null && keyword.trim().isNotEmpty) {
      params['q'] = keyword.trim();
    }
    if (limit != null) {
      params['limit'] = limit.toString();
    }

    final response = await http.get(
      Uri.parse(
        '$_baseUrl/medicines',
      ).replace(queryParameters: params.isEmpty ? null : params),
    );

    if (response.statusCode == 200) {
      return _decodeJsonList(response.body).map(MedicineItem.fromJson).toList();
    } else {
      throw Exception('Failed to load medicines.');
    }
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;

  List<Map<String, dynamic>> _decodeJsonList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is List) {
      return decoded.cast<Map<String, dynamic>>();
    }
    throw Exception('Unexpected response format');
  }

  Map<String, dynamic> _decodeJsonMap(String source) {
    final decoded = jsonDecode(source);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    throw Exception('Unexpected response format');
  }
}
