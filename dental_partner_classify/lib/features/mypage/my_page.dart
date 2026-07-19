import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../auth/login_page.dart';
import '../../services/push_notification_service.dart';

// ── 마이페이지 ────────────────────────────────────────────────
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  String _hospitalName = '';
  String _email = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserInfo();
  }

  Future<void> _loadUserInfo() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('yadm_nm')
          .eq('email', user.email!)
          .maybeSingle();

      setState(() {
        _email = user.email ?? '';
        _hospitalName = hospital?['yadm_nm'] ?? '';
      });
    } catch (e) {
      debugPrint('마이페이지 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout(BuildContext context) async {
    try {
      await PushNotificationService.clearTokenOnLogout();
      await Supabase.instance.client.auth.signOut();
    } catch (_) {}
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
      );
    }
  }

  Future<void> _handleWithdraw(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('회원 탈퇴'),
        content: const Text(
          '탈퇴 시 계정이 비활성화되어 더 이상 로그인할 수 없습니다.\n'
          '예약 및 진료 기록은 보관되며, 계정 복구가 필요하면 고객센터로 문의해 주세요.\n\n'
          '계속 진행하시겠습니까?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('탈퇴하기', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final pwCtrl = TextEditingController();
    final password = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          String? errorMsg;
          return AlertDialog(
            title: const Text('본인 확인'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('탈퇴를 진행하려면 비밀번호를 입력해 주세요.'),
                const SizedBox(height: 15),
                TextField(
                  controller: pwCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: '비밀번호',
                    border: const OutlineInputBorder(),
                    errorText: errorMsg,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('취소')),
              TextButton(
                onPressed: () {
                  if (pwCtrl.text.isEmpty) {
                    setDialogState(() => errorMsg = '비밀번호를 입력해주세요.');
                    return;
                  }
                  Navigator.pop(ctx, pwCtrl.text);
                },
                child: const Text('확인', style: TextStyle(color: Colors.red)),
              ),
            ],
          );
        },
      ),
    );
    if (password == null || !context.mounted) return;

    try {
      // 비밀번호 재검증 (본인 확인)
      await Supabase.instance.client.auth.signInWithPassword(
        email: _email,
        password: password,
      );

      // Edge Function 호출 → 서비스 롤 권한으로 Auth 계정 완전 삭제
      final res = await Supabase.instance.client.functions.invoke('delete-account');
      if (res.status != 200) {
        final msg = (res.data is Map) ? res.data['error'] : null;
        throw Exception(msg ?? '탈퇴 처리에 실패했습니다.');
      }

      await Supabase.instance.client.auth.signOut();

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('탈퇴 완료'),
            content: const Text('회원 탈퇴가 완료되었습니다.\n그동안 이용해 주셔서 감사합니다.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                ),
                child: const Text('확인'),
              ),
            ],
          ),
        );
      }
    } on AuthException {
      if (context.mounted) {
        showDialog(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('탈퇴 실패'),
            content: const Text('비밀번호가 일치하지 않습니다.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('확인')),
            ],
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('탈퇴 처리 중 오류가 발생했습니다: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('마이페이지'), backgroundColor: const Color(0xFF005A9C)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            // 프로필 헤더
            Container(
              padding: const EdgeInsets.all(25),
              color: Colors.white,
              child: Row(
                children: [
                  const CircleAvatar(radius: 35, child: Icon(Icons.local_hospital, size: 36)),
                  const SizedBox(width: 20),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_hospitalName.isNotEmpty ? _hospitalName : '병원명 없음',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(_email, style: const TextStyle(color: Colors.grey, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _section('계정 정보'),
            _tile(Icons.badge_outlined, '계정 상세 정보', 'ID 및 가입일 확인', true, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => AccountDetailPage(email: _email, hospitalName: _hospitalName)));
            }),
            const SizedBox(height: 20),
            _section('보안 및 설정'),
            _tile(Icons.lock_outline, '비밀번호 변경', '안전한 관리를 위해 변경해 주세요', true, () {
              Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PasswordCheckPage(email: _email)));
            }),
            _tile(Icons.notifications_none, '알림 설정', '진료 및 예약 알림을 관리하세요', true, () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => const NotificationSettingsPage()));
            }),
            const SizedBox(height: 20),
            _section('기타'),
            _tile(Icons.help_outline, '고객센터', '문의사항이 있으신가요?', false, null),
            _tile(Icons.privacy_tip_outlined, '개인정보처리방침', '개인정보 수집 및 이용 안내', false, () => launchUrl(
              Uri.parse('https://tender-knot-a79.notion.site/36f5144a05e8808fafd7f0a7f941fa99'),
              mode: LaunchMode.platformDefault,
            )),
            _tile(Icons.info_outline, '앱 버전 정보', 'v 1.0.1 (최신 버전)', false, null),
            const SizedBox(height: 30),
            TextButton(
              onPressed: () => _handleLogout(context),
              child: const Text('로그아웃',
                  style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
            TextButton(
              onPressed: () => _handleWithdraw(context),
              child: const Text('회원 탈퇴',
                  style: TextStyle(
                      color: Colors.grey, fontSize: 13, decoration: TextDecoration.underline)),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  static Widget _section(String t) => Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(t, style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 13)));

  static Widget _tile(IconData i, String t, String s, bool showArrow, VoidCallback? onTap) {
    return Container(
      color: Colors.white,
      child: ListTile(
        leading: Icon(i, color: const Color(0xFF005A9C)),
        title: Text(t),
        subtitle: Text(s, style: const TextStyle(fontSize: 12)),
        trailing: showArrow ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }
}

// ── 계정 상세 정보 페이지 ─────────────────────────────────────
class AccountDetailPage extends StatefulWidget {
  final String email;
  final String hospitalName;
  const AccountDetailPage({super.key, required this.email, required this.hospitalName});

  @override
  State<AccountDetailPage> createState() => _AccountDetailPageState();
}

class _AccountDetailPageState extends State<AccountDetailPage> {
  String _createdAt = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null && user.createdAt.isNotEmpty) {
        final dt = DateTime.parse(user.createdAt).toLocal();
        _createdAt =
        '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')} '
            '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
      }
    } catch (e) {
      debugPrint('계정 상세 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('계정 상세 정보'), backgroundColor: const Color(0xFF005A9C)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 20),
          _item('병원명', widget.hospitalName.isNotEmpty ? widget.hospitalName : '-'),
          _item('계정 ID (이메일)', widget.email.isNotEmpty ? widget.email : '-'),
          _item('계정 생성 일시', _createdAt.isNotEmpty ? _createdAt : '-'),
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(25),
            child: Text('계정 관련 문의는 고객센터로 연락 바랍니다.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _item(String label, String value) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    margin: const EdgeInsets.only(bottom: 1),
    color: Colors.white,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
    ]),
  );
}

// ── 비밀번호 확인 페이지 ──────────────────────────────────────
class PasswordCheckPage extends StatefulWidget {
  final String email;
  const PasswordCheckPage({super.key, required this.email});

  @override
  State<PasswordCheckPage> createState() => _PasswordCheckPageState();
}

class _PasswordCheckPageState extends State<PasswordCheckPage> {
  final _pwCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _verify() async {
    if (_pwCtrl.text.isEmpty) {
      setState(() => _errorMsg = '비밀번호를 입력해주세요.');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      // 실제로 Supabase에 로그인 시도해서 비밀번호 검증
      final res = await Supabase.instance.client.auth.signInWithPassword(
        email: widget.email,
        password: _pwCtrl.text,
      );
      if (res.user != null && mounted) {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const NewPasswordPage()));
      }
    } on AuthException {
      setState(() => _errorMsg = '현재 비밀번호가 일치하지 않습니다.');
    } catch (e) {
      setState(() => _errorMsg = '오류가 발생했습니다. 다시 시도해주세요.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('비밀번호 확인'), backgroundColor: const Color(0xFF005A9C)),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('현재 비밀번호를 입력해 주세요.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _pwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '현재 비밀번호',
                border: const OutlineInputBorder(),
                errorText: _errorMsg,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _verify,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('확인', style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 새 비밀번호 설정 페이지 ───────────────────────────────────
class NewPasswordPage extends StatefulWidget {
  const NewPasswordPage({super.key});

  @override
  State<NewPasswordPage> createState() => _NewPasswordPageState();
}

class _NewPasswordPageState extends State<NewPasswordPage> {
  final _newPwCtrl = TextEditingController();
  final _confirmPwCtrl = TextEditingController();
  bool _isLoading = false;
  String? _errorMsg;

  Future<void> _changePassword() async {
    if (_newPwCtrl.text.length < 6) {
      setState(() => _errorMsg = '비밀번호는 6자리 이상이어야 합니다.');
      return;
    }
    if (_newPwCtrl.text != _confirmPwCtrl.text) {
      setState(() => _errorMsg = '새 비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() { _isLoading = true; _errorMsg = null; });
    try {
      // Supabase Auth 비밀번호 실제 변경
      await Supabase.instance.client.auth.updateUser(
        UserAttributes(password: _newPwCtrl.text),
      );
      // 변경 후 로그아웃
      await Supabase.instance.client.auth.signOut();

      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text('변경 완료'),
            content: const Text('비밀번호가 변경되었습니다.\n새 비밀번호로 다시 로그인해 주세요.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                      (route) => false,
                ),
                child: const Text('로그인하러 가기'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      setState(() => _errorMsg = '비밀번호 변경에 실패했습니다. 다시 시도해주세요.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('새 비밀번호 설정'), backgroundColor: const Color(0xFF005A9C)),
      body: Padding(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('새 비밀번호를 입력해 주세요.',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            TextField(
              controller: _newPwCtrl,
              obscureText: true,
              decoration: const InputDecoration(
                  labelText: '새 비밀번호 (6자리 이상)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 15),
            TextField(
              controller: _confirmPwCtrl,
              obscureText: true,
              decoration: InputDecoration(
                labelText: '새 비밀번호 확인',
                border: const OutlineInputBorder(),
                errorText: _errorMsg,
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _changePassword,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('변경 완료',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── 알림 설정 페이지 ─────────────────────────────────────────
class NotificationSettingsPage extends StatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  State<NotificationSettingsPage> createState() => _NotificationSettingsPageState();
}

class _NotificationSettingsPageState extends State<NotificationSettingsPage> {
  bool isNewBooking = true;
  bool isReviewNotify = true;
  bool isPatientArrival = true;
  int reminderMinutes = 30;
  bool _isLoading = true;

  static const Map<int, String> _reminderLabels = {10: '10분 전', 30: '30분 전', 60: '1시간 전'};

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null) return;

      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('notify_new_booking, notify_review, notify_patient_arrival, arrival_reminder_minutes')
          .eq('email', email)
          .maybeSingle();

      if (hospital == null || !mounted) return;

      setState(() {
        isNewBooking = hospital['notify_new_booking'] ?? true;
        isReviewNotify = hospital['notify_review'] ?? true;
        isPatientArrival = hospital['notify_patient_arrival'] ?? true;
        reminderMinutes = hospital['arrival_reminder_minutes'] ?? 30;
      });
    } catch (e) {
      debugPrint('알림 설정 로드 실패: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings(Map<String, dynamic> changes) async {
    final email = Supabase.instance.client.auth.currentUser?.email;
    if (email == null) return;
    try {
      await Supabase.instance.client.from('hospitals').update(changes).eq('email', email);
    } catch (e) {
      debugPrint('알림 설정 저장 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('알림 상세 설정'), backgroundColor: const Color(0xFF005A9C)),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final reminderTime = _reminderLabels[reminderMinutes] ?? '30분 전';
    return Scaffold(
      appBar: AppBar(title: const Text('알림 상세 설정'), backgroundColor: const Color(0xFF005A9C)),
      body: ListView(
        children: [
          _switchTile('신규 예약 알림', '새로운 예약 신청이 들어오면 알림을 받습니다.',
              isNewBooking, (v) {
            setState(() => isNewBooking = v);
            _saveSettings({'notify_new_booking': v});
          }),
          _switchTile('리뷰 등록 알림', '환자가 리뷰를 작성하면 알림을 받습니다.',
              isReviewNotify, (v) {
            setState(() => isReviewNotify = v);
            _saveSettings({'notify_review': v});
          }),
          _switchTile('환자 방문 예정 알림', '예약 환자의 방문 예정 시간을 미리 알려줍니다.',
              isPatientArrival, (v) {
            setState(() => isPatientArrival = v);
            _saveSettings({'notify_patient_arrival': v});
          }),
          Opacity(
            opacity: isPatientArrival ? 1.0 : 0.4,
            child: AbsorbPointer(
              absorbing: !isPatientArrival,
              child: ListTile(
                leading: const Icon(Icons.access_time, color: Colors.grey),
                title: const Text('방문 알림 시간 설정'),
                subtitle: Text('현재 설정: $reminderTime'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showTimePicker,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTimePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _reminderLabels.entries.map((e) => ListTile(
            title: Center(child: Text(e.value, style: TextStyle(
                fontWeight: reminderMinutes == e.key ? FontWeight.bold : FontWeight.normal))),
            onTap: () {
              setState(() => reminderMinutes = e.key);
              _saveSettings({'arrival_reminder_minutes': e.key});
              Navigator.pop(context);
            },
          )).toList(),
        ),
      ),
    );
  }

  Widget _switchTile(String t, String s, bool v, Function(bool) onChanged) {
    return SwitchListTile(
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(s, style: const TextStyle(fontSize: 12)),
      value: v,
      onChanged: onChanged,
      activeColor: const Color(0xFF005A9C),
    );
  }
}