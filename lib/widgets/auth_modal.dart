// auth_modal.dart — Liquid Glass Google Sign-In Sheet
import 'package:flutter/material.dart';
import '../auth_service.dart';
import 'liquid_glass.dart';

class AuthModal {
  static void showGoogleSignIn(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return _GoogleSignInSheet();
      },
    );
  }
}

class _GoogleSignInSheet extends StatefulWidget {
  @override
  State<_GoogleSignInSheet> createState() => _GoogleSignInSheetState();
}

class _GoogleSignInSheetState extends State<_GoogleSignInSheet> {
  bool _isLoading = false;

  Future<void> _handleGoogleLogin() async {
    setState(() => _isLoading = true);
    try {
      final user = await AuthService.signInWithGoogle();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Selamat datang kembali, ${user.name}! Data Anda berhasil tersimpan.'),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFE50914),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal login Google: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Color(0xFF16181D),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        border: Border(top: BorderSide(color: Color(0x33FFB3C6), width: 1.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.05),
              border: Border.all(color: const Color(0xFFFFB3C6).withValues(alpha: 0.3)),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFFFB3C6).withValues(alpha: 0.15),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Center(
              child: Image.asset(
                'asset/logo aniverse.png',
                width: 48,
                height: 48,
                errorBuilder: (_, __, ___) => const Icon(
                  Icons.account_circle_rounded,
                  color: Color(0xFFFFB3C6),
                  size: 40,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Simpan Progress AniVerse',
            style: TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Masuk dengan Akun Google untuk menyimpan riwayat nonton, bookmark anime, XP level, dan koin Anda secara otomatis di cloud.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 28),
          _isLoading
              ? const CircularProgressIndicator(color: Color(0xFFFFB3C6))
              : LiquidGlassPill(
                  borderRadius: 16,
                  padding: EdgeInsets.zero,
                  child: InkWell(
                    onTap: _handleGoogleLogin,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(4),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.g_mobiledata_rounded,
                              color: Color(0xFF4285F4),
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Masuk dengan Google',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Lanjutkan sebagai Tamu',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.4),
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
