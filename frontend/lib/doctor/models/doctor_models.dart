class DoctorAppointment {
  final int appointmentId;
  final DateTime date;
  final String startTime;
  final String endTime;
  final String placeName;
  final String patientId;
  final String patientName;
  final int? patientAge;
  final double? patientHeightCm;
  final double? patientWeightKg;
  final String? medicalConditions;
  final String? drugAllergies;
  final String? latestDiagnosis;
  final String status;

  DoctorAppointment({
    required this.appointmentId,
    required this.date,
    required this.startTime,
    required this.endTime,
    required this.placeName,
    required this.patientId,
    required this.patientName,
    required this.patientAge,
    required this.patientHeightCm,
    required this.patientWeightKg,
    required this.medicalConditions,
    required this.drugAllergies,
    required this.latestDiagnosis,
    required this.status,
  });

  factory DoctorAppointment.fromJson(Map<String, dynamic> json) {
    return DoctorAppointment(
      appointmentId: json['appointment_id'] as int,
      date: DateTime.parse(json['date'] as String),
      startTime: json['start_time'] as String,
      endTime: json['end_time'] as String,
      placeName: json['place_name'] as String? ?? '-',
      patientId: json['patient_id'] as String,
      patientName: json['patient_name'] as String? ?? '-',
      patientAge: json['patient_age'] as int?,
      patientHeightCm: (json['patient_height_cm'] as num?)?.toDouble(),
      patientWeightKg: (json['patient_weight_kg'] as num?)?.toDouble(),
      medicalConditions: json['medical_conditions'] as String?,
      drugAllergies: json['drug_allergies'] as String?,
      latestDiagnosis: json['latest_diagnosis'] as String?,
      status: (json['status'] as String? ?? 'PENDING').toUpperCase(),
    );
  }

  String get timeRange => '$startTime - $endTime';

  bool get isPending => status == 'PENDING';

  String get statusLabel {
    switch (status) {
      case 'PENDING':
        return 'รอการยืนยัน';
      case 'ACCEPTED':
        return 'ยืนยันแล้ว';
      case 'REJECTED':
        return 'ปฏิเสธ';
      case 'CANCELED':
        return 'ยกเลิก';
      default:
        return status;
    }
  }

  DateTime? get startDateTime {
    final parts = startTime.trim().split(':');
    if (parts.length < 2) {
      return null;
    }
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) {
      return null;
    }
    return DateTime(date.year, date.month, date.day, hour, minute);
  }

  String get formattedDate {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();
    return '$day/$month/$year';
  }

  String get locationLabel => placeName.isEmpty ? '-' : placeName;

  String get medicalHistory {
    final parts = <String>[];
    if (medicalConditions != null && medicalConditions!.trim().isNotEmpty) {
      parts.add('โรคประจำตัว: $medicalConditions');
    }
    if (drugAllergies != null && drugAllergies!.trim().isNotEmpty) {
      parts.add('ประวัติการแพ้ยา: $drugAllergies');
    }
    return parts.isEmpty ? '-' : parts.join('\n');
  }

  String get notes {
    final value = latestDiagnosis?.trim();
    if (value == null || value.isEmpty) {
      return 'ไม่มีบันทึกอาการล่าสุด';
    }
    return value;
  }
}

class DiagnosisEntry {
  final int diagnosisId;
  final int appointmentId;
  final String doctorId;
  final String symptom;
  final DateTime recordedAt;

  DiagnosisEntry({
    required this.diagnosisId,
    required this.appointmentId,
    required this.doctorId,
    required this.symptom,
    required this.recordedAt,
  });

  factory DiagnosisEntry.fromJson(Map<String, dynamic> json) {
    return DiagnosisEntry(
      diagnosisId: json['diagnosis_id'] as int,
      appointmentId: json['appointment_id'] as int,
      doctorId: json['doctor_id'] as String,
      symptom: json['symptom'] as String? ?? '-',
      recordedAt: DateTime.parse(json['recorded_at'] as String),
    );
  }
}

class PrescriptionItem {
  final int prescriptionId;
  final String patientId;
  final int medicineId;
  final String medicineName;
  final String? medicineDetails;
  final String? imageUrl;
  final String dosage;
  final int amount;
  final bool isActive;
  final String? doctorComment;

  PrescriptionItem({
    required this.prescriptionId,
    required this.patientId,
    required this.medicineId,
    required this.medicineName,
    required this.medicineDetails,
    required this.imageUrl,
    required this.dosage,
    required this.amount,
    required this.isActive,
    required this.doctorComment,
  });

  factory PrescriptionItem.fromJson(Map<String, dynamic> json) {
    return PrescriptionItem(
      prescriptionId: json['prescription_id'] as int,
      patientId: json['patient_id'] as String,
      medicineId: json['medicine_id'] as int,
      medicineName: json['medicine_name'] as String? ?? '-',
      medicineDetails: json['medicine_details'] as String?,
      imageUrl: json['image_url'] as String?,
      dosage: json['dosage'] as String? ?? '-',
      amount: json['amount'] as int? ?? 0,
      isActive: json['on_going'] as bool? ?? false,
      doctorComment: json['doctor_comment'] as String?,
    );
  }

  PrescriptionItem copyWith({
    bool? isActive,
    String? dosage,
    String? doctorComment,
    int? amount,
    int? medicineId,
    String? medicineName,
    String? imageUrl,
  }) {
    return PrescriptionItem(
      prescriptionId: prescriptionId,
      patientId: patientId,
      medicineId: medicineId ?? this.medicineId,
      medicineName: medicineName ?? this.medicineName,
      medicineDetails: medicineDetails,
      imageUrl: imageUrl ?? this.imageUrl,
      dosage: dosage ?? this.dosage,
      amount: amount ?? this.amount,
      isActive: isActive ?? this.isActive,
      doctorComment: doctorComment ?? this.doctorComment,
    );
  }
}

class MedicineItem {
  final int medicineId;
  final String medicineName;
  final String? details;
  final String? imageUrl;
  final double? unitPrice;

  MedicineItem({
    required this.medicineId,
    required this.medicineName,
    required this.details,
    required this.imageUrl,
    required this.unitPrice,
  });

  factory MedicineItem.fromJson(Map<String, dynamic> json) {
    return MedicineItem(
      medicineId: json['medicine_id'] as int,
      medicineName: json['medicine_name'] as String? ?? '-',
      details: json['details'] as String?,
      imageUrl: json['image_url'] as String?,
      unitPrice: (json['unit_price'] as num?)?.toDouble(),
    );
  }

  @override
  String toString() => medicineName;
}
