import 'package:hive/hive.dart';


@HiveType(typeId: 0)
class JobOffer extends HiveObject {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String company;

  @HiveField(3)
  final String description;

  @HiveField(4)
  final String address;

  @HiveField(5)
  final String location;

  @HiveField(6)
  final String city;

  @HiveField(7)
  final String region;

  @HiveField(8)
  final bool isRemote;

  @HiveField(9)
  final double? latitude;

  @HiveField(10)
  final double? longitude;

  @HiveField(11)
  final int? salaryMin;

  @HiveField(12)
  final int? salaryMax;

  @HiveField(13)
  final DateTime? postedAt;

  @HiveField(14)
  final DateTime? fetchedAt;

  @HiveField(15)
  final List<String> contractTypes;

  @HiveField(16)
  final String workTime;

  @HiveField(17)
  final List<String> requirements;

  @HiveField(18)
  final List<String> duties;

  @HiveField(19)
  final List<String> benefits;

  @HiveField(20)
  final String? companyLogoUrl;

  @HiveField(21)
  final String? companyWebsite;

  JobOffer({
    required this.id,
    required this.title,
    required this.company,
    required this.description,
    this.address = '',
    this.location = '',
    this.city = '',
    this.region = '',
    this.isRemote = false,
    this.latitude,
    this.longitude,
    this.salaryMin,
    this.salaryMax,
    this.postedAt,
    this.fetchedAt,
    this.contractTypes = const [],
    this.workTime = '',
    this.requirements = const [],
    this.duties = const [],
    this.benefits = const [],
    this.companyLogoUrl,
    this.companyWebsite,
  });

  factory JobOffer.fromMap(Map<String, dynamic> m, {DateTime? fetchedAt}) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      try {
        return DateTime.parse(v.toString());
      } catch (_) {
        return null;
      }
    }

    return JobOffer(
      id: m['id'] is int ? m['id'] as int : int.parse((m['id'] ?? '0').toString()),
      title: (m['title'] ?? '').toString(),
      company: (m['company'] ?? '').toString(),
      description: (m['description'] ?? '').toString(),
      address: (m['address'] ?? '').toString(),
      location: (m['location'] ?? '').toString(),
      city: (m['city'] ?? '').toString(),
      region: (m['region'] ?? '').toString(),
      isRemote: (m['is_remote'] ?? false) as bool,
      latitude: m['latitude'] != null ? (m['latitude'] as num).toDouble() : null,
      longitude: m['longitude'] != null ? (m['longitude'] as num).toDouble() : null,
      salaryMin: m['salary_min'] != null ? int.tryParse(m['salary_min'].toString()) : null,
      salaryMax: m['salary_max'] != null ? int.tryParse(m['salary_max'].toString()) : null,
      postedAt: parseDate(m['posted_at']),
      fetchedAt: fetchedAt ?? DateTime.now(),
      contractTypes: (m['contract_types'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      workTime: (m['work_time'] ?? '').toString(),
      requirements: (m['requirements'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      duties: (m['duties'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      benefits: (m['benefits'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      companyLogoUrl: (m['company_logo_url'] ?? m['companyLogoUrl'])?.toString(),
      companyWebsite: (m['company_website'] ?? m['companyWebsite'])?.toString(),
    );
  }
}
