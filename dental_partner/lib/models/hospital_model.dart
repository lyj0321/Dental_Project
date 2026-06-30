class Hospital {
  final String ykiho;        // 요양기관기호 (PK)
  final String yadmNm;       // 병원명
  final String? addr;        // 주소
  final String? email;       // 이메일
  final String status;       // pending, active 등
  final String? telno;       // 전화번호

  Hospital({
    required this.ykiho,
    required this.yadmNm,
    this.addr,
    this.email,
    required this.status,
    this.telno,
  });

  factory Hospital.fromMap(Map<String, dynamic> map) {
    return Hospital(
      ykiho: map['ykiho'],
      yadmNm: map['yadm_nm'],
      addr: map['addr'],
      email: map['email'],
      status: map['status'] ?? 'pending',
      telno: map['telno'],
    );
  }
}
