import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'address_search_screen.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _pwCtrl = TextEditingController();
  final TextEditingController _pwCheckCtrl = TextEditingController();
  final TextEditingController _addressCtrl = TextEditingController();

  bool _isLoading = false;
  bool _agreedToPrivacy = false;

  // 비밀번호 실시간 유효성 상태
  bool _pwTouched = false;       // 비밀번호 칸 건드렸는지
  bool _pwCheckTouched = false;  // 비밀번호 확인 칸 건드렸는지

  PlatformFile? licenseFile;
  PlatformFile? businessFile;
  PlatformFile? reportFile;

  // 모든 항목이 채워졌는지 체크
  bool get _isAllFilled =>
      _nameCtrl.text.trim().isNotEmpty &&
          _addressCtrl.text.trim().isNotEmpty &&
          _emailCtrl.text.trim().isNotEmpty &&
          _pwCtrl.text.length >= 6 &&
          _pwCtrl.text == _pwCheckCtrl.text &&
          licenseFile != null &&
          businessFile != null &&
          reportFile != null &&
          _agreedToPrivacy;

  // 비밀번호 에러 메시지
  String? get _pwError {
    if (!_pwTouched) return null;
    if (_pwCtrl.text.isEmpty) return '비밀번호를 입력해주세요.';
    if (_pwCtrl.text.length < 6) return '6자리 이상 입력해주세요.';
    return null;
  }

  // 비밀번호 확인 에러 메시지
  String? get _pwCheckError {
    if (!_pwCheckTouched) return null;
    if (_pwCheckCtrl.text.isEmpty) return '비밀번호 확인을 입력해주세요.';
    if (_pwCtrl.text != _pwCheckCtrl.text) return '비밀번호가 일치하지 않습니다.';
    return null;
  }

  @override
  void initState() {
    super.initState();
    // 입력값 바뀔 때마다 버튼 활성화 여부 갱신
    _nameCtrl.addListener(() => setState(() {}));
    _emailCtrl.addListener(() => setState(() {}));
    _pwCtrl.addListener(() => setState(() {}));
    _pwCheckCtrl.addListener(() => setState(() {}));
    _addressCtrl.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _pwCtrl.dispose();
    _pwCheckCtrl.dispose();
    _addressCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFile(String type) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
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
      debugPrint('파일 선택 에러: $e');
    }
  }

  void _searchAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const AddressSearchScreen()),
    );
    if (result != null && result is String) {
      setState(() => _addressCtrl.text = result);
    }
  }

  Future<void> _updateExistingHospital(String ykiho, String addr) async {
    final existing = await Supabase.instance.client
        .from('hospitals')
        .select('status')
        .eq('ykiho', ykiho)
        .maybeSingle();

    final currentStatus = existing?['status'] as String?;
    final updateData = <String, dynamic>{
      'email': _emailCtrl.text.trim(),
      'is_partner': true,
      'addr': addr,
    };
    // 이미 approved면 status 건드리지 않음
    if (currentStatus != 'approved') {
      updateData['status'] = 'pending';
    }

    await Supabase.instance.client
        .from('hospitals')
        .update(updateData)
        .eq('ykiho', ykiho);
  }

  Future<void> _signUp() async {
    setState(() => _isLoading = true);
    try {
      final authResponse = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (authResponse.user == null) {
        _showErrorDialog('가입 실패', '이미 사용 중인 이메일이거나 가입에 실패했습니다.');
        return;
      }

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

      final name = _nameCtrl.text.trim();
      final addr = _addressCtrl.text.trim();

      final normalizedName = name.replaceAll(' ', '');

      // 앞 2글자로 DB 검색 후 Dart에서 로컬 필터링
      // (긴 한글 패턴의 ilike 전송 오류 방지)
      final prefix = normalizedName.length >= 2
          ? normalizedName.substring(0, 2)
          : normalizedName;

      final raw = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho, yadm_nm, addr')
          .ilike('yadm_nm', '%$prefix%')
          .limit(100);

      // Dart 레벨에서 정확한 포함 여부 필터
      final List<dynamic> candidates = (raw as List).where((h) {
        final dbName = (h['yadm_nm'] as String? ?? '').replaceAll(' ', '');
        return dbName.contains(normalizedName) ||
            normalizedName.contains(dbName);
      }).toList();

      final String ykiho;
      if (candidates.isEmpty) {
        // 검색 실패 시 조용히 새 병원 만들지 않고 사용자에게 알림
        await Supabase.instance.client.auth.signOut();
        _showErrorDialog(
          '병원을 찾지 못했습니다',
          '"$name" 병원을 DB에서 찾을 수 없습니다.\n병원명을 정확히 입력해주세요.\n(예: 오오치과 → 오오치과의원)',
        );
        return;
      } else if (candidates.length == 1) {
        // 결과가 하나면 바로 연결
        ykiho = candidates.first['ykiho'] as String;
        await _updateExistingHospital(ykiho, addr);
      } else {
        // 동명 병원 여러 개 → 유저가 직접 선택
        if (!mounted) return;
        final selected = await showDialog<Map<String, dynamic>>(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            title: const Text('병원을 선택해주세요'),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidates.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final h = candidates[i];
                  return ListTile(
                    title: Text(h['yadm_nm'] ?? '',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text(h['addr'] ?? '',
                        style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    onTap: () => Navigator.pop(ctx, h),
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, null),
                child: const Text('취소'),
              ),
            ],
          ),
        );

        if (selected == null) {
          // 유저가 취소 → 가입 중단, auth 계정도 삭제
          await Supabase.instance.client.auth.signOut();
          setState(() => _isLoading = false);
          return;
        }

        ykiho = selected['ykiho'] as String;
        await _updateExistingHospital(ykiho, addr);
      }

      for (final entry in [
        if (licenseUrl != null) {'doc_type': 'license', 'file_url': licenseUrl},
        if (businessUrl != null) {'doc_type': 'business', 'file_url': businessUrl},
        if (reportUrl != null) {'doc_type': 'report', 'file_url': reportUrl},
      ]) {
        await Supabase.instance.client.from('hospital_documents').insert({
          'ykiho': ykiho,
          ...entry,
        });
      }

      _showCompleteDialog();
    } on AuthException catch (e) {
      _showErrorDialog('가입 실패', e.message);
    } catch (e) {
      await Supabase.instance.client.auth.signOut();
      _showErrorDialog('가입 실패', '네트워크 연결을 확인하고 다시 시도해주세요.\n동일한 이메일로 재시도 가능합니다.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('파트너 회원가입'), backgroundColor: const Color(0xFF005A9C)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('병원 정보를 입력해 주세요.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),

            // 병원명
            _labeledField('병원명', TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                  hintText: '병원 이름을 입력하세요.', border: OutlineInputBorder()),
            )),
            const SizedBox(height: 15),

            // 병원 주소
            _labeledField('병원 주소', _buildAddressBtn()),
            const SizedBox(height: 15),

            // 이메일
            _labeledField('이메일(ID)', TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                  hintText: '로그인에 사용할 이메일 주소입니다.', border: OutlineInputBorder()),
            )),
            const SizedBox(height: 15),

            // 비밀번호 - 실시간 유효성 체크
            _labeledField('비밀번호', TextField(
              controller: _pwCtrl,
              obscureText: true,
              onChanged: (_) => setState(() => _pwTouched = true),
              decoration: InputDecoration(
                hintText: '6자리 이상 입력',
                border: const OutlineInputBorder(),
                errorText: _pwError,
                // 6자리 이상이면 초록색 체크 표시
                suffixIcon: _pwTouched && _pwCtrl.text.length >= 6
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : null,
              ),
            )),
            const SizedBox(height: 15),

            // 비밀번호 확인 - 실시간 유효성 체크
            _labeledField('비밀번호 확인', TextField(
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
            )),
            const SizedBox(height: 40),

            // 서류 업로드
            const Text('필수 서류 업로드',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            const Text('심사를 위해 아래 3가지 서류를 모두 첨부해 주세요.',
                style: TextStyle(color: Colors.grey, fontSize: 12)),
            const SizedBox(height: 20),
            _buildUploadBtn('의사 면허증', licenseFile?.name, () => _pickFile('license')),
            const SizedBox(height: 15),
            _buildUploadBtn('사업자 등록증', businessFile?.name, () => _pickFile('business')),
            const SizedBox(height: 15),
            _buildUploadBtn('의료기관 개설 신고증', reportFile?.name, () => _pickFile('report')),
            const SizedBox(height: 50),

            // 개인정보처리방침 동의
            Row(
              children: [
                Checkbox(
                  value: _agreedToPrivacy,
                  onChanged: (v) => setState(() => _agreedToPrivacy = v ?? false),
                  activeColor: const Color(0xFF005A9C),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => launchUrl(
                      Uri.parse('https://tender-knot-a79.notion.site/36f5144a05e8808fafd7f0a7f941fa99'),
                      mode: LaunchMode.platformDefault,
                    ),
                    child: RichText(
                      text: const TextSpan(
                        style: TextStyle(fontSize: 13, color: Colors.black87),
                        children: [
                          TextSpan(text: '(필수) '),
                          TextSpan(
                            text: '개인정보처리방침',
                            style: TextStyle(
                              color: Color(0xFF005A9C),
                              decoration: TextDecoration.underline,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          TextSpan(text: '에 동의합니다.'),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // 가입 요청 버튼 - 모든 항목 완료 시에만 활성화
            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: (_isAllFilled && !_isLoading) ? _signUp : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF005A9C),
                  disabledBackgroundColor: Colors.grey[300],
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('가입 요청하기',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),

            // 버튼 비활성화 안내
            if (!_isAllFilled) ...[
              const SizedBox(height: 12),
              const Center(
                child: Text('모든 항목을 올바르게 입력해야 가입 요청이 가능합니다.',
                    style: TextStyle(color: Colors.grey, fontSize: 12)),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _labeledField(String label, Widget field) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        field,
      ],
    );
  }

  Widget _buildAddressBtn() {
    final filled = _addressCtrl.text.isNotEmpty;
    return InkWell(
      onTap: _searchAddress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        decoration: BoxDecoration(
          color: filled ? const Color(0xFFE3F2FD) : Colors.grey[50],
          border: Border.all(color: filled ? const Color(0xFF005A9C) : Colors.grey[300]!),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(Icons.location_on_outlined,
              color: filled ? const Color(0xFF005A9C) : Colors.grey, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              filled ? _addressCtrl.text : '주소 검색을 눌러주세요.',
              style: TextStyle(
                  color: filled ? const Color(0xFF005A9C) : Colors.grey, fontSize: 14),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
                color: const Color(0xFF005A9C), borderRadius: BorderRadius.circular(6)),
            child: const Text('검색',
                style: TextStyle(
                    color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
          ),
        ]),
      ),
    );
  }

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
              border: Border.all(
                  color: fileName == null ? Colors.grey[300]! : const Color(0xFF005A9C)),
              borderRadius: BorderRadius.circular(10),
              color: fileName == null ? Colors.grey[50] : const Color(0xFFE3F2FD),
            ),
            child: Row(children: [
              Icon(
                  fileName == null ? Icons.file_upload_outlined : Icons.check_circle,
                  color: fileName == null ? Colors.grey : const Color(0xFF005A9C)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  fileName ?? '파일을 선택하세요',
                  style: TextStyle(
                      color: fileName == null ? Colors.grey : const Color(0xFF005A9C),
                      fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ]),
          ),
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
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pop(context);
              },
              child: const Text('확인'))
        ],
      ),
    );
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
}