import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';

class ReviewPage extends StatefulWidget {
  const ReviewPage({super.key});

  @override
  State<ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<ReviewPage> {
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchReviews();
  }

  // 1. 내 병원의 리뷰 가져오기 (ykiho 기준)
  Future<void> _fetchReviews() async {
    setState(() => _isLoading = true);
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 먼저 내 ykiho 가져오기
      final hospitalData = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho')
          .eq('email', user.email!)
          .maybeSingle();

      if (hospitalData == null) return;
      final ykiho = hospitalData['ykiho'];

      // 리뷰 목록 조회
      final res = await Supabase.instance.client
          .from('reviews')
          .select('*')
          .eq('ykiho', ykiho)
          .order('reviewed_at', ascending: false);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(res);
      });
    } catch (e) {
      debugPrint('리뷰 로드 실패: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // 2. 리뷰 답글 달기 (status 업데이트 포함)
  Future<void> _submitReply(String reviewId, String replyText) async {
    try {
      await Supabase.instance.client.from('reviews').update({
        'reply': replyText,
        'status': '답변 완료',
      }).eq('id', reviewId);

      _fetchReviews(); // 목록 새로고침
    } catch (e) {
      debugPrint('답글 등록 실패: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('리뷰 및 평판 관리')),
      body: RefreshIndicator(
        onRefresh: _fetchReviews,
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : _reviews.isEmpty
            ? const Center(child: Text('등록된 리뷰가 없습니다.'))
            : ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _reviews.length,
                itemBuilder: (context, index) => _buildReviewCard(_reviews[index]),
              ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    bool hasReply = review['reply'] != null && review['reply'].toString().isNotEmpty;
    bool isPending = review['status'] == '답변 대기';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10)]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${review['patient_name']} 환자님', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              _statusTag(isPending),
            ],
          ),
          const SizedBox(height: 8),
          Row(children: List.generate(5, (i) => Icon(Icons.star_rounded, size: 20, color: i < (review['rating'] ?? 0) ? Colors.orange : Colors.grey.shade200))),
          const SizedBox(height: 12),
          Text(review['content'] ?? '', style: const TextStyle(height: 1.5, color: Colors.black87)),
          const SizedBox(height: 16),
          if (hasReply)
            Container(
              padding: const EdgeInsets.all(12),
              width: double.infinity,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('내 답변', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                  const SizedBox(height: 4),
                  Text(review['reply'], style: const TextStyle(fontSize: 14, color: Colors.black54)),
                ],
              ),
            )
          else
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => _showReplyModal(review),
                style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                child: const Text('답글 작성하기'),
              ),
            ),
        ],
      ),
    );
  }

  void _showReplyModal(Map<String, dynamic> review) {
    final controller = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 24, left: 24, right: 24, top: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${review['patient_name']}님께 답글 작성', style: AppStyles.subTitleStyle),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLines: 5,
              decoration: const InputDecoration(hintText: '환자분께 전달할 메시지를 입력해주세요.', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () {
                  if (controller.text.isNotEmpty) {
                    _submitReply(review['id'], controller.text);
                    Navigator.pop(context);
                  }
                },
                style: AppStyles.buttonStyle,
                child: const Text('등록하기'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusTag(bool isPending) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(color: isPending ? Colors.red.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(6)),
    child: Text(isPending ? '답변 대기' : '답변 완료', style: TextStyle(color: isPending ? Colors.red : Colors.green, fontSize: 10, fontWeight: FontWeight.bold)),
  );
}
