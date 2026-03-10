import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// ⚡ ويدجت خفيف جداً مخصص لأداء صور المنتجات على الموبايل
/// CachedNetworkImage = كاش القرص + فك تشفير على thread منفصل (native)
class ProductGridImage extends StatelessWidget {
  final String imageUrl;
  final double width;
  final double height;
  final bool isDark;

  /// ⚡ الحد الأقصى لحجم فك التشفير (الصور المصدرية 400×400)
  static const int _maxDecodeSize = 400;

  const ProductGridImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final dpr = MediaQuery.devicePixelRatioOf(context);

    final safeW = width.isFinite ? width : MediaQuery.sizeOf(context).width;
    final safeH = height.isFinite ? height : safeW;

    // ⚡ سقف 400px — لا فائدة من فك تشفير أكبر من المصدر الأصلي
    final cacheW = (safeW * dpr).round().clamp(1, _maxDecodeSize);
    final cacheH = (safeH * dpr).round().clamp(1, _maxDecodeSize);

    return CachedNetworkImage(
      imageUrl: imageUrl,
      fit: BoxFit.cover,
      width: width,
      height: height,
      fadeInDuration: Duration.zero,
      fadeOutDuration: Duration.zero,
      memCacheWidth: cacheW,
      memCacheHeight: cacheH,
      // ⚡ placeholder ثابت — بدون Shimmer أو Animation
      placeholder: (_, __) => ColoredBox(
        color: isDark ? const Color(0xFF15151F) : const Color(0xFFE0E0E0),
      ),
      errorWidget: (_, __, ___) => ColoredBox(
        color: isDark ? const Color(0xFF15151F) : const Color(0xFFE0E0E0),
        child: const Center(
          child: Icon(Icons.broken_image_outlined, color: Colors.grey),
        ),
      ),
    );
  }
}
