from rest_framework import viewsets, permissions, filters, status
from rest_framework.decorators import action, api_view, permission_classes
from rest_framework.response import Response
from django_filters import rest_framework as df
from django.core.files.base import ContentFile
from django.core.files.storage import default_storage
from django.conf import settings
from pathlib import Path
import json

from .models import Job
from .serializers import JobSerializer
from .utils import haversine_km

class JobFilter(df.FilterSet):
    city = df.CharFilter(field_name='city', lookup_expr='icontains')
    region = df.CharFilter(field_name='region', lookup_expr='icontains')
    is_remote = df.BooleanFilter(field_name='is_remote')
    min_salary = df.NumberFilter(field_name='salary_min', lookup_expr='gte')
    max_salary = df.NumberFilter(field_name='salary_max', lookup_expr='lte')

    class Meta:
        model = Job
        fields = ['city', 'region', 'is_remote']

class JobViewSet(viewsets.ReadOnlyModelViewSet):
    queryset = Job.objects.all().order_by('-created_at')
    serializer_class = JobSerializer
    permission_classes = [permissions.AllowAny]
    filterset_class = JobFilter
    filter_backends = [df.DjangoFilterBackend, filters.SearchFilter, filters.OrderingFilter]
    search_fields = ['title', 'company', 'city', 'region', 'description']
    ordering_fields = ['created_at', 'posted_at', 'salary_min', 'salary_max']

    def list(self, request, *args, **kwargs):
        queryset = self.filter_queryset(self.get_queryset())

        # Dodatkowy filtr: promień od wybranego miasta (?city=Poznań&radius_km=25)
        city_name = request.query_params.get('city')
        radius_km = request.query_params.get('radius_km')
        if city_name and radius_km:
            try:
                radius = float(radius_km)
            except ValueError:
                radius = None
            if radius and radius > 0:
                base_dir = Path(settings.BASE_DIR)
                cities_path = base_dir / 'jobs' / 'data' / 'cities.json'
                if cities_path.exists():
                    with cities_path.open('r', encoding='utf-8') as f:
                        cities = json.load(f)
                    city = next((c for c in cities if c['name'].lower() == city_name.lower()), None)
                    if city:
                        clat, clon = float(city['lat']), float(city['lon'])
                        in_radius_ids = []
                        for j in queryset:
                            if j.latitude is None or j.longitude is None:
                                continue
                            d = haversine_km(clat, clon, j.latitude, j.longitude)
                            if d is not None and d <= radius:
                                in_radius_ids.append(j.id)
                        queryset = queryset.filter(id__in=in_radius_ids)

        page = self.paginate_queryset(queryset)
        if page is not None:
            ser = self.get_serializer(page, many=True)
            return self.get_paginated_response(ser.data)
        ser = self.get_serializer(queryset, many=True)
        return Response(ser.data)

    @action(detail=False, methods=['get'], url_path='featured', permission_classes=[permissions.AllowAny])
    def featured(self, request):
        qs = Job.objects.all().order_by('-salary_max', '-posted_at', '-created_at')[:10]
        return Response(self.get_serializer(qs, many=True).data, status=status.HTTP_200_OK)

    @action(detail=False, methods=['get'], url_path='nearby', permission_classes=[permissions.AllowAny])
    def nearby(self, request):
        # /api/jobs/nearby/?lat=...&lon=...&radius_km=...
        try:
            lat = float(request.query_params.get('lat'))
            lon = float(request.query_params.get('lon'))
            radius = float(request.query_params.get('radius_km', 10))
        except (TypeError, ValueError):
            return Response({'detail': 'lat, lon, radius_km są wymagane i muszą być liczbami'}, status=400)

        ids = []
        for j in Job.objects.exclude(latitude__isnull=True).exclude(longitude__isnull=True):
            d = haversine_km(lat, lon, j.latitude, j.longitude)
            if d is not None and d <= radius:
                ids.append(j.id)
        qs = Job.objects.filter(id__in=ids).order_by('-posted_at', '-created_at')
        return Response(self.get_serializer(qs, many=True).data, status=200)

    @action(detail=True, methods=['post'], url_path='apply')
    def apply(self, request, pk=None):
        job = self.get_object()
        name = request.data.get('name', '').strip()
        email = request.data.get('email', '').strip()
        phone = request.data.get('phone', '').strip()
        message = request.data.get('message', '').strip()

        if not name or not email or not phone:
            return Response({'detail': 'Brakuje pól wymaganych'}, status=status.HTTP_400_BAD_REQUEST)

        file_info = None
        if 'file' in request.FILES:
            f = request.FILES['file']
            if f.size > 5 * 1024 * 1024:
                return Response({'detail': 'Plik zbyt duży (max 5 MB)'}, status=status.HTTP_400_BAD_REQUEST)
            path = default_storage.save(f'job_apps/{job.id}/{f.name}', ContentFile(f.read()))
            file_info = {'name': f.name, 'path': path}

        return Response({
            'status': 'ok',
            'job_id': job.id,
            'name': name,
            'email': email,
            'phone': phone,
            'message': message or None,
            'file': file_info,
        }, status=status.HTTP_201_CREATED)

@api_view(['GET'])
@permission_classes([permissions.AllowAny])
def cities_list(request):
    base_dir = Path(settings.BASE_DIR)
    cities_path = base_dir / 'jobs' / 'data' / 'cities.json'
    if not cities_path.exists():
        return Response([], status=200)
    with cities_path.open('r', encoding='utf-8') as f:
        return Response(json.load(f), status=200)
