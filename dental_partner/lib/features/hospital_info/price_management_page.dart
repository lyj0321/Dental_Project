import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class PriceManagementPage extends StatefulWidget {
  const PriceManagementPage({super.key});

  @override
  State<PriceManagementPage> createState() => _PriceManagementPageState();
}

class _PriceManagementPageState extends State<PriceManagementPage> {
  List<Map<String, dynamic>> _prices = [];
  bool _isLoading = false;
  String? _ykiho;

  @override
  void initState() {
    super.initState();
    _loadPrices();
  }

  Future<void> _loadPrices() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho')
          .eq('email', user.email!)
          .maybeSingle();

      if (hospital != null) {
        _ykiho = hospital['ykiho'];
        final data = await Supabase.instance.client
            .from('hospital_prices')
            .select('*')
            .eq('ykiho', _ykiho!);
        setState(() => _prices = List<Map<String, dynamic>>.from(data));
      }
    } catch (e) {
      debugPrint('가격 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _editPrice(Map<String, dynamic> item) {
    final ctrl = TextEditingController(text: item['cur_amt'].toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${item['npay_kor_nm']} 가격 수정'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '가격(원)', suffixText: '원'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ElevatedButton(
            onPressed: () async {
              await Supabase.instance.client.from('hospital_prices').update({
                'cur_amt': int.parse(ctrl.text),
                'updated_at': DateTime.now().toIso8601String(),
              }).eq('ykiho', _ykiho!).eq('npay_cd', item['npay_cd']);
              Navigator.pop(context);
              _loadPrices();
            }, 
            child: const Text('저장')
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('상품 가격 관리')),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _prices.isEmpty
          ? const Center(child: Text('등록된 가격 정보가 없습니다.'))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _prices.length,
              itemBuilder: (context, index) {
                final item = _prices[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(item['npay_kor_nm'] ?? '상품명 없음', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(item['npay_mdiv_cd_nm'] ?? '분류 없음'),
                    trailing: Text('${item['cur_amt']}원', style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 16)),
                    onTap: () => _editPrice(item),
                  ),
                );
              },
            ),
    );
  }
}
