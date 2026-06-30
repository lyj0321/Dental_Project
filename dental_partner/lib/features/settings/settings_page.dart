import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../auth/login_page.dart';
import '../hospital_info/hospital_info_page.dart';
import '../hospital_info/price_management_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('설정')),
      body: ListView(
        children: [
          // 내 병원 정보 섹션
          Container(
            padding: const EdgeInsets.all(24),
            color: Colors.white,
            child: Row(
              children: [
                const CircleAvatar(radius: 30, backgroundColor: AppColors.background, child: Icon(Icons.business, color: AppColors.primary)),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(user?.email ?? '병원 정보 로드 실패', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    const Text('병원 마스터 계정', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          
          _buildMenuTile(context, Icons.info_outline, '병원 정보 관리', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const HospitalInfoPage()));
          }),
          _buildMenuTile(context, Icons.payments_outlined, '상품 가격 관리', () {
            Navigator.push(context, MaterialPageRoute(builder: (_) => const PriceManagementPage()));
          }),
          _buildMenuTile(context, Icons.notifications_outlined, '알림 설정', () {
            // 알림 설정 이동 (필요 시 구현)
          }),
          
          const Divider(height: 32),
          
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('로그아웃', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
            onTap: () async {
              await Supabase.instance.client.auth.signOut();
              if (context.mounted) {
                Navigator.pushAndRemoveUntil(
                  context, 
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
          
          const SizedBox(height: 40),
          const Center(child: Text('앱 버전 1.0.0+1', style: TextStyle(color: Colors.grey, fontSize: 12))),
        ],
      ),
    );
  }

  Widget _buildMenuTile(BuildContext context, IconData icon, String title, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Colors.grey.shade700),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }
}
