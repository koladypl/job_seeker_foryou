from django.contrib.auth import get_user_model
from rest_framework import serializers
from django.contrib.auth.password_validation import validate_password

User = get_user_model()

class RegisterSerializer(serializers.ModelSerializer):
    # frontend może wysyłać "login" i opcjonalnie "password2" i "email"
    login = serializers.CharField(write_only=True)
    password = serializers.CharField(write_only=True, validators=[validate_password])
    password2 = serializers.CharField(write_only=True, required=False, allow_blank=True)
    email = serializers.EmailField(required=False, allow_blank=True)

    class Meta:
        model = User
        fields = ('login', 'password', 'password2', 'email')

    def validate_login(self, value):
        if User.objects.filter(username=value).exists():
            raise serializers.ValidationError("Użytkownik o takiej nazwie już istnieje.")
        return value

    def validate(self, attrs):
        pwd = attrs.get('password')
        pwd2 = attrs.get('password2')
        if pwd2 is not None and pwd2 != '' and pwd != pwd2:
            raise serializers.ValidationError({"password2": "Hasła nie są identyczne."})
        return attrs

    def create(self, validated_data):
        username = validated_data.pop('login')
        password = validated_data.pop('password')
        # password2 może nie być przesłane
        validated_data.pop('password2', None)
        email = validated_data.pop('email', '').strip()

        user = User(username=username, email=email or '')
        user.set_password(password)
        user.is_active = True
        user.save()
        return user
