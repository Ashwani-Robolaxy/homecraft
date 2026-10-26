import 'package:flutter/material.dart';

import '../constants/app_assets.dart';

/// App-wide placeholder when a person's profile image is unavailable or errors.
class PersonProfilePlaceholder extends StatelessWidget {
  const PersonProfilePlaceholder({
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
  });

  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      AppAssets.profilePlaceholder,
      width: width,
      height: height,
      fit: fit,
    );
  }
}
