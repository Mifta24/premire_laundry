import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_colors.dart';
import '../providers/auth_provider.dart';

class EditableAvatar extends StatefulWidget {
  final String? avatarUrl;
  final double radius;
  final IconData placeholderIcon;

  const EditableAvatar({
    super.key,
    required this.avatarUrl,
    this.radius = 32,
    this.placeholderIcon = Icons.person,
  });

  @override
  State<EditableAvatar> createState() => _EditableAvatarState();
}

class _EditableAvatarState extends State<EditableAvatar> {
  bool _isUploading = false;

  Future<void> _pickAndUpload() async {
    final userId = context.read<AuthProvider>().currentUser?.id;
    if (userId == null) return;

    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 512,
    );
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final bytes = await picked.readAsBytes();
      final path = '$userId/avatar.jpg';
      await Supabase.instance.client.storage.from('profile-photos').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
          );
      final baseUrl =
          Supabase.instance.client.storage.from('profile-photos').getPublicUrl(path);
      final bustedUrl = '$baseUrl?t=${DateTime.now().millisecondsSinceEpoch}';

      if (!mounted) return;
      final ok = await context.read<AuthProvider>().updateAvatar(bustedUrl);
      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                context.read<AuthProvider>().error ?? 'Gagal mengunggah foto'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal mengunggah foto: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.radius * 2;
    return GestureDetector(
      onTap: _isUploading ? null : _pickAndUpload,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          children: [
            ClipOval(
              child: widget.avatarUrl != null
                  ? CachedNetworkImage(
                      imageUrl: widget.avatarUrl!,
                      width: size,
                      height: size,
                      fit: BoxFit.cover,
                      placeholder: (ctx, url) => Container(
                        color: AppColors.primary,
                        child: Icon(widget.placeholderIcon,
                            size: widget.radius, color: Colors.white),
                      ),
                      errorWidget: (ctx, url, err) => Container(
                        color: AppColors.primary,
                        child: Icon(widget.placeholderIcon,
                            size: widget.radius, color: Colors.white),
                      ),
                    )
                  : Container(
                      color: AppColors.primary,
                      child: Icon(widget.placeholderIcon,
                          size: widget.radius, color: Colors.white),
                    ),
            ),
            if (_isUploading)
              Container(
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black45,
                ),
                child: const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(Icons.camera_alt, size: 12, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
