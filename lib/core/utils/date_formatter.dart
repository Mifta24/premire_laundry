const _bulanIndo = [
  '',
  'Januari',
  'Februari',
  'Maret',
  'April',
  'Mei',
  'Juni',
  'Juli',
  'Agustus',
  'September',
  'Oktober',
  'November',
  'Desember',
];

String formatTanggalSingkat(DateTime dt) {
  return '${dt.day} ${_bulanIndo[dt.month]} ${dt.year}';
}

String formatTanggalIndo(DateTime dt) {
  return '${formatTanggalSingkat(dt)} · ${formatJamSaja(dt)} WIB';
}

String formatJamSaja(DateTime dt) {
  final jam = dt.hour.toString().padLeft(2, '0');
  final menit = dt.minute.toString().padLeft(2, '0');
  return '$jam:$menit';
}

const _hariIndo = [
  '',
  'Senin',
  'Selasa',
  'Rabu',
  'Kamis',
  'Jumat',
  'Sabtu',
  'Minggu',
];

String formatHariTanggal(DateTime dt) {
  return '${_hariIndo[dt.weekday]}, ${formatTanggalSingkat(dt)}';
}
