String friendlyAuthErrorMessage(Object error) {
  final raw = error.toString().toLowerCase();

  if (raw.contains('invalid login credentials') ||
      raw.contains('invalid credentials') ||
      raw.contains('invalid_grant')) {
    return 'Email atau password salah. Periksa kembali lalu coba lagi.';
  }
  if (raw.contains('email not confirmed') || raw.contains('not confirmed')) {
    return 'Email belum diverifikasi. Silakan cek inbox atau spam email Anda.';
  }
  if (raw.contains('user already registered') ||
      raw.contains('already registered') ||
      raw.contains('already exists')) {
    return 'Email ini sudah terdaftar. Silakan login atau gunakan email lain.';
  }
  if (raw.contains('password should be at least') ||
      raw.contains('weak password') ||
      raw.contains('password')) {
    return 'Password terlalu lemah. Gunakan minimal 6 karakter.';
  }
  if (raw.contains('rate limit') ||
      raw.contains('too many requests') ||
      raw.contains('security purposes')) {
    return 'Terlalu banyak percobaan. Tunggu beberapa saat lalu coba lagi.';
  }
  if (raw.contains('signup disabled')) {
    return 'Pendaftaran sedang tidak tersedia. Hubungi admin toko.';
  }
  if (raw.contains('network') ||
      raw.contains('socket') ||
      raw.contains('connection') ||
      raw.contains('timeout')) {
    return 'Koneksi bermasalah. Periksa internet Anda lalu coba lagi.';
  }
  if (raw.contains('jwt') ||
      raw.contains('session') ||
      raw.contains('expired')) {
    return 'Sesi Anda sudah kedaluwarsa. Silakan login ulang.';
  }

  return 'Terjadi kesalahan autentikasi. Silakan coba lagi.';
}

String friendlyErrorMessage(Object error, {String? fallback}) {
  final raw = error.toString();
  final lower = raw.toLowerCase();

  if (lower.contains('permission denied') ||
      lower.contains('row-level security') ||
      lower.contains('violates row-level security')) {
    return 'Akses ditolak. Akun Anda tidak memiliki izin untuk aksi ini.';
  }
  if (lower.contains('network') ||
      lower.contains('socket') ||
      lower.contains('connection') ||
      lower.contains('timeout')) {
    return 'Koneksi bermasalah. Periksa internet Anda lalu coba lagi.';
  }

  return fallback ?? 'Terjadi kesalahan. Silakan coba lagi.';
}
