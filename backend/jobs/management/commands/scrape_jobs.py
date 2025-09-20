from django.core.management.base import BaseCommand
from jobs.models import Job
from .scraper import scrape_job

class Command(BaseCommand):
    help = "Scrapuje pojedynczą ofertę i zapisuje do bazy. Użycie: --url <link>"

    def add_arguments(self, parser):
        parser.add_argument('--url', type=str, required=True, help='URL oferty')
        parser.add_argument('--source', type=str, default='pracuj.pl', help='Nazwa źródła (opcjonalnie)')

    def handle(self, *args, **options):
        url = options['url']
        source = options['source']

        data = scrape_job(url, source_name=source)
        if not data:
            self.stdout.write(self.style.ERROR("Scraper nie zwrócił danych. Sprawdź debug_offer.html."))
            return

        job, created = Job.objects.update_or_create(
            source_url=data.get('source_url', url),
            defaults=data
        )
        if created:
            self.stdout.write(self.style.SUCCESS(f"Dodano ofertę: {job.title or '(bez tytułu)'}"))
        else:
            self.stdout.write(self.style.WARNING(f"Zaktualizowano ofertę: {job.title or '(bez tytułu)'}"))
