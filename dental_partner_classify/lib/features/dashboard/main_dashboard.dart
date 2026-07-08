import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../hospital_info/hospital_info_page.dart';
import '../reservation/reservation_page.dart';
import '../review/review_management_page.dart';
import '../mypage/my_page.dart';

class MainDashboard extends StatefulWidget {
  const MainDashboard({super.key});

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  bool _isLoading = true;
  String _hospitalName = '';
  List<Map<String, dynamic>> _todayList = [];
  int _unconfirmedCount = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() => _isLoading = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null) return;

      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho, yadm_nm')
          .eq('email', email)
          .maybeSingle();

      if (hospital == null) return;

      _hospitalName = hospital['yadm_nm'] ?? '';
      final ykiho = hospital['ykiho'];

      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day).toUtc().toIso8601String();
      final todayEnd = DateTime(now.year, now.month, now.day, 23, 59, 59).toUtc().toIso8601String();

      final res = await Supabase.instance.client
          .from('reservations')
          .select('id, patient_name, reserved_at, description, status, visit_count, cancel_reason, is_read, preferred_time_slot, patient_profile_json')
          .eq('ykiho', ykiho)
          .gte('reserved_at', todayStart)
          .lte('reserved_at', todayEnd)
          .order('reserved_at', ascending: true);

      final unconfirmed = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('ykiho', ykiho)
          .eq('status', 'pending')
          .isFilter('reserved_at', null);

      setState(() {
        _todayList = List<Map<String, dynamic>>.from(res);
        _unconfirmedCount = (unconfirmed as List).length;
      });
    } catch (e) {
      debugPrint('대시보드 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  int get _totalCount => _todayList.length;
  int get _pendingCount => _todayList.where((r) => r['status'] == 'pending').length;
  int get _confirmedCount => _todayList.where((r) => r['status'] == 'confirmed').length;
  int get _completedCount =>
      _todayList.where((r) => r['status'] == 'completed' || r['status'] == 'done').length;

  Map<String, dynamic>? get _nextReservation {
    final now = DateTime.now();
    final upcoming = _todayList.where((r) {
      if (r['reserved_at'] == null) return false;
      final t = DateTime.parse(r['reserved_at']).toLocal();
      final s = r['status'];
      return t.isAfter(now) && s != 'cancelled' && s != 'done' && s != 'completed';
    }).toList();
    return upcoming.isEmpty ? null : upcoming.first;
  }

  Map<String, dynamic> _toDetailMap(Map<String, dynamic> r) {
    return {
      'id': r['id']?.toString() ?? '',
      'name': r['patient_name'] ?? '',
      'time': r['reserved_at'] != null
          ? DateFormat('HH:mm').format(DateTime.parse(r['reserved_at']).toLocal())
          : '시간 미확정',
      'count': r['visit_count'] ?? 1,
      'desc': r['description'] ?? '',
      'isDone': r['status'] == 'done',
      'isCancelled': r['status'] == 'cancelled',
      'isPending': r['status'] == 'pending' && r['reserved_at'] == null,
      'cancelReason': r['cancel_reason'] ?? '',
      'isRead': r['is_read'] ?? false,
      'preferredSlot': r['preferred_time_slot'] ?? '',
      'patientProfile': r['patient_profile_json'],
      'history': [],
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        title: const Text('치아온 파트너'),
        backgroundColor: const Color(0xFF005A9C),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadTodayData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('오늘의 진료 현황',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              _buildDashboardCard(),
              const SizedBox(height: 30),
              const Text('전체 메뉴',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                childAspectRatio: 1.05,
                children: [
                  _menuButton(
                    '병원 정보 관리', '운영시간 · 서비스',
                    Icons.local_hospital_rounded,
                    const Color(0xFF005A9C), const Color(0xFFEFF6FF),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalInfoPage())),
                  ),
                  _menuButton(
                    '예약 현황', '예약 확인 · 관리',
                    Icons.calendar_month_rounded,
                    const Color(0xFF5B21B6), const Color(0xFFF5F3FF),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationPage())),
                  ),
                  _menuButton(
                    '리뷰 관리', '리뷰 답변 · 현황',
                    Icons.star_rounded,
                    const Color(0xFFC2410C), const Color(0xFFFFF7ED),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReviewManagementPage())),
                  ),
                  _menuButton(
                    '마이페이지', '계정 · 설정',
                    Icons.person_rounded,
                    const Color(0xFF065F46), const Color(0xFFECFDF5),
                    () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyPage())),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardCard() {
    final next = _nextReservation;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF005A9C), Color(0xFF0078D4)]),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: _isLoading
          ? const SizedBox(height: 160, child: Center(child: CircularProgressIndicator(color: Colors.white)))
          : Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── 병원명 + 날짜 + 새로고침 ──
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_hospitalName.isNotEmpty ? _hospitalName : '내 병원',
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              GestureDetector(
                onTap: _loadTodayData,
                child: const Icon(Icons.refresh, color: Colors.white60, size: 18),
              ),
            ],
          ),
          if (_unconfirmedCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: GestureDetector(
                onTap: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => const ReservationPage())),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade700,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '확정 대기 중인 예약 $_unconfirmedCount건 →',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 2),
          Text(DateFormat('MM월 dd일 (E) 오늘').format(DateTime.now()),
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),

          const SizedBox(height: 16),
          const Divider(color: Colors.white24, height: 1),
          const SizedBox(height: 14),

          // ── 1순위: 다음 예약 환자 ──
          if (next != null) ...[
            const Text('다음 예약 환자',
                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            // 탭하면 상세 모달 오픈
            GestureDetector(
              onTap: () => _openDetail(next),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${DateFormat('HH:mm').format(DateTime.parse(next['reserved_at']).toLocal())}  ${next['patient_name']}님',
                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                          ),
                          if ((next['description'] ?? '').isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('상세: ${next['description']}',
                                  style: const TextStyle(color: Colors.white, fontSize: 14)),
                            ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right, color: Colors.white54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Row(children: [
              Icon(
                _totalCount == 0 ? Icons.event_busy : Icons.check_circle_outline,
                color: Colors.white60, size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _totalCount == 0 ? '오늘 예약이 없습니다' : '오늘 남은 예약이 없습니다',
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
            ]),
            const SizedBox(height: 16),
          ],

          // ── 2순위: 통계 카운트 ──
          Row(
            children: [
              _statChip('전체', _totalCount, Colors.white, Colors.white24),
              const SizedBox(width: 8),
              _statChip('대기', _pendingCount, Colors.orange.shade200, Colors.orange.withOpacity(0.25)),
              const SizedBox(width: 8),
              _statChip('확정', _confirmedCount, Colors.green.shade200, Colors.green.withOpacity(0.25)),
              const SizedBox(width: 8),
              _statChip('완료', _completedCount, Colors.blue.shade200, Colors.blue.withOpacity(0.25)),
            ],
          ),
        ],
      ),
    );
  }

  // reservation_page의 _showDetail과 동일한 모달 오픈
  void _openDetail(Map<String, dynamic> rawReservation) {
    final p = _toDetailMap(rawReservation);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Text('${p['name']} 상세 정보',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const Spacer(),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ]),
              const Divider(height: 30),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 기본 정보
                      _detailInfoItem('예약 시간', p['time']),
                      const SizedBox(height: 12),
                      _detailInfoItem('방문 횟수', '${p['count']}번째 방문'),
                      const SizedBox(height: 12),
                      if ((p['desc'] ?? '').isNotEmpty) ...[
                        _detailInfoItem('진료 내용', p['desc']),
                        const SizedBox(height: 12),
                      ],
                      // 진료 히스토리
                      const SizedBox(height: 8),
                      const Text('진료 히스토리',
                          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                      const SizedBox(height: 8),
                      FutureBuilder<List<dynamic>>(
                        future: Supabase.instance.client
                            .from('patient_visits')
                            .select('*')
                            .eq('reservation_id', rawReservation['id']),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Center(child: CircularProgressIndicator());
                          }
                          final visits = snapshot.data ?? [];
                          if (visits.isEmpty) {
                            return const Text('아직 등록된 진료 내역이 없습니다.',
                                style: TextStyle(color: Colors.grey));
                          }
                          return Column(
                            children: visits.map<Widget>((v) => Card(
                              child: ListTile(
                                title: Text(v['visit_date']?.toString() ?? ''),
                                subtitle: Text(v['treatment_type'] ?? ''),
                              ),
                            )).toList(),
                          );
                        },
                      ),
                      if (p['isCancelled'] == true) ...[
                        const SizedBox(height: 16),
                        _detailInfoItem('⚠️ 예약 취소 사유', p['cancelReason'], color: Colors.red),
                      ],
                      const SizedBox(height: 30),
                      // 예약 관리 페이지로 이동 버튼
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.push(context,
                                MaterialPageRoute(builder: (_) => const ReservationPage()));
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF005A9C),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: const Icon(Icons.calendar_month, color: Colors.white),
                          label: const Text('예약 관리 페이지에서 보기',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _detailInfoItem(String label, String value, {Color color = const Color(0xFF005A9C)}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 13)),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(fontSize: 15)),
    ]);
  }

  Widget _statChip(String label, int count, Color textColor, Color bgColor) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: textColor, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _menuButton(String title, String subtitle, IconData icon,
      Color iconColor, Color iconBg, VoidCallback onTap) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, size: 22, color: iconColor),
                  ),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 12, color: Colors.grey.shade300),
                ],
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Color(0xFF111827),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}