import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

class JobLocationMap extends StatefulWidget {
  final String address;
  final double? latitude;
  final double? longitude;
  final double height;
  final double initialZoom;

  const JobLocationMap({super.key, required this.address, this.latitude, this.longitude, this.height = 260, this.initialZoom = 13});

  @override
  State<JobLocationMap> createState() => _JobLocationMapState();
}

class _JobLocationMapState extends State<JobLocationMap> {
  LatLng? _point;
  bool _loading = false;
  String? _label;

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    if (widget.latitude != null && widget.longitude != null) {
      _point = LatLng(widget.latitude!, widget.longitude!);
      _label = widget.address.isNotEmpty ? widget.address : null;
      setState(() {});
      return;
    }

    final q = widget.address.trim();
    if (q.isEmpty) {
      _point =  LatLng(52.2297, 21.0122);
      setState(() {});
      return;
    }

    setState(() => _loading = true);
    try {
      final p = await _geocode(q);
      if (p != null) {
        _point = p;
        _label = q;
      } else {
        _point =  LatLng(52.2297, 21.0122);
      }
    } catch (_) {
      _point =  LatLng(52.2297, 21.0122);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<LatLng?> _geocode(String query) async {
    final uri = Uri.parse('https://nominatim.openstreetmap.org/search').replace(queryParameters: {'q': query, 'format': 'json', 'limit': '1'});
    final res = await http.get(uri, headers: {'User-Agent': 'jobseeker-app/1.0'});
    if (res.statusCode != 200) return null;
    final list = jsonDecode(res.body) as List<dynamic>;
    if (list.isEmpty) return null;
    final first = list.first as Map<String, dynamic>;
    final lat = double.tryParse(first['lat'].toString());
    final lon = double.tryParse(first['lon'].toString());
    if (lat == null || lon == null) return null;
    return LatLng(lat, lon);
  }

  Future<void> _openMaps(LatLng p) async {
    final google = Uri.parse('https://www.google.com/maps/dir/?api=1&destination=${p.latitude},${p.longitude}');
    final geo = Uri.parse('geo:${p.latitude},${p.longitude}');
    try {
      if (await canLaunchUrl(google)) {
        await launchUrl(google, mode: LaunchMode.externalApplication);
        return;
      }
      if (await canLaunchUrl(geo)) {
        await launchUrl(geo);
        return;
      }
      await launchUrl(google, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nie można otworzyć aplikacji mapy')));
    }
  }

  void _showSheet(BuildContext ctx, LatLng p) {
    showModalBottomSheet(context: ctx, showDragHandle: true, builder: (_) => Padding(padding: const EdgeInsets.all(16), child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(_label ?? widget.address, style: const TextStyle(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text('Współrzędne: ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}'),
      const SizedBox(height: 12),
      Row(children: [
        ElevatedButton.icon(icon: const Icon(Icons.directions), label: const Text('Nawiguj'), onPressed: () => _openMaps(p)),
        const SizedBox(width: 8),
        OutlinedButton.icon(icon: const Icon(Icons.copy), label: const Text('Kopiuj współrzędne'), onPressed: () {
          Clipboard.setData(ClipboardData(text: '${p.latitude},${p.longitude}'));
          Navigator.pop(ctx);
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Skopiowano współrzędne')));
        }),
      ]),
    ])));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      height: widget.height,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: _loading
              ? Center(child: CircularProgressIndicator(color: theme.colorScheme.primary))
              : _point == null
                  ? Center(child: Text('Nie znaleziono lokalizacji', style: TextStyle(color: theme.disabledColor)))
                  : FlutterMap(
                      options: MapOptions(center: _point!, zoom: widget.initialZoom, interactiveFlags: InteractiveFlag.all),
                      children: [
                        TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a','b','c'], userAgentPackageName: 'com.example.jobseeker'),
                        MarkerLayer(markers: [Marker(point: _point!, width: 48, height: 48, builder: (ctx) => GestureDetector(onTap: () => _showSheet(ctx, _point!), child: const Icon(Icons.location_pin, color: Colors.red, size: 36)))])
                      ],
                    ),
        ),
      ),
    );
  }
}
