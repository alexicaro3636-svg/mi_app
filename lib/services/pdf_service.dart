import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../models/registro_operacion.dart';

class PdfService {
  static Future<File> generarPdfOperacion(RegistroOperacion op) async {
    final pdf = pw.Document();

    final fechaGeneracion = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.now());

    final fechaInicio = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(op.fechaInicio);

    final fechaFin = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(op.fechaFin);

    final nombreArchivo = _sanitizarNombreArchivo(
      'reporte_${op.operationKey.isNotEmpty ? op.operationKey : op.idTrabajo}_${DateTime.now().millisecondsSinceEpoch}.pdf',
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'REPORTE DE OPERACIÓN',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'Telemetría Bombeo Móvil SOMI',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 10),

                _filaDato('Usuario', op.usuario),
                _filaDato('Rol', op.rol),
                _filaDato('Lugar', op.lugar),
                _filaDato('ID de trabajo', op.idTrabajo),
                _filaDato('Operation Key', op.operationKey),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Fechas y tiempos',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                _filaDato('Fecha inicio', fechaInicio),
                _filaDato('Fecha fin', fechaFin),
                _filaDato('Tiempo operación', op.tiempoOperacion),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Resultados',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                _filaDato(
                  'RPM promedio',
                  op.rpmPromedio.toStringAsFixed(2),
                ),
                _filaDato(
                  'Total bombeado (bbl)',
                  op.totalBombeado.toStringAsFixed(2),
                ),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Resumen',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    op.resumenTexto.trim().isEmpty
                        ? 'Sin resumen disponible'
                        : op.resumenTexto.trim(),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 8),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Generado: $fechaGeneracion',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final directorio = await getApplicationDocumentsDirectory();
    final archivo = File('${directorio.path}/$nombreArchivo');
    await archivo.writeAsBytes(await pdf.save());

    return archivo;
  }

  static Future<void> compartirPdfOperacion(RegistroOperacion op) async {
    final archivo = await generarPdfOperacion(op);

    await Share.shareXFiles(
      [XFile(archivo.path)],
      text: 'Reporte de operación - ${op.idTrabajo}',
      subject: 'Reporte de operación SOMI',
    );
  }

  static Future<void> imprimirPdfOperacion(RegistroOperacion op) async {
    final pdf = pw.Document();

    final fechaGeneracion = DateFormat(
      'dd/MM/yyyy HH:mm',
    ).format(DateTime.now());

    final fechaInicio = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(op.fechaInicio);

    final fechaFin = DateFormat(
      'dd/MM/yyyy HH:mm:ss',
    ).format(op.fechaFin);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        build: (context) => [
          pw.Container(
            padding: const pw.EdgeInsets.all(16),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(width: 1),
              borderRadius: pw.BorderRadius.circular(8),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Center(
                  child: pw.Text(
                    'REPORTE DE OPERACIÓN',
                    style: pw.TextStyle(
                      fontSize: 20,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ),
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'Telemetría Bombeo Móvil SOMI',
                    style: const pw.TextStyle(fontSize: 12),
                  ),
                ),
                pw.SizedBox(height: 16),
                pw.Divider(),
                pw.SizedBox(height: 10),

                _filaDato('Usuario', op.usuario),
                _filaDato('Rol', op.rol),
                _filaDato('Lugar', op.lugar),
                _filaDato('ID de trabajo', op.idTrabajo),
                _filaDato('Operation Key', op.operationKey),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Fechas y tiempos',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                _filaDato('Fecha inicio', fechaInicio),
                _filaDato('Fecha fin', fechaFin),
                _filaDato('Tiempo operación', op.tiempoOperacion),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Resultados',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                _filaDato(
                  'RPM promedio',
                  op.rpmPromedio.toStringAsFixed(2),
                ),
                _filaDato(
                  'Total bombeado (bbl)',
                  op.totalBombeado.toStringAsFixed(2),
                ),

                pw.SizedBox(height: 14),
                pw.Text(
                  'Resumen',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.SizedBox(height: 8),

                pw.Container(
                  width: double.infinity,
                  padding: const pw.EdgeInsets.all(10),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(width: 0.8),
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    op.resumenTexto.trim().isEmpty
                        ? 'Sin resumen disponible'
                        : op.resumenTexto.trim(),
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                ),

                pw.SizedBox(height: 20),
                pw.Divider(),
                pw.SizedBox(height: 8),

                pw.Align(
                  alignment: pw.Alignment.centerRight,
                  child: pw.Text(
                    'Generado: $fechaGeneracion',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'reporte_operacion_${op.idTrabajo}',
    );
  }

  static pw.Widget _filaDato(String titulo, String valor) {
    return pw.Padding(
      padding: const pw.EdgeInsets.only(bottom: 6),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 130,
            child: pw.Text(
              titulo,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              valor.trim().isEmpty ? '-' : valor,
            ),
          ),
        ],
      ),
    );
  }

  static String _sanitizarNombreArchivo(String nombre) {
    return nombre.replaceAll(RegExp(r'[\\/:*?"<>| ]'), '_');
  }
}