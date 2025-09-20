from rest_framework import generics, permissions, status
from rest_framework.response import Response
from rest_framework.views import APIView
from django.contrib.auth import authenticate
from rest_framework_simplejwt.tokens import RefreshToken
from .serializers import RegisterSerializer

class RegisterView(generics.CreateAPIView):
    serializer_class = RegisterSerializer

    def create(self, request, *args, **kwargs):
        serializer = self.get_serializer(data=request.data)
        if serializer.is_valid():
            serializer.save()
            return Response({"message": "Rejestracja udana"}, status=status.HTTP_201_CREATED)
        return Response(serializer.errors, status=status.HTTP_400_BAD_REQUEST)

class LoginView(APIView):
    """
    Login kompatybilny z frontendem: przyjmuje { "login": "...", "password": "..." }
    Zwraca tokeny JWT oraz podstawowe dane użytkownika.
    """
    def post(self, request):
        login = request.data.get('login')
        password = request.data.get('password')

        if not login or not password:
            return Response({"error": "Brak loginu lub hasła"}, status=status.HTTP_400_BAD_REQUEST)

        user = authenticate(username=login, password=password)
        if not user:
            return Response({"error": "Nieprawidłowe dane logowania"}, status=status.HTTP_401_UNAUTHORIZED)

        refresh = RefreshToken.for_user(user)
        return Response({
            "access": str(refresh.access_token),
            "refresh": str(refresh),
            "username": user.username,
            "email": user.email
        }, status=status.HTTP_200_OK)

class MeView(APIView):
    permission_classes = [permissions.IsAuthenticated]

    def get(self, request):
        user = request.user
        return Response({
            "id": user.id,
            "username": user.username,
            "email": user.email,
            "is_active": user.is_active,
        }, status=status.HTTP_200_OK)
