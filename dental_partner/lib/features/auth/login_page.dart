import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../dashboard/main_dashboard.dart';
import 'signup_page.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  bool _isLoading = false;

  void _showError(String title, String msg) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("확인"))],
      ),
    );
  }

  Future<void> _handleLogin() async {
    if (_emailCtrl.text.isEmpty || _pwCtrl.text.isEmpty) {
      _showError("입력 필요", "이메일과 비밀번호를 모두 입력해주세요.");
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Supabase Auth 로그인
      final authRes = await Supabase.instance.client.auth.signInWithPassword(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      final user = authRes.user;
      if (user == null) throw Exception("인증 정보가 없습니다.");

      // 2. 병원 승인 상태 확인 (email 컬럼 활용)
      final hospitalData = await Supabase.instance.client
          .from('hospitals')
          .select('status')
          .eq('email', user.email!)
          .maybeSingle();

      if (hospitalData == null) {
        // 테이블에 정보가 없는 경우
        await Supabase.instance.client.auth.signOut();
        _showError("정보 없음", "등록된 병원 정보를 찾을 수 없습니다. (${user.email})");
        return;
      }

      if (hospitalData['status'] == 'pending') {
        await Supabase.instance.client.auth.signOut();
        _showError("승인 대기 중", "관리자의 승인이 완료된 후 이용 가능합니다.");
        return;
      }

      // 3. 메인 대시보드로 이동
      if (mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainDashboard()));
      }
    } on AuthException catch (e) {
      _showError("로그인 실패", e.message);
    } catch (e) {
      // 실제 에러 내용을 확인하기 위해 상세 메시지 표시
      _showError("시스템 오류", "원인: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('덴탈파인드', style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppColors.primary)),
              const Text('파트너 앱', style: TextStyle(fontSize: 18, color: Colors.grey)),
              const SizedBox(height: 60),
              TextField(controller: _emailCtrl, decoration: AppStyles.inputDecoration.copyWith(labelText: '이메일(ID)')),
              const SizedBox(height: 16),
              TextField(controller: _pwCtrl, obscureText: true, decoration: AppStyles.inputDecoration.copyWith(labelText: '비밀번호')),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: AppStyles.buttonStyle,
                  child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('로그인'),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpPage())), 
                    child: const Text('회원가입하기', style: TextStyle(color: Colors.grey))
                  ),
                  const Text('|', style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())), 
                    child: const Text('아이디/비밀번호 찾기', style: TextStyle(color: Colors.grey))
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
