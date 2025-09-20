from django.db import models

class Job(models.Model):
    title = models.CharField(max_length=255, default='', blank=True)
    company = models.CharField(max_length=255, default='', blank=True)
    address = models.CharField(max_length=255, default='', blank=True)
    city = models.CharField(max_length=120, default='', blank=True)
    region = models.CharField(max_length=120, default='', blank=True)
    location = models.CharField(max_length=255, default='', blank=True)
    latitude = models.FloatField(null=True, blank=True)
    longitude = models.FloatField(null=True, blank=True)
    is_remote = models.BooleanField(default=False)
    salary_text = models.CharField(max_length=255, default='', blank=True)
    salary_min = models.IntegerField(null=True, blank=True)
    salary_max = models.IntegerField(null=True, blank=True)
    currency = models.CharField(max_length=10, default='PLN', blank=True)
    contract_types = models.JSONField(default=list, blank=True, null=True)
    work_time = models.CharField(max_length=120, default='', blank=True)
    posted_at = models.DateField(null=True, blank=True)
    duties = models.JSONField(default=list, blank=True, null=True)
    requirements = models.JSONField(default=list, blank=True, null=True)
    benefits = models.JSONField(default=list, blank=True, null=True)
    description = models.TextField(default='', blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    def save(self, *args, **kwargs):
        if not self.location:
            bits = [b for b in [self.city, self.region] if b]
            self.location = ', '.join(bits)
        super().save(*args, **kwargs)

    def __str__(self):
        return f'{self.title} @ {self.company}'.strip()
