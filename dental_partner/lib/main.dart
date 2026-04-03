import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:daum_postcode_search/daum_postcode_search.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
// import 'package:http/http.dart' as http;  ← 이 줄 삭제

// [수정 1] 데이터 유지 로직: 데이터를 클래스 외부(전역)로 이동하여 페이지 이동 시 초기화 방지
Map<String, List<Map<String, dynamic>>> globalEvents = {
  '2026-02-13': [
    {
      'name': '김승주', 'time': '09:30', 'count': 3, 'desc': '임플란트 정기 검진', 
      'isDone': true, 'isCancelled': false, 'cancelReason': '', 'isRead': true,
      'history': [ // [수정 2] 방문횟수와 히스토리 개수를 일치시키고 상세 데이터 추가
        {'date': '2026.02.13', 'type': '임플란트 정기 검진', 'survey': '수술 부위 양호', 'ai': '골밀도 90% 유지'},
        {'date': '2026.01.10', 'type': '임플란트 1차 식립', 'survey': '약간의 통증', 'ai': '식립 위치 정확도 98%'},
        {'date': '2025.12.15', 'type': '사전 정밀 상담', 'survey': '어금니 시림', 'ai': '치조골 분석 완료'},
      ]
    },
    {
      'name': '이철수', 'time': '11:00', 'count': 1, 'desc': '스케일링 및 검진', 
      'isDone': true, 'isCancelled': false, 'cancelReason': '', 'isRead': true,
      'history': [{'date': '2026.02.13', 'type': '스케일링', 'survey': '특이사항 없음', 'ai': '치석 지수 보통'}]
    },
    {
      'name': '박민지', 'time': '14:30', 'count': 2, 'desc': '첫 방문 상담', 
      'isDone': false, 'isCancelled': false, 'cancelReason': '', 'isRead': false,
      'history': [
        {'date': '2026.02.13', 'type': '첫 방문 상담', 'survey': '교정 희망', 'ai': '부정교합 2급 분석'},
        {'date': '2026.01.20', 'type': '구강 검진', 'survey': '전체적인 검사', 'ai': '충치 2개 발견'},
      ]
    },
    {
      'name': '최영희', 'time': '16:00', 'count': 5, 'desc': '충치 치료', 
      'isDone': false, 'isCancelled': true, 'cancelReason': '개인 사정으로 인한 취소', 'isRead': true,
      'history': List.generate(5, (i) => {'date': '2025.1${i}.10', 'type': '일반 진료', 'survey': '기록 없음', 'ai': '기록 없음'})
    },
  ],
};

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: 'https://rcpmdwvzyfwwlpagetyn.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJjcG1kd3Z6eWZ3d2xwYWdldHluIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQ2MjUzODcsImV4cCI6MjA5MDIwMTM4N30.sEJ50EkwKLo5P8nmTxJE82vmtzcTCzGHljOSVJDBU7Q',
  );
  runApp(const DentalNaraApp());
}

class DentalNaraApp extends StatelessWidget {
  const DentalNaraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '덴탈파인드 파트너',
      theme: ThemeData(
        primaryColor: const Color(0xFF005A9C),
        scaffoldBackgroundColor: const Color(0xFFF5F7FA),
        appBarTheme: const AppBarTheme(
          iconTheme: IconThemeData(color: Colors.white),
          titleTextStyle: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
      home: const LoginPage(),
    );
  }
}

// 1. 로그인 페이지
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  //
  // 입력 필드 제어용 컨트롤러 (입력값 수집)
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  bool _isLoading = false; // 로딩 상태 표시

  //
  // 로그인 요청 함수 (백엔드 /partner/login API 호출)
  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      // Supabase Auth로 이메일/비밀번호 로그인
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (authResponse.user == null) {
        _showErrorDialog("로그인 실패", "이메일 또는 비밀번호를 확인해주세요.");
        return;
      }

      // hospitals 테이블에서 status 확인 (승인 여부)
      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('status')
          .eq('email', _emailCtrl.text.trim())
          .maybeSingle();

      if (hospital == null) {
        _showErrorDialog("오류", "병원 정보를 찾을 수 없습니다.");
        await Supabase.instance.client.auth.signOut();
        return;
      }

      if (hospital['status'] == 'pending') {
        _showErrorDialog("승인 대기", "관리자 승인 후 이용 가능합니다.");
        await Supabase.instance.client.auth.signOut();
        return;
      }

      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainDashboard()));
      }
    } on AuthException catch (e) {
      _showErrorDialog("로그인 실패", e.message);
    } catch (e) {
      _showErrorDialog("연결 실패", "네트워크 상태를 확인해주세요.");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    if(!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('덴탈파인드', 
              style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
            const SizedBox(height: 50),
            TextField(
              controller: _emailCtrl, // 컨트롤러 연결
              keyboardType: TextInputType.emailAddress,
              decoration: InputDecoration(labelText: '이메일(ID)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pwCtrl, // 컨트롤러 연결
              obscureText: true,
              decoration: InputDecoration(labelText: '비밀번호', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login, 
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white) 
                  : const Text('로그인', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SignUpPage())), 
                  child: const Text('회원가입하기', style: TextStyle(color: Colors.grey))
                ),
                const Text('|', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => Navigator.push(
                    context, 
                    MaterialPageRoute(builder: (context) => const ForgotPasswordPage()) // 여기를 수정!
                  ), 
                  child: const Text('아이디/비밀번호 찾기', style: TextStyle(color: Colors.grey))
                ),
              ],
            )
          ],
        ),
      ),
    );
  }
}

// 2. 회원가입 페이지 (서류 업로드 항목 추가 버전)
class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  //
  // 입력 필드 컨트롤러 (데이터 수집)
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  final TextEditingController _pwCheckCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  bool _isLoading = false;

  // 업로드된 파일명을 담아둘 변수 (실제 구현 시에는 File 객체를 사용합니다)
  PlatformFile? licenseFile;      // 의사 면허증
  PlatformFile? businessFile;     // 사업자 등록증
  PlatformFile? reportFile;       // 의료기관 개설 신고증

  // [추가] 실제 기기에서 파일을 선택하는 함수
  Future<void> _pickFile(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
        // [핵심] 경로 대신 데이터를 직접 가져오도록 설정
        withData: true, 
      );

      if (result != null) {
        setState(() {
          if (type == 'license') licenseFile = result.files.first;
          if (type == 'business') businessFile = result.files.first;
          if (type == 'report') reportFile = result.files.first;
        });
      }
    } catch (e) {
      print("파일 선택 에러: $e");
    }
  }

  // [추가] 주소 검색 페이지를 띄우는 함수
  void _searchAddress() async {
    // result에 선택한 주소가 담겨서 돌아옵니다.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressSearchScreen()),
    );

    if (result != null && result is String) { // 주소 문자열이 넘어왔을 때
      setState(() {
        _addressCtrl.text = result; 
      });
    }
  }

  // 회원가입 요청 함수 (백엔드 /partner/signup API 호출)
  Future<void> _signUp() async {
    if (_pwCtrl.text != _pwCheckCtrl.text) {
      _showErrorDialog("가입 실패", "비밀번호가 일치하지 않습니다.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Supabase Auth로 계정 생성
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (authResponse.user == null) {
        _showErrorDialog("가입 실패", "이미 사용 중인 이메일이거나 가입에 실패했습니다.");
        return;
      }

      // 2. Storage에 파일 업로드 후 URL 저장
      String? licenseUrl, businessUrl, reportUrl;
      final bucket = Supabase.instance.client.storage.from('hospital-documents');

      if (licenseFile != null) {
        final path = 'license/${authResponse.user!.id}_${licenseFile!.name}';
        await bucket.uploadBinary(path, licenseFile!.bytes!);
        licenseUrl = bucket.getPublicUrl(path);
      }
      if (businessFile != null) {
        final path = 'business/${authResponse.user!.id}_${businessFile!.name}';
        await bucket.uploadBinary(path, businessFile!.bytes!);
        businessUrl = bucket.getPublicUrl(path);
      }
      if (reportFile != null) {
        final path = 'report/${authResponse.user!.id}_${reportFile!.name}';
        await bucket.uploadBinary(path, reportFile!.bytes!);
        reportUrl = bucket.getPublicUrl(path);
      }

      // 3. hospitals 테이블에 병원 정보 insert
      //    ykiho는 임시로 user.id 사용 (실제 운영 시 관리자가 부여)
      await Supabase.instance.client.from('hospitals').insert({
        'ykiho': authResponse.user!.id,
        'yadm_nm': _nameCtrl.text.trim(),
        'addr': _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'status': 'pending',
      });

      // 4. hospital_documents 테이블에 서류 URL 저장
      for (final entry in [
        if (licenseUrl != null) {'doc_type': 'license', 'file_url': licenseUrl},
        if (businessUrl != null) {'doc_type': 'business', 'file_url': businessUrl},
        if (reportUrl != null) {'doc_type': 'report', 'file_url': reportUrl},
      ]) {
        await Supabase.instance.client.from('hospital_documents').insert({
          'ykiho': authResponse.user!.id,
          ...entry,
        });
      }

      _showCompleteDialog();
    } on AuthException catch (e) {
      _showErrorDialog("가입 실패", e.message);
    } catch (e) {
      _showErrorDialog("가입 실패", "네트워크 또는 파일 접근 권한을 확인해주세요.\n$e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // 3가지 필수 서류가 모두 있는지 확인하는 플래그
    bool isDocsReady = licenseFile != null && businessFile != null && reportFile != null;

    return Scaffold(
      appBar: AppBar(title: const Text('파트너 회원가입'), backgroundColor: const Color(0xFF005A9C)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('병원 정보를 입력해 주세요.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            
            // 1. 병원명
            _inputField('병원명', '병원 이름을 입력하세요.', controller: _nameCtrl),
            const SizedBox(height: 15),
            
            // 2. 병원 주소 (검색 버튼 포함)
            _inputFieldWithBtn('병원 주소', '주소 검색을 눌러주세요.', 
              controller: _addressCtrl, 
              btnLabel: '주소 검색', 
              onBtnTap: _searchAddress
            ),
            const SizedBox(height: 15),
            
            // 3. 이메일
            _inputField('이메일(ID)', '로그인에 사용할 이메일 주소입니다.', controller: _emailCtrl),
            const SizedBox(height: 15),
            
            // 4. 비밀번호
            _inputField('비밀번호', '6자리 이상 입력', obscure: true, controller: _pwCtrl),
            const SizedBox(height: 15),
            
            // 5. 비밀번호 확인
            _inputField('비밀번호 확인', '비밀번호를 다시 입력하세요', obscure: true, controller: _pwCheckCtrl),          
            const SizedBox(height: 40),
            
            const Text('필수 서류 업로드', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('심사를 위해 아래 3가지 서류를 모두 첨부해 주세요.', style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),

            _buildUploadBtn('의사 면허증', licenseFile?.name, () => _pickFile('license')),
            const SizedBox(height: 15),
            _buildUploadBtn('사업자 등록증', businessFile?.name, () => _pickFile('business')),
            const SizedBox(height: 15),
            _buildUploadBtn('의료기관 개설 신고증', reportFile?.name, () => _pickFile('report')),

            const SizedBox(height: 50),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                //
                // 3가지 서류가 다 있고, 로딩 중이 아니어야 버튼 활성화
                onPressed: (isDocsReady && !_isLoading) ? _signUp : null, 
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A9C),
                  disabledBackgroundColor: Colors.grey[300], // 비활성 색상
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('가입 요청하기', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _inputFieldWithBtn(String label, String hint, 
  {required TextEditingController controller, required String btnLabel, required VoidCallback onBtnTap}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onBtnTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            decoration: BoxDecoration(
              color: controller.text.isEmpty ? Colors.grey[50] : const Color(0xFFE3F2FD),
              border: Border.all(
                color: controller.text.isEmpty ? Colors.grey[300]! : const Color(0xFF005A9C),
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  color: controller.text.isEmpty ? Colors.grey : const Color(0xFF005A9C),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    controller.text.isEmpty ? hint : controller.text,
                    style: TextStyle(
                      color: controller.text.isEmpty ? Colors.grey : const Color(0xFF005A9C),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFF005A9C),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    '검색',
                    style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // 파일 업로드 전용 버튼 위젯
  Widget _buildUploadBtn(String label, String? fileName, VoidCallback onTap) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 15),
            decoration: BoxDecoration(
              border: Border.all(color: fileName == null ? Colors.grey[300]! : const Color(0xFF005A9C)),
              borderRadius: BorderRadius.circular(10),
              color: fileName == null ? Colors.grey[50] : const Color(0xFFE3F2FD),
            ),
            child: Row(
              children: [
                Icon(
                  fileName == null ? Icons.file_upload_outlined : Icons.check_circle,
                  color: fileName == null ? Colors.grey : const Color(0xFF005A9C),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    fileName ?? '파일을 선택하세요',
                    style: TextStyle(color: fileName == null ? Colors.grey : const Color(0xFF005A9C), fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ... _inputFieldHelper 위젯 (컨트롤러 파라미터 추가해서 수정)
  Widget _inputField(String label, String hint, {bool isNumber = false, bool obscure = false, TextEditingController? controller}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          controller: controller, // 컨트롤러 연결
          obscureText: obscure,
          keyboardType: isNumber ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder()),
        ),
      ],
    );
  }

  void _showCompleteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('가입 신청 완료'),
        content: const Text('필수 서류 3종 접수가 완료되었습니다.\n관리자 승인 후 로그인이 가능합니다.'),
        actions: [TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('확인'))],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    if(!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))],
      ),
    );
  }
}

class AddressSearchScreen extends StatefulWidget {
  const AddressSearchScreen({super.key});

  @override
  State<AddressSearchScreen> createState() => _AddressSearchScreenState();
}

class _AddressSearchScreenState extends State<AddressSearchScreen> {
  DaumPostcodeLocalServer? _server;
  WebViewController? _webViewController;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startServer();
  }

  Future<void> _startServer() async {
    try {
      final server = DaumPostcodeLocalServer();
      await server.start();
      _server = server;

      // ✅ 서버 URL 확인
      print('===== 서버 URL: ${server.url} =====');
      print('===== 로드할 주소: ${server.url}/${DaumPostcodeAssets.postMessage} =====');

      final controller = WebViewController();
      await controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await controller.addJavaScriptChannel(
        'DaumPostcodeResult',
        onMessageReceived: (JavaScriptMessage message) {
          print('===== JS 메시지 수신: ${message.message} =====');
          
          try {
            // 패키지 파서 대신 직접 JSON 파싱
            final decoded = jsonDecode(message.message);
            final address = decoded['roadAddress'] ?? decoded['jibunAddress'] ?? '';
            
            print('===== 파싱된 주소: $address =====');
            
            if (address.isNotEmpty && mounted) {
              Navigator.pop(context, address);
            }
          } catch (e) {
            print('===== 파싱 에러: $e =====');
            // 파싱 실패 시 raw 문자열 그대로 시도
            if (message.message.isNotEmpty && mounted) {
              Navigator.pop(context, message.message);
            }
          }
        },
      );
      await controller.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (url) {
          print('===== 페이지 시작: $url =====');
          // [핵심] 페이지 로드 후 JS 채널 연결 확인용 코드 주입
          controller.runJavaScript('''
            console.log("JS 주입 시작");
            
            // 기존 daum postcode 콜백을 가로채서 flutter 채널로 전달
            var originalOnComplete = window.daum && window.daum.Postcode ? true : false;
            console.log("daum 객체 존재: " + originalOnComplete);
            
            // postMessage 이벤트 리스너 추가 (패키지가 이 방식 쓸 수도 있음)
            window.addEventListener("message", function(event) {
              console.log("window message 수신: " + JSON.stringify(event.data));
              try {
                flutter.postMessage(JSON.stringify(event.data));
              } catch(e) {
                console.log("flutter 채널 에러: " + e);
              }
            });
            
            console.log("JS 주입 완료");
          ''');

          if (mounted) setState(() => _isLoading = false);
        },
        onWebResourceError: (WebResourceError error) {
          print('===== WebView 에러: ${error.errorCode} / ${error.description} / ${error.url} =====');
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = '[${error.errorCode}] ${error.description}\n${error.url}';
            });
          }
        },
        onNavigationRequest: (NavigationRequest request) {
          print('===== 네비게이션 요청: ${request.url} =====');
          // about:blank 같은 빈 페이지로의 이동 차단
          if (request.url == 'about:blank' || request.url.isEmpty) {
            return NavigationDecision.prevent;
          }
          return NavigationDecision.navigate;
        },
      ));

      final url = '${server.url}/${DaumPostcodeAssets.postMessage}';
      print('===== loadRequest 호출: $url =====');
      await controller.loadRequest(Uri.parse(url));

      if (mounted) {
        setState(() => _webViewController = controller);
      }
    } catch (e, stackTrace) {
      print('===== 서버 시작 예외: $e =====');
      print('===== 스택트레이스: $stackTrace =====');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = '서버 시작 실패: $e';
        });
      }
    }
  }

  @override
  void dispose() {
    _server?.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('주소 검색'),
        backgroundColor: const Color(0xFF005A9C),
      ),
      body: Stack(
        children: [
          // 컨트롤러가 준비됐을 때만 WebView 렌더링
          if (_webViewController != null)
            WebViewWidget(controller: _webViewController!)
          else if (_errorMessage == null)
            const SizedBox.shrink(), // 로딩 중엔 빈 공간 (인디케이터가 대신 표시)

          // 에러 화면
          if (_errorMessage != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 48),
                    const SizedBox(height: 12),
                    Text(_errorMessage!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () {
                        setState(() { _errorMessage = null; _isLoading = true; });
                        _startServer();
                      },
                      child: const Text('다시 시도'),
                    ),
                  ],
                ),
              ),
            ),

          // 로딩 인디케이터
          if (_isLoading)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}

// 2-2. 아이디/비밀번호 찾기 페이지 (신규)
class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('계정 정보 찾기'),
        backgroundColor: const Color(0xFF005A9C),
        centerTitle: true, // 제목 가운데 정렬로 더 깔끔하게
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          // [수정 포인트]
          indicatorColor: Colors.white, // 하단 강조선 흰색
          indicatorWeight: 3,           // 강조선 두께를 살짝 키워서 잘 보이게
          labelColor: Colors.white,      // 선택된 탭 글씨색 (완전 흰색)
          unselectedLabelColor: Colors.white.withOpacity(0.6), // 선택 안 된 탭 (반투명 흰색)
          labelStyle: const TextStyle(
            fontSize: 16, 
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.normal,
          ),
          tabs: const [
            Tab(text: '아이디 찾기'), 
            Tab(text: '비밀번호 재설정')
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFindIdTab(),
          _buildResetPwTab(),
        ],
      ),
    );
  }

  // --- 탭 1: 아이디 찾기 ---
  Widget _buildFindIdTab() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('등록된 병원명과 휴대폰 번호를 입력해주세요.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          _textField('병원명', '정확한 병원명을 입력하세요.'),
          const SizedBox(height: 20),
          _textField('휴대폰 번호', '- 없이 숫자만 입력', isNumber: true),
          const SizedBox(height: 40),
          _actionButton('아이디 찾기', () {
            // 백엔드 연결 전 가짜 결과 팝업
            _showResultDialog('아이디 찾기 결과', '입력하신 정보와 일치하는 아이디는\nadmin@dentalfind.com 입니다.');
          }),
        ],
      ),
    );
  }

  // --- 탭 2: 비밀번호 재설정 ---
  Widget _buildResetPwTab() {
    return Padding(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('가입하신 이메일 주소로\n임시 비밀번호를 발송해 드립니다.', style: TextStyle(color: Colors.grey, height: 1.5)),
          const SizedBox(height: 30),
          _textField('이메일(ID)', '가입 시 등록한 이메일을 입력하세요.'),
          const SizedBox(height: 40),
          _actionButton('임시 비밀번호 발송', () {
            _showResultDialog('발송 완료', '입력하신 이메일로\n임시 비밀번호가 발송되었습니다.');
          }),
        ],
      ),
    );
  }

  Widget _textField(String label, String hint, {bool isNumber = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 10),
        TextField(
          keyboardType: isNumber ? TextInputType.number : TextInputType.emailAddress,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
            border: const OutlineInputBorder(),
          ),
        ),
      ],
    );
  }

  Widget _actionButton(String text, VoidCallback onTap) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showResultDialog(String title, String content) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        content: Text(content),
        actions: [
          TextButton(onPressed: () { Navigator.pop(context); Navigator.pop(context); }, child: const Text('로그인하러 가기'))
        ],
      ),
    );
  }
}

// 3. 메인 대시보드
class MainDashboard extends StatelessWidget {
  const MainDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8), // 배경색을 조금 더 차분하게 변경
      appBar: AppBar(
        title: const Text('덴탈파인드 파트너'),
        backgroundColor: const Color(0xFF005A9C),
        centerTitle: true,
        automaticallyImplyLeading: false, // [요구사항 1] 상단 뒤로가기 화살표 제거
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('오늘의 진료 현황', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            // 상단 예약 현황 요약 카드 (리디자인) [요구사항 2]
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(25),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF005A9C), Color(0xFF0078D4)]),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('다음 예약 환자', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('14:00 김OO 환자님', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 5),
                  const Text('상세: 임플란트 1차 수술 및 상담', style: TextStyle(color: Colors.white60)),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(10)),
                    child: const Text('진료 준비 완료', style: TextStyle(color: Colors.white, fontSize: 12)),
                  )
                ],
              ),
            ),
            
            const SizedBox(height: 30),
            const Text('전체 메뉴', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            
            // 메뉴 그리드 (카드 스타일 개선) [요구사항 2]
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.1,
              children: [
                _newMenuButton(context, '병원 정보 관리', Icons.local_hospital_rounded, const Color(0xFFE3F2FD), const Color(0xFF1976D2), () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const HospitalInfoPage()));
                }),
                _newMenuButton(context, '예약 현황', Icons.calendar_month_rounded, const Color(0xFFF3E5F5), const Color(0xFF7B1FA2), () {
                  // 예약 정보 페이지로 이동하는 명령 [요구사항 반영]
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReservationPage()));
                }),
                _newMenuButton(context, '리뷰 관리', Icons.star_rounded, const Color(0xFFFFF3E0), const Color(0xFFF57C00), () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ReviewManagementPage()));
                }),
                _newMenuButton(context, '마이페이지', Icons.person_rounded, const Color(0xFFE8F5E9), const Color(0xFF388E3C), () {
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const MyPage()));
                }),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _newMenuButton(BuildContext context, String title, IconData icon, Color bg, Color iconColor, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5, offset: Offset(0, 2))]),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bg, shape: BoxShape.circle), child: Icon(icon, size: 30, color: iconColor)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}

// 4. 병원 정보 관리 페이지
class HospitalInfoPage extends StatefulWidget {
  const HospitalInfoPage({super.key});

  @override
  State<HospitalInfoPage> createState() => _HospitalInfoPageState();
}

class _HospitalInfoPageState extends State<HospitalInfoPage> {
  final NumberFormat _formatter = NumberFormat('#,###');

  Map<String, dynamic> hospitalBaseInfo = {
    'name': '덴탈파인드 치과 의원',
    'address': '대구광역시 중구 중앙대로 123',
    // 상세 운영 시간 데이터 구조
    'operatingHours': {
      '월': '09:30 ~ 18:30',
      '화': '09:30 ~ 18:30',
      '수': '09:30 ~ 18:30',
      '목': '09:30 ~ 18:30',
      '금': '09:30 ~ 18:30',
      '토': '09:30 ~ 13:00',
      '일': '정기휴무',
      'lunch': '13:00 ~ 14:00',
      'holiday': '일요일 및 법정 공휴일 휴무', // 연휴 관련 상세
    },
  };

  // HospitalInfoPage 상단의 products 리스트를 아래 데이터로 교체해 주세요.
  List<Map<String, String>> products = [
    {
      'name': '[치과의 보철료] 치과임플란트(Zirconia)', // 명칭을 템플릿과 일치시킴
      'min': '1,100,000', 
      'max': '1,400,000', 
      'info': '최신 3D 프린팅 기술로 제작된 지르코니아 임플란트'
    },
    {
      'name': '[치석제거] 치석제거(전악)', 
      'min': '100,000', 
      'max': '150,000', 
      'info': '꼼꼼한 스케일링 및 구강 검진'
    },
    {
      'name': '[치과 처치·수술료] 인레이(금)', 
      'min': '300,000', 
      'max': '450,000', 
      'info': '고순도 골드를 사용한 내구성 높은 인레이'
    },
  ];

  List<Map<String, String>> doctors = [
    {'name': '정OO 원장', 'special': '임플란트 전문', 'year': '2010', 'month': '03'},
  ];

  String _formatNumber(String s) {
    if (s.isEmpty) return "";
    return _formatter.format(int.parse(s.replaceAll(',', '')));
  }

  void _searchAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressSearchScreen()),
    );
    if (result != null && result is String) {
      setState(() {
        hospitalBaseInfo['address'] = result;
      });
    }
  }

  void _showHoursSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => OperatingHoursPage(
          initialHours: Map<String, String>.from(hospitalBaseInfo['operatingHours']),
        ),
      ),
    );

    if (result != null) {
      setState(() {
        hospitalBaseInfo['operatingHours'] = result;
      });
    }
  }

  void _showDeleteDialog(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말로 이 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(onPressed: () { onConfirm(); Navigator.pop(context); }, child: const Text('삭제', style: TextStyle(color: Colors.red))),
        ],
      ),
    );
  }

  void _showProductTable() async {
    // 표 형식 페이지로 이동하면서 현재 products 리스트를 통째로 넘겨줍니다.
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductTablePage(
          initialProducts: List<Map<String, String>>.from(products),
        ),
      ),
    );

    // 일괄 저장 버튼을 눌러서 데이터가 넘어왔을 때만 업데이트
    if (result != null) {
      setState(() {
        products = List<Map<String, String>>.from(result);
      });
    }
  }

  void _showDoctorSheet({int? index}) {
    var data = index != null ? doctors[index] : {'name': '', 'special': '', 'year': '2024', 'month': '01'};
    TextEditingController nameCtrl = TextEditingController(text: data['name']);
    TextEditingController specCtrl = TextEditingController(text: data['special']);
    String year = data['year']!;
    String month = data['month']!;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('의료진 정보 입력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: specCtrl, decoration: const InputDecoration(labelText: '전문 분야', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('시작 연월'),
                subtitle: Text('$year년 $month월'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _showPicker((y, m) => setSheetState(() { year = y; month = m; })),
                shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(height: 20),
              _saveButton(() {
                setState(() {
                  var newData = {'name': nameCtrl.text, 'special': specCtrl.text, 'year': year, 'month': month};
                  if (index == null) doctors.add(newData); else doctors[index] = newData;
                });
              }),
            ],
          ),
        ),
      ),
    );
  }

  void _showPicker(Function(String, String) onPicked) {
    int selY = 2024; int selM = 1;
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(height: 250, child: Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')), TextButton(onPressed: () { onPicked(selY.toString(), selM.toString().padLeft(2, '0')); Navigator.pop(context); }, child: const Text('확인'))]),
        Expanded(child: Row(children: [
          Expanded(child: CupertinoPicker(itemExtent: 32, onSelectedItemChanged: (i) => selY = 1990 + i, children: List.generate(50, (i) => Text('${1990 + i}년')))),
          Expanded(child: CupertinoPicker(itemExtent: 32, onSelectedItemChanged: (i) => selM = i + 1, children: List.generate(12, (i) => Text('${i + 1}월')))),
        ]))
      ])),
    );
  }

  Widget _saveButton(VoidCallback onSave) {
    return SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { onSave(); Navigator.pop(context); }, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('저장하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('병원 정보 관리'), backgroundColor: const Color(0xFF005A9C)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildSectionHeader('병원 기본 정보', null),
            _buildBaseCard(),

            // HospitalInfoPage의 build 메서드 중 상품 섹션 부분
            const SizedBox(height: 25),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('비보험 진료 상품', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        // [수정] 이제 실제 products.length가 0이면 "총 0건 등록됨"으로 뜹니다.
                        Text('총 ${products.length}건 등록됨', 
                          style: const TextStyle(color: Color(0xFF005A9C), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('심평원 표준 항목에 맞춰 가격을 관리하세요.', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _showProductTable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A9C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('진료 상품 일괄 작성/수정', 
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionHeader('의료진 정보', () => _showDoctorSheet()),
            ...doctors.asMap().entries.map((e) => _buildTile(
              e.key, 
              e.value['name']!, 
              '${e.value['special']}\n시작: ${e.value['year']}.${e.value['month']}', 
              () => _showDoctorSheet(index: e.key), 
              () => _showDeleteDialog(() => setState(() => doctors.removeAt(e.key)))
            )),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  // [추가] 데이터가 없을 때 보여줄 가이드 위젯
  Widget _buildEmptyGuide(String message) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(15),
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.grey[600], fontSize: 13),
      ),
    );
  }

  Widget _buildSectionHeader(String t, VoidCallback? a) {
    return Padding(padding: const EdgeInsets.fromLTRB(20, 20, 15, 10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)), if (a != null) IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF005A9C)), onPressed: a)]));
  }

  Widget _buildBaseCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        children: [
          _row(Icons.business, hospitalBaseInfo['name']!),
          
          // ✅ 주소 행을 탭 가능하게 변경
          InkWell(
            onTap: _searchAddress,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Color(0xFF005A9C)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      hospitalBaseInfo['address']!,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
                ],
              ),
            ),
          ),

          const Divider(height: 20),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: Color(0xFF005A9C), size: 20),
            title: const Text('운영 시간 및 상세 안내', style: TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: _showHoursSettings,
          ),
        ],
      ),
    );
  }

  Widget _row(IconData i, String t) => Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(children: [Icon(i, size: 18, color: const Color(0xFF005A9C)), const SizedBox(width: 10), Text(t)]));

  Widget _buildTile(int i, String t, String s, VoidCallback e, VoidCallback d) {
    return Container(margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)), child: ListTile(title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(s), trailing: Wrap(children: [IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: e), IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: d)])));
  }
}

//운영시간 설정 클래스
class OperatingHoursPage extends StatefulWidget {
  final Map<String, String> initialHours;
  const OperatingHoursPage({super.key, required this.initialHours});

  @override
  State<OperatingHoursPage> createState() => _OperatingHoursPageState();
}

class _OperatingHoursPageState extends State<OperatingHoursPage> {
  late Map<String, String> _tempHours;

  // 30분 단위 시간 리스트 생성 (00:00 ~ 23:30)
  final List<String> _timeSlots = List.generate(48, (i) {
    final hour = i ~/ 2;
    final minute = (i % 2) * 30;
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  });

  @override
  void initState() {
    super.initState();
    _tempHours = Map<String, String>.from(widget.initialHours);
  }

  // 휠 스크롤 피커 호출 함수
  void _showWheelPicker(String day, bool isStart) {
    String currentTime = _tempHours[day] ?? "09:00 ~ 18:00";
    List<String> parts = currentTime.contains('~') ? currentTime.split(' ~ ') : ["09:00", "18:00"];
    
    // 현재 설정된 시간의 인덱스 찾기
    int initialIdx = _timeSlots.indexOf(isStart ? parts[0] : (parts.length > 1 ? parts[1] : "18:00"));
    if (initialIdx == -1) initialIdx = 18; // 못 찾으면 기본 09:00

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              _pickerHeader(context),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: initialIdx),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      if (isStart) {
                        _tempHours[day] = "${_timeSlots[index]} ~ ${parts[1]}";
                      } else {
                        _tempHours[day] = "${parts[0]} ~ ${_timeSlots[index]}";
                      }
                    });
                  },
                  children: _timeSlots.map((time) => Center(child: Text(time))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(color: Colors.grey[100], border: const Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("시간 선택", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("완료")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영 시간 설정'),
        backgroundColor: const Color(0xFF005A9C),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _tempHours),
            child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('요일별 진료 시간'),
          ...['월', '화', '수', '목', '금', '토', '일'].map((day) => _buildDayTimeRow(day)),
          const Divider(height: 40),
          _buildSectionTitle('상세 정보 관리'), // 요청하신 대로 이름 통합
          _buildDetailField('lunch', '점심시간'),
          _buildDetailField('holiday', '상세 정보'), 
        ],
      ),
    );
  }

  Widget _buildDayTimeRow(String day) {
    String timeData = _tempHours[day] ?? "09:00 ~ 18:00";
    bool isClosed = timeData == "정기휴무";
    List<String> times = timeData.contains('~') ? timeData.split(' ~ ') : [timeData, ""];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(width: 35, child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (isClosed)
            Expanded(
              child: InkWell(
                onTap: () => _tempHours[day] = "09:00 ~ 18:00", // 휴무 해제 로직
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('정기 휴무', style: TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          else ...[
            Expanded(child: _timeButton(day, times[0], true)),
            const Padding(padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
            Expanded(child: _timeButton(day, times.length > 1 ? times[1] : "", false)),
          ],
          const SizedBox(width: 5),
          // 옵션 메뉴에서 '직접 입력' 삭제
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (val) {
              setState(() {
                if (val == '정기휴무') _tempHours[day] = "정기휴무";
                else _tempHours[day] = "09:00 ~ 18:00";
              });
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '시간설정', child: Text('시간 다시 설정')),
              const PopupMenuItem(value: '정기휴무', child: Text('정기휴무 설정')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String day, String time, bool isStart) {
    return InkWell(
      onTap: () => _showWheelPicker(day, isStart),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF005A9C).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8)
        ),
        child: Text(time, style: const TextStyle(fontSize: 14, color: Color(0xFF005A9C))),
      ),
    );
  }

  Widget _buildDetailField(String key, String label) {
    TextEditingController ctrl = TextEditingController(text: _tempHours[key]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        onChanged: (val) => _tempHours[key] = val,
        maxLines: key == 'holiday' ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: key == 'lunch' ? '예: 13:00 ~ 14:00' : '기타 상세 내용을 입력하세요',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
  );
}

class ProductTablePage extends StatefulWidget {
  final List<Map<String, String>> initialProducts;
  const ProductTablePage({super.key, required this.initialProducts});

  @override
  State<ProductTablePage> createState() => _ProductTablePageState();
}

class _ProductTablePageState extends State<ProductTablePage> {
  // 심평원 이미지 기반 전체 카테고리 및 세부 항목 정의
  final Map<String, List<String>> _groupedTemplate = {
    '치과의 보철료': ['치과임플란트(Metal)', '치과임플란트(Gold)', '치과임플란트(PFM)', '치과임플란트(Zirconia)', '크라운(Gold)', '크라운(Zirconia)'],
    '치과 처치·수술료': ['인레이(금)', '인레이(레진)', '인레이(세라믹)', '광중합형 복합레진(충전)'],
    '치석제거': ['치석제거(1/3악당)', '치석제거(전악)'],
    '기타 수술': ['자가치아 이식술', '잇몸웃음교정술'],
  };

  // 컨트롤러를 저장할 맵 (key: "[카테고리] 항목명")
  late Map<String, Map<String, TextEditingController>> _controllerMap;

  @override
  void initState() {
    super.initState();
    _controllerMap = {};

    _groupedTemplate.forEach((category, items) {
      for (var item in items) {
        String fullName = "[$category] $item";
        var existing = widget.initialProducts.firstWhere(
          (p) => p['name'] == fullName,
          orElse: () => {'info': '', 'min': '', 'max': ''},
        );

        _controllerMap[fullName] = {
          'info': TextEditingController(text: existing['info']),
          'min': TextEditingController(text: existing['min']),
          'max': TextEditingController(text: existing['max']),
        };
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비급여 항목 일괄 관리'),
        backgroundColor: const Color(0xFF005A9C),
        actions: [
          TextButton(
            onPressed: _saveAndExit,
            child: const Text('일괄저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        children: _groupedTemplate.keys.map((category) => _buildCategorySection(category)).toList(),
      ),
    );
  }

  // 카테고리별 접이식 섹션 빌드
  Widget _buildCategorySection(String category) {
    return ExpansionTile(
      title: Text(category, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
      initiallyExpanded: category == '치과의 보철료', // 첫 섹션만 열어둠
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 15,
            headingRowHeight: 40,
            columns: const [
              DataColumn(label: Text('세부 항목', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('최소(원)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('최대(원)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
              DataColumn(label: Text('상세 설명', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold))),
            ],
            rows: _groupedTemplate[category]!.map((item) {
              String fullName = "[$category] $item";
              return DataRow(cells: [
                DataCell(SizedBox(width: 100, child: Text(item, style: const TextStyle(fontSize: 12)))),
                DataCell(_buildSmallTextField(_controllerMap[fullName]!['min']!)),
                DataCell(_buildSmallTextField(_controllerMap[fullName]!['max']!)),
                DataCell(_buildSmallTextField(_controllerMap[fullName]!['info']!, width: 120, hint: '특이사항')),
              ]);
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTextField(TextEditingController ctrl, {double width = 70, String hint = '0'}) {
    return SizedBox(
      width: width,
      child: TextField(
        controller: ctrl,
        style: const TextStyle(fontSize: 12),
        decoration: InputDecoration(hintText: hint, border: InputBorder.none, isDense: true),
      ),
    );
  }

  void _saveAndExit() {
    List<Map<String, String>> results = [];
    _controllerMap.forEach((name, ctrls) {
      if (ctrls['min']!.text.isNotEmpty || ctrls['max']!.text.isNotEmpty) {
        results.add({
          'name': name,
          'info': ctrls['info']!.text,
          'min': ctrls['min']!.text,
          'max': ctrls['max']!.text,
        });
      }
    });
    Navigator.pop(context, results);
  }
}

// --- 5. 마이페이지 (최적화 버전) ---
class MyPage extends StatelessWidget {
  const MyPage({super.key});

  // [추가] 실제 백엔드와 통신하는 로그아웃 함수
  Future<void> _handleLogout(BuildContext context) async {
    try {
      await Supabase.instance.client.auth.signOut();
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const LoginPage()),
              (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지'), backgroundColor: const Color(0xFF005A9C)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(25),
              color: Colors.white,
              child: const Row(
                children: [
                  CircleAvatar(radius: 35, child: Icon(Icons.person, size: 40)),
                  SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('덴탈파인드 치과', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text('admin@dentalfind.com', style: TextStyle(color: Colors.grey)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            
            _section('계정 정보'),
            _tile(Icons.badge_outlined, '계정 상세 정보', 'ID 및 가입일 확인', true, () { // [요구사항 3] 화살표 표시
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AccountDetailPage()));
            }),
            
            const SizedBox(height: 20),
            _section('보안 및 설정'),
            _tile(Icons.lock_outline, '비밀번호 변경', '안전한 관리를 위해 변경해 주세요', true, () { // [요구사항 3] 화살표 표시
              Navigator.push(context, MaterialPageRoute(builder: (context) => const PasswordCheckPage()));
            }),
            _tile(Icons.notifications_none, '알림 설정', '진료 및 예약 알림을 관리하세요', true, () { // [요구사항 3] 화살표 표시
              Navigator.push(context, MaterialPageRoute(builder: (context) => const NotificationSettingsPage()));
            }),
            
            const SizedBox(height: 20),
            _section('기타'),
            _tile(Icons.help_outline, '고객센터', '문의사항이 있으신가요?', false, null), // [요구사항 3] 화살표 제거 및 클릭 차단
            _tile(Icons.info_outline, '앱 버전 정보', 'v 1.0.1 (최신 버전)', false, null), // [요구사항 3] 화살표 제거 및 클릭 차단
            
            const SizedBox(height: 30),
            TextButton(
              // [수정] 단순 pop이 아니라 서버 통신 함수 호출
              onPressed: () => _handleLogout(context), 
              child: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _section(String t) => Container(width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10), child: Text(t, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)));
  
  // [요구사항 3] 화살표 유무를 선택하는 showArrow 추가
  Widget _tile(IconData i, String t, String s, bool showArrow, VoidCallback? onTap) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(i, color: const Color(0xFF005A9C)),
        title: Text(t),
        subtitle: Text(s, style: const TextStyle(fontSize: 12)),
        trailing: showArrow ? const Icon(Icons.chevron_right) : null, // 화살표 조건부 렌더링
        onTap: onTap,
      ),
    );
  }
}

// --- 6. 비밀번호 확인 페이지 [요구사항 2] ---
class PasswordCheckPage extends StatelessWidget {
  const PasswordCheckPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 확인'), backgroundColor: const Color(0xFF005A9C)),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const Text('현재 비밀번호를 입력해 주세요.', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '현재 비밀번호', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const NewPasswordPage())),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: const Text('확인', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 7. 새 비밀번호 설정 페이지 [요구사항 2] ---
class NewPasswordPage extends StatelessWidget {
  const NewPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 비밀번호 설정'), backgroundColor: const Color(0xFF005A9C)),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '새 비밀번호', border: OutlineInputBorder())),
            const SizedBox(height: 15),
            const TextField(obscureText: true, decoration: InputDecoration(labelText: '새 비밀번호 확인', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () {
                  // 성공 메시지 후 로그아웃 처리
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.')));
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: const Text('변경 완료', style: TextStyle(color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- 8. 알림 설정 페이지 (비활성화 로직 추가) ---
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});
  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool isNewBooking = true;
  bool isReviewNotify = true;
  bool isPatientArrival = true;
  String reminderTime = "30분 전";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('알림 상세 설정'), backgroundColor: const Color(0xFF005A9C)),
      body: ListView(
        children: [
          _buildSwitchTile('신규 예약 알림', '새로운 예약 신청이 들어오면 알림을 받습니다.', isNewBooking, (v) => setState(() => isNewBooking = v)),
          _buildSwitchTile('리뷰 등록 알림', '환자가 리뷰를 작성하면 알림을 받습니다.', isReviewNotify, (v) => setState(() => isReviewNotify = v)),
          _buildSwitchTile('환자 방문 예정 알림', '예약 환자의 방문 예정 시간을 미리 알려줍니다.', isPatientArrival, (v) => setState(() => isPatientArrival = v)),
          
          // 비활성화 로직 적용 섹션 [요구사항 1]
          Opacity(
            opacity: isPatientArrival ? 1.0 : 0.4, // 꺼지면 연하게 만듦
            child: AbsorbPointer(
              absorbing: !isPatientArrival, // 꺼지면 클릭 차단
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.grey),
                title: const Text('방문 알림 시간 설정'),
                subtitle: Text('현재 설정: $reminderTime'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  _showTimePicker();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 시간 선택 바텀 시트
  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: ["10분 전", "30분 전", "1시간 전"].map((t) => ListTile(
            title: Center(child: Text(t, style: TextStyle(fontWeight: reminderTime == t ? FontWeight.bold : FontWeight.normal))),
            onTap: () { setState(() => reminderTime = t); Navigator.pop(context); }
          )).toList(),
        ),
      ),
    );
  }

  Widget _buildSwitchTile(String t, String s, bool v, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(s, style: const TextStyle(fontSize: 12)),
      value: v,
      onChanged: onChanged,
      activeColor: const Color(0xFF005A9C),
    );
  }
}

// --- 9. 계정 상세 정보 페이지 (신규) [요구사항 반영] ---
class AccountDetailPage extends StatelessWidget {
  const AccountDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 상세 정보'), backgroundColor: const Color(0xFF005A9C)),
      body: Column(
        children: [
          const SizedBox(height: 20),
          _buildDetailItem('계정 ID (이메일)', 'admin@dentalnara.com'),
          _buildDetailItem('계정 생성 일시', '2026.01.31 14:00'),
          _buildDetailItem('마지막 로그인 기록', '2026.02.11 09:12'),
          _buildDetailItem('계정 권한', '병원 총괄 관리자 (Master)'),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(25),
            child: const Text('계정 관련 문의는 고객센터로 연락 바랍니다.', style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 1),
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

// 10. 예약 및 진료 관리 페이지
class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});
  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _showHistoryDetail = false;
  Map<String, dynamic> _historyDetailData = {};

  Map<String, List<Map<String, dynamic>>> globalEvents = {};
  bool _loadingReservations = false;

  @override

  void initState() {
    super.initState();
    _loadReservations();
  }

  Future<void> _loadReservations() async {
    setState(() => _loadingReservations = true);
    try {
      final ykiho = Supabase.instance.client.auth.currentUser?.email; // 로그인한 병원 이메일

      // 본인 병원의 reservations만 조회
      final data = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('ykiho', ykiho ?? '')  // 실제로는 ykiho를 저장해둔 값 사용
          .order('reserved_at', ascending: true);

      // Supabase 응답을 globalEvents 형식으로 변환
      final Map<String, List<Map<String, dynamic>>> events = {};
      for (final r in data as List) {
        final dateKey = DateFormat('yyyy-MM-dd').format(DateTime.parse(r['reserved_at']));
        events.putIfAbsent(dateKey, () => []);
        events[dateKey]!.add({
          'id': r['id'],
          'name': r['patient_name'],
          'time': DateFormat('HH:mm').format(DateTime.parse(r['reserved_at'])),
          'count': r['visit_count'] ?? 1,
          'desc': r['description'] ?? '',
          'isDone': r['status'] == 'done',
          'isCancelled': r['status'] == 'cancelled',
          'cancelReason': r['cancel_reason'] ?? '',
          'isRead': r['is_read'] ?? false,
          'history': [],  // patient_visits 테이블에서 별도 조회 가능
        });
      }
      setState(() => globalEvents = events);
    } catch (e) {
      debugPrint('예약 로드 실패: $e');
    } finally {
      setState(() => _loadingReservations = false);
    }
  }

  Widget build(BuildContext context) {
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    List<Map<String, dynamic>> dailyPatients = globalEvents[dateKey] ?? [];

    return Scaffold(
      appBar: AppBar(title: const Text('예약 및 진료 관리'), backgroundColor: const Color(0xFF005A9C), elevation: 0),
      body: Column(
        children: [
          _buildTableCalendar(),
          const Divider(height: 1),
          Expanded(child: dailyPatients.isEmpty ? const Center(child: Text('예약이 없습니다.')) : ListView.builder(padding: const EdgeInsets.all(10), itemCount: dailyPatients.length, itemBuilder: (context, index) => _buildPatientTile(dailyPatients[index], index))),
        ],
      ),
    );
  }

  Widget _buildTableCalendar() {
    DateTime firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    int firstWeekday = firstDay.weekday; // 1(월) ~ 7(일)
    int daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;

    return Column(children: [
      // 달력 헤더 (연/월 및 이동 버튼)
      Padding(padding: const EdgeInsets.all(10), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1))),
        Text(DateFormat('yyyy년 MM월').format(_focusedDay), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1))),
      ])),
      
      // [복구] 요일 표시줄
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['월', '화', '수', '목', '금', '토', '일'].map((d) => 
            Expanded(child: Center(child: Text(d, style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold))))
          ).toList(),
        ),
      ),

      // 캘린더 그리드
      Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[300]!), left: BorderSide(color: Colors.grey[300]!))),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.0),
          itemCount: 35, 
          itemBuilder: (context, index) {
            int dayNum = index - (firstWeekday - 1) + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return Container(decoration: BoxDecoration(border: Border(right: BorderSide(color: Colors.grey[300]!), bottom: BorderSide(color: Colors.grey[300]!))));
            }

            DateTime day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
            String key = DateFormat('yyyy-MM-dd').format(day);
            int activeCount = globalEvents[key]?.where((e) => !e['isDone'] && !e['isCancelled']).length ?? 0;
            bool hasUnread = globalEvents[key]?.any((e) => e['isRead'] == false) ?? false;
            bool isSelected = _selectedDay.day == day.day && _selectedDay.month == day.month;
            bool isToday = DateTime.now().day == day.day && DateTime.now().month == day.month && DateTime.now().year == day.year;

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blue[100] : (isToday ? Colors.blue[50] : Colors.white),
                  border: Border(right: BorderSide(color: Colors.grey[300]!), bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // [왼쪽 위] 날짜 숫자
                        Text('$dayNum', style: TextStyle(
                          fontSize: 12, 
                          fontWeight: isToday || isSelected ? FontWeight.bold : FontWeight.normal,
                          color: isToday ? const Color(0xFF005A9C) : Colors.black
                        )),
                        // [오른쪽 위] 초록색 점 (미확인 알림)
                        if (hasUnread) Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
                      ],
                    ),
                    const Spacer(),
                    // [하단 중앙] 예약 인원
                    if (activeCount > 0)
                      Center(child: Text('$activeCount명', style: const TextStyle(fontSize: 10, color: Color(0xFF005A9C), fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            );
          },
        ),
      )
    ]);
  }

  Widget _buildPatientTile(Map<String, dynamic> p, int index) {
    bool isCancelled = p['isCancelled'];
    return Opacity(
      opacity: (p['isDone'] || isCancelled) ? 0.4 : 1.0,
      child: Card(child: ListTile(
        onTap: () { setState(() { p['isRead'] = true; _showHistoryDetail = false; }); _showDetail(p, index); },
        leading: Text(p['time'], style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
        title: Row(children: [
          Text(p['name'], style: TextStyle(fontWeight: FontWeight.bold, decoration: isCancelled ? TextDecoration.lineThrough : null, color: isCancelled ? Colors.red : Colors.black)),
          const SizedBox(width: 8),
          _badge('${p['count']}번째 방문'),
          if (!p['isRead']) Container(margin: const EdgeInsets.only(left: 5), width: 8, height: 8, decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
          if (isCancelled) const Text(' [취소됨]', style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
        ]),
        subtitle: Text(p['desc']),
        trailing: const Icon(Icons.chevron_right),
      )),
    );
  }

  void _showDetail(Map<String, dynamic> p, int index) {
    showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))), builder: (context) => StatefulBuilder(builder: (context, setSheetState) => Container(
      height: MediaQuery.of(context).size.height * 0.85, padding: const EdgeInsets.all(25),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          if (_showHistoryDetail) IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => setSheetState(() => _showHistoryDetail = false)),
          Text(_showHistoryDetail ? '과거 기록 상세' : '${p['name']} 상세 정보', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const Spacer(), IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
        ]),
        const Divider(height: 30),
        Expanded(child: SingleChildScrollView(child: _showHistoryDetail ? _buildPastContent() : _buildCurrContent(p, setSheetState))),
      ])
    )));
  }

  Widget _buildCurrContent(Map<String, dynamic> p, StateSetter setSheetState) {
    List hists = p['history'] ?? [];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoItem('환자 기본 정보', '성별: 여 / 나이: 28세 / 연락처: 010-XXXX-XXXX'),
      const SizedBox(height: 20),
      _aiBox('현재 AI 분석 결과', hists.first['ai']),
      const SizedBox(height: 30),
      const Text('진료 히스토리 (클릭 시 상세 확인)', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      ...hists.map((h) => Card(child: ListTile(title: Text(h['date']), subtitle: Text(h['type']), trailing: const Icon(Icons.arrow_forward_ios, size: 14), onTap: () => setSheetState(() { _showHistoryDetail = true; _historyDetailData = h; })))).toList(),
      if (p['isCancelled']) ...[const SizedBox(height: 20), _infoItem('⚠️ 예약 취소 사유', p['cancelReason'], color: Colors.red)],
      const SizedBox(height: 30),
      if (!p['isDone'] && !p['isCancelled']) SizedBox(width: double.infinity, height: 50, child: OutlinedButton(onPressed: () => _cancelDlg(p), style: OutlinedButton.styleFrom(foregroundColor: Colors.red), child: const Text('예약 취소'))),
    ]);
  }

  Widget _buildPastContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoItem('진료일', _historyDetailData['date']),
      const SizedBox(height: 20),
      _infoItem('당시 설문', _historyDetailData['survey']),
      const SizedBox(height: 20),
      _aiBox('당시 AI 분석 결과', _historyDetailData['ai']),
    ]);
  }

  // 헬퍼 위젯들 (클래스 내부로 이동하여 에러 방지)
  Widget _badge(String t) => Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)), child: Text(t, style: const TextStyle(fontSize: 10, color: Colors.black54)));
  Widget _infoItem(String t, String c, {Color color = const Color(0xFF005A9C)}) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: color)), const SizedBox(height: 8), Text(c, style: const TextStyle(height: 1.5))]);
  Widget _aiBox(String t, String c) => Container(width: double.infinity, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)), const SizedBox(height: 5), Text(c, style: const TextStyle(fontSize: 13))]));

  void _cancelDlg(p) {
    TextEditingController c = TextEditingController();
    showDialog(context: context, builder: (context) => AlertDialog(title: const Text('취소 사유'), content: TextField(controller: c), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('닫기')), TextButton(onPressed: () { setState(() { p['isCancelled'] = true; p['cancelReason'] = c.text; }); Navigator.pop(context); Navigator.pop(context); }, child: const Text('확인'))]));
  }
}

// --- 11. 리뷰 관리 페이지 (데이터 포함 완전체) ---

// [데이터 유지] 페이지를 나갔다 들어와도 유지되도록 전역 변수로 선언
List<Map<String, dynamic>> globalReviews = [
  {'id': 'P1001', 'name': '김철수', 'doctor': '정OO 원장', 'treatment': '임플란트', 'rating': 5, 'content': '정말 친절하시고 수술도 안 아팠어요! 대만족입니다.', 'date': '2026-02-18', 'reply': '', 'status': '답변 대기'},
  {'id': 'P1002', 'name': '이영희', 'doctor': '김OO 원장', 'treatment': '스케일링', 'rating': 4, 'content': '시설이 깨끗해요. 예약 필수입니다.', 'date': '2026-02-17', 'reply': '소중한 리뷰 감사합니다!', 'status': '답변 완료'},
  {'id': 'P1003', 'name': '박민수', 'doctor': '정OO 원장', 'treatment': '충치치료', 'rating': 3, 'content': '진료는 좋으나 대기가 좀 기네요.', 'date': '2026-02-10', 'reply': '', 'status': '답변 대기'},
  {'id': 'P1004', 'name': '최유진', 'doctor': '박OO 원장', 'treatment': '교정', 'rating': 5, 'content': '꼼꼼하게 잘 봐주셔서 믿음이 가요.', 'date': '2026-01-25', 'reply': '', 'status': '답변 대기'},
  {'id': 'P1005', 'name': '한지민', 'doctor': '정OO 원장', 'treatment': '임플란트', 'rating': 4, 'content': '상담이 매우 자세해서 좋았습니다.', 'date': '2026-01-20', 'reply': '', 'status': '답변 대기'},
];

class ReviewManagementPage extends StatefulWidget {
  const ReviewManagementPage({super.key});
  @override
  State<ReviewManagementPage> createState() => _ReviewManagementPageState();
}

class _ReviewManagementPageState extends State<ReviewManagementPage> {
  // 필터 상태 관리 변수
  String searchPatientId = '';
  List<String> selectedTreatments = [];
  List<Map<String, dynamic>> globalReviews = [];
  bool _loadingReviews = false;

  final List<String> treatments = ['임플란트', '교정', '스케일링', '충치치료', '보철치료'];

  // 필터링 로직 (의료진 매칭 삭제)
  List<Map<String, dynamic>> get filteredReviews {
    return globalReviews.where((r) {
      final matchId = searchPatientId.isEmpty || r['id'].toLowerCase().contains(searchPatientId.toLowerCase());
      final matchTreat = selectedTreatments.isEmpty || selectedTreatments.contains(r['treatment']);
      return matchId && matchTreat;
    }).toList();
  }

  // 병원 전체 평균 별점 계산
  double get hospitalAvg => globalReviews.isEmpty ? 0.0 : globalReviews.map((e) => e['rating'] as int).reduce((a, b) => a + b) / globalReviews.length;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final ykiho = Supabase.instance.client.auth.currentUser?.email;

      final data = await Supabase.instance.client
          .from('reviews')
          .select('*')
          .eq('ykiho', ykiho ?? '')
          .order('reviewed_at', ascending: false);

      setState(() {
        globalReviews = (data as List).map((r) => {
          'id': r['patient_id'] ?? '',
          'name': r['patient_name'] ?? '',
          'treatment': r['treatment'] ?? '',
          'rating': r['rating'] ?? 0,
          'content': r['content'] ?? '',
          'date': r['reviewed_at']?.toString().substring(0, 10) ?? '',
          'reply': r['reply'] ?? '',
          'status': r['status'] ?? '답변 대기',
        }).toList();
      });
    } catch (e) {
      debugPrint('리뷰 로드 실패: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('리뷰 관리', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.black), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF005A9C)),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSummary(), // 병원 전체 평점만 표시
          if (selectedTreatments.isNotEmpty || searchPatientId.isNotEmpty)
            _buildActiveFilterChips(),
          Expanded(
            child: filteredReviews.isEmpty
                ? const Center(child: Text('해당하는 리뷰가 없습니다.'))
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredReviews.length,
                    itemBuilder: (context, index) => _buildReviewItem(filteredReviews[index]),
                  ),
          ),
        ],
      ),
    );
  }

  // 상단 별점 요약 섹션 (병원 평점만 남김)
  Widget _buildTopSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
        color: Colors.white, 
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))
      ),
      child: Center(
        child: _summaryColumn('병원 전체 평점', hospitalAvg.toStringAsFixed(1), Icons.star_rounded, Colors.orange),
      ),
    );
  }

  Widget _summaryColumn(String label, String value, IconData icon, Color color) {
    return Column(
      children: [
        Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 24), 
            const SizedBox(width: 6), 
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold))
          ]
        ),
      ],
    );
  }

  // 활성화된 필터 칩 표시
  Widget _buildActiveFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          ...selectedTreatments.map((t) => _activeChip(t, () => setState(() => selectedTreatments.remove(t)))),
          if (searchPatientId.isNotEmpty) _activeChip('ID: $searchPatientId', () => setState(() => searchPatientId = '')),
        ],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onDelete) => InputChip(label: Text(label, style: const TextStyle(fontSize: 11)), onDeleted: onDelete, deleteIconColor: Colors.red, backgroundColor: Colors.blue[50]);
  
  // 리뷰 리스트 아이템 디자인
  Widget _buildReviewItem(Map<String, dynamic> review) {
    bool isPending = review['status'] == '답변 대기';
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))]),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${review['name']} (${review['id']})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(review['date'], style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ]),
              _statusTag(isPending),
            ],
          ),
          const SizedBox(height: 12),
          // 의료진 태그 삭제하고 시술 태그만 남김
          _infoTag(review['treatment'], Colors.grey[100]!, Colors.grey[700]!),
          const SizedBox(height: 12),
          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 18, color: i < review['rating'] ? Colors.orange : Colors.grey[200]))),
          const SizedBox(height: 10),
          Text(review['content'], style: const TextStyle(height: 1.4, fontSize: 14, color: Colors.black87)),
          if (review['reply'].isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey[200]!)),
              child: Text('답변: ${review['reply']}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
          ],
          if (isPending) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              height: 40,
              child: ElevatedButton(
                onPressed: () => _showReplyModal(review),
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                child: const Text('답글 달기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          ]
        ],
      ),
    );
  }

  // 필터 바텀시트 (의료진 선택 부분 삭제)
  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('리뷰 필터', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                      onPressed: () {
                        setMState(() { selectedTreatments = []; searchPatientId = ''; });
                        setState(() {});
                      }, 
                      child: const Text('초기화', style: TextStyle(color: Colors.red))
                    )
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(hintText: '환자 ID로 검색', prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  onChanged: (val) { setMState(() => searchPatientId = val); setState(() => searchPatientId = val); },
                ),
                const SizedBox(height: 20),
                _filterLabel('시술 종류 (중복 가능)'),
                Wrap(spacing: 8, children: treatments.map((t) => FilterChip(label: Text(t), selected: selectedTreatments.contains(t), onSelected: (val) { setMState(() { val ? selectedTreatments.add(t) : selectedTreatments.remove(t); }); setState(() {}); })).toList()),
                const SizedBox(height: 30),
                SizedBox(width: double.infinity, height: 50, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), onPressed: () => Navigator.pop(context), child: const Text('필터 적용', style: TextStyle(color: Colors.white, fontSize: 16)))),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // 답글 작성 모달 (기존 동일)
  void _showReplyModal(Map<String, dynamic> review) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${review['name']}님께 답글 작성', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            TextField(controller: controller, maxLines: 5, decoration: InputDecoration(hintText: '답변을 입력해주세요.', border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)))),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity, height: 50,
              child: ElevatedButton(
                onPressed: () { setState(() { review['reply'] = controller.text; review['status'] = '답변 완료'; }); Navigator.pop(context); },
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: const Text('등록하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _filterLabel(String label) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)));
  Widget _statusTag(bool isPending) => Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: isPending ? Colors.red[50] : Colors.green[50], borderRadius: BorderRadius.circular(6)), child: Text(isPending ? '답변 대기' : '답변 완료', style: TextStyle(color: isPending ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)));
  Widget _infoTag(String text, Color bg, Color textCol) => Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)), child: Text(text, style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.w600)));
}