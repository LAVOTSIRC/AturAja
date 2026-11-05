String? validateEmail(String? value) {
  final String email = value?.trim() ?? '';
  if (email.isEmpty) {
    return 'Email tidak boleh kosong.';
  }
  final bool isValid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
  if (!isValid) {
    return 'Masukkan format email yang valid.';
  }
  return null;
}

String? validatePassword(String? value) {
  final String password = value ?? '';
  if (password.isEmpty) {
    return 'Kata sandi tidak boleh kosong.';
  }
  if (password.length < 6) {
    return 'Kata sandi minimal 6 karakter.';
  }
  return null;
}

String? validatePasswordConfirmation(String? value, String password) {
  final String confirmation = value ?? '';
  if (confirmation.isEmpty) {
    return 'Konfirmasi kata sandi tidak boleh kosong.';
  }
  if (confirmation != password) {
    return 'Konfirmasi kata sandi tidak cocok.';
  }
  return null;
}
