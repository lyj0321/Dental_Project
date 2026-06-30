import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ReservationPage extends StatefulWidget {
  const ReservationPage({super.key});

  @override
  State<ReservationPage> createState() => _ReservationPageState();
}

class _ReservationPageState extends State<ReservationPage> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _showHistoryDetail = false;
  Map<String, dynamic> _historyDetailData = {};

  Map<String, List<Map<String, dynamic>>> globalEvents = {};
  bool _loadingReservations = false;
  String _ykiho = '';

  @override
  void initState() {
    super.initState();
    _loadReservations();
  }

  // 'x월 x일 오전' 형식에서 날짜 추출
  DateTime? _parseDateFromSlot(String? slot) {
    if (slot == null) return null;
    final match = RegExp(r'(\d+)월\s*(\d+)일').firstMatch(slot);
    if (match == null) return null;
    final month = int.parse(match.group(1)!);
    final day = int.parse(match.group(2)!);
    return DateTime(DateTime.now().year, month, day);
  }

  Future<void> _loadReservations() async {
    setState(() => _loadingReservations = true);
    try {
      final email = Supabase.instance.client.auth.currentUser?.email;

      final hospitalData = await Supabase.instance.client
          .from('hospitals')
          .select('ykiho')
          .eq('email', email ?? '')
          .maybeSingle();

      if (hospitalData == null) return;
      final ykiho = hospitalData['ykiho'] as String;
      _ykiho = ykiho;

      final data = await Supabase.instance.client
          .from('reservations')
          .select('*')
          .eq('ykiho', ykiho)
          .order('created_at', ascending: true);

      final Map<String, List<Map<String, dynamic>>> events = {};
      for (final r in data as List) {
        final reservedAt = r['reserved_at'];
        final preferredSlot = r['preferred_time_slot'] as String?;

        String dateKey;
        String timeDisplay;

        if (reservedAt != null) {
          final dt = DateTime.parse(reservedAt).toLocal();
          dateKey = DateFormat('yyyy-MM-dd').format(dt);
          timeDisplay = DateFormat('HH:mm').format(dt);
        } else {
          final parsed = _parseDateFromSlot(preferredSlot);
          dateKey = parsed != null
              ? DateFormat('yyyy-MM-dd').format(parsed)
              : DateFormat('yyyy-MM-dd').format(DateTime.now());
          timeDisplay = preferredSlot ?? '시간 미확정';
        }

        events.putIfAbsent(dateKey, () => []);
        events[dateKey]!.add({
          'id': r['id'],
          'name': r['patient_name'],
          'time': timeDisplay,
          'count': r['visit_count'] ?? 1,
          'desc': r['description'] ?? '',
          'isDone': r['status'] == 'done',
          'isCancelled': r['status'] == 'cancelled',
          'isPending': r['status'] == 'pending' && reservedAt == null,
          'cancelReason': r['cancel_reason'] ?? '',
          'isRead': r['is_read'] ?? false,
          'preferredSlot': preferredSlot ?? '',
          'patientProfile': r['patient_profile_json'],
          'patientId': r['patient_id']?.toString(),
          'history': [],
        });
      }
      setState(() => globalEvents = events);
    } catch (e) {
      debugPrint('예약 로드 실패: $e');
    } finally {
      setState(() => _loadingReservations = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final selectedDate = DateTime(_selectedDay.year, _selectedDay.month, _selectedDay.day);
    final isSelectedDayPast = selectedDate.isBefore(today);
    String dateKey = DateFormat('yyyy-MM-dd').format(_selectedDay);
    List<Map<String, dynamic>> dailyPatients = globalEvents[dateKey] ?? [];

    return Scaffold(
      appBar: AppBar(
          title: const Text('예약 및 진료 관리'),
          backgroundColor: const Color(0xFF005A9C),
          elevation: 0),
      body: Column(
        children: [
          _buildTableCalendar(),
          const Divider(height: 1),
          if (!_loadingReservations)
            Container(
              color: Colors.grey[50],
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(DateFormat('M월 d일').format(_selectedDay),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(width: 8),
                  Text(
                    '총 ${dailyPatients.length}명',
                    style: const TextStyle(
                        color: Color(0xFF005A9C),
                        fontWeight: FontWeight.bold,
                        fontSize: 14),
                  ),
                  const SizedBox(width: 6),
                  () {
                    final cancelledCount =
                        dailyPatients.where((e) => e['isCancelled'] == true).length;
                    return cancelledCount > 0
                        ? Text('(취소 $cancelledCount명)',
                            style: const TextStyle(color: Colors.red, fontSize: 12))
                        : const SizedBox.shrink();
                  }(),
                ],
              ),
            ),
          Expanded(
            child: _loadingReservations
                ? const Center(child: CircularProgressIndicator())
                : dailyPatients.isEmpty
                    ? const Center(child: Text('예약이 없습니다.'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(10),
                        itemCount: dailyPatients.length,
                        itemBuilder: (context, index) =>
                            _buildPatientTile(dailyPatients[index], index, isSelectedDayPast),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildTableCalendar() {
    DateTime firstDay = DateTime(_focusedDay.year, _focusedDay.month, 1);
    int firstWeekday = firstDay.weekday;
    int daysInMonth = DateTime(_focusedDay.year, _focusedDay.month + 1, 0).day;

    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(10),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() =>
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month - 1))),
          Text(DateFormat('yyyy년 MM월').format(_focusedDay),
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() =>
              _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + 1))),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['월', '화', '수', '목', '금', '토', '일']
              .map((d) => Expanded(
              child: Center(
                  child: Text(d,
                      style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)))))
              .toList(),
        ),
      ),
      Container(
        decoration: BoxDecoration(
            border: Border(
                top: BorderSide(color: Colors.grey[300]!),
                left: BorderSide(color: Colors.grey[300]!))),
        child: GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7, childAspectRatio: 1.0),
          itemCount: ((firstWeekday - 1 + daysInMonth) / 7).ceil() * 7,
          itemBuilder: (context, index) {
            int dayNum = index - (firstWeekday - 1) + 1;
            if (dayNum < 1 || dayNum > daysInMonth) {
              return Container(
                  decoration: BoxDecoration(
                      border: Border(
                          right: BorderSide(color: Colors.grey[300]!),
                          bottom: BorderSide(color: Colors.grey[300]!))));
            }

            DateTime day = DateTime(_focusedDay.year, _focusedDay.month, dayNum);
            final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
            final isPastDay = day.isBefore(today);
            String key = DateFormat('yyyy-MM-dd').format(day);
            int activeCount = globalEvents[key]?.length ?? 0;
            bool hasUnread = !isPastDay &&
                (globalEvents[key]?.any((e) => e['isRead'] == false) ?? false);
            bool isSelected =
                _selectedDay.day == day.day && _selectedDay.month == day.month;
            bool isToday = DateTime.now().day == day.day &&
                DateTime.now().month == day.month &&
                DateTime.now().year == day.year;

            return GestureDetector(
              onTap: () => setState(() => _selectedDay = day),
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected
                      ? Colors.blue[100]
                      : (isToday ? Colors.blue[50] : Colors.white),
                  border: Border(
                      right: BorderSide(color: Colors.grey[300]!),
                      bottom: BorderSide(color: Colors.grey[300]!)),
                ),
                padding: const EdgeInsets.all(6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('$dayNum',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: isToday || isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isToday
                                    ? const Color(0xFF005A9C)
                                    : Colors.black)),
                        if (hasUnread)
                          Container(
                              width: 6,
                              height: 6,
                              decoration: const BoxDecoration(
                                  color: Colors.green, shape: BoxShape.circle)),
                      ],
                    ),
                    const Spacer(),
                    if (activeCount > 0)
                      Center(
                          child: Text('$activeCount명',
                              style: const TextStyle(
                                  fontSize: 10,
                                  color: Color(0xFF005A9C),
                                  fontWeight: FontWeight.bold))),
                  ],
                ),
              ),
            );
          },
        ),
      )
    ]);
  }

  Widget _buildPatientTile(Map<String, dynamic> p, int index, bool isPast) {
    bool isCancelled = p['isCancelled'];
    bool isPending = p['isPending'] ?? false;
    return Opacity(
      opacity: (p['isDone'] || isCancelled || isPast) ? 0.4 : 1.0,
      child: Card(
        child: ListTile(
          onTap: () async {
            setState(() {
              p['isRead'] = true;
              _showHistoryDetail = false;
            });
            if (p['id'] != null && p['id'].toString().isNotEmpty) {
              try {
                await Supabase.instance.client
                    .from('reservations')
                    .update({'is_read': true})
                    .eq('id', p['id']);
              } catch (e) {
                debugPrint('is_read 업데이트 실패: $e');
              }
            }
            _showDetail(p, index);
          },
          leading: isPending
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                      decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4)),
                      child: const Text('확정 대기',
                          style: TextStyle(
                              fontSize: 9,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                )
              : Text(p['time'],
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
          title: Row(children: [
            Text(p['name'],
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    decoration: isCancelled ? TextDecoration.lineThrough : null,
                    color: isCancelled ? Colors.red : Colors.black)),
            const SizedBox(width: 8),
            _badge('${p['count']}번째 방문'),
            if (!p['isRead'])
              Container(
                  margin: const EdgeInsets.only(left: 5),
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle)),
            if (isCancelled)
              const Text(' [취소됨]',
                  style: TextStyle(color: Colors.red, fontSize: 10, fontWeight: FontWeight.bold)),
          ]),
          subtitle: isPending && p['preferredSlot'].toString().isNotEmpty
              ? Text('요청: ${p['preferredSlot']}',
                  style: const TextStyle(color: Colors.orange, fontSize: 12))
              : Text(p['desc']),
          trailing: const Icon(Icons.chevron_right),
        ),
      ),
    );
  }

  Future<List<Map<String, dynamic>>> _loadHistory(String? patientId) async {
    if (patientId == null || _ykiho.isEmpty) return [];
    try {
      final reservations = await Supabase.instance.client
          .from('reservations')
          .select('id')
          .eq('patient_id', patientId)
          .eq('ykiho', _ykiho);

      final ids = (reservations as List).map((r) => r['id'] as String).toList();
      if (ids.isEmpty) return [];

      final visits = await Supabase.instance.client
          .from('patient_visits')
          .select('visit_date, treatment_type, ai_result, survey_result')
          .inFilter('reservation_id', ids)
          .order('visit_date', ascending: false);

      return (visits as List).map<Map<String, dynamic>>((v) => {
        'date': v['visit_date']?.toString() ?? '',
        'type': v['treatment_type'] ?? '',
        'ai': v['ai_result'] ?? '',
        'survey': v['survey_result'] ?? '',
      }).toList();
    } catch (e) {
      debugPrint('히스토리 로드 실패: $e');
      return [];
    }
  }

  void _showDetail(Map<String, dynamic> p, int index) {
    final historyFuture = _loadHistory(p['patientId']);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => Container(
          height: MediaQuery.of(context).size.height * 0.85,
          padding: const EdgeInsets.all(25),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              if (_showHistoryDetail)
                IconButton(
                    icon: const Icon(Icons.arrow_back_ios, size: 20),
                    onPressed: () => setSheetState(() => _showHistoryDetail = false)),
              Text(_showHistoryDetail ? '과거 기록 상세' : '${p['name']} 상세 정보',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const Spacer(),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const Divider(height: 30),
            Expanded(
              child: SingleChildScrollView(
                child: _showHistoryDetail
                    ? _buildPastContent()
                    : FutureBuilder<List<Map<String, dynamic>>>(
                        future: historyFuture,
                        builder: (ctx, snapshot) {
                          final history = snapshot.data ?? [];
                          return _buildCurrContent(p, setSheetState, history);
                        },
                      ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildCurrContent(Map<String, dynamic> p, StateSetter setSheetState, List history) {
    List hists = history;
    bool isPending = p['isPending'] ?? false;

    // patient_profile_json 파싱
    String patientInfo = '정보 없음';
    final profile = p['patientProfile'];
    if (profile != null && profile is Map) {
      final parts = <String>[];
      if (profile['gender'] != null) parts.add('성별: ${profile['gender']}');
      if (profile['birth_year'] != null) parts.add('나이: ${profile['birth_year']}세');
      if (profile['email'] != null) parts.add('이메일: ${profile['email']}');
      if ((profile['symptoms_default'] ?? '').toString().isNotEmpty)
        parts.add('주요 증상: ${profile['symptoms_default']}');
      if ((profile['history_default'] ?? '').toString().isNotEmpty)
        parts.add('병력: ${profile['history_default']}');
      if (parts.isNotEmpty) patientInfo = parts.join('\n');
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoItem('환자 기본 정보', patientInfo),
      if (p['preferredSlot'].toString().isNotEmpty) ...[
        const SizedBox(height: 20),
        _infoItem('요청 시간대', p['preferredSlot'],
            color: isPending ? Colors.orange : const Color(0xFF005A9C)),
      ],
      const SizedBox(height: 20),
      if (hists.isNotEmpty) _aiBox('현재 AI 분석 결과', hists.first['ai'] ?? ''),
      const SizedBox(height: 30),
      const Text('진료 히스토리 (클릭 시 상세 확인)',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
      if (hists.isEmpty)
        const Padding(
          padding: EdgeInsets.only(top: 12),
          child: Text('아직 등록된 진료 내역이 없습니다.', style: TextStyle(color: Colors.grey)),
        )
      else
        ...hists.map((h) => Card(
          child: ListTile(
            title: Text(h['date'] ?? ''),
            subtitle: Text(h['type'] ?? ''),
            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
            onTap: () => setSheetState(() {
              _showHistoryDetail = true;
              _historyDetailData = h;
            }),
          ),
        )),
      if (p['isCancelled']) ...[
        const SizedBox(height: 20),
        _infoItem('⚠️ 예약 취소 사유', p['cancelReason'], color: Colors.red),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _restoreReservation(p),
            child: const Text('취소 철회 (예약 복원)'),
          ),
        ),
      ],
      const SizedBox(height: 30),
      if (isPending) ...[
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: () => _confirmReservation(p),
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF005A9C)),
            child: const Text('예약 확정 (시간 지정)', style: TextStyle(color: Colors.white)),
          ),
        ),
        const SizedBox(height: 10),
      ],
      if (!p['isDone'] && !p['isCancelled'])
        SizedBox(
          width: double.infinity,
          height: 50,
          child: OutlinedButton(
            onPressed: () => _cancelDlg(p),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('예약 취소'),
          ),
        ),
    ]);
  }

  Widget _buildPastContent() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _infoItem('진료일', _historyDetailData['date'] ?? ''),
      const SizedBox(height: 20),
      _infoItem('당시 설문', _historyDetailData['survey'] ?? ''),
      const SizedBox(height: 20),
      _aiBox('당시 AI 분석 결과', _historyDetailData['ai'] ?? ''),
    ]);
  }

  Widget _badge(String t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration:
      BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(4)),
      child: Text(t, style: const TextStyle(fontSize: 10, color: Colors.black54)));

  Widget _infoItem(String t, String c, {Color color = const Color(0xFF005A9C)}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: TextStyle(fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 8),
        Text(c, style: const TextStyle(height: 1.5)),
      ]);

  Widget _aiBox(String t, String c) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration:
      BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(12)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(t, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
        const SizedBox(height: 5),
        Text(c, style: const TextStyle(fontSize: 13)),
      ]));

  void _cancelDlg(Map<String, dynamic> p) {
    final c = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('예약 취소 사유'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(hintText: '취소 사유를 입력하세요'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('닫기')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _updateCancelStatus(p, cancelled: true, reason: c.text);
              if (mounted) Navigator.pop(context);
            },
            child: const Text('확인', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  List<String> _allTimes() {
    final times = <String>[];
    for (int h = 9; h <= 20; h++) {
      times.add('${h.toString().padLeft(2, '0')}:00');
      if (h < 20) times.add('${h.toString().padLeft(2, '0')}:30');
    }
    return times;
  }

  Future<void> _confirmReservation(Map<String, dynamic> p) async {
    final parsed = _parseDateFromSlot(p['preferredSlot']);
    if (parsed == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('날짜를 파싱할 수 없습니다. 요청 시간대를 확인해주세요.')),
        );
      }
      return;
    }

    final slotTimes = _allTimes();
    String? selectedTime;

    final confirmedTime = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.85,
          builder: (_, scrollController) => Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('진료 시간 선택',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(
                  '요청 시간대: ${p['preferredSlot']}',
                  style: const TextStyle(fontSize: 13, color: Colors.orange),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 4,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: 2.2,
                    ),
                    itemCount: slotTimes.length,
                    itemBuilder: (_, i) {
                      final t = slotTimes[i];
                      final isSelected = selectedTime == t;
                      return GestureDetector(
                        onTap: () => setModalState(() => selectedTime = t),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF005A9C) : Colors.grey[100],
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isSelected ? const Color(0xFF005A9C) : Colors.grey[300]!,
                            ),
                          ),
                          child: Text(
                            t,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: isSelected ? Colors.white : Colors.black87,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: selectedTime == null ? null : () => Navigator.pop(ctx, selectedTime),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF005A9C),
                      disabledBackgroundColor: Colors.grey[300],
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      selectedTime == null ? '시간을 선택해주세요' : '$selectedTime 으로 확정',
                      style: const TextStyle(color: Colors.white, fontSize: 15),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (confirmedTime == null) return;

    final parts = confirmedTime.split(':');
    final confirmedAt = DateTime(
        parsed.year, parsed.month, parsed.day,
        int.parse(parts[0]), int.parse(parts[1]));

    try {
      await Supabase.instance.client.from('reservations').update({
        'reserved_at': confirmedAt.toUtc().toIso8601String(),
        'status': 'confirmed',
      }).eq('id', p['id']);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$confirmedTime 으로 예약이 확정되었습니다.')),
        );
      }
      await _loadReservations();
    } catch (e) {
      debugPrint('예약 확정 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('확정 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restoreReservation(Map<String, dynamic> p) async {
    await _updateCancelStatus(p, cancelled: false);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _updateCancelStatus(
    Map<String, dynamic> p, {
    required bool cancelled,
    String? reason,
  }) async {
    try {
      await Supabase.instance.client.from('reservations').update({
        'status': cancelled ? 'cancelled' : 'pending',
        'cancel_reason': cancelled ? (reason ?? '') : '',
      }).eq('id', p['id']);

      setState(() {
        p['isCancelled'] = cancelled;
        p['cancelReason'] = cancelled ? (reason ?? '') : '';
      });
    } catch (e) {
      debugPrint('예약 상태 변경 실패: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('변경 실패: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }
}
