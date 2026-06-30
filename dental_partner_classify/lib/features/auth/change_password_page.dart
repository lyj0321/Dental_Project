import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_page.dart';

class ChangePasswordPage extends StatefulWidget {
  const ChangePasswordPage({super.key});

  @override
  State<ChangePasswordPage> createState() => _ChangePasswordPageState();
}

class _ChangePasswordPageState extends State<ChangePasswordPage> {
  final TextEditingController _pwCtrl = TextEditingController();
  final TextEditingController _pwCheckCtrl = TextEditingController();
  bool _isLoading = false;
  bool _pwTouched = false;
  bool _pwCheckTouched = false;

  String? get _pwError {
    if (!_pwTouched) return null;
    if (_pwCtrl.text.length < 6) return '6자리 이상 입력해주세요.';
    return null;
  }

  String? get _pwCheckError {
    if (!_pwCheckTouched) return null;
    if (_pwCtrl.text != _pwCheckCtrl.text) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  bool get _canSubmit =>
      _pwCtrl.text.length >= 6 &&
      _pwCtrl.text == _pwCheckCtrl.text &&
      !_isLoading;

  @override
  void initState() {
    super.initState();
    _pwCtrl.addListener(() => setState(() {}));
    _pwCheckCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pwCtrl.dispose();
    _pwCheckCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _pwCtrl.text),
      );
      await Supabase.instance.client.auth.signOut();
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('변경 완료', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('비밀번호가 성공적으로 변경되었습니다.\n새 비밀번호로 로그인해주세요.'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (_) => false,
                );
              },
              child: const Text('로그인하러 가기'),
            ),
          ],
        ),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      final msg = e.message.contains('different from the old password')
          ? '이전 비밀번호와 동일합니다. 다른 비밀번호를 입력해주세요.'
          : '오류가 발생했습니다. 다시 시도해주세요.';
      _showErrorDialog(msg);
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('네트워크 상태를 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('오류', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('새 비밀번호 설정'),
        backgroundColor: const Color(0xFF005A9C),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '사용할 새 비밀번호를 입력해주세요.',
              style: TextStyle(color: Colors.grey, height: 1.5),
            ),
            const SizedBox(height: 30),
            const Text('새 비밀번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              onChanged: (_) => setState(() => _pwTouched = true),
              decoration: InputDecoration(
                hintText: '6자리 이상 입력',
                border: const OutlineInputBorder(),
                errorText: _pwError,
                suffixIcon: _pwTouched && _pwCtrl.text.length >= 6
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 20),
            const Text('새 비밀번호 확인', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            TextField(
              controller: _pwCheckCtrl,
              obscureText: true,
              onChanged: (_) => setState(() => _pwCheckTouched = true),
              decoration: InputDecoration(
                hintText: '비밀번호를 다시 입력하세요',
                border: const OutlineInputBorder(),
                errorText: _pwCheckError,
                suffixIcon: _pwCheckTouched &&
                        _pwCheckCtrl.text.isNotEmpty &&
                        _pwCtrl.text == _pwCheckCtrl.text
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _canSubmit ? _changePassword : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A9C),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        '비밀번호 변경',
                        style: TextStyle(
                            color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
