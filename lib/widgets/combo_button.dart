/// Combo button (split button / menu-arrow button).
///
/// Combina dos regiones adyacentes: una zona principal que ejecuta la acción
/// por defecto inmediatamente, y una pequeña flecha adjunta que abre un menú
/// de alternativas relacionadas. No es un pop-up button (que muestra un valor
/// seleccionado) ni un pull-down button (todo el botón abre el menú).
///
/// Inspirado en AppKit NSComboButton.Style.split.
import 'package:flutter/material.dart';

import '../theme.dart';

class ComboButton<T> extends StatelessWidget {
  /// Texto mostrado en la zona principal (opcional; si no hay [icon], se usa el texto).
  final String? label;
  /// Ícono de la zona principal (opcional; si no hay [label], se usa el icono).
  final IconData? icon;
  /// Tooltip de la zona principal.
  final String? tooltip;
  /// Acción ejecutada al tocar la zona principal (acción por defecto inmediata).
  final VoidCallback onPressed;
  /// Ícono de la flecha que abre el menú (por defecto arrow_drop_down).
  final IconData menuIcon;
  /// Ítems del menú desplegable (abiertos por la flecha).
  final List<PopupMenuEntry<T>> menuItems;
  /// Callback invocado al seleccionar un ítem del menú (por la flecha).
  final ValueChanged<T>? onSelected;
  /// Color de fondo del combo (por defecto AppColors.primary).
  final Color? backgroundColor;
  /// Color de los íconos/texto (por defecto blanco).
  final Color? foregroundColor;
  /// Ancho fijo del combo (por defecto se expande al máximo).
  final double? width;
  /// Altura del combo (por defecto 40).
  final double height;

  const ComboButton({
    super.key,
    this.label,
    this.icon,
    this.tooltip,
    required this.onPressed,
    this.menuIcon = Icons.arrow_drop_down,
    required this.menuItems,
    this.onSelected,
    this.backgroundColor,
    this.foregroundColor,
    this.width,
    this.height = 40,
  }) : assert(label != null || icon != null, 'ComboButton necesita al menos un label o un icon');

  @override
  Widget build(BuildContext context) {
    final fg = foregroundColor ?? Colors.white;
    final bg = backgroundColor ?? AppColors.primary;

    Widget primaryRegion = Container(
      height: height,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
      ),
      alignment: Alignment.center,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, color: fg, size: 22),
            const SizedBox(width: 8),
          ],
          if (label != null) Text(label!, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 16)),
        ],
      ),
    );

    Widget menuRegion = Container(
      width: height - 8,
      height: height,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.only(topRight: Radius.circular(12), bottomRight: Radius.circular(12)),
        border: Border(left: BorderSide(color: Colors.white.withValues(alpha: 0.18), width: 1)),
      ),
      alignment: Alignment.center,
      child: Icon(menuIcon, color: fg, size: 20),
    );

    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        width: width,
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Zona principal: acción inmediata. Sin ancho fijo no usa flex (está
            // sin límites en Row), así que no rompe con constraints ilimitados.
            Expanded(
              flex: width == null ? 0 : 1,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
                  onTap: onPressed,
                  child: primaryRegion,
                ),
              ),
            ),
            // Zona flecha: abre el menú.
            PopupMenuButton<T>(
              tooltip: tooltip,
              onSelected: onSelected,
              itemBuilder: (_) => menuItems,
              color: bg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Material(
                color: Colors.transparent,
                child: menuRegion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
