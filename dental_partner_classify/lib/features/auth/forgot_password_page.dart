import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 아이디 찾기
  final TextEditingController _findNameCtrl = TextEditingController();
  final TextEditingController _findPhoneCtrl = TextEditingController();
  bool _isFindIdLoading = false;

  // 비밀번호 재설정
  final TextEditingController _resetEmailCtrl = TextEditingController();
  bool _isResetLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _findNameCtrl.addListener(() => setState(() {}));
    _findPhoneCtrl.addListener(() => setState(() {}));
    _resetEmailCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _tabController.dispose();
    _findNameCtrl.dispose();
    _findPhoneCtrl.dispose();
    _resetEmailCtrl.dispose();
    super.dispose();
  }

  // ── 아이디 찾기 ──────────────────────────────────────────
  Future<void> _findId() async {
    final name = _findNameCtrl.text.trim();
    final phone = _findPhoneCtrl.text.trim().replaceAll('-', '');
    if (name.isEmpty || phone.isEmpty) return;

    setState(() => _isFindIdLoading = true);
    try {
      final rows = await Supabase.instance.client
          .from('hospitals')
          .select('email, telno')
          .ilike('yadm_nm', '%$name%')
          .not('email', 'is', null);

      if (!mounted) return;

      final match = (rows as List).cast<Map<String, dynamic>>().firstWhere(
            (r) => (r['telno'] as String? ?? '').replaceAll('-', '') == phone,
            orElse: () => {},
          );

      if (match.isEmpty || match['email'] == null) {
        _showErrorDialog('찾기 실패', '입력하신 정보와 일치하는 계정을 찾을 수 없습니다.');
        return;
      }

      final masked = _maskEmail(match['email'] as String);
      _showResultDialog('아이디 찾기 결과', '입력하신 정보와 일치하는 아이디는\n$masked 입니다.');
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('오류', '네트워크 상태를 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isFindIdLoading = false);
    }
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final local = parts[0];
    final visible = local.length > 2 ? local.substring(0, 2) : local[0];
    return '$visible***@${parts[1]}';
  }

  // ── 비밀번호 재설정: 이메일로 재설정 링크 발송 ───────────────
  Future<void> _sendResetLink() async {
    final email = _resetEmailCtrl.text.trim();
    if (email.isEmpty) return;

    setState(() => _isResetLoading = true);
    try {
      await Supabase.instance.client.auth.resetPasswordForEmail(
        email,
        redirectTo: 'io.supabase.dentalpartner://login-callback',
      );
      if (!mounted) return;
      _showResultDialog(
        '이메일 발송 완료',
        '입력하신 이메일로\n비밀번호 재설정 링크를 발송했습니다.\n\n메일함을 확인해주세요.',
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      _showErrorDialog('발송 실패', e.message);
    } catch (_) {
      if (!mounted) return;
      _showErrorDialog('발송 실패', '네트워크 상태를 확인해주세요.');
    } finally {
      if (mounted) setState(() => _isResetLoading = false);
    }
  }

  // ── Build ────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('계정 정보 찾기'),
        backgroundColor: const Color(0xFF005A9C),
        centerTitle: true,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(fontSize: 16),
          tabs: const [Tab(text: '아이디 찾기'), Tab(text: '비밀번호 재설정')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildFindIdTab(), _buildResetPwTab()],
      ),
    );
  }

  Widget _buildFindIdTab() {
    final canSubmit = _findNameCtrl.text.trim().isNotEmpty &&
        _findPhoneCtrl.text.trim().isNotEmpty &&
        !_isFindIdLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('등록된 병원명과 전화번호를 입력해주세요.', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 30),
          _label('병원명'),
          const SizedBox(height: 10),
          TextField(
            controller: _findNameCtrl,
            decoration: _inputDeco('정확한 병원명을 입력하세요.'),
          ),
          const SizedBox(height: 20),
          _label('전화번호'),
          const SizedBox(height: 10),
          TextField(
            controller: _findPhoneCtrl,
            keyboardType: TextInputType.phone,
            decoration: _inputDeco('- 없이 숫자만 입력'),
          ),
          const SizedBox(height: 40),
          _submitButton('아이디 찾기', canSubmit ? _findId : null, _isFindIdLoading),
        ],
      ),
    );
  }

  Widget _buildResetPwTab() {
    final canSend = _resetEmailCtrl.text.trim().isNotEmpty && !_isResetLoading;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '가입하신 이메일로\n비밀번호 재설정 링크를 발송해 드립니다.',
            style: TextStyle(color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 30),
          _label('이메일(ID)'),
          const SizedBox(height: 10),
          TextField(
            controller: _resetEmailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: _inputDeco('가입 시 등록한 이메일을 입력하세요.'),
          ),
          const SizedBox(height: 40),
          _submitButton('재설정 링크 발송', canSend ? _sendResetLink : null, _isResetLoading),
        ],
      ),
    );
  }

  // ── 공통 위젯 ────────────────────────────────────────────
  Widget _label(String text) =>
      Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14));

  InputDecoration _inputDeco(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(fontSize: 14, color: Colors.grey),
        border: const OutlineInputBorder(),
      );

  Widget _submitButton(String text, VoidCallback? onTap, bool isLoading) {
    return SizedBox(
      width: double.infinity,
      height: 55,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF005A9C),
          disabledBackgroundColor: Colors.grey[300],
        ),
        child: isLoading
            ? const CircularProgressIndicator(color: Colors.white)
            : Text(text,
                style: const TextStyle(
                    color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
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
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('로그인하러 가기'),
          ),
        ],
      ),
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
        ],
      ),
    );
  }
}
