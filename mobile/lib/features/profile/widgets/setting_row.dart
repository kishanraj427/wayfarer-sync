import 'package:flutter/material.dart';
import '../../../core/theme/appTokens.dart';

/// A single row in the profile's Account section: a leading icon, a label,
/// and either a trailing widget (e.g. a [Switch]) or a tap action.
class SettingRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool isDestructive;

  const SettingRow({
    super.key,
    required this.icon,
    required this.label,
    this.trailing,
    this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final foreground = isDestructive ? colorScheme.error : colorScheme.onSurface;

    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.md),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.md),
          child: Row(
            children: [
              Icon(icon, color: foreground),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Text(
                  label,
                  style: textTheme.titleMedium?.copyWith(color: foreground),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),
      ),
    );
  }
}
