import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../dashboard/main_dashboard.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  bool _isLoading = false;
  bool _rememberEmail = false;

  // encryptedSharedPreferences: true 로 에뮬레이터 호환성 확보
  static const _storage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );
  static const _emailKey = 'saved_email';
  static const _rememberKey = 'remember_email';

  @override
  void initState() {
    super.initState();
    _checkAutoLogin();
    _loadSavedEmail();
  }

  // 앱 재시작 시 기존 세션이 있으면 자동 로그인
  Future<void> _checkAutoLogin() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    setState(() => _isLoading = true);
    try {
      final email = session.user.email;
      if (email == null) return;

      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('status')
          .eq('email', email)
          .maybeSingle();

      if (!mounted) return;

      if (hospital == null ||
          hospital['status'] == 'pending' ||
          hospital['status'] == 'rejected') {
        await Supabase.instance.client.auth.signOut();
        return;
      }

      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => const MainDashboard()));
    } catch (_) {
      // 네트워크 오류 시 로그인 화면 유지
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadSavedEmail() async {
    try {
      final remember = await _storage.read(key: _rememberKey);
      if (remember == 'true') {
        final email = await _storage.read(key: _emailKey);
        if (email != null && mounted) {
          setState(() {
            _emailCtrl.text = email;
            _rememberEmail = true;
          });
        }
      }
    } catch (_) {
      // 에뮬레이터 등 일부 환경에서 secure storage 접근 실패 시 무시
    }
  }

  Future<void> _login() async {
    setState(() => _isLoading = true);
    try {
      final authResponse = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (authResponse.user == null) {
        _showErrorDialog("로그인 실패", "이메일 또는 비밀번호를 확인해주세요.");
        return;
      }

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

      if (hospital['status'] == 'rejected') {
        await Supabase.instance.client.auth.signOut();
        _showErrorDialog('승인 거절', '가입이 거절되었습니다. 관리자에게 문의해주세요.');
        return;
      }

      // 아이디 저장 처리
      try {
        if (_rememberEmail) {
          await _storage.write(key: _emailKey, value: _emailCtrl.text.trim());
          await _storage.write(key: _rememberKey, value: 'true');
        } else {
          await _storage.delete(key: _emailKey);
          await _storage.write(key: _rememberKey, value: 'false');
        }
      } catch (_) {}


      if (mounted) {
        Navigator.pushReplacement(
            context, MaterialPageRoute(builder: (_) => const MainDashboard()));
      }
    } on AuthException catch (e) {
      _showErrorDialog("로그인 실패", e.message);
    } catch (_) {
      _showErrorDialog("연결 실패", "네트워크 상태를 확인해주세요.");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인'))
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - 60),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                const Text('치아온',
                style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF005A9C))),
            const SizedBox(height: 50),
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  labelText: '이메일(ID)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: '비밀번호', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 8),
            // 아이디 저장 체크박스
            Row(
              children: [
                SizedBox(
                  width: 24,
                  height: 24,
                  child: Checkbox(
                    value: _rememberEmail,
                    onChanged: (v) =>
                        setState(() => _rememberEmail = v ?? false),
                    activeColor: const Color(0xFF005A9C),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4)),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () =>
                      setState(() => _rememberEmail = !_rememberEmail),
                  child: const Text('아이디 저장',
                      style: TextStyle(color: Colors.grey, fontSize: 13)),
                ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A9C)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('로그인',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context,
                      MaterialPageRoute(builder: (_) => const SignUpPage())),
                  child: const Text('회원가입하기',
                      style: TextStyle(color: Colors.grey)),
                ),
                const Text('|', style: TextStyle(color: Colors.grey)),
                TextButton(
                  onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ForgotPasswordPage())),
                  child: const Text('아이디/비밀번호 찾기',
                      style: TextStyle(color: Colors.grey)),
                ),
              ],
            ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
