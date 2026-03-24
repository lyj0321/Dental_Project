import 'package:flutter/material.dart';

void main() => runApp(const DentalAdminApp());

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

// --- 1. 로그인 페이지 (한글화 완료) ---
class AdminLoginPage extends StatelessWidget {
  const AdminLoginPage({super.key});

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
              const Center(
                child: Text('DENTAL FINDER', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, letterSpacing: 1.5, color: Color(0xFF0F172A))),
              ),
              const SizedBox(height: 10),
              const Center(
                child: Text('관리자 시스템', style: TextStyle(fontSize: 14, color: Colors.blueGrey, fontWeight: FontWeight.w500)),
              ),
              const SizedBox(height: 40),
              _buildInputLabel('관리자 아이디'), // 'Admin ID' -> '관리자 아이디'
              TextField(
                decoration: _buildInputDecoration('아이디를 입력하세요', Icons.person_outline), // 'Enter your ID' -> '아이디를 입력하세요'
              ),
              const SizedBox(height: 20),
              _buildInputLabel('비밀번호'), // 'Password' -> '비밀번호'
              TextField(
                obscureText: true,
                decoration: _buildInputDecoration('비밀번호를 입력하세요', Icons.lock_outline), // 'Enter your password' -> '비밀번호를 입력하세요'
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminMainDashboard())),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0F172A),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 0,
                  ),
                  child: const Text('시스템 접속', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 15),
              const Center(
                child: Text('※ 승인되지 않은 접근은 로그에 기록됩니다.', style: TextStyle(fontSize: 12, color: Colors.redAccent)),
              ),
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

// --- 2. 메인 대시보드 ---
class AdminMainDashboard extends StatelessWidget {
  const AdminMainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Row(
        children: [
          _buildSidebar(context),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('System Overview', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 30),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      int crossAxisCount = 3;
                      double aspectRatio = 2.2; 

                      if (constraints.maxWidth < 1100) {
                        crossAxisCount = 2;
                        aspectRatio = 2.5;
                      }
                      if (constraints.maxWidth < 700) {
                        crossAxisCount = 1;
                        aspectRatio = 4.0;
                      }

                      return GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: crossAxisCount,
                        crossAxisSpacing: 20,
                        mainAxisSpacing: 20,
                        childAspectRatio: aspectRatio, 
                        children: [
                          _menuCard(context, '병원 관리', '신규 가입 승인 및 리스트 확인', Icons.local_hospital, Colors.indigo, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const HospitalManagementPage()));
                          }),
                          _menuCard(context, '예약/매칭 관리', '환자-병원 매칭 및 예약 현황', Icons.event_note, Colors.blue, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReservationManagementPage()));
                          }),                          
                          _menuCard(context, '서비스 운영 현황', '전체 지표 및 통계 데이터 확인', Icons.bar_chart, Colors.teal, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceStatusPage()));
                          }),
                          _menuCard(context, '환자 관리', '가입 소비자 정보 관리', Icons.people_alt, Colors.orange, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const PatientManagementPage()));
                          }),
                          _menuCard(context, '시스템 로그', '서버 및 접근 로그 확인', Icons.terminal, Colors.blueGrey, () {
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemLogManagementPage()));
                          }),                        
                        ],
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- 대시보드 내부 위젯들 ---
  Widget _buildSidebar(BuildContext context) {
    return Container(
      width: 280,
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ADMIN CENTER', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 50),
          // 1. Dashboard (현재 페이지이므로 스택을 비우고 이동하거나 유지)
          _sidebarItem(Icons.grid_view_rounded, 'Dashboard', true, () {
            Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AdminMainDashboard()), (route) => false);
          }),
          // 2. 병원 관리
          _sidebarItem(Icons.local_hospital, '병원 관리', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const HospitalManagementPage()));
          }),
          // 3. 예약/매칭 관리
          _sidebarItem(Icons.event_available, '예약/매칭 관리', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ReservationManagementPage()));
          }),
          // 4. 서비스 운영 현황
          _sidebarItem(Icons.analytics, '서비스 운영 현황', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const ServiceStatusPage()));
          }),
          // 5. 환자 관리 (아직 페이지 미구현 시 빈 함수 또는 스낵바)
          _sidebarItem(Icons.person_search, '환자 관리', false, () {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('환자 관리 페이지는 준비 중입니다.')));
          }),
          // 6. 시스템 로그
          _sidebarItem(Icons.security, '시스템 로그', false, () {
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SystemLogManagementPage()));
          }),
          const Spacer(),
          TextButton.icon(
            onPressed: () => Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const AdminLoginPage()), (route) => false),
            icon: const Icon(Icons.logout, color: Colors.white54, size: 18),
            label: const Text('Logout', style: TextStyle(color: Colors.white54)),
          )
        ],
      ),
    );
  }

  Widget _sidebarItem(IconData icon, String title, bool isSelected, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: isSelected ? Colors.white : Colors.white24),
        title: Text(title, style: TextStyle(color: isSelected ? Colors.white : Colors.white54, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        tileColor: isSelected ? Colors.white.withOpacity(0.1) : Colors.transparent,
      ),
    );
  }

  Widget _menuCard(BuildContext context, String title, String sub, IconData icon, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub, style: TextStyle(fontSize: 11, color: Colors.grey[500]), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey[300]),
          ],
        ),
      ),
    );
  }
} // <--- AdminMainDashboard 클래스 여기서 끝!

// --- 3. 서비스 운영 현황 페이지 ---
class ServiceStatusPage extends StatelessWidget {
  const ServiceStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(title: const Text('서비스 운영 현황'), backgroundColor: Colors.white, surfaceTintColor: Colors.transparent),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 통계 대시보드', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
              child: DataTable(
                headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                columns: const [
                  DataColumn(label: Text('지표 구분', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('현재 수치', style: TextStyle(fontWeight: FontWeight.bold))),
                  DataColumn(label: Text('전월 대비 (증감)', style: TextStyle(fontWeight: FontWeight.bold))),
                ],
                rows: const [
                  DataRow(cells: [DataCell(Text('가입 병원 수')), DataCell(Text('142개')), DataCell(Text('+5%'))]),
                  DataRow(cells: [DataCell(Text('가입 소비자(환자) 수')), DataCell(Text('3,420명')), DataCell(Text('+12%'))]),
                  DataRow(cells: [DataCell(Text('매칭 성공 건수 (예약 완료)')), DataCell(Text('12,500건')), DataCell(Text('+8%'))]),
                  DataRow(cells: [DataCell(Text('설문 및 AI 분석 요청 수')), DataCell(Text('890건')), DataCell(Text('+15%'))]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 4. 병원 관리 페이지 (데이터 유지 + 클래스 구조 수정) ---

// [데이터 유지] 페이지 이동 시 초기화되지 않도록 전역 변수로 선언
List<Map<String, dynamic>> globalPendingHospitals = [
  {'id': 'H001', 'name': '강남 바른치과', 'date': '2026-02-20', 'doc': '면허증_H001.jpg', 'ai_score': 98, 'is_checked': false},
  {'id': 'H002', 'name': '서울 연세치과', 'date': '2026-02-21', 'doc': '면허증_H002.jpg', 'ai_score': 45, 'is_checked': false},
];

List<Map<String, dynamic>> globalActiveHospitals = [
  {'id': 'D-001', 'name': '미소치과의원', 'location': '서울시 강남구', 'status': '활성'},
  {'id': 'D-002', 'name': '튼튼치과', 'location': '대구시 중구', 'status': '비활성'},
];

// [필수!] StatefulWidget 클래스 정의 (이 부분이 빠져서 에러가 났던 거예요)
class HospitalManagementPage extends StatefulWidget {
  const HospitalManagementPage({super.key});

  @override
  State<HospitalManagementPage> createState() => _HospitalManagementPageState();
}

class _HospitalManagementPageState extends State<HospitalManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF0F172A),
          indicatorColor: const Color(0xFF0F172A),
          tabs: const [Tab(text: '신규 승인 대기'), Tab(text: '가입 병원 목록')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildPendingTab(), _buildActiveTab()],
      ),
    );
  }

  // --- 1. 신규 승인 대기 탭 ---
  Widget _buildPendingTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(30),
      itemCount: globalPendingHospitals.length,
      itemBuilder: (context, index) {
        final h = globalPendingHospitals[index];
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
                      Row(
                        children: [
                          Text(h['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                          const SizedBox(width: 10),
                          _aiBadge(h['ai_score']),
                        ],
                      ),
                      const SizedBox(height: 5),
                      Text('신청일: ${h['date']} | 서류: ${h['doc']}', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => _showDetailDoc(h, index),
                  child: const Text('상세확인'),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: h['is_checked'] ? () => _approveHospital(h, index) : null,
                  style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
                  child: const Text('승인'),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: () => _rejectHospital(index),
                  style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('반려'),
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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(30),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
        child: DataTable(
          columns: const [
            DataColumn(label: Text('ID')),
            DataColumn(label: Text('병원 이름')),
            DataColumn(label: Text('상태')),
            DataColumn(label: Text('관리')),
          ],
          rows: globalActiveHospitals.asMap().entries.map((entry) {
            int idx = entry.key;
            var h = entry.value;
            return DataRow(cells: [
              DataCell(Text(h['id'])),
              DataCell(Text(h['name'])),
              DataCell(_statusBadge(h['status'])),
              DataCell(ElevatedButton(
                onPressed: () => _showStatusManagement(h, idx),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[100], foregroundColor: Colors.black, elevation: 0),
                child: const Text('운영관리'),
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  // AI 배지 및 상태 배지
  Widget _aiBadge(int score) {
    Color color = score > 80 ? Colors.green : (score > 50 ? Colors.orange : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
      child: Text('AI 신뢰도 $score%', style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }

  Widget _statusBadge(String status) {
    Color col = status == '활성' ? Colors.green : (status == '비활성' ? Colors.orange : Colors.red);
    return Text(status, style: TextStyle(color: col, fontWeight: FontWeight.bold, fontSize: 13));
  }

  // 상세 서류 확인 팝업 (이미지 보기 기능 + 즉시 승인/반려 통합)
  void _showDetailDoc(Map<String, dynamic> h, int index) {
    bool licenseOk = false;
    bool businessOk = false;
    bool reportOk = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text('${h['name']} 통합 검수 및 승인'),
          content: SizedBox(
            width: 700,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildAiReportSection(h['ai_score']),
                  const Divider(height: 30),
                  
                  // 3대 서류 체크리스트
                  _checkStepWithImage(
                    title: '1. 의사 면허증',
                    isDone: licenseOk,
                    onTap: () => setDialogState(() => licenseOk = !licenseOk),
                    onImageTap: () => _showImagePreview(context, '의사 면허증 원본', 'assets/images/license_sample.jpg'),
                  ),
                  _checkStepWithImage(
                    title: '2. 사업자 등록증',
                    isDone: businessOk,
                    onTap: () => setDialogState(() => businessOk = !businessOk),
                    onImageTap: () => _showImagePreview(context, '사업자 등록증 원본', 'assets/images/business_sample.jpg'),
                  ),
                  _checkStepWithImage(
                    title: '3. 의료기관 개설 신고증',
                    isDone: reportOk,
                    onTap: () => setDialogState(() => reportOk = !reportOk),
                    onImageTap: () => _showImagePreview(context, '개설 신고증 원본', 'assets/images/report_sample.jpg'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')),
            // 검수 창 내에서 즉시 반려
            OutlinedButton(
              onPressed: () {
                _rejectHospital(index);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('반려'),
            ),
            // 검수 창 내에서 즉시 승인 (3가지 모두 체크 시 활성화)
            ElevatedButton(
              onPressed: (licenseOk && businessOk && reportOk) 
                ? () {
                    _approveHospital(h, index);
                    Navigator.pop(context);
                  } 
                : null,
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0F172A), foregroundColor: Colors.white),
              child: const Text('최종 승인 및 ID 발급'),
            ),
          ],
        ),
      ),
    );
  }

  // 개별 서류 확인 및 이미지 버튼 위젯
  Widget _checkStepWithImage({
    required String title, 
    required bool isDone, 
    required VoidCallback onTap, 
    required VoidCallback onImageTap
  }) {
    return ListTile(
      leading: Checkbox(value: isDone, onChanged: (_) => onTap()),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
      trailing: IconButton(
        icon: const Icon(Icons.image_search, color: Colors.blue),
        onPressed: onImageTap, // 클릭 시 새 창(다이얼로그) 띄움
        tooltip: '이미지 원본 보기',
      ),
    );
  }

  // 이미지 미리보기용 팝업창
  void _showImagePreview(BuildContext context, String title, String imageUrl) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Container(
          width: 500,
          height: 600,
          color: Colors.grey[200],
          // 실제 서비스에선 Image.network(AWS_URL)을 사용합니다.
          child: const Center(child: Text('서류 원본 이미지 출력 (AWS S3 연동 영역)')),
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  // AI 분석 리포트 위젯
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

  // 체크리스트 단계 위젯
  Widget _checkStep({required String title, required String detail, required bool isDone, required VoidCallback onTap}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: isDone ? Colors.blue[50] : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDone ? Colors.blue[200]! : Colors.grey[300]!),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(
          isDone ? Icons.check_circle : Icons.radio_button_unchecked,
          color: isDone ? Colors.blue : Colors.grey,
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        subtitle: Text(detail, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.image_search, size: 20), // 클릭 시 서류 이미지를 띄운다는 상징
      ),
    );
  }

  void _approveHospital(Map<String, dynamic> h, int index) {
    setState(() {
      globalActiveHospitals.add({'id': 'D-${h['id']}', 'name': h['name'], 'location': '서울', 'status': '활성'});
      globalPendingHospitals.removeAt(index);
    });
  }

  void _rejectHospital(int index) {
    setState(() { globalPendingHospitals.removeAt(index); });
  }

  void _showStatusManagement(Map<String, dynamic> h, int index) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(25),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${h['name']} 상태 변경', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 20),
            ListTile(title: const Text('정상 활성화'), leading: const Icon(Icons.check_circle, color: Colors.green), onTap: () => _updateStatus(index, '활성')),
            ListTile(title: const Text('일시 비활성화'), leading: const Icon(Icons.pause_circle, color: Colors.orange), onTap: () => _updateStatus(index, '비활성')),
            ListTile(title: const Text('영구 정지'), leading: const Icon(Icons.block, color: Colors.red), onTap: () => _updateStatus(index, '정지')),
          ],
        ),
      ),
    );
  }

  void _updateStatus(int index, String newStatus) {
    setState(() { globalActiveHospitals[index]['status'] = newStatus; });
    Navigator.pop(context);
  }
}

// --- 예약/매칭 관리 페이지 데이터 ---
List<Map<String, dynamic>> globalReservations = [
  {
    'res_id': 'P001-D001-DOC01-260227', // 고유 예약 번호
    'date_time': '2026-02-27 14:00',
    'patient': '홍길동 (P001)',
    'hospital': '미소치과의원 (D-001)',
    'doctor': '김철수 원장 (DOC01)',
    'status': '신규', // 신규/확정/취소
  },
  {
    'res_id': 'P042-D001-DOC02-260305',
    'date_time': '2026-03-05 10:30',
    'patient': '이영희 (P042)',
    'hospital': '미소치과의원 (D-001)',
    'doctor': '박영수 과장 (DOC02)',
    'status': '확정',
  },
];

class ReservationManagementPage extends StatefulWidget {
  const ReservationManagementPage({super.key});

  @override
  State<ReservationManagementPage> createState() => _ReservationManagementPageState();
}

class _ReservationManagementPageState extends State<ReservationManagementPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('예약/매칭 관리 시스템', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30), // 상하좌우 여백 조절
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 예약 목록 조회', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // 표 영역: 화면 너비에 반응하도록 설정
            Container(
              width: double.infinity, // 부모의 너비를 꽉 채움
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // 화면이 좁아지면 가로 스크롤 생성
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // 최소한 현재 화면 너비(사이드바 제외)만큼 늘어나도록 설정
                    minWidth: MediaQuery.of(context).size.width - 60, 
                  ),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 25, // 열 사이 간격 최적화
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('고유 예약 번호', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('예약 일시', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('환자 정보', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('의료진 정보', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('상태', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('관리', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: globalReservations.asMap().entries.map((entry) {
                      int idx = entry.key;
                      var res = entry.value;
                      return DataRow(cells: [
                        DataCell(Text(res['res_id'], style: const TextStyle(fontSize: 12, color: Colors.blueGrey))),
                        DataCell(Text(res['date_time'])),
                        DataCell(Text(res['patient'])),
                        DataCell(Text(res['doctor'])),
                        DataCell(_buildStatusBadge(res['status'])),
                        DataCell(
                          ElevatedButton(
                            onPressed: () => _showReservationDetail(res, idx),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.grey[100],
                              foregroundColor: Colors.black,
                              elevation: 0,
                            ),
                            child: const Text('상세/수정'),
                          ),
                        ),
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

  // 예약 상태 배지
  Widget _buildStatusBadge(String status) {
    Color color;
    switch (status) {
      case '신규': color = Colors.blue; break;
      case '확정': color = Colors.green; break;
      case '취소': color = Colors.red; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(status, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }

  // 예약 상세 정보 팝업
  void _showReservationDetail(Map<String, dynamic> res, int index) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('예약 상세 정보 및 상태 변경'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _detailText('예약 ID', res['res_id']),
            _detailText('날짜/시간', res['date_time']),
            _detailText('환자 정보', res['patient']),
            _detailText('병원 정보', res['hospital']),
            _detailText('의료진', res['doctor']),
            const Divider(height: 30),
            const Text('상태 변경', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['신규', '확정', '취소'].map((s) => ChoiceChip(
                label: Text(s),
                selected: res['status'] == s,
                onSelected: (val) {
                  if (val) {
                    setState(() { globalReservations[index]['status'] = s; });
                    Navigator.pop(context);
                  }
                },
              )).toList(),
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
      ),
    );
  }

  Widget _detailText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $value', style: const TextStyle(fontSize: 14)),
    );
  }
}

// --- 시스템 로그 관리 페이지 데이터 ---
List<Map<String, dynamic>> globalSystemLogs = [
  {'type': '로그인', 'user': 'Admin01', 'action': '관리자 시스템 접속', 'date': '2026-03-03 09:12:45', 'status': '성공'},
  {'type': '병원 승인', 'user': 'Admin01', 'action': '강남 바른치과(H001) 승인 완료', 'date': '2026-03-02 15:30:12', 'status': '완료'},
  {'type': '예약 변경', 'user': 'System', 'action': 'P001 환자 예약 시간 변경 (14:00 -> 15:30)', 'date': '2026-03-02 11:20:05', 'status': '자동'},
  {'type': '리뷰 관리', 'user': 'Admin02', 'action': '부적절한 리뷰(R992) 숨김 처리', 'date': '2026-03-01 18:05:33', 'status': '처리'},
  {'type': '로그인', 'user': 'Admin02', 'action': '비밀번호 3회 오류로 접속 차단', 'date': '2026-03-01 08:45:10', 'status': '실패'},
];

class SystemLogManagementPage extends StatefulWidget {
  const SystemLogManagementPage({super.key});

  @override
  State<SystemLogManagementPage> createState() => _SystemLogManagementPageState();
}

class _SystemLogManagementPageState extends State<SystemLogManagementPage> {
  String selectedFilter = '전체';

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredLogs = selectedFilter == '전체'
        ? globalSystemLogs
        : globalSystemLogs.where((log) => log['type'] == selectedFilter).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('시스템 로그 관리', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30), // 좌우 여백을 충분히 줌
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('전체 로그 내역', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // 필터 칩 영역 (Wrap으로 자동 줄바꿈)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: ['전체', '로그인', '병원 승인', '예약 변경', '리뷰 관리'].map((filter) {
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
            
            // 표 영역: 화면 전체 너비를 채우도록 설정
            Container(
              width: double.infinity, // 부모 너비를 꽉 채움
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10)],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal, // 화면이 좁아지면 가로 스크롤 허용
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // 최소한 현재 화면의 너비만큼은 표가 늘어나도록 설정 (핵심!)
                    minWidth: MediaQuery.of(context).size.width - 60, 
                  ),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 20, // 열 사이 간격 최적화
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('로그 유형', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('작업자', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('활동 내역', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('발생 일시', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('상태', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredLogs.map((log) {
                      return DataRow(cells: [
                        DataCell(_buildTypeBadge(log['type'])),
                        DataCell(Text(log['user'])),
                        DataCell(
                          // 활동 내역이 너무 길어지면 적절히 조절
                          Container(
                            constraints: const BoxConstraints(maxWidth: 400),
                            child: Text(log['action'], overflow: TextOverflow.ellipsis),
                          )
                        ),
                        DataCell(Text(log['date'], style: const TextStyle(fontSize: 13, color: Colors.grey))),
                        DataCell(Text(log['status'], style: TextStyle(
                          color: log['status'] == '실패' ? Colors.red : (log['status'] == '성공' ? Colors.blue : Colors.blueGrey),
                          fontWeight: FontWeight.bold,
                        ))),
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

  // 로그 유형별 배지 디자인
  Widget _buildTypeBadge(String type) {
    Color color;
    switch (type) {
      case '로그인': color = Colors.indigo; break;
      case '병원 승인': color = Colors.green; break;
      case '예약 변경': color = Colors.orange; break;
      case '리뷰 관리': color = Colors.purple; break;
      default: color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Text(type, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}

// --- 환자 관리 페이지 데이터 ---
List<Map<String, dynamic>> globalPatients = [
  {
    'p_id': 'P001',
    'name': '홍길동',
    'gender': '남',
    'age': 34,
    'phone': '010-1234-5678',
    'last_visit': '2026-02-27',
    'survey_data': '최근 어금니 통증 및 잇몸 부음 증상 있음',
    'ai_report': '제 2대구치 주변 치주염 징후 85% 감지. 스케일링 및 정밀 검사 권장.',
    'history': [ // 단순 문자열에서 객체 형태로 변경
      {
        'date': '2026-02-27',
        'title': '임플란트 상담 및 AI 정밀 분석',
        'survey': '왼쪽 어금니 저작 시 통증, 잇몸 출혈 잦음',
        'ai': '상악 좌측 제1대구치 치조골 흡수 관찰됨. 임플란트 식립 가능성 높음.'
      },
      {
        'date': '2025-11-10',
        'title': '정기 검진 및 스케일링',
        'survey': '전반적인 치아 시림 증상',
        'ai': '전치부 치석 지수 높음. 전반적인 구강 위생 상태 양호.'
      }
    ],
    'reviews': [
      {
        'r_id': 'R001', // 고유 ID 추가
        'date': '2026-02-28', 
        'hospital': '미소치과의원', 
        'doctor': '김철수 원장', 
        'content': '상담이 매우 친절하고 AI 분석 결과가 정확해서 믿음이 갔습니다.', 
        'rating': 5,
        'isHidden': false, // 숨김 여부 상태
        'isDeleted': false, // 삭제 여부
      },
      {
        'r_id': 'R002',
        'date': '2025-11-12', 
        'hospital': '튼튼치과', 
        'doctor': '이영희 과장', 
        'content': '시설은 깨끗한데 대기 시간이 좀 길었어요.', 
        'rating': 4,
        'isHidden': false,
        'isDeleted': false, // 삭제 여부 
      },
    ]  
  },
  {
    'p_id': 'P042',
    'name': '이영희',
    'gender': '여',
    'age': 28,
    'phone': '010-9876-5432',
    'last_visit': '2026-03-05',
    'survey_data': '치아 미백 및 스케일링 희망',
    'ai_report': '전반적 구강 상태 양호. 상악 전치부 착색 확인됨.',
    'history': [],
    'reviews': [
      {
        'r_id': 'R003',
        'date': '2026-03-06', 
        'hospital': '미소치과의원', 
        'doctor': '박영수 과장', 
        'content': '스케일링 하나도 안 아프게 잘해주셨어요!', 
        'rating': 5,
        'isHidden': false,
        'isDeleted': false, // 삭제 여부 추가
      },
    ]
  },
];

class PatientManagementPage extends StatefulWidget {
  const PatientManagementPage({super.key});

  @override
  State<PatientManagementPage> createState() => _PatientManagementPageState();
}

class _PatientManagementPageState extends State<PatientManagementPage> {
  String searchName = '';

  @override
  Widget build(BuildContext context) {
    List<Map<String, dynamic>> filteredPatients = globalPatients
        .where((p) => p['name'].contains(searchName))
        .toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('환자 관리 시스템', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF0F172A),
        elevation: 0,
      ),
      body: SingleChildScrollView(
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
                      hintText: '환자 이름 검색',
                      prefixIcon: const Icon(Icons.search),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    ),
                    onChanged: (val) => setState(() => searchName = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width - 60),
                  child: DataTable(
                    horizontalMargin: 20,
                    columnSpacing: 20,
                    headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                    columns: const [
                      DataColumn(label: Text('ID', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('성함', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('성별/나이', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('연락처', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('최근 방문일', style: TextStyle(fontWeight: FontWeight.bold))),
                      DataColumn(label: Text('상세 관리', style: TextStyle(fontWeight: FontWeight.bold))),
                    ],
                    rows: filteredPatients.map((p) {
                      return DataRow(cells: [
                        DataCell(Text(p['p_id'])),
                        DataCell(Text(p['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        DataCell(Text('${p['gender']} / ${p['age']}세')),
                        DataCell(Text(p['phone'])),
                        DataCell(Text(p['last_visit'])),
                        DataCell(
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => _showPatientDetail(p),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo[50], foregroundColor: Colors.indigo, elevation: 0),
                                child: const Text('리포트/이력'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => _showPatientReviews(p),
                                style: OutlinedButton.styleFrom(foregroundColor: Colors.orange, side: const BorderSide(color: Colors.orange)),
                                child: const Text('리뷰 기록'),
                              ),
                            ],
                          ),
                        ),
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

  // --- [최종 수정] 데이터 참조 오류를 해결한 리뷰 기록 보기 팝업 ---
  void _showPatientReviews(Map<String, dynamic> patientInfo) {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          // [핵심] 전달받은 환자 정보의 ID를 사용하여 원본 globalPatients 리스트에서 환자를 직접 찾습니다.
          // 이렇게 해야 Hot Restart 이후에도 데이터 연결이 끊기지 않습니다.
          var realPatient = globalPatients.firstWhere(
            (item) => item['p_id'] == patientInfo['p_id'],
            orElse: () => patientInfo, // 혹시 못 찾으면 기본 정보 사용
          );
          
          List reviews = realPatient['reviews'] ?? [];
          
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text('${realPatient['name']} 님의 리뷰 관리'),
            content: SizedBox(
              width: 550,
              // [중요] 높이가 지정되지 않아 안 보일 수 있으므로 constraints 추가
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
                child: reviews.isEmpty 
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Center(child: Text('작성한 리뷰가 없습니다.', style: TextStyle(color: Colors.grey))),
                    )
                  : SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: reviews.map((r) {
                          bool isDeleted = r['isDeleted'] ?? false;
                          bool isHidden = r['isHidden'] ?? false;

                          return Container(
                            key: ValueKey(r['r_id']), // 개별 항목 고유 키 부여
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: isDeleted ? Colors.red[50] : (isHidden ? Colors.grey[100] : Colors.orange[50]?.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: isDeleted ? Colors.red[200]! : (isHidden ? Colors.grey[300]! : Colors.orange[100]!)),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Text(r['hospital'] ?? '정보 없음', 
                                          style: TextStyle(fontWeight: FontWeight.bold, color: isDeleted ? Colors.red : (isHidden ? Colors.grey : Colors.orange))),
                                        if (isDeleted) _badge('삭제처리됨', Colors.red)
                                        else if (isHidden) _badge('숨김처리됨', Colors.grey),
                                      ],
                                    ),
                                    Text(r['date'] ?? '', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(r['content'] ?? '', style: TextStyle(
                                  height: 1.4, 
                                  color: (isDeleted || isHidden) ? Colors.grey : Colors.black87,
                                  decoration: isDeleted ? TextDecoration.lineThrough : null 
                                )),
                                const Divider(height: 30),
                                if (!isDeleted)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () {
                                          setDialogState(() => r['isHidden'] = !isHidden);
                                          setState(() {}); // 메인 화면 갱신
                                        },
                                        icon: Icon(isHidden ? Icons.visibility : Icons.visibility_off, size: 16),
                                        label: Text(isHidden ? '숨김 해제' : '리뷰 숨기기'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.blueGrey),
                                      ),
                                      const SizedBox(width: 10),
                                      TextButton.icon(
                                        onPressed: () => _confirmDeleteReview(r, setDialogState),
                                        icon: const Icon(Icons.delete_forever, size: 16),
                                        label: const Text('리뷰 삭제'),
                                        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                                      ),
                                    ],
                                  )
                                else
                                  const Center(child: Text('관리자에 의해 삭제된 리뷰입니다.', style: TextStyle(fontSize: 11, color: Colors.redAccent))),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
          );
        },
      ),
    );
  }

  // 배지 위젯 헬퍼
  Widget _badge(String t, Color col) => Container(
    margin: const EdgeInsets.only(left: 8),
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: col, borderRadius: BorderRadius.circular(4)),
    child: Text(t, style: const TextStyle(color: Colors.white, fontSize: 10)),
  );

  // 삭제 확인 다이얼로그 (진짜 지우지 않고 상태만 변경)
  void _confirmDeleteReview(Map<String, dynamic> review, StateSetter setDialogState) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('리뷰 삭제'),
        content: const Text('이 리뷰를 삭제 처리하시겠습니까?\n데이터는 남지만 서비스에는 노출되지 않습니다.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () {
              setDialogState(() {
                review['isDeleted'] = true; // 실제 삭제가 아닌 상태값 변경
              });
              setState(() {}); // 메인 UI 갱신
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('삭제 확정', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // --- 기존 리포트 팝업 ---
  // --- [최종수정] Null 에러 방지용 환자 리포트 팝업 ---
  void _showPatientDetail(Map<String, dynamic> patientInfo) {
    showDialog(
      context: context,
      builder: (context) {
        // [핵심] ID를 기준으로 원본 데이터 리스트에서 해당 환자 객체를 다시 정확히 찾습니다.
        var targetPatient = globalPatients.firstWhere(
          (item) => item['p_id'] == patientInfo['p_id'],
          orElse: () => patientInfo,
        );

        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text('${targetPatient['name']} 환자 통합 리포트'),
          content: SizedBox(
            width: 600,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildPopupSection('현재 방문 설문 데이터', targetPatient['survey_data'] ?? '데이터 없음', Icons.assignment),
                  const SizedBox(height: 20),
                  _buildAiAnalysisBox(targetPatient['ai_report'] ?? '분석 결과 없음'),
                  const SizedBox(height: 30),
                  const Divider(),
                  const SizedBox(height: 10),
                  const Text('📜 과거 진료 기록', 
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF0F172A))),
                  const SizedBox(height: 15),
                  
                  // 과거 기록 리스트 생성 (Null 체크 추가)
                  if (targetPatient['history'] == null || (targetPatient['history'] as List).isEmpty)
                    const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: Text('과거 진료 기록이 없습니다.', style: TextStyle(color: Colors.grey)),
                    ))
                  else
                    ...(targetPatient['history'] as List).map((h) => Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(color: Colors.grey[200]!),
                      ),
                      child: ListTile(
                        leading: const Icon(Icons.history_edu, color: Colors.indigo),
                        title: Text(h['date'] ?? '날짜 미상', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(h['title'] ?? '제목 없음', style: const TextStyle(fontSize: 13)),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showPastHistoryDetail(h), // 누르면 상세 창 띄우기
                      ),
                    )).toList(),
                ],
              ),
            ),
          ),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기'))],
        );
      },
    );
  }

  // --- 2. [신규] 과거 특정 날짜의 상세 기록 팝업 ---
  void _showPastHistoryDetail(Map<String, dynamic> history) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: const Color(0xFFF8FAFC),
        title: Row(
          children: [
            const Icon(Icons.event_note, color: Colors.indigo),
            const SizedBox(width: 10),
            Text('${history['date']} 상세 진료 기록'),
          ],
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildPopupSection('당시 환자 설문', history['survey'], Icons.mode_edit_outline),
              const SizedBox(height: 20),
              _buildAiAnalysisBox(history['ai']), // 기존 AI 박스 재활용
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('뒤로가기', style: TextStyle(color: Colors.grey))
          ),
        ],
      ),
    );
  }

  Widget _buildPopupSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [Icon(icon, size: 18, color: Colors.blueGrey), const SizedBox(width: 8), Text(title, style: const TextStyle(fontWeight: FontWeight.bold))]),
        const SizedBox(height: 10),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10)),
          child: Text(content, style: const TextStyle(height: 1.5)),
        ),
      ],
    );
  }

  Widget _buildAiAnalysisBox(String report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [Colors.indigo[50]!, Colors.blue[50]!]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.indigo[100]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.psychology, color: Colors.indigo), SizedBox(width: 8), Text('AI 정밀 분석 결과', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo))]),
          const SizedBox(height: 10),
          Text(report, style: const TextStyle(color: Colors.indigo, height: 1.5, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}