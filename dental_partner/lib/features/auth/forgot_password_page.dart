import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'reset_password_page.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _emailCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  
  bool _isOtpSent = false; // 인증번호 발송 여부
  bool _isLoading = false;

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // 1. 인증번호(OTP) 전송
  Future<void> _sendOtp() async {
    if (_emailCtrl.text.isEmpty) {
      _showMsg('이메일을 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // Supabase를 통해 이메일로 재설정 인증번호 발송
      await Supabase.instance.client.auth.resetPasswordForEmail(
        _emailCtrl.text.trim(),
      );
      
      setState(() => _isOtpSent = true);
      _showMsg('이메일로 인증번호(또는 링크)가 전송되었습니다.');
    } catch (e) {
      _showMsg('전송 실패: ${e.toString()}');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 인증번호 확인
  Future<void> _verifyOtp() async {
    if (_otpCtrl.text.isEmpty) {
      _showMsg('인증번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      // 입력받은 6자리 인증번호 확인
      await Supabase.instance.client.auth.verifyOTP(
        token: _otpCtrl.text.trim(),
        type: OtpType.recovery,
        email: _emailCtrl.text.trim(),
      );

      // 인증 성공 시 새 비밀번호 설정 페이지로 이동
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ResetPasswordPage()),
        );
      }
    } catch (e) {
      _showMsg('인증번호가 일치하지 않거나 만료되었습니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('아이디/비밀번호 찾기')),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('비밀번호를 찾으려는 이메일을 입력해주세요.', style: AppStyles.subTitleStyle),
            const SizedBox(height: 24),
            
            // 이메일 입력창 (인증번호 전송 전까지 활성화)
            TextField(
              controller: _emailCtrl,
              enabled: !_isOtpSent,
              decoration: AppStyles.inputDecoration.copyWith(
                labelText: '이메일 주소',
                hintText: 'example@dentalfind.com',
                suffixIcon: _isOtpSent ? const Icon(Icons.check_circle, color: Colors.green) : null,
              ),
            ),
            
            const SizedBox(height: 16),

            // 인증번호 입력창 (인증번호 전송 후에만 나타남)
            if (_isOtpSent) ...[
              const Text('이메일로 받은 6자리 인증번호를 입력하세요.', style: TextStyle(fontSize: 14, color: Colors.grey)),
              const SizedBox(height: 12),
              TextField(
                controller: _otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: AppStyles.inputDecoration.copyWith(
                  labelText: '인증번호 6자리',
                  counterText: '',
                ),
              ),
            ],

            const SizedBox(height: 30),

            // 버튼 로직 (전송 전: 인증번호 받기 / 전송 후: 인증하기)
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _isLoading 
                  ? null 
                  : (_isOtpSent ? _verifyOtp : _sendOtp),
                style: AppStyles.buttonStyle,
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text(_isOtpSent ? '인증 확인' : '인증번호 받기'),
              ),
            ),

            if (_isOtpSent)
              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : _sendOtp,
                  child: const Text('인증번호 재전송', style: TextStyle(color: Colors.grey)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
