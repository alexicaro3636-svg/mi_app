import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/registro_operacion.dart';

class ReporteService {
  static Future<void> guardarOperacionConSync(RegistroOperacion op) async {
    try {
      final duracionSegundos = _parseDuracionASegundos(op.tiempoOperacion);

      final url = Uri.parse(
        'http://${AppConfig.host}:${AppConfig.port}/?key=${AppConfig.apiKey}&guardar=1'
        '&operation_key=${op.operationKey}'
        '&usuario=${Uri.encodeComponent(op.usuario)}'
        '&rol=${Uri.encodeComponent(op.rol)}'
        '&lugar=${Uri.encodeComponent(op.lugar)}'
        '&id=${Uri.encodeComponent(op.idTrabajo)}'
        '&inicio=${Uri.encodeComponent(op.fechaInicio.toIso8601String())}'
        '&fin=${Uri.encodeComponent(op.fechaFin.toIso8601String())}'
        '&duracion_segundos=$duracionSegundos'
        '&rpm=${op.rpmPromedio}'
        '&total=${op.totalBombeado}'
        '&resumen=${Uri.encodeComponent(op.resumenTexto)}',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final historial = await cargarHistorial();
        historial.add(op.copyWith(pendienteEnvio: false));
        await guardarHistorial(historial);
      } else {
        throw Exception("Error servidor");
      }
    } catch (e) {
      final historial = await cargarHistorial();
      historial.add(op);
      await guardarHistorial(historial);

      final pendientes = await cargarPendientes();
      pendientes.add(op);
      await guardarPendientes(pendientes);
    }
  }

  static Future<List<RegistroOperacion>> cargarHistorial() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('historial_operaciones') ?? [];
    return raw.map((e) => RegistroOperacion.fromMap(jsonDecode(e))).toList();
  }

  static Future<void> guardarHistorial(List<RegistroOperacion> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'historial_operaciones',
      lista.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<List<RegistroOperacion>> cargarPendientes() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList('reportes_pendientes') ?? [];
    return raw.map((e) => RegistroOperacion.fromMap(jsonDecode(e))).toList();
  }

  static Future<void> guardarPendientes(List<RegistroOperacion> lista) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'reportes_pendientes',
      lista.map((e) => jsonEncode(e.toMap())).toList(),
    );
  }

  static Future<void> sincronizarPendientes() async {
    final pendientes = await cargarPendientes();
    final List<RegistroOperacion> restantes = [];

    for (final op in pendientes) {
      try {
        final duracionSegundos = _parseDuracionASegundos(op.tiempoOperacion);

        final url = Uri.parse(
          'http://${AppConfig.host}:${AppConfig.port}/?key=${AppConfig.apiKey}&guardar=1'
          '&operation_key=${op.operationKey}'
          '&usuario=${Uri.encodeComponent(op.usuario)}'
          '&rol=${Uri.encodeComponent(op.rol)}'
          '&lugar=${Uri.encodeComponent(op.lugar)}'
          '&id=${Uri.encodeComponent(op.idTrabajo)}'
          '&inicio=${Uri.encodeComponent(op.fechaInicio.toIso8601String())}'
          '&fin=${Uri.encodeComponent(op.fechaFin.toIso8601String())}'
          '&duracion_segundos=$duracionSegundos'
          '&rpm=${op.rpmPromedio}'
          '&total=${op.totalBombeado}'
          '&resumen=${Uri.encodeComponent(op.resumenTexto)}',
        );

        final response = await http.get(url);

        if (response.statusCode == 200) {
          final historial = await cargarHistorial();
          final index = historial.indexWhere(
            (r) => r.operationKey == op.operationKey,
          );

          if (index != -1) {
            historial[index] = historial[index].copyWith(
              pendienteEnvio: false,
            );
            await guardarHistorial(historial);
          }
        } else {
          restantes.add(op);
        }
      } catch (e) {
        restantes.add(op);
      }
    }

    await guardarPendientes(restantes);
  }

  static Future<int> reenviarPendientes() async {
    final antes = await cargarPendientes();
    final cantidadAntes = antes.length;

    await sincronizarPendientes();

    final despues = await cargarPendientes();
    return cantidadAntes - despues.length;
  }

  static int _parseDuracionASegundos(String tiempo) {
    try {
      final partes = tiempo.split(':');
      if (partes.length != 3) return 0;

      final horas = int.tryParse(partes[0]) ?? 0;
      final minutos = int.tryParse(partes[1]) ?? 0;
      final segundos = int.tryParse(partes[2]) ?? 0;

      return (horas * 3600) + (minutos * 60) + segundos;
    } catch (_) {
      return 0;
    }
  }
}