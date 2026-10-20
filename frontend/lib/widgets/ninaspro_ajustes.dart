import 'package:flutter/material.dart';
import '../config/ninaspro_colors.dart';

/// Bloques visuales compartidos por las pantallas de Ajustes de todos los roles.
///
/// - [AjustesPerfilHeader]: banner con avatar, nombre y rol del usuario.
/// - [AjustesSeccion]: grupo con título y tarjeta que contiene varios [AjustesTile].
/// - [AjustesTile]: fila de ajuste (dato de solo lectura, acción o interruptor).
/// - [AjustesApariencia] y [AjustesCuenta]: secciones fijas que comparten todos los roles.

class AjustesPerfilHeader extends StatelessWidget {
  final String nombre;
  final String detalle;
  final String rolEtiqueta;
  final String rolEmoji;

  const AjustesPerfilHeader({
    super.key,
    required this.nombre,
    required this.detalle,
    required this.rolEtiqueta,
    required this.rolEmoji,
  });

  String get _iniciales => nombre
      .split(' ')
      .where((p) => p.isNotEmpty)
      .take(2)
      .map((p) => p[0].toUpperCase())
      .join();

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [NinasProColors.primary900, NinasProColors.accent900]
              : [NinasProColors.primary100, NinasProColors.accent100],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: NinasProColors.primary700,
            child: Text(
              _iniciales,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: NinasProColors.white,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nombre,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    color: isDark ? NinasProColors.white : NinasProColors.primary900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  detalle,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral700,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                  decoration: BoxDecoration(
                    color: NinasProColors.brandPink,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$rolEmoji $rolEtiqueta',
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: NinasProColors.neutral900,
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
}

class AjustesSeccion extends StatelessWidget {
  final String titulo;
  final List<Widget> children;

  const AjustesSeccion({
    super.key,
    required this.titulo,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              titulo.toUpperCase(),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
          ),
          Card(
            elevation: 0,
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            color: isDark ? NinasProColors.dark800 : NinasProColors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
              ),
            ),
            child: Column(
              children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      indent: 56,
                      color: isDark ? NinasProColors.dark700 : NinasProColors.neutral100,
                    ),
                  children[i],
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class AjustesTile extends StatelessWidget {
  final IconData icono;
  final String titulo;
  final String? subtitulo;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool destructivo;

  const AjustesTile({
    super.key,
    required this.icono,
    required this.titulo,
    this.subtitulo,
    this.trailing,
    this.onTap,
    this.destructivo = false,
  });

  /// Interruptor on/off (notificaciones, preferencias).
  factory AjustesTile.interruptor({
    Key? key,
    required IconData icono,
    required String titulo,
    String? subtitulo,
    required bool valor,
    required ValueChanged<bool> onChanged,
  }) {
    return AjustesTile(
      key: key,
      icono: icono,
      titulo: titulo,
      subtitulo: subtitulo,
      onTap: () => onChanged(!valor),
      trailing: Switch(
        value: valor,
        activeThumbColor: NinasProColors.brandPink,
        onChanged: onChanged,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorDestructivo = isDark ? NinasProColors.error300 : NinasProColors.error700;
    final colorAcento = destructivo ? colorDestructivo : NinasProColors.brandPink;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(
          color: colorAcento.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icono, size: 19, color: colorAcento),
      ),
      title: Text(
        titulo,
        style: TextStyle(
          fontSize: 13.5,
          fontWeight: FontWeight.w700,
          color: destructivo ? colorDestructivo : null,
        ),
      ),
      subtitle: subtitulo == null
          ? null
          : Text(
              subtitulo!,
              style: TextStyle(
                fontSize: 12,
                color: isDark ? NinasProColors.neutral300 : NinasProColors.neutral500,
              ),
            ),
      trailing: trailing ??
          (onTap != null && !destructivo
              ? const Icon(Icons.chevron_right_rounded, color: NinasProColors.neutral500)
              : null),
    );
  }
}

/// Sección "Apariencia": modo claro, oscuro o del sistema.
class AjustesApariencia extends StatelessWidget {
  final ValueNotifier<ThemeMode> themeNotifier;

  const AjustesApariencia({super.key, required this.themeNotifier});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, modo, _) {
        return AjustesSeccion(
          titulo: 'Apariencia',
          children: [
            Padding(
              padding: const EdgeInsets.all(14),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_rounded, size: 18),
                      label: Text('Claro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_rounded, size: 18),
                      label: Text('Oscuro'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_rounded, size: 18),
                      label: Text('Sistema'),
                    ),
                  ],
                  selected: {modo},
                  onSelectionChanged: (seleccion) => themeNotifier.value = seleccion.first,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Sección "Cuenta" con "Cerrar sesión" y su confirmación.
/// Sin [onCerrarSesion] (mockup) solo cierra Ajustes y avisa.
class AjustesCuenta extends StatelessWidget {
  final VoidCallback? onCerrarSesion;

  const AjustesCuenta({super.key, this.onCerrarSesion});

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar sesión?'),
        content: const Text('Tendrás que volver a ingresar con tu cuenta para usar NiñasPro Hub.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: NinasProColors.error700),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar sesión'),
          ),
        ],
      ),
    );
    if (confirmado != true || !context.mounted) return;

    if (onCerrarSesion != null) {
      onCerrarSesion!();
      return;
    }

    // Mockup: aún no hay autenticación, solo se vuelve atrás y se informa
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger.showSnackBar(
      const SnackBar(
        backgroundColor: NinasProColors.primary700,
        content: Text('👋 Sesión cerrada (mockup: autenticación pendiente).'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AjustesSeccion(
      titulo: 'Cuenta',
      children: [
        AjustesTile(
          icono: Icons.logout_rounded,
          titulo: 'Cerrar sesión',
          destructivo: true,
          onTap: () => _confirmarCerrarSesion(context),
        ),
      ],
    );
  }
}
