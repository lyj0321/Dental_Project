import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReviewManagementPage extends StatefulWidget {
  const ReviewManagementPage({super.key});

  @override
  State<ReviewManagementPage> createState() => _ReviewManagementPageState();
}

class _ReviewManagementPageState extends State<ReviewManagementPage> {
  String searchPatientId = '';
  List<String> selectedTreatments = [];
  List<Map<String, dynamic>> globalReviews = [];
  bool _loadingReviews = false;

  final List<String> treatments = ['임플란트', '교정', '스케일링', '충치치료', '보철치료'];

  // 신고 사유 목록
  final List<String> reportReasons = [
    '허위 사실 포함',
    '욕설 / 비방',
    '광고성 내용',
    '개인정보 포함',
    '기타',
  ];

  List<Map<String, dynamic>> get filteredReviews {
    return globalReviews.where((r) {
      final matchId = searchPatientId.isEmpty ||
          (r['patient_id'] ?? '').toLowerCase().contains(searchPatientId.toLowerCase());
      final matchTreat =
          selectedTreatments.isEmpty || selectedTreatments.contains(r['treatment']);
      return matchId && matchTreat;
    }).toList();
  }

  double get hospitalAvg => globalReviews.isEmpty
      ? 0.0
      : globalReviews.map((e) => (e['rating'] as int? ?? 0)).reduce((a, b) => a + b) /
      globalReviews.length;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() => _loadingReviews = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;
      final hospital = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho')
          .eq('email', email ?? '')
          .maybeSingle();
      if (hospital == null) return;

      final data = await Supabase.instance.client
          .from('reviews')
          .select('id, patient_id, patient_name, treatment, rating, content, reply, status, reviewed_at, is_reported, report_reason')
          .eq('ykiho', hospital['ykiho'])
          .order('reviewed_at', ascending: false);

      setState(() {
        globalReviews = (data as List).map((r) => {
          'id': r['id']?.toString() ?? '',
          'patient_id': r['patient_id'] ?? '',
          'name': r['patient_name'] ?? '',
          'treatment': r['treatment'] ?? '',
          'rating': r['rating'] ?? 0,
          'content': r['content'] ?? '',
          'reply': r['reply'] ?? '',
          'status': r['status'] ?? '답변 대기',
          'date': r['reviewed_at']?.toString().substring(0, 10) ?? '',
          'is_reported': r['is_reported'] ?? false,
          'report_reason': r['report_reason'] ?? '',
        }).toList();
      });
    } catch (e) {
      debugPrint('리뷰 로드 실패: $e');
    } finally {
      setState(() => _loadingReviews = false);
    }
  }

  // 답글 Supabase 저장
  Future<void> _saveReply(Map<String, dynamic> review, String replyText) async {
    try {
      await Supabase.instance.client.from('reviews').update({
        'reply': replyText,
        'status': '답변 완료',
      }).eq('id', review['id']);

      setState(() {
        review['reply'] = replyText;
        review['status'] = '답변 완료';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('답글이 저장되었습니다.')),
        );
      }
    } catch (e) {
      debugPrint('답글 저장 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('저장에 실패했습니다. 다시 시도해주세요.')),
        );
      }
    }
  }

  // 신고 Supabase 저장
  Future<void> _saveReport(Map<String, dynamic> review, String reason) async {
    try {
      await Supabase.instance.client.from('reviews').update({
        'is_reported': true,
        'report_reason': reason,
        'reported_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', review['id']);

      setState(() {
        review['is_reported'] = true;
        review['report_reason'] = reason;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('신고가 접수되었습니다. 검토 후 처리됩니다.')),
        );
      }
    } catch (e) {
      debugPrint('신고 저장 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('리뷰 관리',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.black),
            onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF005A9C)),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildTopSummary(),
          if (selectedTreatments.isNotEmpty || searchPatientId.isNotEmpty)
            _buildActiveFilterChips(),
          Expanded(
            child: _loadingReviews
                ? const Center(child: CircularProgressIndicator())
                : filteredReviews.isEmpty
                ? const Center(child: Text('해당하는 리뷰가 없습니다.'))
                : RefreshIndicator(
              onRefresh: _loadReviews,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: filteredReviews.length,
                itemBuilder: (context, index) =>
                    _buildReviewItem(filteredReviews[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSummary() {
    return Container(
      padding: const EdgeInsets.all(20),
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20))),
      child: Center(
        child: Column(children: [
          Text('병원 전체 평점', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          const SizedBox(height: 4),
          Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.star_rounded, color: Colors.orange, size: 24),
            const SizedBox(width: 6),
            Text(hospitalAvg.toStringAsFixed(1),
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
          ]),
        ]),
      ),
    );
  }

  Widget _buildActiveFilterChips() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Wrap(
        spacing: 8,
        children: [
          ...selectedTreatments.map(
                  (t) => _activeChip(t, () => setState(() => selectedTreatments.remove(t)))),
          if (searchPatientId.isNotEmpty)
            _activeChip('ID: $searchPatientId', () => setState(() => searchPatientId = '')),
        ],
      ),
    );
  }

  Widget _activeChip(String label, VoidCallback onDelete) => InputChip(
      label: Text(label, style: const TextStyle(fontSize: 11)),
      onDeleted: onDelete,
      deleteIconColor: Colors.red,
      backgroundColor: Colors.blue[50]);

  Widget _buildReviewItem(Map<String, dynamic> review) {
    bool isPending = review['status'] == '답변 대기';
    bool isReported = review['is_reported'] == true;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: isReported ? Border.all(color: Colors.red.shade200) : null,
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 상단: 환자 정보 + 상태 태그
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('${review['name']} (${review['patient_id']})',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(review['date'],
                    style: TextStyle(color: Colors.grey[500], fontSize: 11)),
              ]),
              Row(children: [
                if (isReported)
                  Container(
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: Colors.red[50], borderRadius: BorderRadius.circular(6)),
                    child: const Text('신고됨',
                        style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                _statusTag(isPending),
              ]),
            ],
          ),
          const SizedBox(height: 12),

          // 시술 종류
          _infoTag(review['treatment'], Colors.grey[100]!, Colors.grey[700]!),
          const SizedBox(height: 12),

          // 별점
          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded,
              size: 18,
              color: i < (review['rating'] as int? ?? 0) ? Colors.orange : Colors.grey[200]))),
          const SizedBox(height: 10),

          // 리뷰 내용
          Text(review['content'],
              style: const TextStyle(height: 1.4, fontSize: 14, color: Colors.black87)),

          // 신고 사유 표시
          if (isReported && (review['report_reason'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                  color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.flag, color: Colors.red, size: 14),
                const SizedBox(width: 6),
                Text('신고 사유: ${review['report_reason']}',
                    style: const TextStyle(color: Colors.red, fontSize: 12)),
              ]),
            ),
          ],

          // 기존 답글
          if ((review['reply'] ?? '').isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.grey[200]!)),
              child: Text('답변: ${review['reply']}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54)),
            ),
          ],

          const SizedBox(height: 12),

          // 하단 버튼: 답글달기 + 신고
          Row(children: [
            if (isPending)
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: ElevatedButton(
                    onPressed: () => _showReplyModal(review),
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('답글 달기',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ),
                ),
              )
            else
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: OutlinedButton(
                    onPressed: () => _showReplyModal(review),
                    style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF005A9C)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text('답글 수정',
                        style: TextStyle(color: Color(0xFF005A9C), fontSize: 13)),
                  ),
                ),
              ),
            const SizedBox(width: 8),
            // 신고 버튼
            SizedBox(
              height: 38,
              child: OutlinedButton.icon(
                onPressed: isReported ? null : () => _showReportDialog(review),
                style: OutlinedButton.styleFrom(
                    side: BorderSide(color: isReported ? Colors.grey[300]! : Colors.red[300]!),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                icon: Icon(Icons.flag_outlined,
                    size: 14, color: isReported ? Colors.grey : Colors.red),
                label: Text(isReported ? '신고됨' : '신고',
                    style: TextStyle(
                        color: isReported ? Colors.grey : Colors.red, fontSize: 13)),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // 답글 모달
  void _showReplyModal(Map<String, dynamic> review) {
    final controller = TextEditingController(text: review['reply'] ?? '');
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            left: 20, right: 20, top: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${review['name']}님께 답글 작성',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 15),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: InputDecoration(
                  hintText: '답변을 입력해주세요.',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () async {
                  if (controller.text.trim().isEmpty) return;
                  Navigator.pop(context);
                  await _saveReply(review, controller.text.trim());
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF005A9C),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('등록하기',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  // 신고 다이얼로그
  void _showReportDialog(Map<String, dynamic> review) {
    String? selectedReason;
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('리뷰 신고', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('신고 사유를 선택해주세요.',
                  style: TextStyle(color: Colors.grey, fontSize: 13)),
              const SizedBox(height: 12),
              ...reportReasons.map((reason) => RadioListTile<String>(
                title: Text(reason, style: const TextStyle(fontSize: 14)),
                value: reason,
                groupValue: selectedReason,
                activeColor: const Color(0xFF005A9C),
                contentPadding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                onChanged: (val) => setDialogState(() => selectedReason = val),
              )),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소')),
            TextButton(
              onPressed: selectedReason == null
                  ? null
                  : () async {
                Navigator.pop(context);
                await _saveReport(review, selectedReason!);
              },
              child: const Text('신고하기', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _showFilterDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setMState) => Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              left: 24, right: 24, top: 24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('리뷰 필터',
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                    TextButton(
                        onPressed: () {
                          setMState(() { selectedTreatments = []; searchPatientId = ''; });
                          setState(() {});
                        },
                        child: const Text('초기화', style: TextStyle(color: Colors.red))),
                  ],
                ),
                const SizedBox(height: 20),
                TextField(
                  decoration: InputDecoration(
                      hintText: '환자 ID로 검색',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
                  onChanged: (val) {
                    setMState(() => searchPatientId = val);
                    setState(() => searchPatientId = val);
                  },
                ),
                const SizedBox(height: 20),
                const Text('시술 종류 (중복 가능)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 8),
                Wrap(
                    spacing: 8,
                    children: treatments.map((t) => FilterChip(
                      label: Text(t),
                      selected: selectedTreatments.contains(t),
                      onSelected: (val) {
                        setMState(() => val
                            ? selectedTreatments.add(t)
                            : selectedTreatments.remove(t));
                        setState(() {});
                      },
                    )).toList()),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF005A9C),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('필터 적용',
                        style: TextStyle(color: Colors.white, fontSize: 16)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statusTag(bool isPending) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
          color: isPending ? Colors.red[50] : Colors.green[50],
          borderRadius: BorderRadius.circular(6)),
      child: Text(isPending ? '답변 대기' : '답변 완료',
          style: TextStyle(
              color: isPending ? Colors.red : Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.bold)));

  Widget _infoTag(String text, Color bg, Color textCol) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(color: textCol, fontSize: 11, fontWeight: FontWeight.w600)));
}