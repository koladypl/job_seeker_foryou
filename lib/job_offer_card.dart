import 'package:flutter/material.dart';
import '../job_offer.dart';
import 'package:intl/intl.dart';

class JobOfferCard extends StatelessWidget {
  final JobOffer job;
  final String? query;
  final VoidCallback? onDetails;
  final VoidCallback? onApply;
  final VoidCallback? onShare;

  const JobOfferCard({
    super.key,
    required this.job,
    this.query,
    this.onDetails,
    this.onApply,
    this.onShare,
  });

  Widget _logo(BuildContext ctx) {
    if (job.companyLogoUrl != null && job.companyLogoUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.network(job.companyLogoUrl!, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (_, __, ___) {
          return _avatarFallback(ctx);
        }),
      );
    }
    return _avatarFallback(ctx);
  }

  Widget _avatarFallback(BuildContext ctx) {
    final c = Theme.of(ctx).colorScheme;
    final first = (job.company.isNotEmpty ? job.company[0].toUpperCase() : '?');
    return CircleAvatar(radius: 28, backgroundColor: c.primaryContainer, child: Text(first, style: TextStyle(color: c.onPrimaryContainer, fontWeight: FontWeight.bold)));
  }

  String _salaryText() {
    if (job.salaryMin == null && job.salaryMax == null) return '';
    if (job.salaryMin != null && job.salaryMax != null) return '${job.salaryMin} – ${job.salaryMax} PLN';
    if (job.salaryMin != null) return 'od ${job.salaryMin} PLN';
    return 'do ${job.salaryMax} PLN';
  }

  InlineSpan _highlightedText(String text, String? q, TextStyle normal) {
    if (q == null || q.trim().isEmpty) return TextSpan(text: text, style: normal);
    final low = text.toLowerCase();
    final token = q.toLowerCase();
    final idx = low.indexOf(token);
    if (idx < 0) return TextSpan(text: text, style: normal);
    return TextSpan(children: [
      TextSpan(text: text.substring(0, idx), style: normal),
      TextSpan(text: text.substring(idx, idx + token.length), style: normal.copyWith(fontWeight: FontWeight.bold)),
      TextSpan(text: text.substring(idx + token.length), style: normal),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final df = DateFormat.yMMMMd('pl');
    final salary = _salaryText();
    final subtitleStyle = Theme.of(context).textTheme.bodyMedium!;
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _logo(context),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              RichText(text: _highlightedText(job.title, query, Theme.of(context).textTheme.titleSmall ?? const TextStyle(fontSize: 16))),
              const SizedBox(height: 6),
              Row(children: [
                if (job.company.isNotEmpty) Expanded(child: Text(job.company, style: subtitleStyle.copyWith(color: Colors.blueGrey))),
                if (job.isRemote) Container(margin: const EdgeInsets.only(left: 6), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(16)), child: Text('Zdalnie', style: TextStyle(color: Colors.green.shade800, fontSize: 12))),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                const Icon(Icons.place, size: 14, color: Colors.redAccent),
                const SizedBox(width: 6),
                Expanded(child: Text(job.location.isNotEmpty ? job.location : (job.address.isNotEmpty ? job.address : ''), style: subtitleStyle)),
                if (salary.isNotEmpty)
                  Container(margin: const EdgeInsets.only(left: 8), padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)), child: Text(salary, style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w600))),
              ]),
              const SizedBox(height: 8),
              Text(job.description.isNotEmpty ? (job.description.length > 120 ? '${job.description.substring(0, 120)}…' : job.description) : 'Brak opisu', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 10),
              Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                Text('Opublikowano: ${job.postedAt != null ? df.format(job.postedAt!) : (job.fetchedAt != null ? df.format(job.fetchedAt!) : '')}', style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(width: 12),
                TextButton.icon(onPressed: onDetails, icon: const Icon(Icons.info_outline), label: const Text('Szczegóły')),
                const SizedBox(width: 6),
                ElevatedButton.icon(onPressed: onApply, icon: const Icon(Icons.send), label: const Text('Aplikuj')),
                const SizedBox(width: 6),
                IconButton(onPressed: onShare, icon: const Icon(Icons.share)),
              ])
            ]),
          ),
        ]),
      ),
    );
  }
}
