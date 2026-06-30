import 'package:flutter/material.dart';
import 'dart:convert'; // JSON 변환용
import 'package:http/http.dart' as http; // 네트워크 통신용
import 'package:supabase_flutter/supabase_flutter.dart';
import 'logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rcpmdwvzyfwwlpagetyn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjcG1kd3Z6eWZ3d2xwYWdldHluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MjUzODcsImV4cCI6MjA5MDIwMTM4N30.sEJ50EkwKLo5P8nmTxJE82vmtzcTCzGHljOSVJDBU7Q',
  );
  runApp(const DentalAdminApp());
}

class DentalAdminApp extends StatelessWidget {
  const DentalAdminApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '덴탈파인더 어드민',
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Pretendard',
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1E293B),
          primary: const Color(0xFF0F172A),
        ),
      ),
      home: const AdminLoginPage(),
    );
  }
}

// --- 1. 로그인 페이지 ---
class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _login() async {
    setState((){_isLoading=true; _errorMsg=null;});
    try{
      final res=await Supabase.instance.client.auth.signInWithPassword(
        email:_emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );
      if(res.user!=null){
        final adminCheck=await Supabase.instance.client
            .from('admin_users')
            .select('id')
            .eq('id',res.user!.id)
            .maybeSingle();

        if(adminCheck==null){
          await Supabase.instance.client.auth.signOut();
          setState(()=>_errorMsg='관리자 전용 계정이 아닙니다.');
          SystemLogger.write(category: '로그인', detail: '로그인 실패 - 관리자 권한 없음', actorEmail: _emailCtrl.text.trim());
          return;
        }

        SystemLogger.write(category: '로그인', detail: '관리자 로그인 성공');
        if(mounted){
          Navigator.pushReplacement(context,MaterialPageRoute(builder: (_)=>const AdminMainDashboard()));
        }
      }
    } on AuthException{
      setState(()=> _errorMsg='아이디 또는 비밀번호가 올바르지 않습니다.');
      SystemLogger.write(category: '로그인', detail: '로그인 실패 - 잘못된 비밀번호', actorEmail: _emailCtrl.text.trim());
    } catch(e){
      debugPrint('로그인 에러: $e');
      setState(()=> _errorMsg='권한 확인 중 오류가 발생했습니다.');
    } finally{
      setState(()=> _isLoading=false);
    }

  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Center(
        child: Container(
          width: 450,
          padding: const EdgeInsets.all(50),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 30, offset: const Offset(0, 10))],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(child: Text('DENTAL FINDER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF0F172A)))),
              const SizedBox(height: 10),
              const Center(child: Text('관리자 시스템', style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500))),
              const SizedBox(height: 40),
              _buildInputLabel('관리자 아이디'),
              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: _buildInputDecoration('아이디를 입력하세요', Icons.person_outline)),
              const SizedBox(height: 20),
              _buildInputLabel('비밀번호'),
              TextField(controller: _pwCtrl, obscureText: true, decoration: _buildInputDecoration('비밀번호를 입력하세요', Icons.lock_outline), onSubmitted: (_) => _login()),
              if (_errorMsg != null) ...[
                const SizedBox(height: 12),
                Text(_errorMsg!, style: const TextStyle(color: Colors.red, fontSize: 13)),
              ],
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), elevation: 0),
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('시스템 접속', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              const Center(child: Text('※ 승인되지 않은 접근은 로그에 기록됩니다.', style: TextStyle(fontSize: 12, color: Colors.redAccent))),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInputLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 8.0),
    child: Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.blueGrey)),
  );

  InputDecoration _buildInputDecoration(String hint, IconData icon) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: const Color(0xFFF8FAFC),
    prefixIcon: Icon(icon, size: 20),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
  );
}

class AdminMainDashboard extends StatelessWidget {
  const AdminMainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // 모던한 아주 연한 회색 배경
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        toolbarHeight: 80,
        title: const Padding(
          padding: EdgeInsets.only(left: 20),
          child: Text(
            'DENTAL FINDER',
            style: TextStyle(
              color: Color(0xFF0F172A),
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
              fontSize: 22,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 30),
            child: TextButton.icon(
              onPressed: () => Navigator.pushReplacement(
                  context, MaterialPageRoute(builder: (_) => const AdminLoginPage())
              ),
              icon: const Icon(Icons.logout, color: Colors.blueGrey, size: 20),
              label: const Text('로그아웃', style: TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                backgroundColor: Colors.grey.shade100,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          // 웹 모니터에서 너무 넓게 퍼지지 않도록 최대 너비 제한 (세련됨의 핵심)
          constraints: const BoxConstraints(maxWidth: 1200),
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 50),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // --- 1. 환영 인사 (Hero Section) ---
                const Text(
                  '환영합니다, 관리자님 👋',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Text(
                  '덴탈파인드 시스템의 전체적인 운영 상태와 데이터를 관리하세요.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                ),
                const SizedBox(height: 50),

                // --- 2. 모던 카드 그리드 (Bento Layout) ---
                LayoutBuilder(
                  builder: (context, constraints) {
                    // 화면 크기에 따라 반응형으로 열 개수 조절
                    int crossAxisCount = 3;
                    double aspectRatio = 1.1; // 정사각형에 가까운 예쁜 비율

                    if (constraints.maxWidth < 900) {
                      crossAxisCount = 2;
                      aspectRatio = 1.3;
                    }
                    if (constraints.maxWidth < 600) {
                      crossAxisCount = 1;
                      aspectRatio = 2.0;
                    }

                    return GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 25,
                      mainAxisSpacing: 25,
                      childAspectRatio: aspectRatio,
                      children: [
                        _modernMenuCard(
                          context: context,
                          title: '병원 관리',
                          sub: '신규 가입 파트너 승인 및 기존 병원 상태 관리',
                          icon: Icons.local_hospital_rounded,
                          color: const Color(0xFF4F46E5), // 세련된 인디고
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalManagementPage())),
                        ),
                        _modernMenuCard(
                          context: context,
                          title: '예약/매칭 관리',
                          sub: '환자와 병원 간의 예약 현황 및 매칭 데이터 조회',
                          icon: Icons.event_available_rounded,
                          color: const Color(0xFF0284C7), // 오션 블루
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ReservationManagementPage())),
                        ),
                        _modernMenuCard(
                          context: context,
                          title: '서비스 운영 현황',
                          sub: '전체 지표, 리뷰 수, AI 진단 요청 통계 (실시간)',
                          icon: Icons.insights_rounded,
                          color: const Color(0xFF0D9488), // 청록색
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ServiceStatusPage())),
                        ),
                        _modernMenuCard(
                          context: context,
                          title: '환자 관리',
                          sub: '가입 소비자 상세 정보 및 통합 리포트 조회',
                          icon: Icons.people_alt_rounded,
                          color: const Color(0xFFD97706), // 따뜻한 오렌지
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PatientManagementPage())),
                        ),
                        _modernMenuCard(
                          context: context,
                          title: '시스템 로그',
                          sub: '서버 접근 기록 및 보안 감시 로그 확인',
                          icon: Icons.admin_panel_settings_rounded,
                          color: const Color(0xFF475569), // 슬레이트 그레이
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemLogManagementPage())),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // --- 세련된 느낌의 신규 카드 디자인 위젯 ---
  Widget _modernMenuCard({
    required BuildContext context,
    required String title,
    required String sub,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08), // 카드 메인 컬러가 은은하게 비치는 그림자
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          hoverColor: color.withOpacity(0.03), // 마우스 올렸을 때 고급스러운 효과
          child: Padding(
            padding: const EdgeInsets.all(30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 아이콘 뱃지
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 32),
                ),
                const Spacer(), // 공간을 밀어내서 텍스트를 아래로 정렬
                Text(
                  title,
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 10),
                Text(
                  sub,
                  style: TextStyle(fontSize: 14, color: Colors.grey[500], height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                // 하단 바로가기 버튼 느낌
                Row(
                  children: [
                    Text('관리하기', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14)),
                    const SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, color: color, size: 16),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} // <--- AdminMainDashboard 클래스 여기서 끝!

// --- 3. 서비스 운영 현황 페이지 ---
// --- 3. 서비스 운영 현황 페이지 (실시간 스트림 적용) ---
class ServiceStatusPage extends StatefulWidget {
  const ServiceStatusPage({super.key});

  @override
  State<ServiceStatusPage> createState() => _ServiceStatusPageState();
}

class _ServiceStatusPageState extends State<ServiceStatusPage> {
  final supabase = Supabase.instance.client;

  // 병원, 예약 등 정적인/덜 자주 변하는 데이터
  bool _isLoadingStatic = true;
  int _hospitalCount = 0;
  int _pendingCount = 0;
  int _reservationCount = 0;

  // 🔴 리뷰, AI 진단처럼 실시간으로 숫자가 올라가는 데이터 스트림
  late final Stream<List<Map<String, dynamic>>> _reviewsStream;
  late final Stream<List<Map<String, dynamic>>> _aiDiagnosesStream;

  @override
  void initState() {
    super.initState();
    _loadStaticStats();

    // 🔴 실시간 데이터 스트림 연결 (id 기준)
    _reviewsStream = supabase.from('reviews').stream(primaryKey: ['id']);
    _aiDiagnosesStream = supabase.from('ai_diagnoses').stream(primaryKey: ['id']);
  }

  // 자주 변하지 않는 지표들만 기존처럼 불러오기
  Future<void> _loadStaticStats() async {
    if (!mounted) return;
    setState(() => _isLoadingStatic = true);
    try {
      final hospitalsRes = await supabase
          .from('hospitals')
          .select('*')
          .eq('status', 'approved')
          .count(CountOption.exact);

      final pendingRes = await supabase
          .from('hospitals')
          .select('*')
          .eq('status', 'pending')
          .count(CountOption.exact);

      final reservationsRes = await supabase
          .from('reservations')
          .select('*')
          .count(CountOption.exact);

      if (mounted) {
        setState(() {
          _hospitalCount = hospitalsRes.count;
          _pendingCount = pendingRes.count;
          _reservationCount = reservationsRes.count;
          _isLoadingStatic = false;
        });
      }
    } catch (e) {
      debugPrint('정적 통계 로드 실패: $e');
      if (mounted) setState(() => _isLoadingStatic = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('서비스 운영 현황', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadStaticStats, tooltip: '정적 데이터 새로고침')
        ],
      ),
      body: _isLoadingStatic
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 통계 대시보드', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.grey[200]!)
              ),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('지표 구분', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('현재 수치', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: [
                  DataRow(cells: [const DataCell(Text('승인된 병원 수')), DataCell(Text('$_hospitalCount개'))]),
                  DataRow(cells: [const DataCell(Text('승인 대기 병원 수')), DataCell(Text('$_pendingCount개'))]),
                  DataRow(cells: [const DataCell(Text('전체 예약 건수')), DataCell(Text('$_reservationCount건'))]),
                  // 전체 리뷰 수 (실시간 연동 - 기본 디자인)
                  DataRow(cells: [
                    const DataCell(Text('전체 리뷰 수')),
                    DataCell(
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _reviewsStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('불러오는 중...', style: TextStyle(color: Colors.grey));
                          }
                          return Text('${snapshot.data?.length ?? 0}건');
                        },
                      ),
                    ),
                  ]),
                  // AI 진단 요청 수 (실시간 연동 - 기본 디자인)
                  DataRow(cells: [
                    const DataCell(Text('AI 진단 요청 수')),
                    DataCell(
                      StreamBuilder<List<Map<String, dynamic>>>(
                        stream: _aiDiagnosesStream,
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Text('불러오는 중...', style: TextStyle(color: Colors.grey));
                          }
                          return Text('${snapshot.data?.length ?? 0}건');
                        },
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. 병원 관리 페이지 ---

class HospitalManagementPage extends StatefulWidget {
  const HospitalManagementPage({super.key});

  @override
  State<HospitalManagementPage> createState() => _HospitalManagementPageState();
}

class _HospitalManagementPageState extends State<HospitalManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final supabase = Supabase.instance.client;

  List<Map<String, dynamic>> pendingHospitals = [];
  List<Map<String, dynamic>> activeHospitals = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() => _isLoading = true);
    try {
      final pending = await supabase
          .from('hospitals')
          .select('*, hospital_documents(*)')
          .eq('status', 'pending')
          .eq('is_partner', true);

      print('pending 데이터: $pending'); // 이 줄 추가

      final active = await supabase
          .from('hospitals')
          .select()
          .or('status.eq.approved,status.eq.inactive,status.eq.suspended');

      setState(() {
        pendingHospitals = List<Map<String, dynamic>>.from(pending);
        activeHospitals = List<Map<String, dynamic>>.from(active);
        _isLoading = false;
      });
    } catch (e) {
      print('데이터 로드 에러: $e');
      setState(() => _isLoading = false);
    }
  }

  // 병원 승인
  Future<void> _approveHospital(Map<String, dynamic> h, int index) async {
    try {
      // 1. hospitals 테이블 status 승인
      await supabase
          .from('hospitals')
          .update({'status': 'approved'})
          .eq('ykiho', h['ykiho']);

      // 2. auth.users 이메일 인증 처리
      await supabase.rpc('confirm_user_email', params: {'user_email': h['email']});

      SystemLogger.write(
        category: '병원 승인',
        detail: '병원 가입 승인: ${h['yadm_nm'] ?? h['ykiho']}',
        targetId: h['ykiho'],
        oldValue: 'pending',
        newValue: 'approved',
      );

      setState(() => pendingHospitals.removeAt(index));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('승인 완료! 파트너가 로그인할 수 있습니다.'), backgroundColor: Colors.green),
        );
      }
      _fetchData();
    } catch (e) {
      print('승인 에러: $e');
    }
  }

  // 병원 반려 (status를 rejected로)
  Future<void> _rejectHospital(Map<String, dynamic> h, int index) async {
    try {
      await supabase
          .from('hospitals')
          .update({'status': 'rejected'})
          .eq('ykiho', h['ykiho']);

      await supabase.rpc('delete_user_by_email', params: {'user_email': h['email']});

      SystemLogger.write(
        category: '병원 승인',
        detail: '병원 가입 반려: ${h['yadm_nm'] ?? h['ykiho']}',
        targetId: h['ykiho'],
        oldValue: 'pending',
        newValue: 'rejected',
      );

      setState(() => pendingHospitals.removeAt(index));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('반려 처리되었습니다.'), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      print('반려 에러: $e');
    }
  }

  // 가입 병원 상태 변경
  Future<void> _updateHospitalStatus(Map<String, dynamic> h, int index, String newStatus) async {
    final statusMap = {'활성': 'approved', '비활성': 'inactive', '정지': 'suspended'};
    final oldStatus = h['status'] ?? 'unknown';
    try {
      await supabase
          .from('hospitals')
          .update({'status': statusMap[newStatus] ?? newStatus})
          .eq('ykiho', h['ykiho']);

      setState(() => activeHospitals[index]['status'] = statusMap[newStatus] ?? newStatus);

      SystemLogger.write(
        category: '병원 승인',
        detail: '병원 상태 변경: ${h['yadm_nm'] ?? h['ykiho']}',
        targetId: h['ykiho'],
        oldValue: oldStatus,
        newValue: statusMap[newStatus] ?? newStatus,
      );

      if (mounted) Navigator.pop(context);
    } catch (e) {
      print('상태 변경 에러: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('병원 관리 시스템', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchData,
            tooltip: '새로고침',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
          tabs: [
            Tab(text: '신규 승인 대기 (${pendingHospitals.length})'),
            Tab(text: '가입 병원 목록 (${activeHospitals.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
        controller: _tabController,
        children: [_buildPendingTab(), _buildActiveTab()],
      ),
    );
  }

  // --- 1. 신규 승인 대기 탭 ---
  Widget _buildPendingTab() {
    if (pendingHospitals.isEmpty) {
      return const Center(child: Text('승인 대기 중인 병원이 없습니다.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(30),
      itemCount: pendingHospitals.length,
      itemBuilder: (context, index) {
        final h = pendingHospitals[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(h['yadm_nm'] ?? '이름 없음',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 5),
                      Text('주소: ${h['addr'] ?? '-'}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                      Text('이메일: ${h['email'] ?? '-'} | 신청일: ${h['last_synced_at']?.toString().substring(0, 10) ?? '-'}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showDetailDoc(h, index),
                  child: const Text('서류 확인'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: () => _confirmReject(h, index),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
                  child: const Text('반려'),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () => _approveHospital(h, index),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  child: const Text('즉시 승인'),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // --- 2. 가입 병원 목록 탭 ---
  Widget _buildActiveTab() {
    if (activeHospitals.isEmpty) {
      return const Center(child: Text('가입된 병원이 없습니다.'));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey[200]!)),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
              columnSpacing: 30,
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('병원명', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('이메일', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('주소', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('상태', style: TextStyle(fontWeight: FontWeight.bold))),
                DataColumn(label: Text('관리', style: TextStyle(fontWeight: FontWeight.bold))),
              ],
              rows: activeHospitals.asMap().entries.map((entry) {
                int idx = entry.key;
                var h = entry.value;
                return DataRow(cells: [
                  DataCell(Text(h['yadm_nm'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                  DataCell(Text(h['email'] ?? '-')),
                  DataCell(SizedBox(width: 200, child: Text(h['addr'] ?? '-', overflow: TextOverflow.ellipsis))),
                  DataCell(_statusBadge(h['status'] ?? 'approved')),
                  DataCell(ElevatedButton(
                    onPressed: () => _showStatusManagement(h, idx),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[100], foregroundColor: Colors.black, elevation: 0),
                    child: const Text('운영관리'),
                  )),
                ]);
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final map = {
      'approved': ('활성', Colors.green),
      'inactive': ('비활성', Colors.orange),
      'suspended': ('정지', Colors.red),
      'pending': ('대기', Colors.blue),
      'rejected': ('반려', Colors.red),
    };
    final info = map[status] ?? (status, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: info.$2.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(info.$1, style: TextStyle(color: info.$2, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // 반려 확인 팝업
  void _confirmReject(Map<String, dynamic> h, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('반려 확인'),
        content: Text('${h['yadm_nm']}의 가입 신청을 반려하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); _rejectHospital(h, index); },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('반려'),
          ),
        ],
      ),
    );
  }

  // 서류 확인 팝업
  void _showDetailDoc(Map<String, dynamic> h, int index) {
    // 이 줄 추가
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('서류 수: ${(h['hospital_documents'] as List?)?.length ?? 0}개'))
    );

    bool licenseOk = false;
    bool businessOk = false;
    bool reportOk = false;

    // hospital_documents에서 서류 URL 추출 (파트너앱 doc_type 기준)
    final docs = (h['hospital_documents'] as List?) ?? [];
    String? licenseUrl = docs.firstWhere((d) => d['doc_type'] == 'license', orElse: () => {})['file_url'];
    String? businessUrl = docs.firstWhere((d) => d['doc_type'] == 'business', orElse: () => {})['file_url'];
    String? reportUrl = docs.firstWhere((d) => d['doc_type'] == 'report', orElse: () => {})['file_url'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${h['yadm_nm'] ?? '이름 없음'} 서류 검수'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAiReportSection(75), // AI 신뢰도는 고정값 (추후 연동 가능)
                  const Divider(height: 30),
                  _checkStepWithImage(
                    title: '1. 의사 면허증',
                    isDone: licenseOk,
                    onTap: () => setDialogState(() => licenseOk = !licenseOk),
                    onImageTap: () => _showImagePreview(context, '의사 면허증', licenseUrl),
                  ),
                  _checkStepWithImage(
                    title: '2. 사업자 등록증',
                    isDone: businessOk,
                    onTap: () => setDialogState(() => businessOk = !businessOk),
                    onImageTap: () => _showImagePreview(context, '사업자 등록증', businessUrl),
                  ),
                  _checkStepWithImage(
                    title: '3. 의료기관 개설 신고증',
                    isDone: reportOk,
                    onTap: () => setDialogState(() => reportOk = !reportOk),
                    onImageTap: () => _showImagePreview(context, '의료기관 개설 신고증', reportUrl),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            OutlinedButton(
              onPressed: () { Navigator.pop(context); _confirmReject(h, index); },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red, side: const BorderSide(color: Colors.red)),
              child: const Text('반려'),
            ),
            ElevatedButton(
              onPressed: (licenseOk && businessOk && reportOk)
                  ? () { _approveHospital(h, index); Navigator.pop(context); }
                  : null,
              style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey[300]),
              child: const Text('최종 승인 및 파트너 등록'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _checkStepWithImage({
    required String title,
    required bool isDone,
    required VoidCallback onTap,
    required VoidCallback onImageTap,
  }) {
    return ListTile(
      leading: Checkbox(value: isDone, onChanged: (_) => onTap()),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.image_search, color: Colors.blue),
        onPressed: onImageTap,
        tooltip: '이미지 원본 보기',
      ),
    );
  }

  // Supabase Storage URL로 이미지 미리보기
  void _showImagePreview(BuildContext context, String title, String? fileUrl) {
    if (fileUrl == null || fileUrl.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('업로드된 파일이 없습니다.')),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 500,
          height: 600,
          child: Image.network(
            fileUrl,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) =>
            const Center(child: Text('이미지를 불러올 수 없습니다.')),
          ),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  Widget _buildAiReportSection(int score) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: score > 60 ? Colors.green[50] : Colors.red[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: score > 60 ? Colors.green[200]! : Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.psychology, size: 20),
              const SizedBox(width: 8),
              const Text('AI 분석 의견', style: TextStyle(fontWeight: FontWeight.bold)),
              const Spacer(),
              Text('신뢰도 $score%', style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            score > 60
                ? '● 서류 내 인장 및 텍스트 데이터가 공공 DB와 90% 이상 일치합니다.\n● 육안상 특이점이 발견되지 않아 승인을 권장합니다.'
                : '● 주의: 서류의 일부 텍스트가 흐릿하거나 위변조 흔적이 감지되었습니다.\n● 반드시 원본 이미지를 정밀하게 대조하십시오.',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
      ),
    );
  }

  void _showStatusManagement(Map<String, dynamic> h, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${h['yadm_nm']} 상태 변경', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            ListTile(
              title: const Text('정상 활성화'),
              leading: const Icon(Icons.check_circle, color: Colors.green),
              onTap: () => _updateHospitalStatus(h, index, '활성'),
            ),
            ListTile(
              title: const Text('일시 비활성화'),
              leading: const Icon(Icons.pause_circle, color: Colors.orange),
              onTap: () => _updateHospitalStatus(h, index, '비활성'),
            ),
            ListTile(
              title: const Text('영구 정지'),
              leading: const Icon(Icons.block, color: Colors.red),
              onTap: () => _updateHospitalStatus(h, index, '정지'),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 예약/매칭 관리 페이지 ---
class ReservationManagementPage extends StatefulWidget {
  const ReservationManagementPage({super.key});

  @override
  State<ReservationManagementPage> createState() => _ReservationManagementPageState();
}

class _ReservationManagementPageState extends State<ReservationManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reservations = [];
  bool _isLoading = true;

  final Map<String, String> _statusLabel = {'pending': '대기', 'confirmed': '확정', 'cancelled': '취소', 'done': '완료', 'completed': '완료'};

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('reservations')
          .select('id, patient_name, patient_id, reserved_at, description, status, ykiho, hospitals(yadm_nm)')
          .order('reserved_at', ascending: false)
          .limit(100);
      setState(() => _reservations = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('예약 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final idx = _reservations.indexWhere((r) => r['id'].toString() == id);
    final oldStatus = idx != -1 ? (_reservations[idx]['status'] ?? 'unknown') : 'unknown';
    try {
      await supabase.from('reservations').update({'status': newStatus}).eq('id', id);
      setState(() {
        if (idx != -1) _reservations[idx]['status'] = newStatus;
      });
      SystemLogger.write(
        category: '예약 변경',
        detail: '예약 상태 변경 [${_statusLabel[oldStatus] ?? oldStatus} → ${_statusLabel[newStatus] ?? newStatus}]',
        targetId: id,
        oldValue: oldStatus,
        newValue: newStatus,
      );
    } catch (e) {
      debugPrint('상태 변경 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('예약/매칭 관리 시스템', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadReservations, tooltip: '새로고침')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 예약 목록 조회', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)]),
              child: _reservations.isEmpty
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('예약 데이터가 없습니다.')))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 25,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('예약 ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('예약 일시', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('환자명', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('병원명', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('진료 내용', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('상태', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('관리', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _reservations.asMap().entries.map((entry) {
                      final res = entry.value;
                      final hospitalName = res['hospitals']?['yadm_nm'] ?? '-';
                      final dt = DateTime.tryParse(res['reserved_at'] ?? '');
                      final dtStr = dt != null ? '${dt.toLocal().year}-${dt.toLocal().month.toString().padLeft(2,'0')}-${dt.toLocal().day.toString().padLeft(2,'0')} ${dt.toLocal().hour.toString().padLeft(2,'0')}:${dt.toLocal().minute.toString().padLeft(2,'0')}' : '-';
                      final status = res['status'] ?? 'pending';
                      return DataRow(cells: [
                        DataCell(Text(res['id'].toString().substring(0, 8), style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                        DataCell(Text(dtStr)),
                        DataCell(Text(res['patient_name'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text(hospitalName)),
                        DataCell(SizedBox(width: 150, child: Text(res['description'] ?? '-', overflow: TextOverflow.ellipsis))),
                        DataCell(_buildStatusBadge(status)),
                        DataCell(ElevatedButton(
                          onPressed: () => _showReservationDetail(res),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[100], foregroundColor: Colors.black, elevation: 0),
                          child: const Text('상세/수정'),
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String status) {
    final map = {'pending': ('대기', Colors.blue), 'confirmed': ('확정', Colors.green), 'cancelled': ('취소', Colors.red), 'done': ('완료', Colors.grey), 'completed': ('완료', Colors.grey)};
    final info = map[status] ?? (status, Colors.grey);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: info.$2.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(info.$1, style: TextStyle(color: info.$2, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  void _showReservationDetail(Map<String, dynamic> res) {
    final hospitalName = res['hospitals']?['yadm_nm'] ?? '-';
    final id = res['id'].toString();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setD) => AlertDialog(
          title: const Text('예약 상세 정보 및 상태 변경'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _detailText('예약 ID', id),
              _detailText('환자명', res['patient_name'] ?? '-'),
              _detailText('병원', hospitalName),
              _detailText('진료 내용', res['description'] ?? '-'),
              const Divider(height: 30),
              const Text('상태 변경', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: ['pending', 'confirmed', 'cancelled', 'completed'].map((s) {
                  final lbl = _statusLabel[s] ?? s;
                  return ChoiceChip(
                    label: Text(lbl),
                    selected: res['status'] == s,
                    onSelected: (val) async {
                      if (val) {
                        await _updateStatus(id, s);
                        setD(() => res['status'] = s);
                        if (mounted) Navigator.pop(context);
                      }
                    },
                  );
                }).toList(),
              ),
            ],
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
        ),
      ),
    );
  }

  Widget _detailText(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Text('$label: $value', style: const TextStyle(fontSize: 14)),
  );
}

// --- 시스템 로그 관리 페이지 데이터 ---

class SystemLogManagementPage extends StatefulWidget {
  const SystemLogManagementPage({super.key});

  @override
  State<SystemLogManagementPage> createState() => _SystemLogManagementPageState();
}

class _SystemLogManagementPageState extends State<SystemLogManagementPage> {
  final supabase = Supabase.instance.client;
  String selectedFilter = '전체';

  List<Map<String, dynamic>> _logs = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  // 수파베이스에서 진짜 로그 데이터를 최신순으로 불러오는 함수
  Future<void> _loadLogs() async {
    setState(() => _isLoading = true);
    try {
      final data = await supabase
          .from('system_logs')
          .select()
          .order('created_at', ascending: false);

      setState(() => _logs = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('시스템 로그 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 필터링 적용
    List<Map<String, dynamic>> filteredLogs = selectedFilter == '전체'
        ? _logs
        : _logs.where((log) => log['category'] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('시스템 로그 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [
          // 새로고침 버튼
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadLogs, tooltip: '새로고침'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 로그 내역', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),

            // 필터 칩 영역
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['전체', '로그인', '병원 승인', '예약 변경', '리뷰 관리', '민감정보 열람', '병원정보 변경', '가격 변경'].map((filter) {
                return ChoiceChip(
                  label: Text(filter),
                  selected: selectedFilter == filter,
                  onSelected: (val) {
                    if (val) setState(() => selectedFilter = filter);
                  },
                );
              }).toList(),
            ),

            const SizedBox(height: 30),

            // 표 영역
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: filteredLogs.isEmpty
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('기록된 로그가 없습니다.')))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('로그 유형', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('작업자 (이메일)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('활동 내역', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('변경 내역', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('발생 일시', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredLogs.map((log) {
                      final dt = DateTime.tryParse(log['created_at'] ?? '')?.toLocal();
                      final dateStr = dt != null ? '${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')} ${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}' : '-';

                      final oldVal = log['old_value'];
                      final newVal = log['new_value'];
                      final changeStr = (oldVal != null && newVal != null) ? '$oldVal → $newVal' : '-';

                      return DataRow(cells: [
                        DataCell(_buildTypeBadge(log['category'] ?? '기타')),
                        DataCell(Text(log['actor_email'] ?? '-')),
                        DataCell(
                          Container(
                            constraints: const BoxConstraints(maxWidth: 350),
                            child: Text(log['action_detail'] ?? '-', overflow: TextOverflow.ellipsis),
                          ),
                        ),
                        DataCell(Text(changeStr, style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                        DataCell(Text(dateStr, style: const TextStyle(fontSize: 13, color: Colors.grey))),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTypeBadge(String type) {
    Color color;
    switch (type) {
      case '로그인': color = Colors.indigo; break;
      case '병원 승인': color = Colors.green; break;
      case '예약 변경': color = Colors.orange; break;
      case '리뷰 관리': color = Colors.purple; break;
      case '민감정보 열람': color = Colors.red; break;
      case '병원정보 변경': color = Colors.teal; break;
      case '가격 변경': color = Colors.brown; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(type, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// --- 환자 관리 페이지 (실제 DB 스키마 완벽 반영 버전) ---
class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _patients = [];
  bool _isLoading = true;
  String _searchKeyword = '';

  @override
  void initState() {
    super.initState();
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    setState(() => _isLoading = true);
    try {
      // (만약 에러가 난다면 .order('"createdAt"', ascending: false) 로 따옴표를 추가해야 할 수 있습니다)
      final data = await supabase
          .from('user')
          .select('id, email, firstName, lastName, createdAt, lastActiveAt')
          .order('createdAt', ascending: false);

      setState(() => _patients = List<Map<String, dynamic>>.from(data));
    } catch (e) {
      debugPrint('환자 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filtered => _patients
      .where((p) {
    // Postgres는 대소문자를 무시하고 소문자로 반환할 때가 있어서 두 경우 모두 대비
    final fName = p['firstName'] ?? p['firstname'] ?? '';
    final lName = p['lastName'] ?? p['lastname'] ?? '';
    final fullName = '$lName$fName'.toLowerCase();
    final search = _searchKeyword.toLowerCase();

    return fullName.contains(search) ||
        (p['email'] ?? '').toString().toLowerCase().contains(search);
  })
      .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('환자 관리 시스템', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
        actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _loadPatients, tooltip: '새로고침')],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('전체 가입 환자 목록', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                SizedBox(
                  width: 300,
                  child: TextField(
                    decoration: InputDecoration(
                        hintText: '환자 이름/이메일 검색',
                        prefixIcon: const Icon(Icons.search),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)
                    ),
                    onChanged: (val) => setState(() => _searchKeyword = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
              child: _filtered.isEmpty
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('가입된 환자 데이터가 없습니다.')))
                  : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 30,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('성함 (이메일)', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('성별/나이', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('연락처', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('최근 접속일', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('상세 관리', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: _filtered.map((p) {
                      // 🔴 데이터 파싱 (스키마 완벽 대응)
                      final id = p['id']?.toString().substring(0, 8) ?? '-';

                      // 이름 조합
                      final fName = p['firstName'] ?? p['firstname'] ?? '';
                      final lName = p['lastName'] ?? p['lastname'] ?? '';
                      String name = '$lName $fName'.trim();
                      if (name.isEmpty) name = '미입력';

                      final email = p['email'] ?? '이메일 없음';

                      // DB에 없는 정보들
                      final gender = '미상';
                      final age = '?';
                      final phone = '미입력';

                      // 날짜 처리 (createdAt, lastActiveAt)
                      final activeRaw = p['lastActiveAt'] ?? p['lastactiveat'];
                      final createdRaw = p['createdAt'] ?? p['createdat'];

                      // lastActiveAt이 있으면 쓰고, 없으면 createdAt 사용
                      final dateToShow = activeRaw != null
                          ? activeRaw.toString().substring(0, 10)
                          : (createdRaw != null ? createdRaw.toString().substring(0, 10) : '-');

                      return DataRow(cells: [
                        DataCell(Text(id, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold, fontSize: 12))),
                        DataCell(Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(email, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                          ],
                        )),
                        DataCell(Text('$gender/${age}세')),
                        DataCell(Text(phone)),
                        DataCell(Text(dateToShow)),
                        DataCell(Row(
                          children: [
                            OutlinedButton(
                              onPressed: () => _showReportModal(p, name),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.indigo, side: const BorderSide(color: Colors.indigo),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero),
                              child: const Text('리포트/이력', style: TextStyle(fontSize: 12)),
                            ),
                            const SizedBox(width: 8),
                            OutlinedButton(
                              onPressed: () => _showReviewModal(p, name),
                              style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.teal, side: const BorderSide(color: Colors.teal),
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8), minimumSize: Size.zero),
                              child: const Text('리뷰 기록', style: TextStyle(fontSize: 12)),
                            ),
                          ],
                        )),
                      ]);
                    }).toList(),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showReportModal(Map<String, dynamic> patient, String name) {
    SystemLogger.write(
      category: '민감정보 열람',
      detail: '환자 통합 리포트 열람: $name',
      targetId: patient['id']?.toString(),
    );
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('$name 환자 통합 리포트', style: const TextStyle(fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
          ],
        ),
        content: SizedBox(
          width: 600,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionTitle('현재 방문 설문 데이터'),
                _buildInfoBox('최근 어금니 통증 및 잇몸 부음 증상 있음'),
                const SizedBox(height: 20),
                _buildSectionTitle('AI 정밀 분석 결과'),
                _buildInfoBox('제 2대구치 주변 치주염 징후 85% 감지. 스케일링 및 정밀 검사 권장.', isAi: true),
                const SizedBox(height: 20),
                _buildSectionTitle('과거 진료 기록'),
                _buildHistoryItem('2026-02-27', '임플란트 상담 및 AI 정밀 분석'),
                _buildHistoryItem('2025-11-10', '정기 검진 및 스케일링'),
              ],
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
            child: const Text('닫기'),
          )
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('• $title', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildInfoBox(String content, {bool isAi = false}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: isAi ? Colors.blue[50] : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: isAi ? Border.all(color: Colors.blue[200]!) : null,
      ),
      child: Text(content, style: const TextStyle(fontSize: 14)),
    );
  }

  Widget _buildHistoryItem(String date, String desc) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(date, style: const TextStyle(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
          ),
          Expanded(child: Text(desc)),
        ],
      ),
    );
  }

  void _showReviewModal(Map<String, dynamic> patient, String name) async {
    List<Map<String, dynamic>> reviews = [];
    try {
      final data = await supabase
          .from('reviews')
          .select('id, ykiho, content, rating, reviewed_at, is_hidden, is_deleted, hospitals(yadm_nm)')
          .eq('patient_id', patient['id'].toString())
          .order('reviewed_at', ascending: false);
      reviews = List<Map<String, dynamic>>.from(data);
    } catch (e) {
      debugPrint('리뷰 로드 실패: $e');
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFFF8FAFC),
              surfaceTintColor: Colors.transparent,
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$name 님의 리뷰 관리', style: const TextStyle(fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))
                ],
              ),
              content: SizedBox(
                width: 700,
                child: reviews.isEmpty
                  ? const Padding(padding: EdgeInsets.all(40), child: Center(child: Text('작성된 리뷰가 없습니다.')))
                  : SingleChildScrollView(
                      child: Column(
                        children: reviews.map((rev) {
                          final hospitalName = rev['hospitals']?['yadm_nm'] ?? rev['ykiho'] ?? '-';
                          final isHidden = rev['is_hidden'] ?? false;
                          final isDeleted = rev['is_deleted'] ?? false;
                          final dt = DateTime.tryParse(rev['reviewed_at'] ?? '')?.toLocal();
                          final dateStr = dt != null ? '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}' : '-';

                          return Card(
                            color: Colors.white,
                            margin: const EdgeInsets.only(bottom: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey[200]!)),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Text(hospitalName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                          if (isHidden) ...[
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(4)),
                                              child: const Text('숨김처리됨', style: TextStyle(color: Colors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                          if (isDeleted) ...[
                                            const SizedBox(width: 10),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(color: Colors.red[100], borderRadius: BorderRadius.circular(4)),
                                              child: const Text('삭제처리됨', style: TextStyle(color: Colors.red, fontSize: 11, fontWeight: FontWeight.bold)),
                                            )
                                          ],
                                        ],
                                      ),
                                      Text(dateStr, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                    ],
                                  ),
                                  const SizedBox(height: 15),
                                  Text(
                                    isDeleted ? '관리자에 의해 삭제된 리뷰입니다.' : (rev['content'] ?? ''),
                                    style: TextStyle(fontSize: 14, color: isDeleted ? Colors.redAccent : Colors.black87),
                                  ),
                                  const SizedBox(height: 15),
                                  const Divider(height: 1),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      if (!isDeleted)
                                        TextButton.icon(
                                          icon: Icon(isHidden ? Icons.visibility : Icons.visibility_off, size: 16, color: Colors.orange),
                                          label: Text(isHidden ? '숨김 해제' : '리뷰 숨기기', style: const TextStyle(color: Colors.orange)),
                                          onPressed: () async {
                                            final newHidden = !isHidden;
                                            await supabase.from('reviews').update({'is_hidden': newHidden}).eq('id', rev['id'].toString());
                                            setModalState(() => rev['is_hidden'] = newHidden);
                                            SystemLogger.write(
                                              category: '리뷰 관리',
                                              detail: newHidden ? '리뷰 숨김 처리: $hospitalName' : '리뷰 숨김 해제: $hospitalName',
                                              targetId: rev['id'].toString(),
                                            );
                                          },
                                        ),
                                      const SizedBox(width: 10),
                                      if (!isDeleted)
                                        TextButton.icon(
                                          icon: const Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                          label: const Text('리뷰 삭제', style: TextStyle(color: Colors.red)),
                                          onPressed: () => _confirmDeleteReview(context, setModalState, rev, hospitalName),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              ),
            );
          }
      ),
    );
  }

  void _confirmDeleteReview(BuildContext parentContext, void Function(void Function()) setModalState, Map<String, dynamic> review, String hospitalName) {
    showDialog(
      context: parentContext,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('이 리뷰를 삭제 처리하시겠습니까?\n데이터는 남지만 서비스에는 노출되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            onPressed: () async {
              await supabase.from('reviews').update({'is_deleted': true}).eq('id', review['id'].toString());
              setModalState(() => review['is_deleted'] = true);
              SystemLogger.write(
                category: '리뷰 관리',
                detail: '리뷰 삭제 처리: $hospitalName',
                targetId: review['id'].toString(),
              );
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('삭제 확정'),
          ),
        ],
      ),
    );
  }
}