import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/constants/app_colors.dart';
import '../../../widgets/app_button.dart';

class AdminSettingsPage extends StatefulWidget {
  const AdminSettingsPage({super.key});

  @override
  State<AdminSettingsPage> createState() => _AdminSettingsPageState();
}

class _AdminSettingsPageState extends State<AdminSettingsPage> {
  final _supabase = Supabase.instance.client;
  final _mapController = MapController();

  final _latController = TextEditingController();
  final _lngController = TextEditingController();

  LatLng _storeLocation = const LatLng(-6.2088, 106.8456);
  String _qrisImageUrl = '';
  bool _isLoading = false;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  @override
  void dispose() {
    _latController.dispose();
    _lngController.dispose();
    super.dispose();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabase.from('settings').select();
      final map = <String, String>{};
      for (final row in data as List<dynamic>) {
        map[row['key'] as String] = row['value'] as String? ?? '';
      }

      final lat = double.tryParse(map['store_latitude'] ?? '') ?? -6.2088;
      final lng = double.tryParse(map['store_longitude'] ?? '') ?? 106.8456;

      setState(() {
        _storeLocation = LatLng(lat, lng);
        _latController.text = lat.toString();
        _lngController.text = lng.toString();
        _qrisImageUrl = map['qris_image_url'] ?? '';
      });
    } catch (e) {
      _showSnack('Gagal memuat settings: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSetting(String key, String value) async {
    await _supabase.from('settings').upsert(
      {'key': key, 'value': value},
      onConflict: 'key',
    );
  }

  Future<void> _saveCoordinates() async {
    final lat = double.tryParse(_latController.text);
    final lng = double.tryParse(_lngController.text);
    if (lat == null || lng == null) {
      _showSnack('Koordinat tidak valid', isError: true);
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _saveSetting('store_latitude', lat.toString()),
        _saveSetting('store_longitude', lng.toString()),
      ]);
      setState(() => _storeLocation = LatLng(lat, lng));
      _showSnack('Koordinat toko berhasil disimpan');
    } catch (e) {
      _showSnack('Gagal simpan koordinat: $e', isError: true);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _uploadQris() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    setState(() => _isUploading = true);
    try {
      final file = File(picked.path);
      final bytes = await file.readAsBytes();
      final path = 'qris/qris_${DateTime.now().millisecondsSinceEpoch}.png';

      await _supabase.storage.from('qris-assets').uploadBinary(
            path,
            bytes,
            fileOptions: const FileOptions(contentType: 'image/png', upsert: true),
          );

      final url = _supabase.storage.from('qris-assets').getPublicUrl(path);
      await _saveSetting('qris_image_url', url);

      setState(() => _qrisImageUrl = url);
      _showSnack('QRIS berhasil diupload');
    } catch (e) {
      _showSnack('Gagal upload QRIS: $e', isError: true);
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? AppColors.error : AppColors.success,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Pengaturan Toko'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0.5,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadSettings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    title: 'Lokasi Toko',
                    icon: Icons.location_on,
                    child: Column(
                      children: [
                        // Peta interaktif
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            height: 220,
                            child: FlutterMap(
                              mapController: _mapController,
                              options: MapOptions(
                                initialCenter: _storeLocation,
                                initialZoom: 15,
                                onTap: (_, point) {
                                  setState(() {
                                    _storeLocation = point;
                                    _latController.text =
                                        point.latitude.toStringAsFixed(6);
                                    _lngController.text =
                                        point.longitude.toStringAsFixed(6);
                                  });
                                },
                              ),
                              children: [
                                TileLayer(
                                  urlTemplate:
                                      'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                                  userAgentPackageName:
                                      'com.premierlaundry.app',
                                ),
                                MarkerLayer(
                                  markers: [
                                    Marker(
                                      point: _storeLocation,
                                      width: 40,
                                      height: 40,
                                      child: const Icon(
                                        Icons.store,
                                        color: AppColors.primary,
                                        size: 36,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Tap pada peta untuk memilih lokasi toko',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _latController,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: 'Latitude',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (v) {
                                  final lat = double.tryParse(v);
                                  final lng = double.tryParse(_lngController.text);
                                  if (lat != null && lng != null) {
                                    setState(() => _storeLocation = LatLng(lat, lng));
                                  }
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextField(
                                controller: _lngController,
                                keyboardType: const TextInputType.numberWithOptions(
                                    decimal: true, signed: true),
                                decoration: InputDecoration(
                                  labelText: 'Longitude',
                                  border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10)),
                                  filled: true,
                                  fillColor: Colors.white,
                                ),
                                onChanged: (v) {
                                  final lat = double.tryParse(_latController.text);
                                  final lng = double.tryParse(v);
                                  if (lat != null && lng != null) {
                                    setState(() => _storeLocation = LatLng(lat, lng));
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        AppButton(
                          onPressed: _saveCoordinates,
                          label: 'Simpan Lokasi Toko',
                          isLoading: _isLoading,
                          color: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  _buildSection(
                    title: 'Gambar QRIS',
                    icon: Icons.qr_code,
                    child: Column(
                      children: [
                        if (_qrisImageUrl.isNotEmpty)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _qrisImageUrl,
                              height: 200,
                              fit: BoxFit.contain,
                              errorBuilder: (ctx, e, stack) => const Icon(
                                Icons.broken_image,
                                size: 80,
                                color: Colors.grey,
                              ),
                            ),
                          )
                        else
                          Container(
                            height: 120,
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.qr_code, size: 48, color: Colors.grey),
                                  SizedBox(height: 8),
                                  Text('Belum ada gambar QRIS',
                                      style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        AppButton(
                          onPressed: _uploadQris,
                          label: _isUploading ? 'Mengupload...' : 'Upload Gambar QRIS',
                          isLoading: _isUploading,
                          color: AppColors.secondary,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Widget child,
  }) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppColors.primary, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const Divider(height: 24),
            child,
          ],
        ),
      ),
    );
  }
}
