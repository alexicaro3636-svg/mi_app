class RegistroOperacion {
  final String operationKey;
  final String usuario;
  final String rol;
  final String lugar;
  final String idTrabajo;
  final String grupoHistorial;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String tiempoOperacion;
  final double rpmPromedio;
  final double totalBombeado;
  final String resumenTexto;
  final bool pendienteEnvio;

  RegistroOperacion({
    required this.operationKey,
    required this.usuario,
    required this.rol,
    required this.lugar,
    required this.idTrabajo,
    required this.grupoHistorial,
    required this.fechaInicio,
    required this.fechaFin,
    required this.tiempoOperacion,
    required this.rpmPromedio,
    required this.totalBombeado,
    required this.resumenTexto,
    required this.pendienteEnvio,
  });

  Map<String, dynamic> toMap() {
    return {
      'operationKey': operationKey,
      'usuario': usuario,
      'rol': rol,
      'lugar': lugar,
      'idTrabajo': idTrabajo,
      'grupoHistorial': grupoHistorial,
      'fechaInicio': fechaInicio.toIso8601String(),
      'fechaFin': fechaFin.toIso8601String(),
      'tiempoOperacion': tiempoOperacion,
      'rpmPromedio': rpmPromedio,
      'totalBombeado': totalBombeado,
      'resumenTexto': resumenTexto,
      'pendienteEnvio': pendienteEnvio,
    };
  }

  factory RegistroOperacion.fromMap(Map<String, dynamic> map) {
    return RegistroOperacion(
      operationKey: map['operationKey'] ?? '',
      usuario: map['usuario'] ?? '',
      rol: map['rol'] ?? '',
      lugar: map['lugar'] ?? '',
      idTrabajo: map['idTrabajo'] ?? '',
      grupoHistorial: map['grupoHistorial'] ?? '',
      fechaInicio: DateTime.parse(map['fechaInicio']),
      fechaFin: DateTime.parse(map['fechaFin']),
      tiempoOperacion: map['tiempoOperacion'] ?? '',
      rpmPromedio: (map['rpmPromedio'] ?? 0).toDouble(),
      totalBombeado: (map['totalBombeado'] ?? 0).toDouble(),
      resumenTexto: map['resumenTexto'] ?? '',
      pendienteEnvio: map['pendienteEnvio'] ?? false,
    );
  }

  RegistroOperacion copyWith({
    String? operationKey,
    String? usuario,
    String? rol,
    String? lugar,
    String? idTrabajo,
    String? grupoHistorial,
    DateTime? fechaInicio,
    DateTime? fechaFin,
    String? tiempoOperacion,
    double? rpmPromedio,
    double? totalBombeado,
    String? resumenTexto,
    bool? pendienteEnvio,
  }) {
    return RegistroOperacion(
      operationKey: operationKey ?? this.operationKey,
      usuario: usuario ?? this.usuario,
      rol: rol ?? this.rol,
      lugar: lugar ?? this.lugar,
      idTrabajo: idTrabajo ?? this.idTrabajo,
      grupoHistorial: grupoHistorial ?? this.grupoHistorial,
      fechaInicio: fechaInicio ?? this.fechaInicio,
      fechaFin: fechaFin ?? this.fechaFin,
      tiempoOperacion: tiempoOperacion ?? this.tiempoOperacion,
      rpmPromedio: rpmPromedio ?? this.rpmPromedio,
      totalBombeado: totalBombeado ?? this.totalBombeado,
      resumenTexto: resumenTexto ?? this.resumenTexto,
      pendienteEnvio: pendienteEnvio ?? this.pendienteEnvio,
    );
  }
}