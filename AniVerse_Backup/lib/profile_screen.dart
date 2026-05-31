import 'package:flutter/material.dart';
import 'app_theme.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Profile")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Center(
            child: Column(
              children: [
                CircleAvatar(
                  radius: 50,
                  backgroundColor: AppTheme.sakuraPink,
                  child: Icon(Icons.person, size: 50, color: Colors.white),
                ),
                SizedBox(height: 16),
                Text("OtakuUser_99", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                Text("Free Member", style: TextStyle(color: AppTheme.sakuraPink)),
              ],
            ),
          ),
          const SizedBox(height: 32),
          _buildSettingsTile(Icons.history, "Watch History"),
          _buildSettingsTile(Icons.download, "Downloads"),
          _buildSettingsTile(Icons.notifications_outlined, "Notifications"),
          _buildSettingsTile(Icons.settings_outlined, "App Settings"),
          const Divider(height: 40),
          _buildSettingsTile(Icons.logout, "Logout", textColor: Colors.red),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(IconData icon, String title, {Color? textColor}) {
    return ListTile(
      leading: Icon(icon, color: textColor ?? Colors.white),
      title: Text(title, style: TextStyle(color: textColor ?? Colors.white)),
      trailing: const Icon(Icons.chevron_right, size: 20),
      onTap: () {},
    );
  }
}