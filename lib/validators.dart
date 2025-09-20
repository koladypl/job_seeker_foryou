String? validateUsername(String? v) {
  if (v == null || v.trim().isEmpty) return 'Podaj login';
  if (v.trim().length < 3) return 'Login musi mieć minimum 3 znaki';
  return null;
}

String? validateEmail(String? v) {
  if (v == null || v.trim().isEmpty) return 'Podaj e-mail';
  final regex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
  if (!regex.hasMatch(v.trim())) return 'Nieprawidłowy e-mail';
  return null;
}

String? validatePassword(String? v) {
  if (v == null || v.isEmpty) return 'Podaj hasło';
  if (v.length < 8) return 'Hasło musi mieć minimum 8 znaków';
  return null;
}

String? validatePhone(String? v) {
  if (v == null || v.trim().isEmpty) return 'Podaj telefon';
  if (!RegExp(r'^\+?\d{7,15}$').hasMatch(v.trim())) return 'Nieprawidłowy numer telefonu';
  return null;
}

String? validateMessage(String? v) {
  if (v == null || v.trim().isEmpty) return 'Wpisz wiadomość';
  if (v.trim().length < 20) return 'Wiadomość musi mieć minimum 20 znaków';
  return null;
}
