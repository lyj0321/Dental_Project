import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../models/reservation_model.dart';

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  DateTime _selectedDay = DateTime.now();
  List<Reservation> _reservations = [];
  bool _isLoading = false;

  // 대시보드 카드용
  String? _ykiho;
  String _hospitalName = '';
  bool _isCardLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReservations();
  }

  Future<void> _fetchReservations() async {
    setState(() {
      _isLoading = true;
      _isCardLoading = true;
    });
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final hospitalData = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho, yadm_nm')
          .eq('email', user.email!)
          .maybeSingle();

      if (hospitalData == null) return;

      _ykiho = hospitalData['ykiho'];
      _hospitalName = hospitalData['yadm_nm'] ?? '';

      final res = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('ykiho', _ykiho!)
          .order('reserved_at', ascending: true);

      setState(() {
        _reservations = (res as List).map((e) => Reservation.fromMap(e)).toList();
      });
    } catch (e) {
      debugPrint('예약 로드 실패: $e');
    } finally {
      setState(() {
        _isLoading = false;
        _isCardLoading = false;
      });
    }
  }

  // 오늘 예약만
  List<Reservation> get _todayReservations {
    final now = DateTime.now();
    return _reservations.where((r) =>
    r.reservedAt.toLocal().year == now.year &&
        r.reservedAt.toLocal().month == now.month &&
        r.reservedAt.toLocal().day == now.day
    ).toList();
  }

  int get _pendingCount  => _todayReservations.where((r) => r.status == 'pending').length;
  int get _confirmedCount => _todayReservations.where((r) => r.status == 'confirmed').length;
  int get _completedCount => _todayReservations.where((r) => r.status == 'completed').length;

  // 선택된 날짜 예약
  List<Reservation> get _dailyReservations {
    return _reservations.where((r) {
      final local = r.reservedAt.toLocal();
      return local.year == _selectedDay.year &&
          local.month == _selectedDay.month &&
          local.day == _selectedDay.day;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('진료 및 예약 관리')),
      body: Column(
        children: [
          // ── 오늘의 진료현황 카드 ──────────────────────────
          _buildDashboardCard(),

          // ── 날짜 선택 헤더 ────────────────────────────────
          _buildCalendarHeader(),
          const Divider(height: 1),

          // ── 예약 목록 ─────────────────────────────────────
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _dailyReservations.isEmpty
                ? const Center(child: Text('해당 일자에 예약이 없습니다.'))
                : RefreshIndicator(
              onRefresh: _fetchReservations,
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _dailyReservations.length,
                itemBuilder: (context, index) =>
                    _buildReservationCard(_dailyReservations[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 오늘의 진료현황 카드 ──────────────────────────────────
  Widget _buildDashboardCard() {
    final now = DateTime.now();
    final dateStr = DateFormat('MM월 dd일 (E)').format(now);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, Color(0xFF0077CC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _isCardLoading
          ? const SizedBox(
        height: 90,
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      )
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 병원명 + 날짜 + 새로고침
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _hospitalName.isNotEmpty ? _hospitalName : '내 병원',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '오늘 $dateStr',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: _fetchReservations,
                child: const Icon(Icons.refresh, color: Colors.white70, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 숫자 카운트
          Row(
            children: [
              _buildStatChip('전체', _todayReservations.length, Colors.white, Colors.white24),
              const SizedBox(width: 8),
              _buildStatChip('대기', _pendingCount, Colors.orange.shade200, Colors.orange.withOpacity(0.25)),
              const SizedBox(width: 8),
              _buildStatChip('확정', _confirmedCount, Colors.green.shade200, Colors.green.withOpacity(0.25)),
              const SizedBox(width: 8),
              _buildStatChip('완료', _completedCount, Colors.blue.shade200, Colors.blue.withOpacity(0.25)),
            ],
          ),

          // 다음 예약 미리보기
          if (_todayReservations.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(color: Colors.white24, height: 1),
            const SizedBox(height: 10),
            _buildNextReservationRow(),
          ],
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, int count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text('$count',
                style: TextStyle(
                    color: textColor,
                    fontSize: 22,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(color: Colors.white70, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  Widget _buildNextReservationRow() {
    final now = DateTime.now();
    final upcoming = _todayReservations
        .where((r) => r.reservedAt.toLocal().isAfter(now) && r.status != 'completed')
        .toList();

    if (upcoming.isEmpty) {
      return const Row(children: [
        Icon(Icons.check_circle_outline, color: Colors.white70, size: 14),
        SizedBox(width: 6),
        Text('오늘 남은 예약이 없습니다', style: TextStyle(color: Colors.white70, fontSize: 12)),
      ]);
    }

    final next = upcoming.first;
    return Row(children: [
      const Icon(Icons.access_time, color: Colors.white70, size: 14),
      const SizedBox(width: 6),
      Text(
        '다음 예약: ${DateFormat('HH:mm').format(next.reservedAt.toLocal())} ${next.patientName}님',
        style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
      ),
    ]);
  }

  // ── 날짜 선택 헤더 ────────────────────────────────────────
  Widget _buildCalendarHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: () => setState(() =>
            _selectedDay = _selectedDay.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Text(DateFormat('yyyy년 MM월 dd일').format(_selectedDay),
              style: AppStyles.subTitleStyle),
          IconButton(
            onPressed: () => setState(() =>
            _selectedDay = _selectedDay.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }

  // ── 예약 카드 ─────────────────────────────────────────────
  Widget _buildReservationCard(Reservation r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8)),
          child: Text(
            DateFormat('HH:mm').format(r.reservedAt.toLocal()),
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.primary),
          ),
        ),
        title: Text(r.patientName,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(r.description ?? '설명 없음'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showPatientDetail(r),
      ),
    );
  }

  // ── 환자 상세 ─────────────────────────────────────────────
  void _showPatientDetail(Reservation r) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => FutureBuilder<List<dynamic>>(
        future: Supabase.instance.client
            .from('patient_visits')
            .select('*')
            .eq('reservation_id', r.id),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const SizedBox(
                height: 300,
                child: Center(child: CircularProgressIndicator()));
          }
          final visits = snapshot.data ?? [];
          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.6,
            maxChildSize: 0.9,
            builder: (_, controller) => SingleChildScrollView(
              controller: controller,
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${r.patientName} 상세 정보', style: AppStyles.titleStyle),
                  const Divider(height: 32),
                  const Text('진료 히스토리 및 AI 분석',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                  const SizedBox(height: 16),
                  if (visits.isEmpty)
                    const Text('아직 등록된 진료 내역이 없습니다.')
                  else
                    ...visits.map((v) => _buildVisitItem(v)),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('닫기')),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildVisitItem(Map<String, dynamic> v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
          color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('진료일: ${v['visit_date']}',
              style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('진료 타입: ${v['treatment_type'] ?? '미지정'}'),
          const Divider(height: 20),
          const Row(children: [
            Icon(Icons.auto_awesome, size: 16, color: Colors.blue),
            SizedBox(width: 8),
            Text('AI 분석 결과',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
          ]),
          const SizedBox(height: 8),
          Text(v['ai_result'] ?? '분석 데이터가 아직 없습니다.',
              style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}