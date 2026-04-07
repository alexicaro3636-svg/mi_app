import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bluetooth_serial_plus/flutter_bluetooth_serial_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/reporte_service.dart';
import 'models/registro_operacion.dart';

void main() {
  runApp(const TelemetriaApp());
}

class Usuario {
  final String nombre;
  final String pin;
  final String rol;

  Usuario({
    required this.nombre,
    required this.pin,
    required this.rol,
  });
}

  

final List<Usuario> usuarios = [
  Usuario(nombre: 'admin', pin: '1234', rol: 'admin'),
  Usuario(nombre: 'operador', pin: '0000', rol: 'general'),
];

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

  @override
  void dispose() {
    usuarioController.dispose();
    pinController.dispose();
    super.dispose();
  }

  void iniciarSesion() {
    final nombre = usuarioController.text.trim();
    final pin = pinController.text.trim();

    final usuario = usuarios.firstWhere(
      (u) => u.nombre == nombre && u.pin == pin,
      orElse: () => Usuario(nombre: '', pin: '', rol: ''),
    );

    if (usuario.nombre.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Credenciales incorrectas')),
      );
      return;
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => PantallaInicio(usuario: usuario),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.white70,
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'INICIAR SESIÓN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 28),
                  TextField(
                    controller: usuarioController,
                    decoration: InputDecoration(
                      hintText: 'Usuario',
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: pinController,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: 'PIN (4 dígitos)',
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 26),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: iniciarSesion,
                      child: const Text(
                        'ENTRAR',
                        style: TextStyle(fontSize: 17),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Usuario admin: admin / ****\nUsuario general: operador / 0000',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 13,
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

  bool get esAdmin => widget.usuario.rol == 'admin';

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

    setState(() {
      idsDisponibles = idsGuardados ?? ['ID-1001', 'ID-1002', 'ID-1003'];
    });
  }

  Future<void> guardarIds() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('ids_disponibles', idsDisponibles);
  }

  Future<void> agregarNuevoId() async {
    final nuevoId = nuevoIdController.text.trim();

    if (nuevoId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe un ID válido')),
      );
      return;
    }

    if (idsDisponibles.contains(nuevoId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ese ID ya existe')),
      );
      return;
    }

    setState(() {
      idsDisponibles.add(nuevoId);
      idsDisponibles.sort();
      nuevoIdController.clear();
    });

    await guardarIds();

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('ID agregado: $nuevoId')),
    );
  }

  Future<void> reintentarPendientesSilencioso() async {
    if (reenviandoPendientes) return;
    reenviandoPendientes = true;
    final enviados = await ReporteService.reenviarPendientes();
    reenviandoPendientes = false;

    if (!mounted) return;
    if (enviados > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Se enviaron $enviados reporte(s) pendiente(s)')),
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
        builder: (_) => const PantallaPendientes(),
      ),
    );
  }

  Future<void> iniciarOperacion() async {
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  String capitalizar(String texto) {
    if (texto.isEmpty) return texto;
    return texto[0].toUpperCase() + texto.substring(1);
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
            decoration: InputDecoration(
              hintText: 'Escribe el identificador',
              filled: true,
              fillColor: Colors.black54,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
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
          dropdownColor: const Color(0xFF2A2A2A),
          decoration: InputDecoration(
            hintText: 'Selecciona un ID',
            filled: true,
            fillColor: Colors.black54,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
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
          onChanged: (value) {
            setState(() {
              idSeleccionado = value;
            });
          },
        ),
        const SizedBox(height: 8),
        const Text(
          'Modo operador: solo puedes seleccionar IDs existentes.',
          style: TextStyle(color: Colors.white60, fontSize: 13),
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black38,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Administración de IDs',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nuevoIdController,
                decoration: InputDecoration(
                  hintText: 'Escribe un nuevo ID',
                  filled: true,
                  fillColor: Colors.black54,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 48,
                child: ElevatedButton(
                  onPressed: agregarNuevoId,
                  child: const Text('AGREGAR ID'),
                ),
              ),
              const SizedBox(height: 14),
              const Text(
                'IDs guardados:',
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
                          backgroundColor: Colors.blueGrey,
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
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('INICIO DE OPERACIÓN'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'Historiales',
                child: Text('Historiales'),
              ),
              PopupMenuItem(
                value: 'Pendientes de envío',
                child: Text('Pendientes de envío'),
              ),
              PopupMenuItem(
                value: 'Descarga de reporte',
                child: Text('Descarga de reporte'),
              ),
              PopupMenuItem(
                value: 'Solicita ayuda o reporta errores',
                child: Text('Solicita ayuda o reporta errores'),
              ),
              PopupMenuItem(
                value: 'Cerrar sesión',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 20,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white12),
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'MONITOREO DE TRANSFERENCIA\nDE CRUDO',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w300,
                      height: 1.1,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.black38,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Text(
                      'Mini manual:\n'
                      '1. Selecciona el lugar de trabajo.\n'
                      '2. Selecciona o captura el ID según tu rol.\n'
                      '3. Presiona INICIAR DESCARGA.\n'
                      '4. La app se conectará por Bluetooth clásico.\n'
                      '5. Revisa los datos en vivo.\n'
                      '6. Al finalizar, genera el resumen.',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white70,
                        height: 1.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Lugar de trabajo de bombeo móvil',
                    style: TextStyle(fontSize: 18),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: lugarSeleccionado,
                    dropdownColor: const Color(0xFF2A2A2A),
                    decoration: InputDecoration(
                      hintText: 'Selecciona una opción',
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
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
                    onChanged: (value) {
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
                    height: 56,
                    child: ElevatedButton(
                      onPressed: enviandoContexto ? null : iniciarOperacion,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueGrey,
                      ),
                      child: Text(
                        textoBoton,
                        style: const TextStyle(fontSize: 17),
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
        return Colors.greenAccent;
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
        builder: (_) => const PantallaPendientes(),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
  }

  Widget tarjetaDisplay({
    required String titulo,
    required String valor,
    required String unidad,
    Color color = Colors.greenAccent,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.12),
            blurRadius: 16,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            titulo,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w300,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              style: TextStyle(
                fontSize: 62,
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            unidad,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
        ],
      ),
    );
  }

  Widget panelVisual() {
    final String estadoConexion = conectandoBt
        ? 'Conectando Bluetooth...'
        : (conectado ? 'Conectado' : 'Sin conexión');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.local_shipping,
            size: 92,
            color: Colors.white70,
          ),
          const SizedBox(height: 10),
          const Text(
            'UNIDAD MÓVIL DE BOMBEO',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
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
              const SizedBox(width: 16),
              Container(
                width: 90,
                height: 110,
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
                        height: 70,
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
                          (_) => Container(height: 3, color: Colors.white24),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: conectado ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                estadoConexion,
                style: TextStyle(
                  fontSize: 16,
                  color: conectado ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            contextoEnviado ? 'Contexto enviado al equipo' : 'Contexto pendiente',
            style: TextStyle(
              fontSize: 14,
              color: contextoEnviado ? Colors.greenAccent : Colors.orangeAccent,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final tiempoFormateado = formatearTiempo(segundosOperacion);

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('MONITOREO EN VIVO'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'Historiales',
                child: Text('Historiales'),
              ),
              PopupMenuItem(
                value: 'Pendientes de envío',
                child: Text('Pendientes de envío'),
              ),
              PopupMenuItem(
                value: 'Descarga de reporte',
                child: Text('Descarga de reporte'),
              ),
              PopupMenuItem(
                value: 'Solicita ayuda o reporta errores',
                child: Text('Solicita ayuda o reporta errores'),
              ),
              PopupMenuItem(
                value: 'Cerrar sesión',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Usuario: ${widget.usuario.nombre} | Rol: ${widget.usuario.rol}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
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
                            fontSize: 16,
                            color: colorEstado(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        'TIEMPO: $tiempoFormateado',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Lugar de trabajo de bombeo móvil: ${widget.lugar} - ID: ${widget.idTrabajo}',
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final esAncho = constraints.maxWidth > 900;

                  if (esAncho) {
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 6, child: panelVisual()),
                        const SizedBox(width: 18),
                        Expanded(
                          flex: 5,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                tarjetaDisplay(
                                  titulo: 'CAUDAL ACTUAL',
                                  valor: caudal.toStringAsFixed(4),
                                  unidad: 'BARRILES / MIN',
                                ),
                                const SizedBox(height: 16),
                                tarjetaDisplay(
                                  titulo: 'CAUDAL POR HORA',
                                  valor: caudalHora.toStringAsFixed(2),
                                  unidad: 'BARRILES / HORA',
                                  color: Colors.cyanAccent,
                                ),
                                const SizedBox(height: 16),
                                tarjetaDisplay(
                                  titulo: 'VOLUMEN TOTAL BOMB.',
                                  valor: totalBombeado.toStringAsFixed(4),
                                  unidad: 'BARRILES',
                                  color: Colors.orangeAccent,
                                ),
                                const SizedBox(height: 16),
                                tarjetaDisplay(
                                  titulo: 'REVOLUCIONES DEL MOTOR',
                                  valor: rpm.toStringAsFixed(2),
                                  unidad: 'RPM',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    );
                  }

                  return SingleChildScrollView(
                    child: Column(
                      children: [
                        panelVisual(),
                        const SizedBox(height: 18),
                        tarjetaDisplay(
                          titulo: 'CAUDAL ACTUAL',
                          valor: caudal.toStringAsFixed(4),
                          unidad: 'BARRILES / MIN',
                        ),
                        const SizedBox(height: 16),
                        tarjetaDisplay(
                          titulo: 'CAUDAL POR HORA',
                          valor: caudalHora.toStringAsFixed(2),
                          unidad: 'BARRILES / HORA',
                          color: Colors.cyanAccent,
                        ),
                        const SizedBox(height: 16),
                        tarjetaDisplay(
                          titulo: 'VOLUMEN TOTAL BOMB.',
                          valor: totalBombeado.toStringAsFixed(4),
                          unidad: 'BARRILES',
                          color: Colors.orangeAccent,
                        ),
                        const SizedBox(height: 16),
                        tarjetaDisplay(
                          titulo: 'REVOLUCIONES DEL MOTOR',
                          valor: rpm.toStringAsFixed(2),
                          unidad: 'RPM',
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 56,
              child: ElevatedButton(
                onPressed: finalizando ? null : finalizarOperacion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                ),
                child: Text(
                  finalizando ? 'FINALIZANDO...' : 'FINALIZAR DESCARGA',
                  style: const TextStyle(fontSize: 17),
                ),
              ),
            ),
          ],
        ),
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
        builder: (_) => const PantallaPendientes(),
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Opción seleccionada: $value')),
    );
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
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('RESUMEN FINAL'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: (value) => manejarMenu(context, value),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'Historiales',
                child: Text('Historiales'),
              ),
              PopupMenuItem(
                value: 'Pendientes de envío',
                child: Text('Pendientes de envío'),
              ),
              PopupMenuItem(
                value: 'Cerrar sesión',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            borderRadius: BorderRadius.circular(14),
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
              const SizedBox(height: 16),
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
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white10),
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
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.popUntil(context, (route) => route.isFirst);
                  },
                  child: const Text('VOLVER AL INICIO'),
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

  @override
  void initState() {
    super.initState();
    cargarHistorial();
  }

  Future<void> cargarHistorial() async {
    final lista = await ReporteService.cargarHistorial();
    lista.sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

    setState(() {
      registros = lista;
      cargando = false;
    });
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

  Widget tarjetaRegistro(RegistroOperacion r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
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
          Text(
            'Estado de envío: ${r.pendienteEnvio ? 'PENDIENTE' : 'ENVIADO'}',
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, List<RegistroOperacion>> grupos = {};

    for (final registro in registros) {
      grupos.putIfAbsent(registro.grupoHistorial, () => []);
      grupos[registro.grupoHistorial]!.add(registro);
    }

    final claves = grupos.keys.toList();

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('HISTORIALES'),
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            onSelected: manejarMenu,
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'Cerrar sesión',
                child: Text('Cerrar sesión'),
              ),
            ],
          ),
        ],
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : registros.isEmpty
              ? const Center(
                  child: Text(
                    'No hay registros guardados todavía',
                    style: TextStyle(fontSize: 16, color: Colors.white70),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: claves.length,
                  itemBuilder: (context, index) {
                    final grupo = claves[index];
                    final lista = grupos[grupo]!;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2A2A2A),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            grupo,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.lightBlueAccent,
                            ),
                          ),
                          const SizedBox(height: 12),
                          ...lista.map(tarjetaRegistro),
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}

class PantallaPendientes extends StatefulWidget {
  const PantallaPendientes({super.key});

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
    lista.sort((a, b) => b.fechaFin.compareTo(a.fechaFin));

    setState(() {
      pendientes = lista;
      cargando = false;
    });
  }

  Future<void> reenviarTodos() async {
    if (reenviando) return;

    setState(() => reenviando = true);

    final enviados = await ReporteService.reenviarPendientes();
    await cargarPendientes();

    if (!mounted) return;

    setState(() => reenviando = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Se enviaron $enviados reporte(s) pendiente(s)')),
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

  Widget tarjetaPendiente(RegistroOperacion r) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.black38,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
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
              color: Colors.black54,
              borderRadius: BorderRadius.circular(10),
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
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('PENDIENTES DE ENVÍO'),
        centerTitle: true,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: reenviando ? null : reenviarTodos,
                      child: Text(
                        reenviando ? 'REENVIANDO...' : 'REENVIAR TODOS',
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
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                          itemCount: pendientes.length,
                          itemBuilder: (context, index) {
                            return tarjetaPendiente(pendientes[index]);
                          },
                        ),
                ),
              ],
            ),
    );
  }
}