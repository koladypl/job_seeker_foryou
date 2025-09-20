// lib/job_offer_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'api_service.dart';
import 'job_offer.dart';
import 'widgets/job_location_map.dart';
import 'application_form_screen.dart';

class JobOfferDetailScreen extends StatelessWidget {
  final JobOffer offer;
  const JobOfferDetailScreen({super.key, required this.offer});

  Future<void> _openCompanySite(String? url, BuildContext ctx) async {
    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Brak strony firmy')));
      return;
    }
    final uri = Uri.tryParse(url);
    if (uri == null) {
      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text('Nieprawidłowy adres firmy')));
      return;
    }
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(offer.title, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: () => Navigator.pushNamed(context, '/settings')),
          IconButton(
            icon: Icon(api.isSaved(offer) ? Icons.bookmark : Icons.bookmark_border, color: Colors.blueAccent),
            onPressed: () async {
              if (!api.isLoggedIn) {
                Navigator.pushNamed(context, '/login');
                return;
              }
              api.isSaved(offer) ? await api.removeSaved(offer) : await api.saveOffer(offer);
            },
          ),
        ],
      ),
      bottomNavigationBar: _buildActionBar(context, api),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildHeader(offer),
          const SizedBox(height: 12),
          _buildCompanyCard(context, offer),
          const SizedBox(height: 12),
          if (offer.address.isNotEmpty) _buildSection('Adres', Row(children: [const Icon(Icons.place, size: 18, color: Colors.redAccent), const SizedBox(width: 6), Expanded(child: Text(offer.address, style: const TextStyle(fontWeight: FontWeight.w600)))])),
          _buildSection(
            'Lokalizacja',
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [const Icon(Icons.location_on_outlined, size: 18), const SizedBox(width: 6), Expanded(child: Text(_locationText(offer)))]),
              const SizedBox(height: 12),
              JobLocationMap(address: offer.address.isNotEmpty ? offer.address : offer.location, latitude: offer.latitude, longitude: offer.longitude, height: 260),
              const SizedBox(height: 8),
              if (offer.latitude != null && offer.longitude != null) Text('Współrzędne: ${offer.latitude!.toStringAsFixed(5)}, ${offer.longitude!.toStringAsFixed(5)}', style: const TextStyle(fontSize: 12, color: Colors.black54)),
            ]),
          ),
          _buildSection('Opis', Text(offer.description.isNotEmpty ? offer.description : 'Brak opisu.', style: const TextStyle(height: 1.4))),
          if (offer.requirements.isNotEmpty) _buildSection('Wymagania', _bulleted(offer.requirements)),
          if (offer.duties.isNotEmpty) _buildSection('Obowiązki', _bulleted(offer.duties)),
          if (offer.benefits.isNotEmpty) _buildSection('Oferujemy', _bulleted(offer.benefits)),
        ],
      ),
    );
  }

  Widget _buildCompanyCard(BuildContext ctx, JobOffer o) {
    final hasLogo = (o is JobOffer && (o as JobOffer).company.isNotEmpty); // placeholder check: company exists
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
        if (o.company.isNotEmpty)
          CircleAvatar(
            radius: 28,
            backgroundColor: Colors.grey.shade200,
            child: Text(o.company.trim().isNotEmpty ? o.company.trim()[0].toUpperCase() : '?', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          )
        else
          const SizedBox(width: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(o.company.isNotEmpty ? o.company : 'Nieznany pracodawca', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              ElevatedButton.icon(icon: const Icon(Icons.search), label: const Text('Oferty firmy'), onPressed: () => Navigator.pushNamed(ctx, '/jobs', arguments: {'company': o.company})),
              const SizedBox(width: 8),
              OutlinedButton.icon(icon: const Icon(Icons.public), label: const Text('Strona firmy'), onPressed: () => _openCompanySite(o.company, ctx)),
            ]),
          ]),
        ),
      ])),
    );
  }

  Widget _buildActionBar(BuildContext ctx, ApiService api) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(color: Theme.of(ctx).cardColor, boxShadow: [BoxShadow(color: Colors.black.withAlpha((0.06 * 255).round()), blurRadius: 6, offset: const Offset(0, -2))]),
      child: Row(children: [
        Expanded(child: OutlinedButton.icon(icon: Icon(api.isSaved(offer) ? Icons.bookmark : Icons.bookmark_border), label: Text(api.isSaved(offer) ? 'Zapisano' : 'Zapisz'), onPressed: () async {
          if (!api.isLoggedIn) {
            Navigator.pushNamed(ctx, '/login');
            return;
          }
          api.isSaved(offer) ? await api.removeSaved(offer) : await api.saveOffer(offer);
        })),
        const SizedBox(width: 12),
        Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.send), label: const Text('Aplikuj'), onPressed: () {
          if (!api.isLoggedIn) {
            Navigator.pushNamed(ctx, '/login');
            return;
          }
          Navigator.push(ctx, MaterialPageRoute(builder: (_) => ApplicationFormScreen(offer: offer)));
        })),
      ]),
    );
  }

  Widget _buildHeader(JobOffer o) => Card(elevation: 3, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(o.title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
    const SizedBox(height: 8),
    if (o.salaryMin != null || o.salaryMax != null) Row(children: [const Icon(Icons.attach_money, size: 16, color: Colors.green), const SizedBox(width: 4), Text(_salaryText(o.salaryMin, o.salaryMax), style: const TextStyle(fontWeight: FontWeight.w600))]),
  ])));

  Widget _buildSection(String title, Widget child) => Card(elevation: 2, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const SizedBox(height: 8), child])));

  static String _locationText(JobOffer job) {
    final parts = [
      if (job.city.isNotEmpty) job.city,
      if (job.region.isNotEmpty) job.region,
      if (job.isRemote) 'praca zdalna',
    ];
    return parts.isNotEmpty ? parts.join(' / ') : job.location;
  }

  static Widget _bulleted(List<String> items) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: items.map((t) => Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [const Padding(padding: EdgeInsets.only(right: 8, top: 6), child: Icon(Icons.circle, size: 6)), Expanded(child: Text(t))]))).toList());

  static String _salaryText(int? min, int? max) {
    if (min == null && max == null) return '';
    if (min != null && max != null) return '$min – $max PLN';
    if (min != null) return 'od $min PLN';
    return 'do $max PLN';
  }
}
