class Reservation {
  final String id;
  final String ykiho;
  final String patientName;
  final DateTime reservedAt;
  final String status;
  final int visitCount;
  final String? description;
  final bool isRead;

  Reservation({
    required this.id,
    required this.ykiho,
    required this.patientName,
    required this.reservedAt,
    required this.status,
    required this.visitCount,
    this.description,
    this.isRead = false,
  });

  factory Reservation.fromMap(Map<String, dynamic> map) {
    return Reservation(
      id: map['id'],
      ykiho: map['ykiho'],
      patientName: map['patient_name'],
      reservedAt: DateTime.parse(map['reserved_at']),
      status: map['status'] ?? 'pending',
      visitCount: map['visit_count'] ?? 1,
      description: map['description'],
      isRead: map['is_read'] ?? false,
    );
  }
}

class PatientVisit {
  final String id;
  final String? treatmentType;
  final String? surveyResult;
  final String? aiResult;      // AI 분석 결과 (핵심 MVP)
  final DateTime visitDate;

  PatientVisit({
    required this.id,
    this.treatmentType,
    this.surveyResult,
    this.aiResult,
    required this.visitDate,
  });

  factory PatientVisit.fromMap(Map<String, dynamic> map) {
    return PatientVisit(
      id: map['id'],
      treatmentType: map['treatment_type'],
      surveyResult: map['survey_result'],
      aiResult: map['ai_result'],
      visitDate: DateTime.parse(map['visit_date']),
    );
  }
}
