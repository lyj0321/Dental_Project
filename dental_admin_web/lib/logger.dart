import 'package:supabase_flutter/supabase_flutter.dart';

class SystemLogger {
  static final _supabase = Supabase.instance.client;

  static Future<void> write({
    required String category,
    required String detail,
    String? targetId,
    String? oldValue,
    String? newValue,
    String? actorEmail,
  }) async {
    try {
      await _supabase.from('system_logs').insert({
        'category': category,
        'actor_email': actorEmail ?? _supabase.auth.currentUser?.email ?? 'System',
        'target_id': targetId,
        'action_detail': detail,
        'old_value': oldValue,
        'new_value': newValue,
      });
    } catch (e) {
      print('로그 기록 실패: $e');
    }
  }
}