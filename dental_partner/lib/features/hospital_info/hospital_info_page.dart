import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class HospitalInfoPage extends StatefulWidget {
  const HospitalInfoPage({super.key});

  @override
  State<HospitalInfoPage> createState() => _HospitalInfoPageState();
}

class _HospitalInfoPageState extends State<HospitalInfoPage> {
  final _descCtrl = TextEditingController();
  final _telCtrl = TextEditingController();
  Map<String, dynamic> _operatingHours = {};
  bool _isLoading = false;
  String? _ykiho;

  @override
  void initState() {
    super.initState();
    _loadHospitalData();
  }

  Future<void> _loadHospitalData() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final data = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho, description, telno, operating_hours')
          .eq('email', user.email!)
          .maybeSingle();

      if (data != null) {
        setState(() {
          _ykiho = data['ykiho'];
          _descCtrl.text = data['description'] ?? '';
          _telCtrl.text = data['telno'] ?? '';
          _operatingHours = data['operating_hours'] ?? {};
        });
      }
    } catch (e) {
      debugPrint('병원 정보 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _updateInfo() async {
    if (_ykiho == null) return;
    setState(() => _isLoading = true);
    try {
      await Supabase.instance.client.from('hospitals').update({
        'description': _descCtrl.text,
        'telno': _telCtrl.text,
        // 'operating_hours': _operatingHours, // 필요 시 확장
      }).eq('ykiho', _ykiho!);
      
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('병원 정보가 저장되었습니다.')));
    } catch (e) {
      debugPrint('저장 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('병원 정보 관리'), actions: [
        TextButton(onPressed: _updateInfo, child: const Text('저장', style: TextStyle(color: Colors.white)))
      ]),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('병원 소개', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _descCtrl,
                  maxLines: 5,
                  decoration: const InputDecoration(hintText: '환자들에게 보여줄 병원 소개글을 입력하세요.'),
                ),
                const SizedBox(height: 32),
                const Text('대표 전화번호', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                TextField(
                  controller: _telCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(hintText: '02-1234-5678'),
                ),
                const SizedBox(height: 32),
                const Text('운영 시간 (현재는 텍스트로 표시)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 12),
                // 운영시간 편집 로직은 JSON 구조에 따라 추후 고도화 가능
                const Text('월-금: 09:30 ~ 18:30\n토요일: 09:30 ~ 14:00\n일요일/공휴일 휴무', style: TextStyle(color: Colors.grey)),
              ],
            ),
          ),
    );
  }
}
