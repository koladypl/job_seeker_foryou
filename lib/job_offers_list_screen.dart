// lib/job_offers_list_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import 'api_service.dart';
import 'job_offer.dart';
import 'widgets/jobs_map_view.dart';

class JobOffersListScreen extends StatefulWidget {
  const JobOffersListScreen({super.key});

  @override
  State<JobOffersListScreen> createState() => _JobOffersListScreenState();
}

class _JobOffersListScreenState extends State<JobOffersListScreen> {
  bool mapMode = false;
  String? q;
  String? companyFilter;
  String? quickFilter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = ModalRoute.of(context)?.settings.arguments;
      if (args is Map) {
        setState(() {
          q = args['q'] as String?;
          companyFilter = args['company'] as String?;
          quickFilter = args['filter'] as String?;
        });
      }
    });
    _loadOffers();
  }

  Future<void> _loadOffers() async {
    await context.read<ApiService>().fetchOffers(q: q);
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final offers = api.cache;
    final df = DateFormat.yMMMMd('pl');

    final filtered = offers.where((job) {
      if (companyFilter != null && companyFilter!.isNotEmpty && job.company.toLowerCase() != companyFilter!.toLowerCase()) return false;
      if (q != null && q!.isNotEmpty) {
        final token = q!.toLowerCase();
        if (!(job.title.toLowerCase().contains(token) || job.company.toLowerCase().contains(token) || job.location.toLowerCase().contains(token))) return false;
      }
      if (quickFilter != null) {
        if (quickFilter == 'Zdalnie' && !job.isRemote) return false;
        if (quickFilter == 'W biurze' && job.isRemote) return false;
      }
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Oferty pracy'),
        actions: [
          IconButton(icon: const Icon(Icons.search), onPressed: () => _showSearch(context)),
          IconButton(icon: const Icon(Icons.map), onPressed: () => setState(() => mapMode = !mapMode)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadOffers,
        child: ListView(padding: const EdgeInsets.all(8), children: [
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(children: [
                Expanded(child: TextField(controller: TextEditingController(text: q), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Szukaj...'), onSubmitted: (v) {
                  setState(() => q = v);
                  _loadOffers();
                })),
                const SizedBox(width: 8),
                ElevatedButton.icon(icon: const Icon(Icons.tune), label: const Text('Filtruj'), onPressed: () {}),
              ]),
            ),
          ),
          if (mapMode)
            Builder(builder: (ctx) {
              final withCoords = filtered.where((j) => j.latitude != null && j.longitude != null).toList();
              final initLat = withCoords.isNotEmpty ? withCoords.first.latitude! : 52.2297;
              final initLon = withCoords.isNotEmpty ? withCoords.first.longitude! : 21.0122;
              return SizedBox(height: 400, child: JobsMapView(jobs: withCoords, initialLat: initLat, initialLon: initLon, initialZoom: 11));
            }),
          if (!mapMode)
            ...filtered.map((job) {
              final when = job.postedAt ?? job.fetchedAt ?? DateTime.now();
              final salary = _salaryText(job.salaryMin, job.salaryMax);
              final locParts = [
                if (job.city.isNotEmpty) job.city,
                if (job.region.isNotEmpty) job.region,
                if (job.isRemote) 'zdalnie',
              ];
              final loc = locParts.join(' / ');
              return Card(
                margin: const EdgeInsets.symmetric(vertical: 8),
                elevation: 3,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    if (job.address.isNotEmpty)
                      Row(children: [const Icon(Icons.place, size: 16, color: Colors.redAccent), const SizedBox(width: 6), Expanded(child: Text(job.address, style: const TextStyle(fontWeight: FontWeight.w600)))]),
                    const SizedBox(height: 6),
                    Text(job.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    if (job.company.isNotEmpty) Text(job.company, style: const TextStyle(color: Colors.blueGrey)),
                    const SizedBox(height: 8),
                    if (salary != null) Text(salary, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                    const SizedBox(height: 6),
                    Text('Opublikowano: ${df.format(when)}', style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                      OutlinedButton.icon(icon: const Icon(Icons.info_outline), label: const Text('Szczegóły'), onPressed: () => Navigator.pushNamed(context, '/detail', arguments: job)),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(icon: const Icon(Icons.send), label: const Text('Aplikuj'), onPressed: () {
                        if (!api.isLoggedIn) {
                          Navigator.pushNamed(context, '/login');
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zaloguj się, aby aplikować')));
                          return;
                        }
                        Navigator.pushNamed(context, '/detail', arguments: job);
                      }),
                    ])
                  ]),
                ),
              );
            }).toList(),
        ]),
      ),
    );
  }

  void _showSearch(BuildContext ctx) {
    showSearch(context: ctx, delegate: _JobSearchDelegate(onSelected: (q) {
      setState(() => this.q = q);
      _loadOffers();
    }));
  }

  static String? _salaryText(int? min, int? max) {
    if (min == null && max == null) return null;
    if (min != null && max != null) return '$min – $max PLN';
    if (min != null) return 'od $min PLN';
    return 'do $max PLN';
  }
}

class _JobSearchDelegate extends SearchDelegate<String> {
  final void Function(String)? onSelected;
  _JobSearchDelegate({this.onSelected});
  @override
  List<Widget>? buildActions(BuildContext context) => [IconButton(icon: const Icon(Icons.clear), onPressed: () => query = '')];
  @override
  Widget? buildLeading(BuildContext context) => IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => close(context, ''));
  @override
  Widget buildResults(BuildContext context) {
    onSelected?.call(query);
    close(context, query);
    return const SizedBox.shrink();
  }
  @override
  Widget buildSuggestions(BuildContext context) => ListTile(title: Text('Szukaj: $query'));
}
