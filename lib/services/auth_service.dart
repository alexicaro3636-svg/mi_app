import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../main.dart';

class AuthService {
  static const String baseUrl = 'http://64.227.90.16:3000';

  // ==========================
  // LOGIN ONLINE
  // ==========================
  static Future<Usuario?> loginOnline(
    String usuario,
    String pin,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'apiKey': 'SOMI2026',
          'usuario': usuario,
          'pin': pin,
        }),
      );

      final data = jsonDecode(response.body);

      if (data['ok'] == true) {
        final user = Usuario.fromJson(data['usuario']);
        await guardarUsuarioLocal(user, pin);
        return user;
      }

      return null;
    } catch (e) {
      return null;
    }
  }

  // ==========================
  // LOGIN OFFLINE
  // ==========================
  static Future<Usuario?> loginOffline(
    String usuario,
    String pin,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final guardado = prefs.getString('usuario_guardado');
    if (guardado == null) return null;

    final data = jsonDecode(guardado);

    if (data['nombre'] == usuario && data['pin'] == pin) {
      return Usuario(
        nombre: data['nombre'],
        pin: data['pin'],
        rol: data['rol'],
        idsPermitidos: List<String>.from(data['ids']),
      );
    }

    return null;
  }

  // ==========================
  // GUARDAR LOCAL
  // ==========================
  static Future<void> guardarUsuarioLocal(
    Usuario user,
    String pin,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'usuario_guardado',
      jsonEncode({
        'nombre': user.nombre,
        'pin': pin,
        'rol': user.rol,
        'ids': user.idsPermitidos,
      }),
    );
  }
}