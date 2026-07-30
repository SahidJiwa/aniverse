// settings_screen.dart — AniVerse Settings
// Full-page settings screen dengan 4 section + connect dari gear icon
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aniverse/app_theme.dart';
import 'auth_service.dart';
import 'user_model.dart';
import 'widgets/auth_modal.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {

  // ── Notification toggles ──────────────────────────────────────────────────
  bool _notifEpisodeBaru    = true;
  bool _notifRekomendasi    = true;
  bool _notifChallenge      = true;
  bool _notifPromo          = false;

  // ── Tampilan toggles ──────────────────────────────────────────────────────
  bool _autoplay            = true;
  bool _skipIntro           = true;
  String _kualitas          = 'Auto';
  String _bahasa            = 'Indonesia';

  // ── Header animation ──────────────────────────────────────────────────────
  late AnimationController _auraCtrl;

  @override
  void initState() {
    super.initState();
    _auraCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _notifEpisodeBaru = p.getBool('notif_episode') ?? true;
      _notifRekomendasi = p.getBool('notif_rekom')   ?? true;
      _notifChallenge   = p.getBool('notif_challenge')?? true;
      _notifPromo       = p.getBool('notif_promo')   ?? false;
      _autoplay         = p.getBool('autoplay')       ?? true;
      _skipIntro        = p.getBool('skip_intro')     ?? true;
      _kualitas         = p.getString('kualitas')     ?? 'Auto';
      _bahasa           = p.getString('bahasa')       ?? 'Indonesia';
    });
  }

  Future<void> _saveBool(String key, bool val) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(key, val);
  }

  Future<void> _saveString(String key, String val) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key, val);
  }

  @override
  void dispose() {
    _auraCtrl.dispose();
    super.dispose();
  }

  // ── Pilih kualitas ────────────────────────────────────────────────────────
  void _pickKualitas() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Kualitas Video',
        options: const ['Auto', '1080p', '720p', '480p', '360p'],
        selected: _kualitas,
        onSelect: (v) {
          setState(() => _kualitas = v);
          _saveString('kualitas', v);
        },
      ),
    );
  }

  // ── Pilih bahasa ─────────────────────────────────────────────────────────
  void _pickBahasa() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _PickerSheet(
        title: 'Bahasa Antarmuka',
        options: const ['Indonesia', 'English', '日本語'],
        selected: _bahasa,
        onSelect: (v) {
          setState(() => _bahasa = v);
          _saveString('bahasa', v);
        },
      ),
    );
  }

  // ── Konfirmasi keluar ─────────────────────────────────────────────────────
  void _showLogoutDialog() {
    HapticFeedback.mediumImpact();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Keluar dari AniVerse?',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        content: Text(
          'Progres dan koleksi kamu tetap tersimpan.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Batal',
              style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Keluar',
              style: TextStyle(color: AppTheme.highlight, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final safeTop = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Stack(
        children: [
          // ── Ambient glow background ────────────────────────────────────
          _SettingsAtmosphere(auraCtrl: _auraCtrl),

          // ── Content ───────────────────────────────────────────────────
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Header
              SliverToBoxAdapter(
                child: _buildHeader(safeTop),
              ),

              // Sections
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: Column(
                    children: [

                      // ── AKUN ──────────────────────────────────────────
                      _SectionCard(
                        icon: Icons.person_rounded,
                        label: 'Akun',
                        accentColor: AppTheme.highlight,
                        children: [
                          // Status login Google — tile ini otomatis berubah
                          // tampilan begitu AuthService.currentUserNotifier
                          // berubah (login/logout dari mana pun di app).
                          ValueListenableBuilder<UserModel?>(
                            valueListenable: AuthService.currentUserNotifier,
                            builder: (context, user, _) {
                              if (user == null) {
                                return _SettingsTile(
                                  icon: Icons.login_rounded,
                                  label: 'Masuk dengan Google',
                                  subtitle:
                                      'Simpan progress & sinkron antar device',
                                  onTap: () =>
                                      AuthModal.showGoogleSignIn(context),
                                  trailing: const Icon(
                                      Icons.chevron_right_rounded,
                                      color: AppTheme.textSecondary,
                                      size: 20),
                                );
                              }
                              return _SettingsTile(
                                icon: Icons.verified_user_rounded,
                                label: user.name,
                                subtitle:
                                    '${user.email} • ${user.formattedAccountId}',
                                onTap: () => _confirmSignOut(context),
                                trailing: const Icon(Icons.logout_rounded,
                                    color: AppTheme.textSecondary, size: 20),
                              );
                            },
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.edit_rounded,
                            label: 'Edit Profil',
                            subtitle: 'Nama, bio, foto, lokasi',
                            onTap: () {
                              // Kembali ke ProfileScreen dan buka sheet
                              Navigator.pop(context, 'edit_profile');
                            },
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.lock_rounded,
                            label: 'Ubah Password',
                            subtitle: 'Terakhir diubah 3 bulan lalu',
                            onTap: () => _showComingSoon('Ubah Password'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.shield_rounded,
                            label: 'Privasi',
                            subtitle: 'Profil publik, aktivitas, data',
                            onTap: () => _showComingSoon('Pengaturan Privasi'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── NOTIFIKASI ─────────────────────────────────────
                      _SectionCard(
                        icon: Icons.notifications_rounded,
                        label: 'Notifikasi',
                        accentColor: AppTheme.accent,
                        children: [
                          _ToggleTile(
                            icon: Icons.play_circle_rounded,
                            label: 'Episode Baru',
                            subtitle: 'Update anime dalam daftar kamu',
                            value: _notifEpisodeBaru,
                            accentColor: AppTheme.accent,
                            onChanged: (v) {
                              setState(() => _notifEpisodeBaru = v);
                              _saveBool('notif_episode', v);
                            },
                          ),
                          _Divider(),
                          _ToggleTile(
                            icon: Icons.recommend_rounded,
                            label: 'Rekomendasi',
                            subtitle: 'Anime yang cocok dengan selera kamu',
                            value: _notifRekomendasi,
                            accentColor: AppTheme.accent,
                            onChanged: (v) {
                              setState(() => _notifRekomendasi = v);
                              _saveBool('notif_rekom', v);
                            },
                          ),
                          _Divider(),
                          _ToggleTile(
                            icon: Icons.emoji_events_rounded,
                            label: 'Challenge & Event',
                            subtitle: 'Pengingat sebelum tantangan berakhir',
                            value: _notifChallenge,
                            accentColor: AppTheme.accent,
                            onChanged: (v) {
                              setState(() => _notifChallenge = v);
                              _saveBool('notif_challenge', v);
                            },
                          ),
                          _Divider(),
                          _ToggleTile(
                            icon: Icons.local_offer_rounded,
                            label: 'Promo & Diskon',
                            subtitle: 'Penawaran Premium terbatas',
                            value: _notifPromo,
                            accentColor: AppTheme.accent,
                            onChanged: (v) {
                              setState(() => _notifPromo = v);
                              _saveBool('notif_promo', v);
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── TAMPILAN & PEMUTARAN ───────────────────────────
                      _SectionCard(
                        icon: Icons.tune_rounded,
                        label: 'Tampilan & Pemutaran',
                        accentColor: AppTheme.primary,
                        children: [
                          _ToggleTile(
                            icon: Icons.skip_next_rounded,
                            label: 'Putar Otomatis',
                            subtitle: 'Episode berikutnya langsung lanjut',
                            value: _autoplay,
                            accentColor: AppTheme.primary,
                            onChanged: (v) {
                              setState(() => _autoplay = v);
                              _saveBool('autoplay', v);
                            },
                          ),
                          _Divider(),
                          _ToggleTile(
                            icon: Icons.fast_forward_rounded,
                            label: 'Skip Intro Otomatis',
                            subtitle: 'Lewati opening & ending',
                            value: _skipIntro,
                            accentColor: AppTheme.primary,
                            onChanged: (v) {
                              setState(() => _skipIntro = v);
                              _saveBool('skip_intro', v);
                            },
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.hd_rounded,
                            label: 'Kualitas Video',
                            subtitle: _kualitas,
                            onTap: _pickKualitas,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(_kualitas,
                                    style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.language_rounded,
                            label: 'Bahasa',
                            subtitle: _bahasa,
                            onTap: _pickBahasa,
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: AppTheme.primary.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppTheme.primary.withOpacity(0.3)),
                                  ),
                                  child: Text(_bahasa,
                                    style: TextStyle(color: AppTheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                                ),
                                const SizedBox(width: 6),
                                const Icon(Icons.chevron_right_rounded,
                                    color: AppTheme.textSecondary, size: 20),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // ── LAINNYA ───────────────────────────────────────
                      _SectionCard(
                        icon: Icons.info_rounded,
                        label: 'Lainnya',
                        accentColor: AppTheme.textSecondary,
                        children: [
                          _SettingsTile(
                            icon: Icons.star_rounded,
                            label: 'Beri Rating di Store',
                            subtitle: 'Bantu AniVerse berkembang',
                            onTap: () => _showComingSoon('Rating App'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.help_rounded,
                            label: 'Bantuan & FAQ',
                            subtitle: 'Cara pakai fitur AniVerse',
                            onTap: () => _showComingSoon('Bantuan'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.description_rounded,
                            label: 'Syarat & Ketentuan',
                            onTap: () => _showComingSoon('Syarat & Ketentuan'),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                          _Divider(),
                          _SettingsTile(
                            icon: Icons.info_outline_rounded,
                            label: 'Tentang AniVerse',
                            subtitle: 'Versi 1.0.0 · Built with ❤️',
                            onTap: () => _showAbout(),
                            trailing: const Icon(Icons.chevron_right_rounded,
                                color: AppTheme.textSecondary, size: 20),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── KELUAR ────────────────────────────────────────
                      GestureDetector(
                        onTap: _showLogoutDialog,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.red.withOpacity(0.25)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.logout_rounded, color: Colors.red.shade400, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Keluar',
                                style: TextStyle(
                                  color: Colors.red.shade400,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 48),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(double safeTop) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, safeTop + 12, 16, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.surfaceElevated.withOpacity(0.95),
            AppTheme.surface.withOpacity(0.80),
            AppTheme.background.withOpacity(0.60),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AppTheme.textPrimary.withOpacity(0.07)),
        ),
      ),
      child: Row(
        children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.8),
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.textSecondary.withOpacity(0.15)),
              ),
              child: const Icon(Icons.arrow_back_ios_rounded,
                  color: AppTheme.textSecondary, size: 16),
            ),
          ),
          const SizedBox(width: 14),

          // Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ShaderMask(
                  shaderCallback: (r) => LinearGradient(
                    colors: [AppTheme.textPrimary, AppTheme.highlight.withOpacity(0.85)],
                  ).createShader(r),
                  child: const Text(
                    'Pengaturan',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                ),
                Text(
                  'AniVerse v1.0.0',
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.6),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),

          // Gear icon (decorative, already on this screen)
          AnimatedBuilder(
            animation: _auraCtrl,
            builder: (_, __) {
              return Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.highlight.withOpacity(0.10 + _auraCtrl.value * 0.06),
                  border: Border.all(
                    color: AppTheme.highlight.withOpacity(0.25 + _auraCtrl.value * 0.15),
                  ),
                ),
                child: Icon(Icons.settings_rounded,
                    color: AppTheme.highlight.withOpacity(0.7 + _auraCtrl.value * 0.3),
                    size: 18),
              );
            },
          ),
        ],
      ),
    );
  }

  void _confirmSignOut(BuildContext context) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Keluar Akun?',
            style: TextStyle(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        content: const Text(
          'Progress kamu tetap aman tersimpan di cloud. Kamu bisa login lagi kapan saja untuk melanjutkan.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Batal',
                style: TextStyle(color: AppTheme.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await AuthService.signOut();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Berhasil keluar akun'),
                    backgroundColor: AppTheme.surface,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    margin: const EdgeInsets.all(16),
                  ),
                );
              }
            },
            child: const Text('Keluar',
                style: TextStyle(
                    color: Colors.redAccent, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String feature) {
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature segera hadir 🚀',
          style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppTheme.surface,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showAbout() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64, height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.highlight, AppTheme.accent],
                ),
                boxShadow: [
                  BoxShadow(color: AppTheme.highlight.withOpacity(0.35), blurRadius: 20),
                ],
              ),
              child: const Icon(Icons.play_circle_rounded,
                  color: Colors.white, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('AniVerse',
              style: TextStyle(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text('Versi 1.0.0 · Build 2025',
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
            const SizedBox(height: 12),
            Text(
              'Platform streaming anime premium.\nDibuat dengan Flutter 💙',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.5),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Tutup',
              style: TextStyle(color: AppTheme.highlight, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ── Ambient atmosphere ────────────────────────────────────────────────────────

class _SettingsAtmosphere extends StatelessWidget {
  final AnimationController auraCtrl;
  const _SettingsAtmosphere({required this.auraCtrl});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: auraCtrl,
        builder: (_, __) => Stack(
          children: [
            Positioned(
              top: -40, right: -50,
              child: Container(
                width: 220, height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.highlight.withOpacity(0.08 + auraCtrl.value * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 300, left: -60,
              child: Container(
                width: 180, height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppTheme.accent.withOpacity(0.07 + auraCtrl.value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Section card wrapper ───────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accentColor;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.label,
    required this.accentColor,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section label
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Container(
                width: 3, height: 13,
                decoration: BoxDecoration(
                  color: accentColor,
                  borderRadius: BorderRadius.circular(2),
                  boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 6)],
                ),
              ),
              const SizedBox(width: 8),
              Icon(icon, color: accentColor, size: 14),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: accentColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),

        // Card
        Container(
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppTheme.textPrimary.withOpacity(0.06)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withOpacity(0.04),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

// ── Settings tile (navigasi) ──────────────────────────────────────────────────

class _SettingsTile extends StatefulWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  State<_SettingsTile> createState() => _SettingsTileState();
}

class _SettingsTileState extends State<_SettingsTile> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        color: _pressed ? AppTheme.surfaceElevated.withOpacity(0.5) : Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated.withOpacity(0.6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(widget.icon, color: AppTheme.textSecondary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.label,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
                  if (widget.subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(widget.subtitle!,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.7),
                        fontSize: 11,
                      )),
                  ],
                ],
              ),
            ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
      ),
    );
  }
}

// ── Toggle tile ───────────────────────────────────────────────────────────────

class _ToggleTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final Color accentColor;
  final ValueChanged<bool> onChanged;

  const _ToggleTile({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.value,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: value
                  ? accentColor.withOpacity(0.12)
                  : AppTheme.surfaceElevated.withOpacity(0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon,
              color: value ? accentColor : AppTheme.textSecondary,
              size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  )),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!,
                    style: TextStyle(
                      color: AppTheme.textSecondary.withOpacity(0.7),
                      fontSize: 11,
                    )),
                ],
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(!value);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              width: 44, height: 26,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(13),
                color: value ? accentColor : AppTheme.surfaceElevated,
                boxShadow: value
                    ? [BoxShadow(color: accentColor.withOpacity(0.35), blurRadius: 8)]
                    : [],
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: value ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  margin: const EdgeInsets.all(3),
                  width: 20, height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Divider tipis ─────────────────────────────────────────────────────────────

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      color: AppTheme.textPrimary.withOpacity(0.05),
      indent: 62,
    );
  }
}

// ── Picker bottom sheet ───────────────────────────────────────────────────────

class _PickerSheet extends StatelessWidget {
  final String title;
  final List<String> options;
  final String selected;
  final ValueChanged<String> onSelect;

  const _PickerSheet({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: AppTheme.textPrimary.withOpacity(0.08)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: AppTheme.surfaceElevated,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 14),
          ...options.map((opt) {
            final isSelected = opt == selected;
            return GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelect(opt);
                Navigator.pop(context);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.highlight.withOpacity(0.12)
                      : AppTheme.surfaceElevated.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? AppTheme.highlight.withOpacity(0.4)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Text(opt,
                      style: TextStyle(
                        color: isSelected ? AppTheme.highlight : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      )),
                    const Spacer(),
                    if (isSelected)
                      Icon(Icons.check_circle_rounded,
                          color: AppTheme.highlight, size: 18),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}
