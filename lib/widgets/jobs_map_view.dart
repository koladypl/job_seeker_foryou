import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';
import '../job_offer.dart';

class JobsMapView extends StatefulWidget {
  final List<JobOffer> jobs;
  final double initialLat;
  final double initialLon;
  final double initialZoom;

  const JobsMapView({
    super.key,
    required this.jobs,
    required this.initialLat,
    required this.initialLon,
    this.initialZoom = 11,
  });

  @override
  State<JobsMapView> createState() => _JobsMapViewState();
}

class _JobsMapViewState extends State<JobsMapView> {
  final Map<int, LatLng> _points = {};
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _preparePoints();
  }

  void _preparePoints() {
    _points.clear();
    for (final j in widget.jobs) {
      if (j.latitude != null && j.longitude != null) {
        _points[j.id] = LatLng(j.latitude!, j.longitude!);
      }
    }
    setState(() => _ready = true);
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

  void _showJobSheet(BuildContext ctx, JobOffer job, LatLng p) {
    showModalBottomSheet(
      context: ctx,
      showDragHandle: true,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(job.title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (job.company.isNotEmpty) Text(job.company),
          if (job.address.isNotEmpty) ...[const SizedBox(height: 6), Text(job.address)],
          const SizedBox(height: 8),
          Text('Współrzędne: ${p.latitude.toStringAsFixed(5)}, ${p.longitude.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          Row(children: [
            ElevatedButton.icon(icon: const Icon(Icons.info_outline), label: const Text('Szczegóły'), onPressed: () {
              Navigator.pop(ctx);
              Navigator.pushNamed(ctx, '/detail', arguments: job);
            }),
            const SizedBox(width: 8),
            OutlinedButton.icon(icon: const Icon(Icons.directions), label: const Text('Nawiguj'), onPressed: () => _openMaps(p)),
          ]),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = <Marker>[];
    for (final job in widget.jobs) {
      final p = _points[job.id];
      if (p == null) continue;
      markers.add(Marker(point: p, width: 44, height: 44, builder: (ctx) => GestureDetector(onTap: () => _showJobSheet(ctx, job, p), child: const Icon(Icons.location_pin, color: Colors.red, size: 36))));
    }

    final center = markers.isNotEmpty ? markers.first.point : LatLng(widget.initialLat, widget.initialLon);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Card(
        elevation: 2,
        child: SizedBox(
          height: double.infinity,
          child: !_ready ? const Center(child: CircularProgressIndicator()) : FlutterMap(
            options: MapOptions(center: center, zoom: widget.initialZoom),
            children: [
              TileLayer(urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', subdomains: const ['a','b','c'], userAgentPackageName: 'com.example.jobseeker'),
              MarkerLayer(markers: markers),
            ],
          ),
        ),
      ),
    );
  }
}
