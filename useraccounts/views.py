from django.http import JsonResponse
from django.contrib.auth import authenticate, get_user_model
from django.views.decorators.csrf import csrf_exempt
import json

User = get_user_model()

@csrf_exempt
def register_view(request):
    if request.method == 'GET':
        # Informacyjny komunikat przy żądaniu GET
        return JsonResponse({"message": "Użyj metody POST, aby zarejestrować użytkownika."}, status=200)
    elif request.method == 'POST':
        try:
            data = json.loads(request.body)
            username = data.get('username')
            password = data.get('password')
            if not username or not password:
                return JsonResponse({'error': 'Podaj username i password.'}, status=400)
            if User.objects.filter(username=username).exists():
                return JsonResponse({'error': 'Username już istnieje.'}, status=400)
            User.objects.create_user(username=username, password=password)
            return JsonResponse({'message': 'Użytkownik został utworzony.'}, status=201)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    else:
        return JsonResponse({'message': 'Metoda nieobsługiwana'}, status=405)


@csrf_exempt
def login_view(request):
    if request.method == 'GET':
        # Informacyjny komunikat przy żądaniu GET
        return JsonResponse({"message": "Użyj metody POST, aby zalogować się."}, status=200)
    elif request.method == 'POST':
        try:
            data = json.loads(request.body)
            username = data.get('username')
            password = data.get('password')
            if not username or not password:
                return JsonResponse({'error': 'Podaj username i password.'}, status=400)
            user = authenticate(username=username, password=password)
            if user is not None:
                return JsonResponse({'message': 'Logowanie pomyślne.'}, status=200)
            else:
                return JsonResponse({'error': 'Błędne dane logowania.'}, status=400)
        except Exception as e:
            return JsonResponse({'error': str(e)}, status=400)
    else:
        return JsonResponse({'message': 'Metoda nieobsługiwana'}, status=405)
