import 'package:flutter/material.dart';
import '../../../core/constants/appStrings.dart';
import '../../../core/theme/appTheme.dart';
import '../../../core/theme/appTokens.dart';

class MemberAvatarCluster extends StatelessWidget {
  final List<Color> colors;
  final int total;
  const MemberAvatarCluster({super.key, required this.colors, required this.total});

  static const int _maxShown = 4;
  static const double _avatarSize = 22;
  static const double _overlap = 14;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    final shown = colors.take(_maxShown).toList();
    final clusterWidth =
        shown.isEmpty ? 0.0 : _avatarSize + (shown.length - 1) * _overlap;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: clusterWidth,
          height: _avatarSize,
          child: Stack(
            children: [
              for (var index = 0; index < shown.length; index++)
                Positioned(
                  left: index * _overlap,
                  child: Container(
                    width: _avatarSize,
                    height: _avatarSize,
                    decoration: BoxDecoration(
                      color: shown[index],
                      shape: BoxShape.circle,
                      border: Border.all(color: surface, width: 2),
                    ),
                  ),
                ),
            ],
          ),
        ),
        if (clusterWidth > 0) const SizedBox(width: AppSpace.sm),
        Text(AppStrings.travelersCount(total), style: monoData(context, size: 12)),
      ],
    );
  }
}
