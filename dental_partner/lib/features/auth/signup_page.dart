import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import 'address_search_page.dart';

class SignUpPage extends StatefulWidget {
  const SignUpPage({super.key});

  @override
  State<SignUpPage> createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _emailCtrl = TextEditingController();
  final _pwCtrl = TextEditingController();
  final _pwConfirmCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _businessNumCtrl = TextEditingController();

  PlatformFile? _file1; 
  PlatformFile? _file2; 
  PlatformFile? _file3; 

  bool _isLoading = false;

  String? get _pwErrorText {
    if (_pwConfirmCtrl.text.isEmpty) return null;
    if (_pwCtrl.text != _pwConfirmCtrl.text) return '비밀번호가 일치하지 않습니다.'; 
    return null;
  }

  void _showMsg(String title, String msg, {bool success = false}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (success) Navigator.pop(context);
            },
            child: const Text("확인"),
          )
        ],
      ),
    );
  }

  Future<String?> _uploadFile(PlatformFile? pickedFile, String bizNum, String type) async {
    if (pickedFile == null || pickedFile.path == null) return null;
    try {
      final file = File(pickedFile.path!);
      final fileName = '${bizNum}_${type}_${DateTime.now().millisecondsSinceEpoch}.${pickedFile.extension}';
      final filePath = 'hospital_documents/$fileName';

      await Supabase.instance.client.storage
          .from('certificates')
          .upload(filePath, file, fileOptions: const FileOptions(upsert: true));

      return Supabase.instance.client.storage.from('certificates').getPublicUrl(filePath);
    } catch (e) {
      return null;
    }
  }

  Future<void> _handleSignUp() async {
    if (_emailCtrl.text.isEmpty || _pwCtrl.text.isEmpty || _pwConfirmCtrl.text.isEmpty ||
        _nameCtrl.text.isEmpty || _addressCtrl.text.isEmpty || _businessNumCtrl.text.isEmpty ||
        _file1 == null || _file2 == null || _file3 == null) {
      _showMsg("알림", "모든 항목을 입력하고 3가지 서류를 모두 첨부해주세요.");
      return;
    }

    if (_pwCtrl.text != _pwConfirmCtrl.text) {
      _showMsg("오류", "비밀번호가 서로 일치하지 않습니다.");
      return;
    }

    if (!ValidationUtils.isPasswordValid(_pwCtrl.text)) {
      _showMsg("알림", ValidationUtils.passwordHint);
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authRes = await Supabase.instance.client.auth.signUp(
        email: _emailCtrl.text.trim(),
        password: _pwCtrl.text,
      );

      if (authRes.user == null) throw Exception("인증 생성 실패");

      await Supabase.instance.client.from('hospitals').insert({
        'ykiho': _businessNumCtrl.text.trim(),
        'yadm_nm': _nameCtrl.text.trim(),
        'addr': _addressCtrl.text.trim(),
        'email': _emailCtrl.text.trim(),
        'status': 'pending',
        'is_active': true,
      });

      final files = {'biz_reg': _file1, 'med_lic': _file2, 'bank': _file3};
      for (var f in files.entries) {
        final url = await _uploadFile(f.value, _businessNumCtrl.text.trim(), f.key);
        if (url != null) {
          await Supabase.instance.client.from('hospital_documents').insert({
            'ykiho': _businessNumCtrl.text.trim(),
            'doc_type': f.key,
            'file_url': url,
          });
        }
      }

      _showMsg("가입 완료", "회원가입 신청이 완료되었습니다. 관리자 승인 후 이용 가능합니다.", success: true);
    } catch (e) {
      _showMsg("오류", "가입 처리 중 문제가 발생했습니다: ${e.toString()}");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('회원가입')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Center(child: Text('DentalFind 파트너 가입', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF005A9C)))),
            const SizedBox(height: 40),
            
            _buildLabel('이메일(ID)'),
            _buildTextField(_emailCtrl, '이메일 주소를 입력하세요'),
            
            _buildLabel('비밀번호'),
            _buildTextField(_pwCtrl, '비밀번호를 입력하세요', isObscure: true, onChanged: (_) => setState(() {})),
            
            _buildLabel('비밀번호 재확인'),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: TextField(
                controller: _pwConfirmCtrl,
                obscureText: true,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: '비밀번호를 다시 입력하세요',
                  border: const OutlineInputBorder(),
                  errorText: _pwErrorText,
                  contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                ),
              ),
            ),
            
            _buildLabel('병원명'),
            _buildTextField(_nameCtrl, '병원 이름을 입력하세요'),
            
            _buildLabel('병원 주소'),
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _addressCtrl,
                      readOnly: true,
                      decoration: const InputDecoration(
                        hintText: '주소를 검색하세요',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(vertical: 18, horizontal: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: () async {
                        // 사용자님이 수정한 페이지는 String을 직접 반환하므로 그에 맞춰 수정
                        final res = await Navigator.push(context, MaterialPageRoute(builder: (_) => const AddressSearchPage()));
                        if (res != null && res is String) {
                          setState(() {
                            _addressCtrl.text = res;
                          });
                        }
                      }, 
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        elevation: 0,
                      ),
                      child: const Text('주소 검색')
                    ),
                  ),
                ],
              ),
            ),
            
            _buildLabel('사업자 등록번호'),
            _buildTextField(_businessNumCtrl, '숫자만 입력하세요'),
            
            const SizedBox(height: 30),
            const Align(alignment: Alignment.centerLeft, child: Text('필수 서류 첨부 (3종)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            const SizedBox(height: 15),
            
            _buildFileRow('사업자 등록증', _file1, (f) => setState(() => _file1 = f)),
            _buildFileRow('의료기관 개설신고필증', _file2, (f) => setState(() => _file2 = f)),
            _buildFileRow('통장 사본', _file3, (f) => setState(() => _file3 = f)),
            
            const SizedBox(height: 48),
            SizedBox(
              width: double.infinity, height: 60,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleSignUp,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
                child: _isLoading ? const CircularProgressIndicator(color: Colors.white) : const Text('가입 신청하기', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.black87)),
    );
  }

  Widget _buildTextField(TextEditingController ctrl, String hint, {bool isObscure = false, bool isReadOnly = false, Function(String)? onChanged}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: TextField(
        controller: ctrl,
        obscureText: isObscure,
        readOnly: isReadOnly,
        onChanged: onChanged,
        decoration: InputDecoration(
          hintText: hint,
          border: const OutlineInputBorder(),
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 12),
        ),
      ),
    );
  }

  Widget _buildFileRow(String label, PlatformFile? file, Function(PlatformFile) onPicked) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 14))),
          Text(file == null ? '미선택' : '선택됨', style: TextStyle(fontSize: 12, color: file == null ? Colors.red : Colors.blue, fontWeight: FontWeight.bold)),
          const SizedBox(width: 15),
          ElevatedButton(
            onPressed: () async {
              final res = await FilePicker.platform.pickFiles();
              if (res != null) onPicked(res.files.first);
            }, 
            child: const Text('파일 선택')
          ),
        ],
      ),
    );
  }
}
