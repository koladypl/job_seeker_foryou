from django.urls import path
from rest_framework_simplejwt.views import TokenObtainPairView, TokenRefreshView
from .views import RegisterView, LoginView, MeView

urlpatterns = [
    # Rejestracja i profil
    path('register/', RegisterView.as_view(), name='register'),
    path('me/', MeView.as_view(), name='me'),

    # Logowanie – dwa warianty:
    path('login/', LoginView.as_view(), name='login'),                # kompatybilny: login+password
    path('token/', TokenObtainPairView.as_view(), name='token'),      # standard JWT: username+password
    path('token/refresh/', TokenRefreshView.as_view(), name='token_refresh'),
]
