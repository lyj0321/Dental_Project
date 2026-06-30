import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../auth/address_search_screen.dart';
import 'operating_hours_page.dart';
import 'product_table_page.dart';
import 'package:dental_nara/utils/logger.dart';

class HospitalInfoPage extends StatefulWidget {
  const HospitalInfoPage({super.key});

  @override
  State<HospitalInfoPage> createState() => _HospitalInfoPageState();
}

class _HospitalInfoPageState extends State<HospitalInfoPage> {
  bool _isLoading = true;
  String? _ykiho;

  // 병원 기본 정보
  String _hospitalName = '';
  String _address = '';
  String _phone = '';
  Map<String, String> _operatingHours = {
    '월': '09:30 ~ 18:30', '화': '09:30 ~ 18:30', '수': '09:30 ~ 18:30',
    '목': '09:30 ~ 18:30', '금': '09:30 ~ 18:30', '토': '09:30 ~ 13:00',
    '일': '정기휴무', 'lunch': '13:00 ~ 14:00', 'holiday': '일요일 및 법정 공휴일 휴무',
  };

  int _priceCount = 0;
  List<Map<String, dynamic>> doctors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      if (email == null) return;

      // 병원 기본 정보 로드
      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho, yadm_nm, addr, operating_hours, telno')
          .eq('email', email)
          .maybeSingle();

      if (hospital == null) return;

      _ykiho = hospital['ykiho'];

      // 비급여 가격 건수 로드
      await _loadPriceCount();

      // 의료진 로드
      final doctorData = await Supabase.instance.client
          .from('doctors')
          .select('id, name, specialty, started_year, started_month')
          .eq('ykiho', _ykiho!)
          .order('created_at', ascending: true);

      setState(() {
        _hospitalName = hospital['yadm_nm'] ?? '';
        _address = hospital['addr'] ?? '';
        _phone = hospital['telno'] ?? '';

        // operating_hours가 DB에 있으면 덮어쓰기
        if (hospital['operating_hours'] != null) {
          final raw = Map<String, dynamic>.from(hospital['operating_hours']);
          _operatingHours = raw.map((k, v) => MapEntry(k, v.toString()));
        }

        doctors = (doctorData as List).map((d) => {
          'id': d['id'].toString(),
          'name': d['name'] ?? '',
          'special': d['specialty'] ?? '',
          'year': d['started_year']?.toString() ?? '',
          'month': d['started_month']?.toString().padLeft(2, '0') ?? '',
        }).toList();
      });
    } catch (e) {
      debugPrint('병원 정보 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadPriceCount() async {
    if (_ykiho == null) return;
    try {
      final res = await Supabase.instance.client
          .from('hospital_prices')
          .select('npay_cd')
          .eq('ykiho', _ykiho!);
      setState(() => _priceCount = (res as List).length);
    } catch (_) {}
  }

  // 주소 수정 후 Supabase 저장 + 로그 기록
  Future<void> _searchAddress() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddressSearchScreen()),
    );

    // 결과값이 있고, 기존 주소와 다르며, ykiho가 있을 때만 괄호 안의 코드가 실행됩니다.
    if (result != null && result is String && result != _address && _ykiho != null) {

      // 1. 변경 전 주소를 안전하게 변수에 담아둡니다. (여기서 선언해야 아래에서 쓸 수 있음)
      String oldAddr = _address;

      // 2. 실제 DB(hospitals 테이블)에 새 주소 업데이트하기
      await Supabase.instance.client
          .from('hospitals')
          .update({'addr': result})
          .eq('ykiho', _ykiho!);

      // 3. 화면 업데이트
      setState(() => _address = result);

      // 4. 모든 작업이 성공하면 로그 기록!
      await SystemLogger.write(
        category: '운영관리',
        detail: '병원 주소 수정',
        targetId: _ykiho,
        oldValue: oldAddr,
        newValue: result,
      );
    }
  }

  // 전화번호 수정
  Future<void> _editPhone() async {
    final ctrl = TextEditingController(text: _phone);
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('전화번호 수정', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
            hintText: '000-0000-0000',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('저장', style: TextStyle(color: Color(0xFF005A9C), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (result != null && result != _phone && _ykiho != null) {
      final old = _phone;
      await Supabase.instance.client
          .from('hospitals')
          .update({'telno': result})
          .eq('ykiho', _ykiho!);
      setState(() => _phone = result);
      await SystemLogger.write(
        category: '운영관리',
        detail: '병원 전화번호 수정',
        targetId: _ykiho,
        oldValue: old,
        newValue: result,
      );
    }
  }

  // 운영시간 수정 후 Supabase 저장
  Future<void> _showHoursSettings() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OperatingHoursPage(
          initialHours: Map<String, String>.from(_operatingHours),
        ),
      ),
    );
    if (result != null && _ykiho != null) {
      await Supabase.instance.client
          .from('hospitals')
          .update({'operating_hours': result})
          .eq('ykiho', _ykiho!);
      setState(() => _operatingHours = Map<String, String>.from(result));
    }
  }

  void _showDeleteDialog(VoidCallback onConfirm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('삭제 확인'),
        content: const Text('정말로 이 항목을 삭제하시겠습니까?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          TextButton(
            onPressed: () { onConfirm(); Navigator.pop(context); },
            child: const Text('삭제', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showProductTable() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductTablePage(ykiho: _ykiho!),
      ),
    );
    if (result == true) await _loadPriceCount();
  }

  // 의료진 추가/수정
  void _showDoctorSheet({int? index}) {
    final existing = index != null ? doctors[index] : null;
    final nameCtrl = TextEditingController(text: existing?['name'] ?? '');
    final specCtrl = TextEditingController(text: existing?['special'] ?? '');
    String year = existing?['year'] ?? '2024';
    String month = existing?['month'] ?? '01';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('의료진 정보 입력', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 15),
              TextField(controller: nameCtrl,
                  decoration: const InputDecoration(labelText: '이름', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              TextField(controller: specCtrl,
                  decoration: const InputDecoration(labelText: '전문 분야', border: OutlineInputBorder())),
              const SizedBox(height: 10),
              ListTile(
                title: const Text('시작 연월'),
                subtitle: Text('$year년 $month월'),
                trailing: const Icon(Icons.calendar_month),
                onTap: () => _showPicker((y, m) => setSheetState(() { year = y; month = m; })),
                shape: RoundedRectangleBorder(
                    side: const BorderSide(color: Colors.grey), borderRadius: BorderRadius.circular(5)),
              ),
              const SizedBox(height: 20),
              // 수정 후
              _saveButton(() => _saveDoctor(
                index: index,
                existingId: existing?['id'],
                name: nameCtrl.text,
                special: specCtrl.text,
                year: year,
                month: month,
              )),
            ],
          ),
        ),
      ),
    );
  }

  // --- 1. 의료진 Supabase 저장 (성공 여부를 반환하도록 수정) ---
  Future<bool> _saveDoctor({
    int? index,
    String? existingId,
    required String name,
    required String special,
    required String year,
    required String month,
  }) async {
    if (_ykiho == null) return false;
    try {
      if (existingId != null) {
        // 수정
        await Supabase.instance.client.from('doctors').update({
          'name': name,
          'specialty': special,
          'started_year': int.tryParse(year),
          'started_month': int.tryParse(month),
        }).eq('id', existingId);

        setState(() {
          doctors[index!] = {'id': existingId, 'name': name, 'special': special, 'year': year, 'month': month};
        });
      } else {
        // 신규 추가
        final res = await Supabase.instance.client.from('doctors').insert({
          'ykiho': _ykiho,
          'name': name,
          'specialty': special,
          'started_year': int.tryParse(year),
          'started_month': int.tryParse(month),
        }).select('id').single();

        setState(() {
          doctors.add({'id': res['id'].toString(), 'name': name, 'special': special, 'year': year, 'month': month});
        });
      }
      return true; // 성공 시 true 반환
    } catch (e) {
      debugPrint('의료진 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장에 실패했습니다: $e'), backgroundColor: Colors.red),
        );
      }
      return false; // 실패 시 false 반환
    }
  }

  // 의료진 삭제
  Future<void> _deleteDoctor(int index) async {
    final id = doctors[index]['id'];
    if (id == null) return;
    try {
      await Supabase.instance.client.from('doctors').delete().eq('id', id);
      setState(() => doctors.removeAt(index));
    } catch (e) {
      debugPrint('의료진 삭제 실패: $e');
    }
  }

  void _showPicker(Function(String, String) onPicked) {
    int selY = 2024, selM = 1;
    showModalBottomSheet(
      context: context,
      builder: (context) => SizedBox(
        height: 250,
        child: Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: () {
                onPicked(selY.toString(), selM.toString().padLeft(2, '0'));
                Navigator.pop(context);
              },
              child: const Text('확인'),
            ),
          ]),
          Expanded(
            child: Row(children: [
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  onSelectedItemChanged: (i) => selY = 1990 + i,
                  children: List.generate(50, (i) => Text('${1990 + i}년')),
                ),
              ),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 32,
                  onSelectedItemChanged: (i) => selM = i + 1,
                  children: List.generate(12, (i) => Text('${i + 1}월')),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  // --- 2. 저장 버튼 로직 수정 (성공했을 때만 창을 닫도록 수정) ---
  Widget _saveButton(Future<bool> Function() onSave) {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: () async {
          // DB 저장이 완료될 때까지 확실하게 기다립니다.
          final success = await onSave();

          // 성공(true)이고, 화면이 살아있을 때만 팝업 창(BottomSheet)을 닫습니다.
          if (success && mounted) {
            Navigator.pop(context);
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF005A9C),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        child: const Text('저장하기', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('병원 정보 관리'), backgroundColor: const Color(0xFF005A9C)),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        child: Column(
          children: [
            _buildSectionHeader('병원 기본 정보', null),
            _buildBaseCard(),
            const SizedBox(height: 25),

            // 비보험 진료 상품
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('비보험 진료 상품',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('총 ${_priceCount}건 등록됨',
                            style: const TextStyle(
                                color: Color(0xFF005A9C), fontSize: 13, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('심평원 표준 항목에 맞춰 가격을 관리하세요.',
                        style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: _showProductTable,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF005A9C),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: const Text('진료 상품 일괄 작성/수정',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 25),
            _buildSectionHeader('의료진 정보', () => _showDoctorSheet()),
            ...doctors.asMap().entries.map((e) => _buildTile(
              e.key,
              e.value['name']!,
              '${e.value['special']}\n시작: ${e.value['year']}.${e.value['month']}',
                  () => _showDoctorSheet(index: e.key),
                  () => _showDeleteDialog(() => _deleteDoctor(e.key)),
            )),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String t, VoidCallback? a) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 15, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(t, style: const TextStyle(fontSize: 14, color: Colors.grey, fontWeight: FontWeight.bold)),
          if (a != null)
            IconButton(icon: const Icon(Icons.add_circle, color: Color(0xFF005A9C)), onPressed: a),
        ],
      ),
    );
  }

  Widget _buildBaseCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 5)],
      ),
      child: Column(
        children: [
          // 병원명 (수정 불가 - 관리자가 승인한 이름)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              const Icon(Icons.business, size: 18, color: Color(0xFF005A9C)),
              const SizedBox(width: 10),
              Text(_hospitalName, style: const TextStyle(fontSize: 14)),
            ]),
          ),
          // 주소 (수정 가능)
          InkWell(
            onTap: _searchAddress,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.location_on, size: 18, color: Color(0xFF005A9C)),
                const SizedBox(width: 10),
                Expanded(child: Text(_address.isNotEmpty ? _address : '주소를 등록해주세요',
                    style: TextStyle(fontSize: 14,
                        color: _address.isEmpty ? Colors.grey : Colors.black))),
                const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
              ]),
            ),
          ),
          // 전화번호 (수정 가능)
          InkWell(
            onTap: _editPhone,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(children: [
                const Icon(Icons.phone, size: 18, color: Color(0xFF005A9C)),
                const SizedBox(width: 10),
                Expanded(child: Text(_phone.isNotEmpty ? _phone : '전화번호를 등록해주세요',
                    style: TextStyle(fontSize: 14,
                        color: _phone.isEmpty ? Colors.grey : Colors.black))),
                const Icon(Icons.edit_outlined, size: 16, color: Colors.grey),
              ]),
            ),
          ),
          const Divider(height: 20),
          // 운영시간
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.access_time, color: Color(0xFF005A9C), size: 20),
            title: const Text('운영 시간 및 상세 안내', style: TextStyle(fontSize: 14)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
            onTap: _showHoursSettings,
          ),
        ],
      ),
    );
  }

  Widget _buildTile(int i, String t, String s, VoidCallback e, VoidCallback d) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(s),
        trailing: Wrap(children: [
          IconButton(icon: const Icon(Icons.edit, size: 20), onPressed: e),
          IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: d),
        ]),
      ),
    );
  }
}