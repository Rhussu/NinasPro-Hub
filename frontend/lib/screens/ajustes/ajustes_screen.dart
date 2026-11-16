import 'package:flutter/material.dart';
import '../../config/ninaspro_colors.dart';
import '../../widgets/ninaspro_ajustes.dart';

/// Datos de cabecera que cada rol entrega a [AjustesScreen].
@immutable
class AjustesPerfil {
  final String nombre;
  final String detalle;
  final String rolEtiqueta;
  final String rolEmoji;

  const AjustesPerfil({
    required this.nombre,
    required this.detalle,
    required this.rolEtiqueta,
    required this.rolEmoji,
  });
}

/// Pantalla base de Ajustes compartida por los 4 roles.
///
/// Estructura fija:
/// 1. Cabecera de perfil ([perfil])
/// 2. Secciones propias del rol ([secciones]) — aquí va lo que cambia entre roles
/// 3. Apariencia (modo claro / oscuro / sistema) con [AjustesApariencia]
/// 4. Cuenta (cerrar sesión) con [AjustesCuenta]
///
/// Cada rol crea su propio wrapper (ej. `AjustesAlumnaScreen`) que carga sus datos
/// y arma sus [secciones] con [AjustesSeccion] + [AjustesTile].
/// [anchoMaximo] centra el contenido en pantallas anchas (vista Desktop de Directiva).
class AjustesScreen extends StatelessWidget {
  final AjustesPerfil? perfil;
  final List<Widget> secciones;
  final ValueNotifier<ThemeMode>? themeNotifier;
  final VoidCallback? onCerrarSesion;
  final bool cargando;
  final double anchoMaximo;

  const AjustesScreen({
    super.key,
    required this.perfil,
    this.secciones = const [],
    this.themeNotifier,
    this.onCerrarSesion,
    this.cargando = false,
    this.anchoMaximo = 640,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: cargando || perfil == null
          ? const Center(child: CircularProgressIndicator())
          : Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: anchoMaximo),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  children: [
                    AjustesPerfilHeader(
                      nombre: perfil!.nombre,
                      detalle: perfil!.detalle,
                      rolEtiqueta: perfil!.rolEtiqueta,
                      rolEmoji: perfil!.rolEmoji,
                    ),
                    const SizedBox(height: 20),
                    ...secciones,
                    if (themeNotifier != null) AjustesApariencia(themeNotifier: themeNotifier!),
                    AjustesCuenta(onCerrarSesion: onCerrarSesion),
                    const Center(
                      child: Text(
                        'NiñasPro Hub · MVP',
                        style: TextStyle(fontSize: 11, color: NinasProColors.neutral500),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
