import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'models/registro_operacion.dart';
import 'services/auth_service.dart';
import 'services/pdf_service.dart';
import 'services/reporte_service.dart';

void main() {
  runApp(const TelemetriaApp());
}

class Usuario {
  final String nombre;
  final String pin;
  final String rol;
  final List<String> idsPermitidos;

  const Usuario({
    required this.nombre,
    required this.pin,
    required this.rol,
    required this.idsPermitidos,
  });

  bool get esAdmin => rol == 'admin';
  bool get esOperador => rol == 'operador';
  bool get esPemex => rol == 'pemex';
  bool get accesoTotalIds => idsPermitidos.contains('*');

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final ids = (json['idsPermitidos'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    return Usuario(
      nombre: json['nombre']?.toString() ?? '',
      pin: '',
      rol: json['rol']?.toString() ?? '',
      idsPermitidos: ids,
    );
  }
}

bool usuarioPuedeUsarId(Usuario usuario, String idTrabajo) {
  if (usuario.accesoTotalIds) return true;
  return usuario.idsPermitidos.contains(idTrabajo);
}

List<String> filtrarIdsPorUsuario(Usuario usuario, List<String> ids) {
  if (usuario.accesoTotalIds) {
    final copia = List<String>.from(ids)..sort();
    return copia;
  }

  final filtrados = ids.where((id) => usuario.idsPermitidos.contains(id)).toList()
    ..sort();

  return filtrados;
}

List<RegistroOperacion> filtrarRegistrosPorUsuario(
  Usuario usuario,
  List<RegistroOperacion> registros,
) {
  if (usuario.accesoTotalIds) return registros;

  return registros.where((r) => usuario.idsPermitidos.contains(r.idTrabajo)).toList();
}

class BtConfig {
  static const String deviceName = 'SOMI_BT_CLASSIC';
}

class AppConfig {
  static const String apiKey = 'SOMI2026';
  static const String device = 'APP_MOVIL';
  static const String host = '64.227.90.16';
  static const int port = 3000;
  static const String sendPath = '/send';
}

class TelemetriaApp extends StatelessWidget {
  const TelemetriaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Monitoreo de Bombeo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const PantallaLogin(),
    );
  }
}

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final TextEditingController usuarioController = TextEditingController();
  final TextEditingController pinController = TextEditingController();

  bool cargandoLogin = false;
  String mensajeLogin = '';

  @override
  void dispose() {
    usuarioController.dispose();
    pinController.dispose();
    super.dispose();
  }

  Future<void> iniciarSesion() async {
    if (cargandoLogin) return;

    final nombre = usuarioController.text.trim().toLowerCase();
    final pin = pinController.text.trim();

    if (nombre.isEmpty || pin.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe usuario y PIN')),
      );
      return;
    }

    setState(() {
      cargandoLogin = true;
      mensajeLogin = 'Intentando conexión con servidor...';
    });

    Usuario? usuario = await AuthService.loginOnline(nombre, pin);

    bool usoModoOffline = false;

    if (usuario == null) {
      setState(() {
        mensajeLogin =
            'Sin conexión o credenciales no válidas. Probando acceso offline...';
      });

      usuario = await AuthService.loginOffline(nombre, pin);

      if (usuario != null) {
        usoModoOffline = true;
      }
    }

    if (!mounted) return;

    setState(() {
      cargandoLogin = false;
    });

    if (usuario == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No se pudo iniciar sesión. Verifica usuario, PIN o conexión.',
          ),
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          usoModoOffline ? 'Acceso offline autorizado' : 'Acceso online correcto',
        ),
      ),
    );

    if (usuario.esPemex) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => PantallaConsultaPemex(usuario: usuario!),
        ),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaInicio(usuario: usuario!),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                decoration: BoxDecoration(
                  color: const Color(0xFF0D131A),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 24,
                      offset: Offset(0, 10),
                    ),
                  ],
                  border: Border.all(
                    color: Colors.white.withOpacity(0.06),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 92,
                      height: 92,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF1BE28B).withOpacity(0.12),
                        border: Border.all(
                          color: const Color(0xFF1BE28B).withOpacity(0.35),
                          width: 1.4,
                        ),
                      ),
                      child: const Icon(
                        Icons.person_outline_rounded,
                        size: 44,
                        color: Color(0xFF1BE28B),
                      ),
                    ),
                    const SizedBox(height: 22),
                    const Text(
                      'Iniciar sesión',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sistema de monitoreo de bombeo móvil',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white60,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Usuario',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: usuarioController,
                      textCapitalization: TextCapitalization.none,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Ejemplo: admin',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF111923),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1BE28B),
                            width: 1.4,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'PIN',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.88),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: pinController,
                      obscureText: true,
                      keyboardType: TextInputType.number,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '4 dígitos',
                        hintStyle: const TextStyle(color: Colors.white38),
                        filled: true,
                        fillColor: const Color(0xFF111923),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 18,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: BorderSide(
                            color: Colors.white.withOpacity(0.08),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(
                            color: Color(0xFF1BE28B),
                            width: 1.4,
                          ),
                        ),
                      ),
                      onSubmitted: (_) => iniciarSesion(),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: cargandoLogin ? null : iniciarSesion,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1BE28B),
                          foregroundColor: const Color(0xFF08110C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          cargandoLogin ? 'VALIDANDO...' : 'ENTRAR',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ),
                    ),
                    if (mensajeLogin.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.06),
                          ),
                        ),
                        child: Text(
                          mensajeLogin,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111923),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.05),
                        ),
                      ),
                      child: const Text(
                        'Bienvenido\nIngresa tus credenciales',
                        textAlign: TextAlign.center,
                          style: TextStyle(
                          color: Colors.white60,
                          fontSize: 13,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PantallaInicio extends StatefulWidget {
  final Usuario usuario;

  const PantallaInicio({
    super.key,
    required this.usuario,
  });

  @override
  State<PantallaInicio> createState() => _PantallaInicioState();
}

class _PantallaInicioState extends State<PantallaInicio> {
  String? lugarSeleccionado;
  final TextEditingController idController = TextEditingController();
  final TextEditingController nuevoIdController = TextEditingController();

  String? idSeleccionado;
  List<String> idsDisponibles = [];
  bool enviandoContexto = false;
  bool reenviandoPendientes = false;

  bool get esAdmin => widget.usuario.esAdmin;
  bool get esOperador => widget.usuario.esOperador;
  bool get esPemex => widget.usuario.esPemex;

  @override
  void initState() {
    super.initState();
    cargarIds();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      reintentarPendientesSilencioso();
    });
  }

  @override
  void dispose() {
    idController.dispose();
    nuevoIdController.dispose();
    super.dispose();
  }

  Future<void> cargarIds() async {
    final prefs = await SharedPreferences.getInstance();
    final idsGuardados = prefs.getStringList('ids_disponibles');

    final baseIds = idsGuardados ?? ['ID-1001', 'ID-1002', 'ID-1003'];

    final idsFiltrados = filtrarIdsPorUsuario(
      widget.usuario,
      baseIds,
    );

    String? nuevoSeleccionado = idSeleccionado;
    if (nuevoSeleccionado != null && !idsFiltrados.contains(nuevoSeleccionado)) {
      nuevoSeleccionado = null;
    }

    setState(() {
      idsDisponibles = idsFiltrados;
      idSeleccionado = nuevoSeleccionado;
    });
  }

  Future<void> guardarIds(List<String> todosLosIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ids_disponibles', todosLosIds);
  }

  Future<void> agregarNuevoId() async {
    if (!esAdmin) return;

    final nuevoId = nuevoIdController.text.trim();

    if (nuevoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un ID válido')),
      );
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final idsGuardados =
        prefs.getStringList('ids_disponibles') ?? ['ID-1001', 'ID-1002', 'ID-1003'];

    if (idsGuardados.contains(nuevoId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese ID ya existe')),
      );
      return;
    }

    idsGuardados.add(nuevoId);
    idsGuardados.sort();

    await guardarIds(idsGuardados);

    setState(() {
      nuevoIdController.clear();
      idsDisponibles = filtrarIdsPorUsuario(widget.usuario, idsGuardados);
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ID agregado: $nuevoId')),
    );
  }

  Future<void> reintentarPendientesSilencioso() async {
    if (reenviandoPendientes || esPemex) return;

    reenviandoPendientes = true;
    final enviados = await ReporteService.reenviarPendientes();
    reenviandoPendientes = false;

    if (!mounted) return;
    if (enviados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Se enviaron $enviados reporte(s) pendiente(s)'),
        ),
      );
    }
  }

  void abrirHistoriales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistoriales(usuario: widget.usuario),
      ),
    );
  }

  void abrirPendientes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaPendientes(usuario: widget.usuario),
      ),
    );
  }

  void abrirConsultaPemex() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
      ),
    );
  }

  Future<void> iniciarOperacion() async {
    if (esPemex) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El usuario Pemex solo puede consultar registros'),
        ),
      );
      return;
    }

    final id = esAdmin ? idController.text.trim() : (idSeleccionado ?? '');

    if (lugarSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona el lugar de trabajo')),
      );
      return;
    }

    if (id.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecciona o escribe el ID del trabajo')),
      );
      return;
    }

    if (!usuarioPuedeUsarId(widget.usuario, id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ese ID no está permitido para este usuario'),
        ),
      );
      return;
    }

    setState(() {
      enviandoContexto = true;
    });

    await Future.delayed(const Duration(milliseconds: 250));

    if (!mounted) return;

    setState(() {
      enviandoContexto = false;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaMonitoreo(
          usuario: widget.usuario,
          lugar: lugarSeleccionado!,
          idTrabajo: id,
          fechaInicio: DateTime.now(),
        ),
      ),
    );
  }

  void cerrarSesion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion();
      return;
    }

    if (value == 'Historiales') {
      abrirHistoriales();
      return;
    }

    if (value == 'Pendientes de envío') {
      abrirPendientes();
      return;
    }

    if (value == 'Consulta Pemex') {
      abrirConsultaPemex();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  String capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'Historiales',
        child: Text('Historiales'),
      ),
      const PopupMenuItem(
        value: 'Consulta Pemex',
        child: Text('Consulta Pemex'),
      ),
    ];

    if (!esPemex) {
      items.add(
        const PopupMenuItem(
          value: 'Pendientes de envío',
          child: Text('Pendientes de envío'),
        ),
      );
    }

    items.add(
      const PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    );

    return items;
  }

  Widget bloqueIdOperacion() {
    if (esAdmin) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'ID para operar:',
            style: TextStyle(fontSize: 18),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: idController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Escribe el identificador',
              hintStyle: const TextStyle(color: Colors.white38),
              filled: true,
              fillColor: const Color(0xFF111923),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Colors.white.withOpacity(0.08),
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: Color(0xFF1BE28B),
                  width: 1.4,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Modo admin: puedes capturar el ID manualmente.',
            style: TextStyle(color: Colors.white60, fontSize: 13),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'ID para operar:',
          style: TextStyle(fontSize: 18),
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(
          value: idSeleccionado,
          dropdownColor: const Color(0xFF111923),
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Selecciona un ID',
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF111923),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 18,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(
                color: Colors.white.withOpacity(0.08),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(
                color: Color(0xFF1BE28B),
                width: 1.4,
              ),
            ),
          ),
          items: idsDisponibles
              .map(
                (id) => DropdownMenuItem(
                  value: id,
                  child: Text(id),
                ),
              )
              .toList(),
          onChanged: esPemex
              ? null
              : (value) {
                  setState(() {
                    idSeleccionado = value;
                  });
                },
        ),
        const SizedBox(height: 8),
        Text(
          esOperador
              ? 'Modo operador: solo puedes seleccionar tus IDs permitidos.'
              : 'Modo consulta: sin permisos para operar.',
          style: const TextStyle(color: Colors.white60, fontSize: 13),
        ),
      ],
    );
  }

  Widget bloqueAdminIds() {
    if (!esAdmin) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF111923),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Administración de IDs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nuevoIdController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Escribe un nuevo ID',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: const Color(0xFF0D131A),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 18,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: Colors.white.withOpacity(0.08),
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(
                      color: Color(0xFF1BE28B),
                      width: 1.4,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: agregarNuevoId,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BE28B),
                    foregroundColor: const Color(0xFF08110C),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'AGREGAR ID',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'IDs visibles para este usuario:',
                style: TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              if (idsDisponibles.isEmpty)
                const Text(
                  'No hay IDs guardados',
                  style: TextStyle(color: Colors.white60),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: idsDisponibles
                      .map(
                        (id) => Chip(
                          label: Text(id),
                          backgroundColor: const Color(0xFF1BE28B).withOpacity(0.12),
                          side: BorderSide(
                            color: const Color(0xFF1BE28B).withOpacity(0.18),
                          ),
                          labelStyle: const TextStyle(color: Colors.white),
                        ),
                      )
                      .toList(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final textoBoton = enviandoContexto ? 'PREPARANDO...' : 'INICIAR DESCARGA';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Inicio de operación'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Container(
              padding: const EdgeInsets.all(26),
              decoration: BoxDecoration(
                color: const Color(0xFF0D131A),
                borderRadius: BorderRadius.circular(28),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 24,
                    offset: Offset(0, 10),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.06),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111923),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Usuario: ${widget.usuario.nombre}',
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Rol: ${capitalizar(widget.usuario.rol)}',
                          style: const TextStyle(
                            fontSize: 16,
                            color: Colors.white70,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'IDs permitidos: ${widget.usuario.accesoTotalIds ? 'TODOS' : widget.usuario.idsPermitidos.join(', ')}',
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 26),
                  const Text(
                    'Monitoreo de transferencia\n de crudo',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      height: 1.1,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF111923),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.05),
                      ),
                    ),
                    child: Text(
                      esPemex
                          ? 'Mini manual:\n'
                              '1. Este usuario es solo de consulta.\n'
                              '2. Usa la opción Consulta Pemex o Historiales.\n'
                              '3. No puede iniciar nuevas operaciones.'
                          : 'Mini manual:\n'
                              '1. Selecciona el lugar de trabajo.\n'
                              '2. Selecciona o captura el ID según tu rol.\n'
                              '3. Presiona INICIAR DESCARGA.\n'
                              '4. La app se conectará por Bluetooth clásico.\n'
                              '5. Revisa los datos en vivo.\n'
                              '6. Al finalizar, genera el resumen.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'Lugar de trabajo de bombeo móvil',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: lugarSeleccionado,
                    dropdownColor: const Color(0xFF111923),
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Selecciona una opción',
                      hintStyle: const TextStyle(color: Colors.white38),
                      filled: true,
                      fillColor: const Color(0xFF111923),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 18,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: Colors.white.withOpacity(0.08),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: Color(0xFF1BE28B),
                          width: 1.4,
                        ),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'Tanque Vertical',
                        child: Text('Tanque Vertical'),
                      ),
                      DropdownMenuItem(
                        value: 'Presa Metálica',
                        child: Text('Presa Metálica'),
                      ),
                    ],
                    onChanged: esPemex
                        ? null
                        : (value) {
                            setState(() {
                              lugarSeleccionado = value;
                            });
                          },
                  ),
                  const SizedBox(height: 20),
                  bloqueIdOperacion(),
                  bloqueAdminIds(),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 58,
                    child: ElevatedButton(
                      onPressed: enviandoContexto || esPemex ? null : iniciarOperacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            esPemex ? Colors.grey : const Color(0xFF1BE28B),
                        foregroundColor:
                            esPemex ? Colors.white : const Color(0xFF08110C),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        esPemex ? 'SOLO CONSULTA' : textoBoton,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
class PantallaMonitoreo extends StatefulWidget {
  final Usuario usuario;
  final String lugar;
  final String idTrabajo;
  final DateTime fechaInicio;

  const PantallaMonitoreo({
    super.key,
    required this.usuario,
    required this.lugar,
    required this.idTrabajo,
    required this.fechaInicio,
  });

  @override
  State<PantallaMonitoreo> createState() => _PantallaMonitoreoState();
}

class _PantallaMonitoreoState extends State<PantallaMonitoreo> {
  BluetoothConnection? conexionBT;
  StreamSubscription<Uint8List>? btSubscription;

  Timer? timerDuracion;
  Timer? timerReconnect;

  String buffer = '';

  double rpm = 0.0;
  double caudal = 0.0;
  double totalBombeado = 0.0;
  double caudalHora = 0.0;

  String estado = 'DESCONECTADO';
  bool conectado = false;
  bool conectandoBt = false;
  bool contextoEnviado = false;
  bool finalizando = false;

  int segundosOperacion = 0;
  final List<double> historialRpm = [];

  @override
  void initState() {
    super.initState();

    timerDuracion = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        segundosOperacion++;
      });
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      iniciarBt();
    });

    timerReconnect = Timer.periodic(const Duration(seconds: 6), (_) async {
      if (!mounted || finalizando) return;

      if (!conectado && !conectandoBt) {
        await iniciarBt();
      }
    });
  }

  @override
  void dispose() {
    timerDuracion?.cancel();
    timerReconnect?.cancel();
    btSubscription?.cancel();
    try {
      conexionBT?.dispose();
    } catch (_) {}
    super.dispose();
  }

  Future<void> iniciarBt() async {
    if (conectandoBt) return;

    setState(() {
      conectandoBt = true;
      conectado = false;
      contextoEnviado = false;
      estado = 'BUSCANDO BT';
    });

    try {
      debugPrint('========== BT DEBUG ==========');
      debugPrint('Entrando a iniciarBt()');

      final dispositivos =
          await FlutterBluetoothSerial.instance.getBondedDevices();

      debugPrint('Dispositivos vinculados encontrados: ${dispositivos.length}');

      for (final d in dispositivos) {
        debugPrint('BT Vinculado -> Nombre: ${d.name} | MAC: ${d.address}');
      }

      BluetoothDevice? objetivo;

      for (final d in dispositivos) {
        final nombre = (d.name ?? '').trim();
        if (nombre == BtConfig.deviceName) {
          objetivo = d;
          break;
        }
      }

      if (objetivo == null) {
        debugPrint('No se encontró el dispositivo: ${BtConfig.deviceName}');
        if (!mounted) return;
        setState(() {
          conectandoBt = false;
          conectado = false;
          estado = 'ESP32 NO EMPAREJADO';
        });
        return;
      }

      debugPrint('Dispositivo objetivo encontrado');
      debugPrint('Nombre objetivo: ${objetivo.name}');
      debugPrint('MAC objetivo: ${objetivo.address}');

      setState(() {
        estado = 'CONECTANDO BT';
      });

      debugPrint('Intentando BluetoothConnection.toAddress(...)');

      conexionBT = await BluetoothConnection.toAddress(objetivo.address);

      debugPrint('Conexión BT abierta correctamente');

      await btSubscription?.cancel();
      btSubscription = conexionBT!.input!.listen((data) {
        final recibido = utf8.decode(data, allowMalformed: true);
        debugPrint('RAW BT: $recibido');
        buffer += recibido;
        procesarBuffer();
      });

      debugPrint('Listener BT iniciado');

      if (!mounted) return;
      setState(() {
        conectandoBt = false;
        conectado = true;
        estado = 'CONECTADO';
      });

      debugPrint('Enviando PING...');
      await enviarContextoABt();

      debugPrint('Enviando START...');
      await enviarComandoInicio();

      debugPrint('========== BT OK ==========');
    } catch (e) {
      debugPrint('ERROR BT: $e');
      debugPrint('========== BT FAIL ==========');

      if (!mounted) return;
      setState(() {
        conectandoBt = false;
        conectado = false;
        estado = 'ERROR BT';
      });
    }
  }

  Future<void> enviarTextoBt(String texto) async {
    if (conexionBT == null) return;
    try {
      conexionBT!.output.add(Uint8List.fromList(utf8.encode('$texto\n')));
      await conexionBT!.output.allSent;
    } catch (e) {
      debugPrint('ERROR enviando BT: $e');
    }
  }

  Future<void> enviarContextoABt() async {
    await enviarTextoBt('PING');
    if (!mounted) return;
    setState(() {
      contextoEnviado = true;
    });
  }

  Future<void> enviarComandoInicio() async {
    await enviarTextoBt('START');
  }

  Future<void> enviarComandoFin() async {
    await enviarTextoBt('STOP');
  }

  void procesarBuffer() {
    while (buffer.contains('\n')) {
      final idx = buffer.indexOf('\n');
      final linea = buffer.substring(0, idx).trim();
      buffer = buffer.substring(idx + 1);

      if (linea.isEmpty) continue;
      procesarLinea(linea);
    }
  }

  void procesarLinea(String linea) {
    debugPrint('DATA BT: $linea');

    if (linea.startsWith('ACK:')) {
      return;
    }

    final partes = linea.split(',');
    final Map<String, String> datos = {};

    for (final p in partes) {
      final idx = p.indexOf(':');
      if (idx <= 0) continue;
      final key = p.substring(0, idx).trim().toUpperCase();
      final value = p.substring(idx + 1).trim();
      datos[key] = value;
    }

    final rpmNueva = double.tryParse(datos['RPM'] ?? '') ?? 0.0;
    final bblNueva = double.tryParse(datos['BBL'] ?? '') ?? 0.0;
    final totalNuevo = double.tryParse(datos['TOTAL'] ?? '') ?? totalBombeado;
    final estadoNuevo = (datos['ESTADO'] ?? '').trim();
    final alertaNueva = (datos['ALERTA'] ?? '').trim();

    if (rpmNueva > 0) {
      historialRpm.add(rpmNueva);
    }

    setState(() {
      rpm = rpmNueva;
      caudal = bblNueva;
      caudalHora = bblNueva * 60.0;
      totalBombeado = totalNuevo;

      if (estadoNuevo.isNotEmpty) {
        estado = estadoNuevo;
      } else if (conectado) {
        estado = 'CONECTADO';
      }

      if (alertaNueva.isNotEmpty && estadoNuevo.isEmpty) {
        estado = alertaNueva;
      }

      conectado = true;
      conectandoBt = false;
    });
  }

  String formatoSoloFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    return '$dia/$mes/$anio';
  }

  String formatoFechaHora(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    final segundo = fecha.second.toString().padLeft(2, '0');
    return '$dia/$mes/$anio $hora:$minuto:$segundo';
  }

  String formatearTiempo(int segundos) {
    final horas = (segundos ~/ 3600).toString().padLeft(2, '0');
    final minutos = ((segundos % 3600) ~/ 60).toString().padLeft(2, '0');
    final segs = (segundos % 60).toString().padLeft(2, '0');
    return '$horas:$minutos:$segs';
  }

  String construirResumenFinal({
    required DateTime fechaFin,
    required double rpmPromedio,
    required double totalFinal,
    required String tiempoOperacion,
  }) {
    return '📡 REPORTE DE BOMBEO\n\n'
        '📍 Lugar: ${widget.lugar}\n'
        '🆔 ID: ${widget.idTrabajo}\n'
        '👤 Usuario: ${widget.usuario.nombre}\n\n'
        '⏱ Inicio: ${formatoFechaHora(widget.fechaInicio)}\n'
        '⏱ Fin: ${formatoFechaHora(fechaFin)}\n'
        '⌛ Tiempo: $tiempoOperacion\n\n'
        '⚙️ RPM Promedio: ${rpmPromedio.toStringAsFixed(2)}\n'
        '🛢 Total Bombeado: ${totalFinal.toStringAsFixed(4)} bbl';
  }

  Color colorEstado() {
    switch (estado.toUpperCase()) {
      case 'OPTIMO':
        return Colors.lightGreenAccent;
      case 'TRABAJANDO':
      case 'ACTIVO':
      case 'CONECTADO':
        return const Color(0xFF1BE28B);
      case 'BAJO':
        return Colors.orangeAccent;
      case 'ALTO':
        return Colors.amber;
      case 'DETENIDO':
      case 'SIN_FLUJO':
        return Colors.redAccent;
      case 'BUSCANDO BT':
      case 'CONECTANDO BT':
        return Colors.orangeAccent;
      default:
        return Colors.redAccent;
    }
  }

  Future<void> finalizarOperacion() async {
    if (finalizando) return;

    setState(() {
      finalizando = true;
    });

    timerDuracion?.cancel();

    await enviarComandoFin();
    await Future.delayed(const Duration(milliseconds: 500));

    final fechaFin = DateTime.now();
    final tiempoOperacion = formatearTiempo(segundosOperacion);

    double rpmPromedio = 0.0;
    if (historialRpm.isNotEmpty) {
      final suma = historialRpm.reduce((a, b) => a + b);
      rpmPromedio = suma / historialRpm.length;
    }

    final totalFinal = totalBombeado;
    final resumen = construirResumenFinal(
      fechaFin: fechaFin,
      rpmPromedio: rpmPromedio,
      totalFinal: totalFinal,
      tiempoOperacion: tiempoOperacion,
    );

    final operationKey =
        '${widget.idTrabajo}_${fechaFin.microsecondsSinceEpoch}';

    final grupo = '${widget.lugar} - ${formatoSoloFecha(fechaFin)}';

    final registro = RegistroOperacion(
      operationKey: operationKey,
      usuario: widget.usuario.nombre,
      rol: widget.usuario.rol,
      lugar: widget.lugar,
      idTrabajo: widget.idTrabajo,
      grupoHistorial: grupo,
      fechaInicio: widget.fechaInicio,
      fechaFin: fechaFin,
      tiempoOperacion: tiempoOperacion,
      rpmPromedio: rpmPromedio,
      totalBombeado: totalFinal,
      resumenTexto: resumen,
      pendienteEnvio: true,
    );

    await ReporteService.guardarOperacionConSync(registro);

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaResumen(
          usuario: widget.usuario,
          lugar: widget.lugar,
          idTrabajo: widget.idTrabajo,
          fechaInicio: widget.fechaInicio,
          fechaFin: fechaFin,
          rpmPromedio: rpmPromedio,
          totalBombeado: totalFinal,
          tiempoOperacion: tiempoOperacion,
          resumenTexto: resumen,
          pendienteEnvio: true,
        ),
      ),
    );
  }

  void abrirHistoriales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistoriales(usuario: widget.usuario),
      ),
    );
  }

  void abrirPendientes() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaPendientes(usuario: widget.usuario),
      ),
    );
  }

  void abrirConsultaPemex() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
      ),
    );
  }

  void cerrarSesion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion();
      return;
    }

    if (value == 'Historiales') {
      abrirHistoriales();
      return;
    }

    if (value == 'Pendientes de envío') {
      abrirPendientes();
      return;
    }

    if (value == 'Consulta Pemex') {
      abrirConsultaPemex();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'Historiales',
        child: Text('Historiales'),
      ),
      const PopupMenuItem(
        value: 'Consulta Pemex',
        child: Text('Consulta Pemex'),
      ),
    ];

    if (!widget.usuario.esPemex) {
      items.add(
        const PopupMenuItem(
          value: 'Pendientes de envío',
          child: Text('Pendientes de envío'),
        ),
      );
    }

    items.add(
      const PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    );

    return items;
  }

  Widget tarjetaDisplay({
    required String titulo,
    required String valor,
    required String unidad,
    Color color = const Color(0xFF1BE28B),
    double valorFontSize = 58,
    double tituloFontSize = 16,
    double unidadFontSize = 13,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.08),
            blurRadius: 18,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: tituloFontSize,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.4,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: valorFontSize,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          if (unidad.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              unidad,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: unidadFontSize,
                color: Colors.white54,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget panelVisual() {
    final String estadoConexion = conectandoBt
        ? 'Conectando Bluetooth...'
        : (conectado ? 'Conectado' : 'Sin conexión');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.03),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white.withOpacity(0.04)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Usuario: ${widget.usuario.nombre} | Rol: ${widget.usuario.rol}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.white70,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: colorEstado(),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              estado,
                              style: TextStyle(
                                fontSize: 14,
                                color: colorEstado(),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(
                            formatearTiempo(segundosOperacion),
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Lugar de trabajo de bombeo móvil:',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.72),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${widget.lugar} - ID: ${widget.idTrabajo}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Colors.white70,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.04)),
            ),
            child: Column(
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFF1BE28B).withOpacity(0.10),
                    border: Border.all(
                      color: const Color(0xFF1BE28B).withOpacity(0.22),
                    ),
                  ),
                  child: const Icon(
                    Icons.local_shipping,
                    size: 42,
                    color: Color(0xFF1BE28B),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'UNIDAD MÓVIL DE\nBOMBEO',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    height: 1.2,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        height: 14,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFF4A1A00),
                              Color(0xFF8A4B00),
                              Color(0xFFE3A11A),
                              Color(0xFF8A4B00),
                              Color(0xFF4A1A00),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Container(
                      width: 82,
                      height: 98,
                      decoration: BoxDecoration(
                        color: const Color(0xFF202020),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white30, width: 3),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            left: 10,
                            right: 10,
                            bottom: 10,
                            child: Container(
                              height: 58,
                              decoration: BoxDecoration(
                                color: const Color(0xFF5A1C00),
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: List.generate(
                                3,
                                (_) => Container(
                                  height: 3,
                                  color: Colors.white24,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color:
                            conectado ? const Color(0xFF1BE28B) : Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        estadoConexion,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          color: conectado
                              ? const Color(0xFF1BE28B)
                              : Colors.redAccent,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  contextoEnviado ? 'Contexto enviado al equipo' : 'Contexto pendiente',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: contextoEnviado
                        ? const Color(0xFF1BE28B)
                        : Colors.orangeAccent,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget filaTresTarjetas() {
    return Row(
      children: [
        Expanded(
          child: tarjetaDisplay(
            titulo: 'CAUDAL / HORA',
            valor: caudalHora.toStringAsFixed(2),
            unidad: 'barriles/hora',
            color: Colors.cyanAccent,
            valorFontSize: 30,
            tituloFontSize: 14,
            unidadFontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tarjetaDisplay(
            titulo: 'TIEMPO',
            valor: formatearTiempo(segundosOperacion),
            unidad: 'hh:mm:ss',
            color: Colors.white,
            valorFontSize: 23,
            tituloFontSize: 14,
            unidadFontSize: 12,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: tarjetaDisplay(
            titulo: 'ESTADO',
            valor: estado,
            unidad: '',
            color: colorEstado(),
            valorFontSize: 22,
            tituloFontSize: 14,
            unidadFontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget filaTresTarjetasMovil() {
    return Column(
      children: [
        tarjetaDisplay(
          titulo: 'CAUDAL / HORA',
          valor: caudalHora.toStringAsFixed(2),
          unidad: 'barriles/hora',
          color: Colors.cyanAccent,
          valorFontSize: 38,
          tituloFontSize: 15,
          unidadFontSize: 12,
        ),
        const SizedBox(height: 12),
        tarjetaDisplay(
          titulo: 'TIEMPO',
          valor: formatearTiempo(segundosOperacion),
          unidad: 'hh:mm:ss',
          color: Colors.white,
          valorFontSize: 34,
          tituloFontSize: 15,
          unidadFontSize: 12,
        ),
        const SizedBox(height: 12),
        tarjetaDisplay(
          titulo: 'ESTADO',
          valor: estado,
          unidad: '',
          color: colorEstado(),
          valorFontSize: 30,
          tituloFontSize: 15,
          unidadFontSize: 12,
        ),
      ],
    );
  }
    @override
  Widget build(BuildContext context) {
    if (widget.usuario.esPemex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
          ),
        );
      });

      return const Scaffold(
        backgroundColor: Color(0xFF0A0F14),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Monitoreo en vivo'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final bool esPantallaAmplia = constraints.maxWidth >= 760;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(18),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: esPantallaAmplia ? 860 : 520,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      panelVisual(),
                      const SizedBox(height: 16),
                      tarjetaDisplay(
                        titulo: 'VOLUMEN TOTAL BOMB.',
                        valor: totalBombeado.toStringAsFixed(4),
                        unidad: 'BARRILES',
                        color: Colors.orangeAccent,
                        valorFontSize: esPantallaAmplia ? 56 : 52,
                        tituloFontSize: 16,
                        unidadFontSize: 13,
                      ),
                      const SizedBox(height: 12),
                      tarjetaDisplay(
                        titulo: 'CAUDAL ACTUAL',
                        valor: caudal.toStringAsFixed(4),
                        unidad: 'BARRILES / MIN',
                        color: Colors.lightGreenAccent,
                        valorFontSize: esPantallaAmplia ? 56 : 52,
                        tituloFontSize: 16,
                        unidadFontSize: 13,
                      ),
                      const SizedBox(height: 12),
                      tarjetaDisplay(
                        titulo: 'REVOLUCIONES DEL MOTOR',
                        valor: rpm.toStringAsFixed(2),
                        unidad: 'RPM',
                        color: const Color(0xFF57F2B2),
                        valorFontSize: esPantallaAmplia ? 56 : 52,
                        tituloFontSize: 16,
                        unidadFontSize: 13,
                      ),
                      const SizedBox(height: 12),
                      esPantallaAmplia
                          ? filaTresTarjetas()
                          : filaTresTarjetasMovil(),
                      const SizedBox(height: 18),
                      SizedBox(
                        width: double.infinity,
                        height: 60,
                        child: ElevatedButton(
                          onPressed: finalizando ? null : finalizarOperacion,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(18),
                            ),
                          ),
                          child: const Text(
                            'FINALIZAR OPERACIÓN',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class PantallaResumen extends StatelessWidget {
  final Usuario usuario;
  final String lugar;
  final String idTrabajo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final double rpmPromedio;
  final double totalBombeado;
  final String tiempoOperacion;
  final String resumenTexto;
  final bool pendienteEnvio;

  const PantallaResumen({
    super.key,
    required this.usuario,
    required this.lugar,
    required this.idTrabajo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.rpmPromedio,
    required this.totalBombeado,
    required this.tiempoOperacion,
    required this.resumenTexto,
    required this.pendienteEnvio,
  });

  String formato(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio  $hora:$minuto';
  }

  void abrirHistoriales(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistoriales(usuario: usuario),
      ),
    );
  }

  void abrirPendientes(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaPendientes(usuario: usuario),
      ),
    );
  }

  void abrirConsultaPemex(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConsultaPemex(usuario: usuario),
      ),
    );
  }

  void cerrarSesion(BuildContext context) {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(BuildContext context, String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion(context);
      return;
    }

    if (value == 'Historiales') {
      abrirHistoriales(context);
      return;
    }

    if (value == 'Pendientes de envío') {
      abrirPendientes(context);
      return;
    }

    if (value == 'Consulta Pemex') {
      abrirConsultaPemex(context);
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'Historiales',
        child: Text('Historiales'),
      ),
      const PopupMenuItem(
        value: 'Consulta Pemex',
        child: Text('Consulta Pemex'),
      ),
    ];

    if (!usuario.esPemex) {
      items.add(
        const PopupMenuItem(
          value: 'Pendientes de envío',
          child: Text('Pendientes de envío'),
        ),
      );
    }

    items.add(
      const PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    );

    return items;
  }

  Widget fila(String titulo, String valor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: Text(
              titulo,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 16,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Resumen final'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => manejarMenu(context, value),
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            color: const Color(0xFF0D131A),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black54,
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              fila('Usuario', usuario.nombre),
              fila('Rol', usuario.rol),
              fila('Lugar de trabajo', lugar),
              fila('ID', idTrabajo),
              fila('Inicio', formato(fechaInicio)),
              fila('Fin', formato(fechaFin)),
              fila('Tiempo total', tiempoOperacion),
              fila('RPM promedio', rpmPromedio.toStringAsFixed(2)),
              fila(
                'Total bombeado',
                '${totalBombeado.toStringAsFixed(4)} barriles',
              ),
              fila(
                'Estado de envío',
                pendienteEnvio ? 'PENDIENTE' : 'ENVIADO',
              ),
              const SizedBox(height: 18),
              const Text(
                'Resumen listo para envío:',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111923),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.05),
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      resumenTexto,
                      style: const TextStyle(fontSize: 15, height: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    if (usuario.esPemex) {
                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PantallaConsultaPemex(usuario: usuario),
                        ),
                        (route) => false,
                      );
                      return;
                    }

                    Navigator.pushAndRemoveUntil(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PantallaInicio(usuario: usuario),
                      ),
                      (route) => false,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1BE28B),
                    foregroundColor: const Color(0xFF08110C),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    usuario.esPemex ? 'VOLVER A CONSULTA' : 'VOLVER AL INICIO',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class PantallaHistoriales extends StatefulWidget {
  final Usuario usuario;

  const PantallaHistoriales({
    super.key,
    required this.usuario,
  });

  @override
  State<PantallaHistoriales> createState() => _PantallaHistorialesState();
}

class _PantallaHistorialesState extends State<PantallaHistoriales> {
  List<RegistroOperacion> registros = [];
  bool cargando = true;
  bool usandoVps = false;
  String? mensajeEstado;
  bool procesandoPdf = false;

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    setState(() {
      cargando = true;
      mensajeEstado = null;
    });

    try {
      final lista = await ReporteService.cargarHistorialDesdeVps();

      for (var i = 0; i < lista.length; i++) {
        final r = lista[i];
        if (r.grupoHistorial.trim().isEmpty) {
          final grupo = '${r.lugar} - ${formatoSoloFecha(r.fechaFin)}';
          lista[i] = r.copyWith(grupoHistorial: grupo);
        }
      }

      final filtrados = filtrarRegistrosPorUsuario(widget.usuario, lista);
      filtrados.sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

      if (!mounted) return;
      setState(() {
        registros = filtrados;
        cargando = false;
        usandoVps = true;
        mensajeEstado = 'Historial cargado desde VPS';
      });
    } catch (_) {
      final listaLocal = await ReporteService.cargarHistorial();

      final filtrados = filtrarRegistrosPorUsuario(widget.usuario, listaLocal);
      filtrados.sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

      if (!mounted) return;
      setState(() {
        registros = filtrados;
        cargando = false;
        usandoVps = false;
        mensajeEstado = 'Sin conexión al VPS. Mostrando historial local';
      });
    }
  }

  Future<void> generarPdf(RegistroOperacion r) async {
  if (procesandoPdf) return;

  setState(() => procesandoPdf = true);

  try {
    await PdfService.compartirPdfOperacion(r);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PDF compartido correctamente')),
    );
  } catch (e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Error al compartir PDF: $e')),
    );
  } finally {
    if (mounted) {
      setState(() => procesandoPdf = false);
    }
  }
}

  void abrirConsultaPemex() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
      ),
    );
  }

  void cerrarSesion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion();
      return;
    }

    if (value == 'Recargar historial') {
      cargarHistorial();
      return;
    }

    if (value == 'Consulta Pemex') {
      abrirConsultaPemex();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  String formato(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio  $hora:$minuto';
  }

  String formatoSoloFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    return '$dia/$mes/$anio';
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    return const [
      PopupMenuItem(
        value: 'Recargar historial',
        child: Text('Recargar historial'),
      ),
      PopupMenuItem(
        value: 'Consulta Pemex',
        child: Text('Consulta Pemex'),
      ),
      PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    ];
  }

  Widget tarjetaRegistro(RegistroOperacion r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuario: ${r.usuario} | Rol: ${r.rol}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text('ID: ${r.idTrabajo}'),
                Text('Inicio: ${formato(r.fechaInicio)}'),
                Text('Fin: ${formato(r.fechaFin)}'),
                Text('Tiempo total: ${r.tiempoOperacion}'),
                Text('RPM promedio: ${r.rpmPromedio.toStringAsFixed(2)}'),
                Text(
                  'Total bombeado: ${r.totalBombeado.toStringAsFixed(4)} barriles',
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D131A),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    r.resumenTexto,
                    style: const TextStyle(height: 1.4),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ElevatedButton(
                    onPressed: procesandoPdf ? null : () => generarPdf(r),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1BE28B),
                      foregroundColor: const Color(0xFF08110C),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      procesandoPdf ? 'COMPARTIENDO PDF...' : 'COMPARTIR PDF',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<RegistroOperacion>> agrupados = {};

    for (final r in registros) {
      agrupados.putIfAbsent(r.grupoHistorial, () => []).add(r);
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Historial de operaciones'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (mensajeEstado != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: usandoVps
                          ? const Color(0xFF1BE28B).withOpacity(0.10)
                          : Colors.orange.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: usandoVps
                            ? const Color(0xFF1BE28B).withOpacity(0.20)
                            : Colors.orange.withOpacity(0.20),
                      ),
                    ),
                    child: Text(
                      mensajeEstado!,
                      style: TextStyle(
                        color: usandoVps
                            ? const Color(0xFF1BE28B)
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Expanded(
                  child: registros.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay historial disponible',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: agrupados.keys.length,
                          itemBuilder: (_, i) {
                            final grupo = agrupados.keys.elementAt(i);
                            final lista = agrupados[grupo]!;

                            return Container(
                              margin: const EdgeInsets.only(bottom: 16),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D131A),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    grupo,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1BE28B),
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  ...lista.map(tarjetaRegistro),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
class PantallaPendientes extends StatefulWidget {
  final Usuario usuario;

  const PantallaPendientes({
    super.key,
    required this.usuario,
  });

  @override
  State<PantallaPendientes> createState() => _PantallaPendientesState();
}

class _PantallaPendientesState extends State<PantallaPendientes> {
  List<RegistroOperacion> pendientes = [];
  bool cargando = true;
  bool reenviando = false;

  @override
  void initState() {
    super.initState();
    cargarPendientes();
  }

  Future<void> cargarPendientes() async {
    final lista = await ReporteService.cargarPendientes();
    final filtrados = filtrarRegistrosPorUsuario(widget.usuario, lista)
      ..sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

    setState(() {
      pendientes = filtrados;
      cargando = false;
    });
  }

  Future<void> reenviarTodos() async {
    if (reenviando) return;

    if (!widget.usuario.esAdmin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Solo el administrador puede reenviar pendientes'),
        ),
      );
      return;
    }

    setState(() => reenviando = true);

    final enviados = await ReporteService.reenviarPendientes();
    await cargarPendientes();

    if (!mounted) return;

    setState(() => reenviando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se enviaron $enviados reporte(s) pendiente(s)')),
    );
  }

  void abrirHistoriales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistoriales(usuario: widget.usuario),
      ),
    );
  }

  void abrirConsultaPemex() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
      ),
    );
  }

  void cerrarSesion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion();
      return;
    }

    if (value == 'Historiales') {
      abrirHistoriales();
      return;
    }

    if (value == 'Consulta Pemex') {
      abrirConsultaPemex();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  String formato(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio  $hora:$minuto';
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    return const [
      PopupMenuItem(
        value: 'Historiales',
        child: Text('Historiales'),
      ),
      PopupMenuItem(
        value: 'Consulta Pemex',
        child: Text('Consulta Pemex'),
      ),
      PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    ];
  }

  Widget tarjetaPendiente(RegistroOperacion r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${r.lugar} - ${r.idTrabajo}',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text('Usuario: ${r.usuario}'),
          Text('Inicio: ${formato(r.fechaInicio)}'),
          Text('Fin: ${formato(r.fechaFin)}'),
          Text('RPM promedio: ${r.rpmPromedio.toStringAsFixed(2)}'),
          Text(
            'Total bombeado: ${r.totalBombeado.toStringAsFixed(4)} barriles',
          ),
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFF0D131A),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              r.resumenTexto,
              style: const TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.usuario.esPemex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PantallaConsultaPemex(usuario: widget.usuario),
          ),
        );
      });

      return const Scaffold(
        backgroundColor: Color(0xFF0A0F14),
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Pendientes de envío'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (widget.usuario.esAdmin)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: reenviando ? null : reenviarTodos,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1BE28B),
                          foregroundColor: const Color(0xFF08110C),
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          reenviando ? 'REENVIANDO...' : 'REENVIAR TODOS',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: pendientes.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay reportes pendientes',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: pendientes.length,
                          itemBuilder: (_, i) => tarjetaPendiente(pendientes[i]),
                        ),
                ),
              ],
            ),
    );
  }
}

class PantallaConsultaPemex extends StatefulWidget {
  final Usuario usuario;

  const PantallaConsultaPemex({
    super.key,
    required this.usuario,
  });

  @override
  State<PantallaConsultaPemex> createState() => _PantallaConsultaPemexState();
}

class _PantallaConsultaPemexState extends State<PantallaConsultaPemex> {
  List<RegistroOperacion> registros = [];
  List<RegistroOperacion> filtrados = [];

  final TextEditingController usuarioFiltroController = TextEditingController();
  final TextEditingController idFiltroController = TextEditingController();
  final TextEditingController fechaFiltroController = TextEditingController();

  bool cargando = true;
  bool usandoVps = false;
  String? mensajeEstado;
  bool procesandoPdf = false;

  @override
  void initState() {
    super.initState();
    cargarRegistros();
  }

  @override
  void dispose() {
    usuarioFiltroController.dispose();
    idFiltroController.dispose();
    fechaFiltroController.dispose();
    super.dispose();
  }

  Future<void> cargarRegistros() async {
    setState(() {
      cargando = true;
      mensajeEstado = null;
    });

    try {
      final lista = await ReporteService.cargarHistorialDesdeVps();

      for (var i = 0; i < lista.length; i++) {
        final r = lista[i];
        if (r.grupoHistorial.trim().isEmpty) {
          final grupo = '${r.lugar} - ${formatoSoloFecha(r.fechaFin)}';
          lista[i] = r.copyWith(grupoHistorial: grupo);
        }
      }

      final filtradosPorUsuario = filtrarRegistrosPorUsuario(
        widget.usuario,
        lista,
      )..sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

      if (!mounted) return;
      setState(() {
        registros = filtradosPorUsuario;
        filtrados = List<RegistroOperacion>.from(filtradosPorUsuario);
        cargando = false;
        usandoVps = true;
        mensajeEstado = 'Consulta cargada desde servidor';
      });
    } catch (e) {
      final listaLocal = await ReporteService.cargarHistorial();

      for (var i = 0; i < listaLocal.length; i++) {
        final r = listaLocal[i];
        if (r.grupoHistorial.trim().isEmpty) {
          final grupo = '${r.lugar} - ${formatoSoloFecha(r.fechaFin)}';
          listaLocal[i] = r.copyWith(grupoHistorial: grupo);
        }
      }

      final filtradosPorUsuario = filtrarRegistrosPorUsuario(
        widget.usuario,
        listaLocal,
      )..sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

      if (!mounted) return;
      setState(() {
        registros = filtradosPorUsuario;
        filtrados = List<RegistroOperacion>.from(filtradosPorUsuario);
        cargando = false;
        usandoVps = false;
        mensajeEstado = 'Sin conexión al servidor. Mostrando historial local';
      });
    }
  }

  void aplicarFiltros() {
    final usuarioFiltro = usuarioFiltroController.text.trim().toLowerCase();
    final idFiltro = idFiltroController.text.trim().toLowerCase();
    final fechaFiltro = fechaFiltroController.text.trim().toLowerCase();

    final lista = registros.where((r) {
      final coincideUsuario =
          usuarioFiltro.isEmpty || r.usuario.toLowerCase().contains(usuarioFiltro);

      final coincideId =
          idFiltro.isEmpty || r.idTrabajo.toLowerCase().contains(idFiltro);

      final fechaTexto = formatoSoloFecha(r.fechaFin).toLowerCase();
      final coincideFecha =
          fechaFiltro.isEmpty || fechaTexto.contains(fechaFiltro);

      return coincideUsuario && coincideId && coincideFecha;
    }).toList();

    setState(() {
      filtrados = lista;
    });
  }

  void limpiarFiltros() {
    usuarioFiltroController.clear();
    idFiltroController.clear();
    fechaFiltroController.clear();

    setState(() {
      filtrados = List<RegistroOperacion>.from(registros);
    });
  }

  Future<void> manejarAccionPdf(String accion, RegistroOperacion r) async {
    if (procesandoPdf) return;

    if (!usuarioPuedeUsarId(widget.usuario, r.idTrabajo)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tienes permiso para abrir ese registro'),
        ),
      );
      return;
    }

    setState(() {
      procesandoPdf = true;
    });

    try {
      if (accion == 'ver_pdf') {
        await PdfService.imprimirPdfOperacion(r);
      } else if (accion == 'compartir_pdf') {
        await PdfService.compartirPdfOperacion(r);
      } else if (accion == 'guardar_pdf') {
        final archivo = await PdfService.generarPdfOperacion(r);

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF guardado en: ${archivo.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error con PDF: $e')),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        procesandoPdf = false;
      });
    }
  }

  void abrirHistoriales() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaHistoriales(usuario: widget.usuario),
      ),
    );
  }

  void abrirPendientes() {
    if (widget.usuario.esPemex) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El usuario Pemex no tiene acceso a pendientes'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaPendientes(usuario: widget.usuario),
      ),
    );
  }

  void abrirInicio() {
    if (widget.usuario.esPemex) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('El usuario Pemex solo tiene acceso de consulta'),
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaInicio(usuario: widget.usuario),
      ),
    );
  }

  void cerrarSesion() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const PantallaLogin()),
      (route) => false,
    );
  }

  void manejarMenu(String value) {
    if (value == 'Cerrar sesión') {
      cerrarSesion();
      return;
    }

    if (value == 'Historiales') {
      abrirHistoriales();
      return;
    }

    if (value == 'Pendientes de envío') {
      abrirPendientes();
      return;
    }

    if (value == 'Inicio') {
      abrirInicio();
      return;
    }

    if (value == 'Recargar') {
      cargarRegistros();
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  String formato(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    final hora = fecha.hour.toString().padLeft(2, '0');
    final minuto = fecha.minute.toString().padLeft(2, '0');
    return '$dia/$mes/$anio  $hora:$minuto';
  }

  String formatoSoloFecha(DateTime fecha) {
    final dia = fecha.day.toString().padLeft(2, '0');
    final mes = fecha.month.toString().padLeft(2, '0');
    final anio = fecha.year.toString();
    return '$dia/$mes/$anio';
  }

  List<PopupMenuEntry<String>> construirItemsMenu() {
    final items = <PopupMenuEntry<String>>[
      const PopupMenuItem(
        value: 'Recargar',
        child: Text('Recargar'),
      ),
      const PopupMenuItem(
        value: 'Historiales',
        child: Text('Historiales'),
      ),
    ];

    if (!widget.usuario.esPemex) {
      items.addAll([
        const PopupMenuItem(
          value: 'Inicio',
          child: Text('Inicio'),
        ),
        const PopupMenuItem(
          value: 'Pendientes de envío',
          child: Text('Pendientes de envío'),
        ),
      ]);
    }

    items.add(
      const PopupMenuItem(
        value: 'Cerrar sesión',
        child: Text('Cerrar sesión'),
      ),
    );

    return items;
  }

  Widget campoFiltro({
    required TextEditingController controller,
    required String hint,
  }) {
    return Expanded(
      child: TextField(
        controller: controller,
        onChanged: (_) => aplicarFiltros(),
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white38),
          filled: true,
          fillColor: const Color(0xFF111923),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: Colors.white.withOpacity(0.08),
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
              color: Color(0xFF1BE28B),
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Widget tarjetaRegistro(RegistroOperacion r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF111923),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Usuario: ${r.usuario} | Rol: ${r.rol}',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 6),
                Text('Lugar: ${r.lugar}'),
                Text('ID: ${r.idTrabajo}'),
                Text('Inicio: ${formato(r.fechaInicio)}'),
                Text('Fin: ${formato(r.fechaFin)}'),
                Text('Tiempo total: ${r.tiempoOperacion}'),
                Text('RPM promedio: ${r.rpmPromedio.toStringAsFixed(2)}'),
                Text(
                  'Total bombeado: ${r.totalBombeado.toStringAsFixed(4)} barriles',
                ),
                Text(
                  'Estado de envío: ${r.pendienteEnvio ? 'PENDIENTE' : 'ENVIADO'}',
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            icon: const Icon(
              Icons.picture_as_pdf,
              color: Colors.white70,
            ),
            onSelected: (value) => manejarAccionPdf(value, r),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'ver_pdf',
                child: Text('Ver / imprimir PDF'),
              ),
              PopupMenuItem(
                value: 'compartir_pdf',
                child: Text('Compartir PDF'),
              ),
              PopupMenuItem(
                value: 'guardar_pdf',
                child: Text('Guardar PDF'),
              ),
            ],
          ),
        ],
      ),
    );
  }
    @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F14),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0D131A),
        elevation: 0,
        title: const Text('Consulta Pemex'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => construirItemsMenu(),
          ),
        ],
      ),
      body: cargando
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : Column(
              children: [
                if (mensajeEstado != null)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: usandoVps
                          ? const Color(0xFF1BE28B).withOpacity(0.10)
                          : Colors.orange.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: usandoVps
                            ? const Color(0xFF1BE28B).withOpacity(0.20)
                            : Colors.orange.withOpacity(0.20),
                      ),
                    ),
                    child: Text(
                      mensajeEstado!,
                      style: TextStyle(
                        color: usandoVps
                            ? const Color(0xFF1BE28B)
                            : Colors.orangeAccent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          campoFiltro(
                            controller: usuarioFiltroController,
                            hint: 'Filtrar por usuario',
                          ),
                          const SizedBox(width: 10),
                          campoFiltro(
                            controller: idFiltroController,
                            hint: 'Filtrar por ID',
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          campoFiltro(
                            controller: fechaFiltroController,
                            hint: 'Filtrar por fecha (dd/mm/aaaa)',
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            height: 52,
                            child: ElevatedButton(
                              onPressed: limpiarFiltros,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white10,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                              child: const Text(
                                'LIMPIAR',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: filtrados.isEmpty
                      ? const Center(
                          child: Text(
                            'No hay registros para mostrar',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.white70,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: filtrados.length,
                          itemBuilder: (_, i) => tarjetaRegistro(filtrados[i]),
                        ),
                ),
              ],
            ),
    );
  }
}