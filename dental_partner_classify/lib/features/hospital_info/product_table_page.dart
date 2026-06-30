import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:dental_nara/utils/logger.dart';

class ProductTablePage extends StatefulWidget {
  final String ykiho;

  const ProductTablePage({
    super.key,
    required this.ykiho,
  });

  @override
  State<ProductTablePage> createState() => _ProductTablePageState();
}

class _ProductTablePageState extends State<ProductTablePage> {
  final _supabase = Supabase.instance.client;

  Map<String, Map<String, dynamic>> _dbPrices = {};
  Map<String, Map<String, TextEditingController>> _controllers = {};
  final Map<String, String?> _templateNpayCds = {};

  bool _isLoading = true;
  bool _isSaving = false;

  static const Map<String, List<String>> _template = {
    '치과 처치·수술료': [
      '인레이(금)', '인레이(레진)', '인레이(도재-세라믹)', '인레이(도재-CAD/CAM 세라믹)',
      '온레이(금)', '온레이(레진)', '온레이(도재-세라믹)', '온레이(도재-CAD/CAM 세라믹)',
      '광중합형 복합레진 충전(우식-1면)', '광중합형 복합레진 충전(우식-2면)',
      '광중합형 복합레진 충전(우식-3면 이상)', '광중합형 복합레진 충전(마모)',
      '광중합형 복합레진 충전(파절 등)',
      '치석제거(1/3악당)', '치석제거(상악)', '치석제거(하악)', '치석제거(전악)',
      '자가치아 이식술',
      '잇몸웃음교정술(잇몸절제)', '잇몸웃음교정술(치조골 삭제)',
    ],
    '치과의 보철료': [
      '치과임플란트(Metal)', '치과임플란트(Gold)', '치과임플란트(PFM)',
      '치과임플란트(PFG)', '치과임플란트(올세라믹)', '치과임플란트(Zirconia)', '치과임플란트(기타)',
      '크라운(Metal)', '크라운(Gold)', '크라운(PFM)',
      '크라운(PFG)', '크라운(올세라믹)', '크라운(Zirconia)', '크라운(기타)',
    ],
  };

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  @override
  void dispose() {
    for (final ctrlMap in _controllers.values) {
      for (final ctrl in ctrlMap.values) {
        ctrl.dispose();
      }
    }
    super.dispose();
  }

  Future<void> _loadPrices() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase
          .from('hospital_prices')
          .select()
          .eq('ykiho', widget.ykiho);

      _dbPrices = {};
      _controllers = {};

      for (final row in List<Map<String, dynamic>>.from(data)) {
        final npaycd = row['npay_cd'] as String;
        _dbPrices[npaycd] = row;
        _controllers[npaycd] = {
          'min': TextEditingController(text: row['min_amt']?.toString() ?? ''),
          'max': TextEditingController(text: row['max_amt']?.toString() ?? ''),
          'desc': TextEditingController(text: row['description'] ?? ''),
        };
      }

      final allItems = _template.values.expand((e) => e).toList();
      await Future.wait(allItems.map(_prefetchNpayCd));
    } catch (e) {
      debugPrint('가격 로드 실패: $e');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _prefetchNpayCd(String itemName) async {
    if (_templateNpayCds.containsKey(itemName)) return;
    try {
      final result = await _supabase
          .from('price_codes')
          .select('npay_cd')
          .ilike('npay_kor_nm', '%$itemName%')
          .limit(1)
          .maybeSingle();
      _templateNpayCds[itemName] = result?['npay_cd'];
    } catch (_) {
      _templateNpayCds[itemName] = null;
    }
  }

  String? _findMatchedNpayCd(String templateName) {
    for (final entry in _dbPrices.entries) {
      final kor = (entry.value['npay_kor_nm'] ?? '').toString();
      if (kor.isEmpty) continue;
      if (kor.contains(templateName) || templateName.contains(kor)) {
        return entry.key;
      }
    }
    return null;
  }

  List<Map<String, dynamic>> _getExtraDbItems() {
    final templateNames = _template.values.expand((e) => e).toList();
    return _dbPrices.values.where((row) {
      final kor = (row['npay_kor_nm'] ?? '').toString();
      return !templateNames.any((name) =>
          kor.contains(name) || name.contains(kor));
    }).toList();
  }

  Future<void> _saveAll() async {
    setState(() => _isSaving = true);

    final List<Map<String, dynamic>> upsertRows = [];
    final List<String> oldSummary = [];
    final List<String> newSummary = [];

    // 1. 심평원 기존 항목 업데이트
    for (final npaycd in _dbPrices.keys) {
      final ctrl = _controllers[npaycd];
      if (ctrl == null) continue;

      final minAmt = int.tryParse(ctrl['min']!.text.replaceAll(',', ''));
      final maxAmt = int.tryParse(ctrl['max']!.text.replaceAll(',', ''));
      final desc = ctrl['desc']!.text;
      final old = _dbPrices[npaycd]!;

      oldSummary.add('${old['npay_kor_nm'] ?? npaycd}: ${old['min_amt'] ?? '-'}~${old['max_amt'] ?? '-'}');
      newSummary.add('${old['npay_kor_nm'] ?? npaycd}: ${minAmt ?? '-'}~${maxAmt ?? '-'}');

      upsertRows.add({
        'ykiho': widget.ykiho,
        'npay_cd': npaycd,
        'min_amt': minAmt,
        'max_amt': maxAmt,
        'description': desc,
        'updated_at': DateTime.now().toIso8601String(),
      });
    }

    // 2. 직접 입력 항목 신규 저장
    for (final entry in _template.entries) {
      for (final itemName in entry.value) {
        if (_findMatchedNpayCd(itemName) != null) continue;

        final ctrl = _controllers[itemName];
        if (ctrl == null) continue;
        if (ctrl['min']!.text.isEmpty && ctrl['max']!.text.isEmpty) continue;

        final minAmt = int.tryParse(ctrl['min']!.text.replaceAll(',', ''));
        final maxAmt = int.tryParse(ctrl['max']!.text.replaceAll(',', ''));

        final npaycd = _templateNpayCds[itemName] ??
            'MANUAL_${itemName.replaceAll(RegExp(r'[^a-zA-Z0-9가-힣]'), '_')}';

        newSummary.add('$itemName: ${minAmt ?? '-'}~${maxAmt ?? '-'} (신규)');

        upsertRows.add({
          'ykiho': widget.ykiho,
          'npay_cd': npaycd,
          'npay_kor_nm': itemName,
          'npay_mdiv_cd_nm': entry.key,
          'min_amt': minAmt,
          'max_amt': maxAmt,
          'description': ctrl['desc']!.text,
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
    }

    if (upsertRows.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('변경된 내용이 없습니다.')),
        );
      }
      setState(() => _isSaving = false);
      return;
    }

    try {
      await _supabase.from('hospital_prices').upsert(upsertRows);

      await SystemLogger.write(
        category: '가격 변경',
        detail: '비급여 진료비 업데이트 (${upsertRows.length}건)',
        targetId: widget.ykiho,
        oldValue: oldSummary.join(' | '),
        newValue: newSummary.join(' | '),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장되었습니다.'), backgroundColor: Colors.green),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint('가격 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('저장 실패: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('비급여 항목 관리'),
        backgroundColor: const Color(0xFF005A9C),
        foregroundColor: Colors.white,
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveAll,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                  )
                : const Text('일괄저장',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
    );
  }

  Widget _buildBody() {
    final extraItems = _getExtraDbItems();

    return ListView(
      padding: const EdgeInsets.only(bottom: 80),
      children: [
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _Legend(color: Colors.blue, label: '심평원 기준가 있음'),
              SizedBox(width: 16),
              _Legend(color: Colors.orange, label: '직접 입력'),
            ],
          ),
        ),
        ..._template.entries.map((e) => _buildSection(e.key, e.value)),

        // 템플릿에 없는 심평원 항목 (있을 경우만 표시)
        if (extraItems.isNotEmpty) ...[
          _buildSectionHeader('기타 심평원 항목', const Color(0xFF607D8B)),
          _buildTableHeader(),
          ...extraItems.map((row) {
            final npaycd = row['npay_cd'] as String;
            final ctrl = _controllers[npaycd]!;
            return _buildTableRow(
              name: (row['npay_kor_nm'] ?? npaycd) as String,
              ctrl: ctrl,
              curAmt: row['cur_amt'],
              isInDb: true,
            );
          }),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  Widget _buildSection(String category, List<String> items) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader(category, const Color(0xFF005A9C)),
        _buildTableHeader(),
        ...items.map((name) {
          final matchedKey = _findMatchedNpayCd(name);
          final isInDb = matchedKey != null;
          final ctrl = isInDb
              ? _controllers[matchedKey]!
              : _controllers.putIfAbsent(name, () => {
                  'min': TextEditingController(),
                  'max': TextEditingController(),
                  'desc': TextEditingController(),
                });
          final curAmt = isInDb ? (_dbPrices[matchedKey]?['cur_amt']) : null;
          return _buildTableRow(
            name: name,
            ctrl: ctrl,
            curAmt: curAmt,
            isInDb: isInDb,
          );
        }),
        const SizedBox(height: 12),
      ],
    );
  }

  Widget _buildSectionHeader(String title, Color color) {
    return Container(
      color: color,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Text(
        title,
        style: const TextStyle(
            color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
      ),
    );
  }

  Widget _buildTableHeader() {
    return Container(
      color: Colors.grey[100],
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          _hCell('항목명', flex: 5),
          _hCell('최소금액(원)', flex: 3),
          _hCell('최대금액(원)', flex: 3),
          _hCell('특이사항', flex: 3),
        ],
      ),
    );
  }

  Widget _hCell(String text, {required int flex}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Text(
          text,
          style: TextStyle(
              fontSize: 11,
              color: Colors.grey[600],
              fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTableRow({
    required String name,
    required Map<String, TextEditingController> ctrl,
    dynamic curAmt,
    required bool isInDb,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isInDb ? Colors.white : Colors.orange[50],
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 항목명
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w500)),
                  if (curAmt != null)
                    Text('심평원 ${_fmt(curAmt)}원',
                        style: const TextStyle(
                            fontSize: 10, color: Colors.blue)),
                  if (!isInDb)
                    const Text('직접 입력',
                        style: TextStyle(fontSize: 10, color: Colors.orange)),
                ],
              ),
            ),
          ),
          // 최소
          Expanded(flex: 3, child: _tField(ctrl['min']!, '최소', isNum: true)),
          // 최대
          Expanded(flex: 3, child: _tField(ctrl['max']!, '최대', isNum: true)),
          // 특이사항
          Expanded(flex: 3, child: _tField(ctrl['desc']!, '특이사항')),
        ],
      ),
    );
  }

  Widget _tField(TextEditingController ctrl, String hint,
      {bool isNum = false}) {
    return Padding(
      padding: const EdgeInsets.all(4),
      child: TextField(
        controller: ctrl,
        keyboardType: isNum ? TextInputType.number : TextInputType.text,
        style: const TextStyle(fontSize: 11),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(fontSize: 10, color: Colors.grey[400]),
          border:
              OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
      ),
    );
  }

  String _fmt(dynamic amt) {
    final n = int.tryParse(amt.toString());
    if (n == null) return amt.toString();
    return n.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final String label;

  const _Legend({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
