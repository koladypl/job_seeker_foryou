from rest_framework import serializers
from .models import Job

class JobSerializer(serializers.ModelSerializer):
    class Meta:
        model = Job
        fields = [
            'id', 'title', 'company',
            'address', 'city', 'region', 'location', 'latitude', 'longitude', 'is_remote',
            'salary_text', 'salary_min', 'salary_max', 'currency',
            'contract_types', 'work_time', 'posted_at',
            'duties', 'requirements', 'benefits',
            'description', 'created_at', 'updated_at',
        ]
