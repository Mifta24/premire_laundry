import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/app_button.dart';
import '../../widgets/auth_background.dart';
import '../../widgets/auth_icon_badge.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _handleSendLink() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final success = await authProvider
        .sendPasswordResetEmail(_emailController.text.trim());

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (success) {
      setState(() => _emailSent = true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(authProvider.error ?? 'Gagal mengirim tautan. Coba lagi.'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: AuthBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => context.go('/login'),
                    icon: const Icon(Icons.arrow_back,
                        color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: 8),
                const Center(child: AuthIconBadge(icon: Icons.lock_outline)),
                const SizedBox(height: 24),
                Text(
                  _emailSent ? 'Cek Email Anda' : 'Lupa Password',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _emailSent
                      ? 'Kami telah mengirimkan tautan untuk mengatur ulang password ke ${_emailController.text.trim()}.'
                      : 'Masukkan email Anda. Kami akan mengirimkan tautan untuk mengatur ulang password.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
                const SizedBox(height: 32),
                if (!_emailSent) ...[
                  Form(
                    key: _formKey,
                    child: TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email / No. HP',
                        prefixIcon: const Icon(Icons.email_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      validator: (val) {
                        if (val == null || val.isEmpty) {
                          return 'Email wajib diisi';
                        }
                        if (!val.contains('@')) return 'Email tidak valid';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppButton(
                    onPressed: _handleSendLink,
                    label: 'Kirim Kode',
                    isLoading: _isLoading,
                  ),
                ] else
                  AppButton(
                    onPressed: () => context.go('/login'),
                    label: 'Kembali ke Login',
                  ),
                const SizedBox(height: 20),
                if (!_emailSent)
                  Center(
                    child: GestureDetector(
                      onTap: () => context.go('/login'),
                      child: const Text(
                        'Kembali ke Login',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
