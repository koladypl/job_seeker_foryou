from django.core.management.base import BaseCommand
from jobs.models import Job

class Command(BaseCommand):
    help = "Naprawia pola JSONField w modelu Job, ustawiając [] tam, gdzie są niepoprawne wartości."

    def handle(self, *args, **options):
        updated_count = 0
        for job in Job.objects.all():
            changed = False

            if not isinstance(job.requirements, list):
                job.requirements = []
                changed = True

            if not isinstance(job.duties, list):
                job.duties = []
                changed = True

            if not isinstance(job.benefits, list):
                job.benefits = []
                changed = True

            if not isinstance(job.contract_types, list):
                job.contract_types = []
                changed = True

            if changed:
                job.save(update_fields=['requirements', 'duties', 'benefits', 'contract_types'])
                updated_count += 1

        self.stdout.write(self.style.SUCCESS(f"Zaktualizowano {updated_count} rekordów Job."))
