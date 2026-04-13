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

        final existe = historial.any(
          (r) => r.operationKey == op.operationKey,
        );

        if (!existe) {
          historial.add(op.copyWith(pendienteEnvio: false));
          await guardarHistorial(historial);
        } else {
          final index = historial.indexWhere(
            (r) => r.operationKey == op.operationKey,
          );

          if (index != -1) {
            historial[index] = historial[index].copyWith(
              pendienteEnvio: false,
            );
            await guardarHistorial(historial);
          }
        }
      } else {
        throw Exception('Error servidor');
      }
    } catch (e) {
      final historial = await cargarHistorial();

      final existeHistorial = historial.any(
        (r) => r.operationKey == op.operationKey,
      );

      if (!existeHistorial) {
        historial.add(op);
        await guardarHistorial(historial);
      }

      final pendientes = await cargarPendientes();

      final existePendiente = pendientes.any(
        (r) => r.operationKey == op.operationKey,
      );

      if (!existePendiente) {
        pendientes.add(op);
        await guardarPendientes(pendientes);
      }
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
          } else {
            historial.add(op.copyWith(pendienteEnvio: false));
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

  static Future<List<RegistroOperacion>> cargarHistorialDesdeVps() async {
    final url = Uri.parse(
      'http://${AppConfig.host}:${AppConfig.port}/?key=${AppConfig.apiKey}&listar=1',
    );

    final response = await http.get(url);

    if (response.statusCode != 200) {
      throw Exception('Error al cargar historial desde VPS');
    }

    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Respuesta inválida del VPS');
    }

    if (decoded['ok'] != true) {
      throw Exception('El VPS respondió con error');
    }

    final data = decoded['data'];

    if (data is! List) {
      throw Exception('La lista de historial no viene en data');
    }

    return data.map<RegistroOperacion>((item) {
      final fechaInicio =
          DateTime.tryParse(item['fecha_inicio']?.toString() ?? '') ??
          DateTime.now();

      final fechaFin =
          DateTime.tryParse(item['fecha_fin']?.toString() ?? '') ?? fechaInicio;

      final duracionSegundos =
          int.tryParse(item['duracion_segundos']?.toString() ?? '0') ?? 0;

      final horas = (duracionSegundos ~/ 3600).toString().padLeft(2, '0');
      final minutos =
          ((duracionSegundos % 3600) ~/ 60).toString().padLeft(2, '0');
      final segundos = (duracionSegundos % 60).toString().padLeft(2, '0');

      final lugar = item['lugar']?.toString() ?? '';
      final grupo =
          '$lugar - ${fechaFin.day.toString().padLeft(2, '0')}/${fechaFin.month.toString().padLeft(2, '0')}/${fechaFin.year}';

      return RegistroOperacion(
        operationKey: item['operation_key']?.toString() ?? '',
        usuario: item['usuario']?.toString() ?? '',
        rol: item['rol']?.toString() ?? '',
        lugar: lugar,
        idTrabajo: item['id_trabajo']?.toString() ?? '',
        grupoHistorial: grupo,
        fechaInicio: fechaInicio,
        fechaFin: fechaFin,
        tiempoOperacion: '$horas:$minutos:$segundos',
        rpmPromedio:
            double.tryParse(item['rpm_promedio']?.toString() ?? '0') ?? 0,
        totalBombeado:
            double.tryParse(item['volumen_total']?.toString() ?? '0') ?? 0,
        resumenTexto: item['resumen_texto']?.toString() ?? '',
        pendienteEnvio: false,
      );
    }).toList();
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