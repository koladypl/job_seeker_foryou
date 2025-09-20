import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';

import 'api_service.dart';
import 'job_offer.dart';
import 'widgets/jobs_map_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<JobOffer> _featured = [];
  bool _loading = true;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<ApiService>();
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final featured = await api.fetchFeaturedJobs();
      if (!mounted) return;
      setState(() {
        _featured = featured;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  void _onSearchSubmitted(String q) {
    final query = q.trim();
    if (query.isEmpty) return;
    Navigator.pushNamed(context, '/jobs', arguments: {'q': query});
  }

  @override
  Widget build(BuildContext context) {
    final api = context.watch<ApiService>();
    final username = api.username ?? 'Gość';
    final initialChar = (api.username != null && api.username!.isNotEmpty) ? api.username![0].toUpperCase() : 'G';
    final df = DateFormat.yMMMMd('pl');

    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(radius: 16, child: Text(initialChar)),
          const SizedBox(width: 12),
          Expanded(child: Text('Witaj, $username')),
        ]),
        actions: [
          IconButton(icon: const Icon(Icons.bookmark), onPressed: () => Navigator.pushNamed(context, '/jobs', arguments: {'saved': true})),
          IconButton(icon: const Icon(Icons.work), onPressed: () => Navigator.pushNamed(context, '/jobs')),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              Expanded(
                child: TextField(
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: 'Szukaj stanowisk, firm, miejscowości...',
                    filled: true,
                    fillColor: Theme.of(context).cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: _onSearchSubmitted,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () => _onSearchSubmitted(_query),
                child: const Padding(padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12), child: Text('Szukaj')),
              )
            ]),
          ),
        ),
      ),
      drawer: Drawer(
        child: ListView(padding: EdgeInsets.zero, children: [
          UserAccountsDrawerHeader(
            currentAccountPicture: const CircleAvatar(child: Icon(Icons.person)),
            accountName: Text(api.isLoggedIn ? (api.username ?? 'Użytkownik') : 'Gość'),
            accountEmail: Text(api.isLoggedIn ? 'Konto aktywne' : 'Zaloguj się, aby aplikować'),
          ),
          ListTile(leading: const Icon(Icons.home), title: const Text('Strona główna'), onTap: () => Navigator.pushReplacementNamed(context, '/jobs')),
          ListTile(leading: const Icon(Icons.bookmark), title: const Text('Zapisane'), onTap: () => Navigator.pushNamed(context, '/jobs', arguments: {'saved': true})),
          ListTile(leading: const Icon(Icons.settings), title: const Text('Ustawienia'), onTap: () => Navigator.pushNamed(context, '/settings')),
        ]),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                _sectionTitle('Szybkie filtry'),
                const SizedBox(height: 8),
                _quickFilters(),
                const SizedBox(height: 16),
                _sectionTitle('Polecane firmy'),
                const SizedBox(height: 8),
                _buildCompaniesRow(),
                const SizedBox(height: 16),
                _sectionTitle('Polecane oferty'),
                const SizedBox(height: 8),
                _buildFeaturedCarousel(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.list),
                    label: const Text('Zobacz wszystkie oferty'),
                    onPressed: () => Navigator.pushNamed(context, '/jobs'),
                  ),
                ),
                const SizedBox(height: 24),
                Text('Aktualizacja: ${df.format(DateTime.now())}', style: Theme.of(context).textTheme.bodySmall),
              ]),
            ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.my_location),
        onPressed: () async {
          try {
            final permission = await Geolocator.checkPermission();
            if (permission == LocationPermission.denied) {
              final req = await Geolocator.requestPermission();
              if (req == LocationPermission.denied || req == LocationPermission.deniedForever) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak zgody na lokalizację')));
                return;
              }
            }
            final pos = await Geolocator.getCurrentPosition();
            final lat = pos.latitude;
            final lon = pos.longitude;
            final withCoords = _featured.where((j) => j.latitude != null && j.longitude != null).toList();
            if (withCoords.isNotEmpty) {
              if (!mounted) return;
              Navigator.push(context, MaterialPageRoute(builder: (_) => Scaffold(appBar: AppBar(title: const Text('W pobliżu')), body: JobsMapView(jobs: withCoords, initialLat: lat, initialLon: lon, initialZoom: 12))));
            } else {
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Brak ofert z lokalizacją')));
            }
          } catch (e) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Błąd uzyskania lokalizacji')));
          }
        },
      ),
    );
  }

  Widget _sectionTitle(String title) => Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold));

  Widget _quickFilters() {
    final items = [
      _QuickFilterItem(Icons.home_work, 'W biurze'),
      _QuickFilterItem(Icons.laptop_chromebook, 'Zdalnie'),
      _QuickFilterItem(Icons.star, 'Najlepsze'),
      _QuickFilterItem(Icons.new_releases, 'Najnowsze'),
    ];
    return Row(
      children: items
          .map((it) => Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  child: OutlinedButton.icon(
                    icon: Icon(it.icon),
                    label: Text(it.label),
                    onPressed: () => Navigator.pushNamed(context, '/jobs', arguments: {'filter': it.label}),
                  ),
                ),
              ))
          .toList(),
    );
  }

  Widget _buildCompaniesRow() {
    final firms = <String>{};
    for (final j in _featured) {
      if (j.company.isNotEmpty) firms.add(j.company);
    }
    final list = firms.toList();
    if (list.isEmpty) return const SizedBox.shrink();
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: list.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final name = list[i];
          return GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/jobs', arguments: {'company': name}),
            child: Chip(label: Text(name), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
          );
        },
      ),
    );
  }

  Widget _buildFeaturedCarousel() {
    if (_featured.isEmpty) return Container(height: 160, alignment: Alignment.center, child: const Text('Brak polecanych ofert.'));
    return SizedBox(
      height: 160,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _featured.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (ctx, i) {
          final j = _featured[i];
          return SizedBox(
            width: 300,
            child: Card(
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: InkWell(
                onTap: () => Navigator.pushNamed(ctx, '/detail', arguments: j),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(j.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    if (j.company.isNotEmpty) Text(j.company, style: const TextStyle(color: Colors.blueGrey)),
                    const Spacer(),
                    Row(children: [const Icon(Icons.place, size: 14, color: Colors.redAccent), const SizedBox(width: 6), Expanded(child: Text(j.location, maxLines: 1, overflow: TextOverflow.ellipsis))]),
                  ]),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _QuickFilterItem {
  final IconData icon;
  final String label;
  _QuickFilterItem(this.icon, this.label);
}
