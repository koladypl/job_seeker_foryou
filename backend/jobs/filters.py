import django_filters
from django.db.models import JSONField
from .models import Job

class JobFilter(django_filters.FilterSet):
    class Meta:
        model = Job
        fields = [
            'city',
            'region',
            'is_remote',
            'is_archived',
            'salary_min',
            'salary_max',
            'contract_types',
        ]
        filter_overrides = {
            JSONField: {
                'filter_class': django_filters.CharFilter,
                'extra': lambda f: {'lookup_expr': 'icontains'},
            },
        }
