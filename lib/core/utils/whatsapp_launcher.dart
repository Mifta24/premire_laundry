import 'package:url_launcher/url_launcher.dart';

String normalizePhoneForWhatsApp(String phone) {
  var digits = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.startsWith('0')) {
    digits = '62${digits.substring(1)}';
  } else if (!digits.startsWith('62')) {
    digits = '62$digits';
  }
  return digits;
}

/// Opens a WhatsApp chat with [phone], preferring the native app and
/// falling back to wa.me. Returns false if WhatsApp couldn't be opened
/// either way, so callers can show their own feedback.
Future<bool> openWhatsAppChat(String phone) async {
  final waPhone = normalizePhoneForWhatsApp(phone);

  final appUri = Uri.parse('whatsapp://send?phone=$waPhone');
  if (await canLaunchUrl(appUri)) {
    await launchUrl(appUri);
    return true;
  }

  final webUri = Uri.parse('https://wa.me/$waPhone');
  if (await canLaunchUrl(webUri)) {
    await launchUrl(webUri, mode: LaunchMode.externalApplication);
    return true;
  }

  return false;
}
