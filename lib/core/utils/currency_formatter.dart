import 'package:intl/intl.dart';

String formatRupiah(num amount) {
  final formatter = NumberFormat('#,###', 'id_ID');
  return 'Rp ${formatter.format(amount)}';
}
