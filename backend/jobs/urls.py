from django.urls import path, include
from rest_framework.routers import DefaultRouter
from .views import JobViewSet, cities_list

router = DefaultRouter()
router.register(r'jobs', JobViewSet, basename='job')

urlpatterns = [
    path('', include(router.urls)),
    path('cities/', cities_list, name='cities'),
]
