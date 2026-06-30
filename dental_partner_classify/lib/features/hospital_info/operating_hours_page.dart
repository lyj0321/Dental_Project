import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

class OperatingHoursPage extends StatefulWidget {
  final Map<String, String> initialHours;
  const OperatingHoursPage({super.key, required this.initialHours});

  @override
  State<OperatingHoursPage> createState() => _OperatingHoursPageState();
}

class _OperatingHoursPageState extends State<OperatingHoursPage> {
  late Map<String, String> _tempHours;

  final List<String> _timeSlots = List.generate(48, (i) {
    final hour = i ~/ 2;
    final minute = (i % 2) * 30;
    return "${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}";
  });

  @override
  void initState() {
    super.initState();
    _tempHours = Map<String, String>.from(widget.initialHours);
  }

  void _showWheelPicker(String day, bool isStart) {
    String currentTime = _tempHours[day] ?? "09:00 ~ 18:00";
    List<String> parts =
    currentTime.contains('~') ? currentTime.split(' ~ ') : ["09:00", "18:00"];

    int initialIdx =
    _timeSlots.indexOf(isStart ? parts[0] : (parts.length > 1 ? parts[1] : "18:00"));
    if (initialIdx == -1) initialIdx = 18;

    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          height: 250,
          color: Colors.white,
          child: Column(
            children: [
              _pickerHeader(context),
              Expanded(
                child: CupertinoPicker(
                  itemExtent: 40,
                  scrollController: FixedExtentScrollController(initialItem: initialIdx),
                  onSelectedItemChanged: (int index) {
                    setState(() {
                      if (isStart) {
                        _tempHours[day] = "${_timeSlots[index]} ~ ${parts[1]}";
                      } else {
                        _tempHours[day] = "${parts[0]} ~ ${_timeSlots[index]}";
                      }
                    });
                  },
                  children: _timeSlots.map((time) => Center(child: Text(time))).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _pickerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      decoration: BoxDecoration(
          color: Colors.grey[100],
          border: const Border(bottom: BorderSide(color: Colors.black12))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("시간 선택", style: TextStyle(fontWeight: FontWeight.bold)),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("완료")),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('운영 시간 설정'),
        backgroundColor: const Color(0xFF005A9C),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _tempHours),
            child: const Text('저장', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          )
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _buildSectionTitle('요일별 진료 시간'),
          ...['월', '화', '수', '목', '금', '토', '일'].map((day) => _buildDayTimeRow(day)),
          const Divider(height: 40),
          _buildSectionTitle('상세 정보 관리'),
          _buildDetailField('lunch', '점심시간'),
          _buildDetailField('holiday', '상세 정보'),
        ],
      ),
    );
  }

  Widget _buildDayTimeRow(String day) {
    String timeData = _tempHours[day] ?? "09:00 ~ 18:00";
    bool isClosed = timeData == "정기휴무";
    List<String> times = timeData.contains('~') ? timeData.split(' ~ ') : [timeData, ""];

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
              width: 35, child: Text(day, style: const TextStyle(fontWeight: FontWeight.bold))),
          if (isClosed)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tempHours[day] = "09:00 ~ 18:00"),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration:
                  BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(8)),
                  child: const Text('정기 휴무',
                      style: TextStyle(
                          color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          else ...[
            Expanded(child: _timeButton(day, times[0], true)),
            const Padding(
                padding: EdgeInsets.symmetric(horizontal: 8), child: Text('~')),
            Expanded(child: _timeButton(day, times.length > 1 ? times[1] : "", false)),
          ],
          const SizedBox(width: 5),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: Colors.grey),
            onSelected: (val) {
              setState(() {
                if (val == '정기휴무')
                  _tempHours[day] = "정기휴무";
                else
                  _tempHours[day] = "09:00 ~ 18:00";
              });
            },
            itemBuilder: (ctx) => [
              const PopupMenuItem(value: '시간설정', child: Text('시간 다시 설정')),
              const PopupMenuItem(value: '정기휴무', child: Text('정기휴무 설정')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _timeButton(String day, String time, bool isStart) {
    return InkWell(
      onTap: () => _showWheelPicker(day, isStart),
      child: Container(
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFF005A9C).withOpacity(0.3)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(time, style: const TextStyle(fontSize: 14, color: Color(0xFF005A9C))),
      ),
    );
  }

  Widget _buildDetailField(String key, String label) {
    TextEditingController ctrl = TextEditingController(text: _tempHours[key]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextField(
        controller: ctrl,
        onChanged: (val) => _tempHours[key] = val,
        maxLines: key == 'holiday' ? 3 : 1,
        decoration: InputDecoration(
          labelText: label,
          hintText: key == 'lunch' ? '예: 13:00 ~ 14:00' : '기타 상세 내용을 입력하세요',
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 15),
    child: Text(title,
        style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF005A9C))),
  );
}