import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter/services.dart';

import '../api_service.dart';

enum SortBy { relevance, newest, salaryHigh, salaryLow }

class AdvancedSearchResult {
  final String query;
  final String? city;
  final int radiusKm;
  final bool remoteOnly;
  final int? salaryMin;
  final int? salaryMax;
  final List<String> contractTypes;
  final SortBy sortBy;

  AdvancedSearchResult({
    required this.query,
    this.city,
    required this.radiusKm,
    required this.remoteOnly,
    this.salaryMin,
    this.salaryMax,
    this.contractTypes = const [],
    this.sortBy = SortBy.relevance,
  });

  Map<String, dynamic> toMap() => {
        'q': query,
        'city': city,
        'radius_km': radiusKm,
        'remote_only': remoteOnly,
        'salary_min': salaryMin,
        'salary_max': salaryMax,
        'contracts': contractTypes,
        'sort': sortBy.name,
      };

  String shortLabel() {
    final parts = <String>[];
    if (query.isNotEmpty) parts.add(query);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (remoteOnly) parts.add('zdalnie');
    if (salaryMin != null || salaryMax != null) parts.add('${salaryMin ?? '—'}–${salaryMax ?? '—'} PLN');
    return parts.join(' • ');
  }
}

class AdvancedSearch extends StatefulWidget {
  final String initialQuery;
  final String? initialCity;
  final int initialRadiusKm;
  final bool initialRemoteOnly;
  final int? initialSalaryMin;
  final int? initialSalaryMax;
  final List<String> initialContractTypes;
  final SortBy initialSort;
  final void Function(AdvancedSearchResult result)? onApply;
  final void Function(AdvancedSearchResult result)? onPreview;
  final bool compact;

  const AdvancedSearch({
    super.key,
    this.initialQuery = '',
    this.initialCity,
    this.initialRadiusKm = 25,
    this.initialRemoteOnly = false,
    this.initialSalaryMin,
    this.initialSalaryMax,
    this.initialContractTypes = const [],
    this.initialSort = SortBy.relevance,
    this.onApply,
    this.onPreview,
    this.compact = false,
  });

  @override
  State<AdvancedSearch> createState() => _AdvancedSearchState();
}

class _AdvancedSearchState extends State<AdvancedSearch> {
  late TextEditingController _qCtl;
  late TextEditingController _cityCtl;
  int _radius = 25;
  bool _remoteOnly = false;
  int? _salaryMin;
  int? _salaryMax;
  List<String> _contracts = [];
  SortBy _sort = SortBy.relevance;

  List<String> _citySuggestions = [];
  bool _loadingCities = false;
  Timer? _debounce;

  // Presets stored in Hive box 'search_presets'
  Box<dynamic>? _presetsBox;
  List<Map<String, dynamic>> _presets = [];

  final List<String> _availableContracts = ['umowa o pracę', 'umowa zlecenie', 'umowa o dzieło', 'B2B', 'praktyki'];

  // local cities loaded from assets (optional)
  List<String> _localCities = [];
  bool _citiesLoaded = false;

  @override
  void initState() {
    super.initState();
    _qCtl = TextEditingController(text: widget.initialQuery);
    _cityCtl = TextEditingController(text: widget.initialCity ?? '');
    _radius = widget.initialRadiusKm;
    _remoteOnly = widget.initialRemoteOnly;
    _salaryMin = widget.initialSalaryMin;
    _salaryMax = widget.initialSalaryMax;
    _contracts = List.from(widget.initialContractTypes);
    _sort = widget.initialSort;
    _cityCtl.addListener(_onCityChangedDebounced);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initPresets();
      _initCitiesFromAssets();
    });
  }

  Future<void> _initPresets() async {
    await Hive.initFlutter(); // safe no-op if already initialized
    _presetsBox = await Hive.openBox('search_presets');
    final raw = _presetsBox!.get('presets', defaultValue: <Map<String, dynamic>>[]);
    try {
      _presets = List<Map<String, dynamic>>.from(raw as List<dynamic>);
    } catch (_) {
      _presets = [];
    }
    if (mounted) setState(() {});
  }

  Future<void> _initCitiesFromAssets() async {
    try {
      final data = await rootBundle.loadString('assets/cities_pl.json');
      final List<dynamic> parsed = jsonDecode(data) as List<dynamic>;
      _localCities = parsed.map((e) => e.toString()).toList();
      _citiesLoaded = true;
    } catch (_) {
      _localCities = [];
      _citiesLoaded = true;
    }
  }

  @override
  void dispose() {
    _qCtl.dispose();
    _cityCtl.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onCityChangedDebounced() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _fetchCitySuggestions(_cityCtl.text.trim()));
  }

  Future<void> _fetchCitySuggestions(String q) async {
    if (q.isEmpty) {
      if (mounted) setState(() => _citySuggestions = []);
      return;
    }
    if (mounted) setState(() => _loadingCities = true);

    try {
      final api = context.read<ApiService>();
      // 1) try backend suggestCities
      try {
        final backend = await api.suggestCities(q, limit: 12);
        if (backend.isNotEmpty) {
          if (!mounted) return;
          setState(() {
            _citySuggestions = backend;
            _loadingCities = false;
          });
          return;
        }
      } catch (_) {
        // ignore backend errors and fallback
      }

      // 2) fallback to local assets if loaded
      if (_citiesLoaded && _localCities.isNotEmpty) {
        final low = q.toLowerCase();
        final starts = _localCities.where((c) => c.toLowerCase().startsWith(low)).toList();
        final contains = _localCities.where((c) => !c.toLowerCase().startsWith(low) && c.toLowerCase().contains(low)).toList();
        final merged = [...starts, ...contains];
        final limited = merged.take(12).toList();
        if (!mounted) return;
        setState(() {
          _citySuggestions = limited;
          _loadingCities = false;
        });
        return;
      }

      // 3) small hardcoded fallback
      final allCities = <String>[
        'Warszawa','Kraków','Łódź','Wrocław','Poznań','Gdańsk','Szczecin','Bydgoszcz','Lublin','Białystok',
        'Katowice','Gdynia','Częstochowa','Radom','Sosnowiec','Toruń','Kielce','Rzeszów','Gliwice','Zabrze',
        'Olsztyn','Bielsko-Biała','Rybnik','Ruda Śląska','Opole','Tarnów','Gorzów Wielkopolski','Dąbrowa Górnicza',
        'Płock','Elbląg','Wałbrzych','Włocławek','Zielona Góra','Tychy','Koszalin','Kalisz','Legnica','Grudziądz',
        'Słupsk','Jaworzno','Jastrzębie-Zdrój','Nowy Sącz','Siedlce','Przemyśl','Stalowa Wola','Ostrołęka','Puławy',
        'Świnoujście','Nysa','Ciechanów','Sanok','Konin','Piła','Chorzów','Nowy Targ','Suwałki','Świdnica'
      ];
      final fallback = allCities.where((c) => c.toLowerCase().contains(q.toLowerCase())).take(12).toList();
      if (!mounted) return;
      setState(() {
        _citySuggestions = fallback;
        _loadingCities = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _citySuggestions = [];
        _loadingCities = false;
      });
    }
  }

  void _toggleContract(String name) {
    setState(() {
      if (_contracts.contains(name))
        _contracts.remove(name);
      else
        _contracts.add(name);
    });
  }

  void _clearContracts() => setState(() => _contracts.clear());

  AdvancedSearchResult _buildResult() => AdvancedSearchResult(
        query: _qCtl.text.trim(),
        city: _cityCtl.text.trim().isEmpty ? null : _cityCtl.text.trim(),
        radiusKm: _radius,
        remoteOnly: _remoteOnly,
        salaryMin: _salaryMin,
        salaryMax: _salaryMax,
        contractTypes: List.from(_contracts),
        sortBy: _sort,
      );

  Future<void> _apply() async {
    final result = _buildResult();
    // optionally call backend search via ApiService.search(result.toMap())
    try {
      final api = context.read<ApiService>();
      await api.search(result.toMap());
    } catch (_) {}
    widget.onApply?.call(result);
  }

  void _preview() {
    final result = _buildResult();
    widget.onPreview?.call(result);
  }

  Future<void> _savePreset(String name) async {
    final result = _buildResult();
    final map = {'name': name, 'params': result.toMap()};
    _presets.insert(0, map);
    await _presetsBox?.put('presets', _presets);
    if (mounted) setState(() {});
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Zapisano preset')));
  }

  Future<void> _loadPreset(int index) async {
    if (index < 0 || index >= _presets.length) return;
    final p = _presets[index];
    final params = (p['params'] ?? {}) as Map<String, dynamic>;
    setState(() {
      _qCtl.text = (params['q'] ?? '') as String;
      _cityCtl.text = (params['city'] ?? '') as String;
      _radius = (params['radius_km'] ?? 25) as int;
      _remoteOnly = params['remote_only'] as bool? ?? false;
      _salaryMin = params['salary_min'] as int?;
      _salaryMax = params['salary_max'] as int?;
      _contracts = List<String>.from(params['contracts'] as List<dynamic>? ?? []);
      _sort = SortBy.values.firstWhere((s) => s.name == (params['sort'] ?? SortBy.relevance.name), orElse: () => SortBy.relevance);
    });
  }

  Future<void> _removePreset(int index) async {
    if (index < 0 || index >= _presets.length) return;
    _presets.removeAt(index);
    await _presetsBox?.put('presets', _presets);
    if (mounted) setState(() {});
  }

  Widget _buildCompact() {
    return Row(children: [
      Expanded(
        child: TextField(
          controller: _qCtl,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _apply(),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Szukaj...'),
        ),
      ),
      const SizedBox(width: 8),
      IconButton(icon: const Icon(Icons.mic), onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Voice not implemented')))),
      ElevatedButton(onPressed: _apply, child: const Text('Szukaj')),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) return _buildCompact();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Query + actions
        Row(children: [
          Expanded(
            child: TextField(
              controller: _qCtl,
              decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Stanowisko, umiejętności, firma...'),
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _apply(),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton.icon(onPressed: _apply, icon: const Icon(Icons.search), label: const Text('Szukaj')),
          const SizedBox(width: 8),
          OutlinedButton.icon(onPressed: _preview, icon: const Icon(Icons.visibility), label: const Text('Podgląd')),
        ]),
        const SizedBox(height: 12),

        // Location row
        Row(children: [
          Expanded(
            flex: 3,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Miasto / lokalizacja'),
              const SizedBox(height: 6),
              Stack(children: [
                TextField(
                  controller: _cityCtl,
                  decoration: InputDecoration(prefixIcon: const Icon(Icons.place), hintText: 'np. Poznań', suffixIcon: _loadingCities ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) : null),
                ),
                if (_citySuggestions.isNotEmpty)
                  Positioned(
                    top: 48,
                    left: 0,
                    right: 0,
                    child: Material(
                      elevation: 6,
                      borderRadius: BorderRadius.circular(8),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _citySuggestions.length,
                        itemBuilder: (_, i) {
                          final s = _citySuggestions[i];
                          return ListTile(
                            title: Text(s),
                            onTap: () {
                              _cityCtl.text = s;
                              setState(() => _citySuggestions = []);
                            },
                          );
                        },
                      ),
                    ),
                  ),
              ]),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Promień (km)'),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: Slider(
                    value: _radius.toDouble(),
                    min: 5,
                    max: 200,
                    divisions: 39,
                    label: '$_radius km',
                    onChanged: (v) => setState(() => _radius = v.round()),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$_radius km', style: const TextStyle(fontWeight: FontWeight.bold)),
              ]),
              Row(children: [
                const Text('Tylko zdalne'),
                const Spacer(),
                Switch(value: _remoteOnly, onChanged: (v) => setState(() => _remoteOnly = v)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 12),

        // Salary range
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Wynagrodzenie (PLN)'),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Min', prefixText: ''),
                onChanged: (v) => setState(() => _salaryMin = int.tryParse(v)),
                controller: TextEditingController(text: _salaryMin?.toString() ?? ''),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Max', prefixText: ''),
                onChanged: (v) => setState(() => _salaryMax = int.tryParse(v)),
                controller: TextEditingController(text: _salaryMax?.toString() ?? ''),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            const Text('Szybkie przedziały:'),
            const SizedBox(width: 8),
            Wrap(spacing: 8, children: [
              ActionChip(label: const Text('0–30000'), onPressed: () => setState(() { _salaryMin = 0; _salaryMax = 30000; })),
              ActionChip(label: const Text('30000–60000'), onPressed: () => setState(() { _salaryMin = 30000; _salaryMax = 60000; })),
              ActionChip(label: const Text('60000+'), onPressed: () => setState(() { _salaryMin = 60000; _salaryMax = null; })),
              ActionChip(label: const Text('Wyczyść'), onPressed: () => setState(() { _salaryMin = null; _salaryMax = null; })),
            ]),
          ]),
        ]),
        const SizedBox(height: 12),

        // Contracts multi-select
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Typ umowy'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _availableContracts.map((c) {
              final selected = _contracts.contains(c);
              return FilterChip(
                label: Text(c),
                selected: selected,
                onSelected: (_) => _toggleContract(c),
              );
            }).toList(),
          ),
          const SizedBox(height: 6),
          Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _clearContracts, child: const Text('Wyczyść'))),
        ]),
        const SizedBox(height: 12),

        // Sort + presets
        Row(children: [
          Expanded(
            child: DropdownButtonFormField<SortBy>(
              value: _sort,
              items: const [
                DropdownMenuItem(value: SortBy.relevance, child: Text('Trafność')),
                DropdownMenuItem(value: SortBy.newest, child: Text('Najnowsze')),
                DropdownMenuItem(value: SortBy.salaryHigh, child: Text('Wynagrodzenie: malejąco')),
                DropdownMenuItem(value: SortBy.salaryLow, child: Text('Wynagrodzenie: rosnąco')),
              ],
              onChanged: (v) => setState(() => _sort = v ?? SortBy.relevance),
              decoration: const InputDecoration(labelText: 'Sortuj'),
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            icon: const Icon(Icons.save),
            label: const Text('Zapisz preset'),
            onPressed: () async {
              final nameCtl = TextEditingController();
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Zapisz preset'),
                  content: TextField(controller: nameCtl, decoration: const InputDecoration(hintText: 'Nazwa presetu')),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Anuluj')),
                    ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Zapisz')),
                  ],
                ),
              );
              if (ok == true && nameCtl.text.trim().isNotEmpty) {
                await _savePreset(nameCtl.text.trim());
              }
            },
          ),
        ]),
        const SizedBox(height: 12),

        // Presets list
        if (_presets.isNotEmpty)
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Presets'),
            const SizedBox(height: 8),
            SizedBox(
              height: 96,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final p = _presets[i];
                  final name = p['name'] as String? ?? 'Preset';
                  final params = p['params'] as Map<String, dynamic>? ?? {};
                  final label = (params['q'] ?? '') as String;
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(label.isNotEmpty ? label : (params['city'] ?? ''), maxLines: 2, overflow: TextOverflow.ellipsis),
                        const Spacer(),
                        Row(children: [
                          IconButton(icon: const Icon(Icons.play_arrow), onPressed: () => _loadPreset(i)),
                          IconButton(icon: const Icon(Icons.delete), onPressed: () => _removePreset(i)),
                        ])
                      ]),
                    ),
                  );
                },
              ),
            ),
          ]),

        const SizedBox(height: 16),

        // Footer buttons
        Row(children: [
          Expanded(child: OutlinedButton(onPressed: () => Navigator.maybePop(context), child: const Text('Anuluj'))),
          const SizedBox(width: 12),
          Expanded(child: ElevatedButton.icon(onPressed: _apply, icon: const Icon(Icons.check), label: const Text('Zastosuj'))),
        ]),
      ]),
    );
  }
}
