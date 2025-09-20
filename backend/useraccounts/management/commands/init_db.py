import os
from django.core.management.base import BaseCommand
from django.core.management import call_command
from django.contrib.auth import get_user_model

class Command(BaseCommand):
    help = 'Run migrations and optionally create a superuser from environment variables.'

    def handle(self, *args, **options):
        self.stdout.write(self.style.WARNING('Running makemigrations...'))
        call_command('makemigrations', interactive=False)
        self.stdout.write(self.style.WARNING('Running migrate...'))
        call_command('migrate', interactive=False)

        username = os.getenv('DJANGO_SUPERUSER_USERNAME')
        email = os.getenv('DJANGO_SUPERUSER_EMAIL', '')
        password = os.getenv('DJANGO_SUPERUSER_PASSWORD')

        if username and password:
            User = get_user_model()
            if not User.objects.filter(username=username).exists():
                self.stdout.write(self.style.WARNING(f'Creating superuser {username}...'))
                User.objects.create_superuser(username=username, email=email, password=password)
                self.stdout.write(self.style.SUCCESS('Superuser created.'))
            else:
                self.stdout.write(self.style.NOTICE('Superuser already exists.'))
        else:
            self.stdout.write(self.style.NOTICE('No superuser env vars provided. Skipping superuser creation.'))
