import 'package:flutter/material.dart';
import '../../core/constants.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({super.key});

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 비밀번호 설정')),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          children: [
            TextField(
              controller: _newPwCtrl,
              obscureText: true,
              decoration: AppStyles.inputDecoration.copyWith(
                labelText: '새 비밀번호',
                helperText: ValidationUtils.passwordHint,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPwCtrl,
              obscureText: true,
              decoration: AppStyles.inputDecoration.copyWith(labelText: '새 비밀번호 확인'),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: () {
                  if (!ValidationUtils.isPasswordValid(_newPwCtrl.text)) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(ValidationUtils.passwordHint))
                    );
                    return;
                  }
                  if (_newPwCtrl.text != _confirmPwCtrl.text) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('비밀번호가 일치하지 않습니다.'))
                    );
                    return;
                  }
                  
                  // 성공 메시지 후 로그인 화면으로 복귀
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('비밀번호가 변경되었습니다. 다시 로그인해 주세요.'))
                  );
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
                style: AppStyles.buttonStyle,
                child: const Text('변경 완료'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
