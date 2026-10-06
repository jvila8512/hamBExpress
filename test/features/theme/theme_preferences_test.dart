import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:etecsa/config/theme/theme_preferences.dart';
import 'package:etecsa/config/theme/theme_provider.dart';

void main() {
  group('defaultThemeForRole — two-entry matrix, no dark entry', () {
    test('admin defaults to light', () {
      expect(defaultThemeForRole('admin'), ThemeMode.light);
    });

    test('vendedor defaults to light', () {
      expect(defaultThemeForRole('vendedor'), ThemeMode.light);
    });

    test('role matching is case-insensitive', () {
      expect(defaultThemeForRole('VENDEDOR'), ThemeMode.light);
      expect(defaultThemeForRole('Admin'), ThemeMode.light);
    });

    test('no legacy role defaults to dark', () {
      const legacy = [
        'super_admin',
        'redes',
        'cocina',
        'mesero',
        'domicilio',
        'almacenero',
      ];
      for (final role in legacy) {
        expect(
          defaultThemeForRole(role),
          ThemeMode.light,
          reason: 'deleted role "$role" must not carry a dark default',
        );
      }
    });

    test('unknown role falls back to light mode', () {
      expect(defaultThemeForRole('nobody'), ThemeMode.light);
    });
  });

  group('ThemePreferenceStore', () {
    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      ThemePrefs.initialMode = null;
    });

    test('read returns null when nothing was persisted', () async {
      expect(await ThemePreferenceStore.read(), isNull);
    });

    test('write then read round-trips light mode', () async {
      await ThemePreferenceStore.write(ThemeMode.light);
      expect(await ThemePreferenceStore.read(), ThemeMode.light);
    });

    test('write then read round-trips dark mode', () async {
      await ThemePreferenceStore.write(ThemeMode.dark);
      expect(await ThemePreferenceStore.read(), ThemeMode.dark);
    });

    test('write then read round-trips system mode', () async {
      await ThemePreferenceStore.write(ThemeMode.system);
      expect(await ThemePreferenceStore.read(), ThemeMode.system);
    });

    test('last write wins', () async {
      await ThemePreferenceStore.write(ThemeMode.dark);
      await ThemePreferenceStore.write(ThemeMode.light);
      expect(await ThemePreferenceStore.read(), ThemeMode.light);
    });
  });

  group('resolveMode — saved choice overrides role default', () {
    test('saved light wins over the light role default', () {
      expect(resolveMode(ThemeMode.light, 'vendedor'), ThemeMode.light);
    });

    test('saved dark overrides the admin light default', () {
      expect(resolveMode(ThemeMode.dark, 'admin'), ThemeMode.dark);
    });

    test('saved system wins over any role default', () {
      expect(resolveMode(ThemeMode.system, 'admin'), ThemeMode.system);
    });

    test('no saved choice: admin role default light wins', () {
      expect(resolveMode(null, 'admin'), ThemeMode.light);
    });

    test('no saved choice: vendedor role default light wins', () {
      expect(resolveMode(null, 'vendedor'), ThemeMode.light);
    });

    test('no saved choice: a legacy role never falls back to dark', () {
      expect(resolveMode(null, 'cocina'), ThemeMode.light);
    });
  });
}
