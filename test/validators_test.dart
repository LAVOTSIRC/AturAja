import 'package:aturaja/utils/validators.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('menolak email kosong', () {
      expect(validateEmail(null), 'Email tidak boleh kosong.');
      expect(validateEmail(''), 'Email tidak boleh kosong.');
      expect(validateEmail('   '), 'Email tidak boleh kosong.');
    });

    test('menolak format email yang tidak valid', () {
      expect(validateEmail('bukan-email'), 'Masukkan format email yang valid.');
      expect(validateEmail('nama@'), 'Masukkan format email yang valid.');
      expect(validateEmail('nama@kampus'), 'Masukkan format email yang valid.');
      expect(
        validateEmail('nama kampus@email.id'),
        'Masukkan format email yang valid.',
      );
    });

    test('menerima email valid dan menghapus spasi di tepi', () {
      expect(validateEmail('nama@kampus.id'), isNull);
      expect(validateEmail('  nama@kampus.id  '), isNull);
    });
  });

  group('validatePassword', () {
    test('menolak kata sandi kosong', () {
      expect(validatePassword(null), 'Kata sandi tidak boleh kosong.');
      expect(validatePassword(''), 'Kata sandi tidak boleh kosong.');
    });

    test('menolak kata sandi kurang dari enam karakter', () {
      expect(validatePassword('12345'), 'Kata sandi minimal 6 karakter.');
    });

    test('menerima kata sandi minimal enam karakter', () {
      expect(validatePassword('123456'), isNull);
    });
  });

  group('validatePasswordConfirmation', () {
    test('menolak konfirmasi kosong', () {
      expect(
        validatePasswordConfirmation(null, '123456'),
        'Konfirmasi kata sandi tidak boleh kosong.',
      );
      expect(
        validatePasswordConfirmation('', '123456'),
        'Konfirmasi kata sandi tidak boleh kosong.',
      );
    });

    test('menolak konfirmasi yang tidak cocok', () {
      expect(
        validatePasswordConfirmation('123457', '123456'),
        'Konfirmasi kata sandi tidak cocok.',
      );
    });

    test('menerima konfirmasi yang cocok', () {
      expect(validatePasswordConfirmation('123456', '123456'), isNull);
    });
  });
}
