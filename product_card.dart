import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../models/product.dart';
import '../../../../services/cart_service.dart';
import '../../../../services/favorites_service.dart';
import '../../../../utils/font_helper.dart';
import '../../../../widgets/app_toast.dart';
import 'product_grid_image.dart';

/// ⚡ بطاقة منتج خفيفة — أبسط تصميم ممكن
class ProductCard extends StatelessWidget {
  final Product product;
  final bool isDark;
  const ProductCard({super.key, required this.product, required this.isDark});

  // ═══ ثوابت ═══
  static const double fixedCardHeight = 240.0;
  static const double fixedImageHeight = 170.0;

  // ═══ Card ═══
  static const _radius = BorderRadius.all(Radius.circular(12));
  static const _darkCard = BoxDecoration(
    color: Color(0xFF111118),
    borderRadius: _radius,
  );
  static const _lightCard = BoxDecoration(
    color: Colors.white,
    borderRadius: _radius,
  );

  // ═══ Quantity badge (أعلى يسار الصورة) ═══
  // تم تخفيف شكلها (القص المعقد كان يؤثر على الأداء)
  static const _qtyDeco = BoxDecoration(
    color: Color(0xCCD4AF37),
  );
  static final _qtyStyle = FontHelper.cairo(color: Colors.black, fontSize: 9, fontWeight: FontWeight.w700);

  // ═══ Name ═══
  static final _nameDark = FontHelper.cairo(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700, height: 1.2);
  static final _nameLight = FontHelper.cairo(color: const Color(0xFF1C1C1E), fontSize: 13, fontWeight: FontWeight.w700, height: 1.2);

  // ═══ Price ═══
  static final _priceGold = FontHelper.cairo(color: const Color(0xFFD4AF37), fontSize: 14, fontWeight: FontWeight.w700);
  static final _discounted = FontHelper.cairo(color: const Color(0xFFE53935), fontSize: 13, fontWeight: FontWeight.w700);
  static final _strikeDark = FontHelper.cairo(color: const Color(0xFF555566), fontSize: 11, decoration: TextDecoration.lineThrough, decorationColor: const Color(0xFF555566));
  static final _strikeLight = FontHelper.cairo(color: Colors.grey, fontSize: 11, decoration: TextDecoration.lineThrough, decorationColor: Colors.grey);

  // ═══ Heart button ═══
  static const _heartLiked = BoxDecoration(
    color: Color(0x20EF4444),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _heartDark = BoxDecoration(
    color: Color(0xFF1A1A25),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _heartLight = BoxDecoration(
    color: Color(0xFFF5F5F5),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  // ═══ Cart button ═══
  static const _cartIn = BoxDecoration(
    color: Color(0x2010B981),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _cartDark = BoxDecoration(
    color: Color(0xFF1A1A25),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _cartLight = BoxDecoration(
    color: Color(0xFFF5F5F5),
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );

  // ═══ Helpers ═══
  static final _priceRe = RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))');
  String _fmt(num p) => '${p.toInt().toString().replaceAllMapped(_priceRe, (m) => '${m[1]},')} د.ع';

  static int getSmartColumnCount(double sw) {
    if (sw > 1400) return 5;
    if (sw > 1100) return 4;
    if (sw > 800) return 3;
    return 2;
  }

  bool get _hasDiscount => (product.userOffer?.hasOffer ?? false) || (product.globalDiscount?.isActive ?? false);
  double get _finalPrice {
    final p = product.wholesalePrice;
    if (product.userOffer?.hasOffer ?? false) return product.userOffer!.calculateFinalPrice(p);
    if (product.globalDiscount?.isActive ?? false) return product.globalDiscount!.calculateFinalPrice(p);
    return p;
  }

  @override
  Widget build(BuildContext context) {
    final discount = _hasDiscount;

    return RepaintBoundary(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/products/details/${product.id}');
        },
        child: ClipRRect(
          borderRadius: _radius,
          clipBehavior: Clip.hardEdge, // ⚡ أخف من antiAlias
          child: DecoratedBox(
            decoration: isDark ? _darkCard : _lightCard,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ═══ الصورة + عداد القطع (أعلى يسار) ═══
                SizedBox(
                  height: fixedImageHeight,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      (product.thumbnailUrl?.isNotEmpty ?? false) || product.images.isNotEmpty
                          ? ProductGridImage(
                              imageUrl: product.thumbnailUrl?.isNotEmpty == true
                                  ? product.thumbnailUrl!
                                  : product.images.first,
                              width: double.infinity,
                              height: fixedImageHeight,
                              isDark: isDark,
                            )
                          : ColoredBox(
                              color: isDark ? const Color(0xFF15151F) : const Color(0xFFE0E0E0),
                              child: const Center(
                                child: Icon(Icons.image_outlined, color: Colors.grey, size: 32),
                              ),
                            ),
                      // عداد القطع — أعلى يسار
                      Positioned(
                        left: 0,
                        top: 0,
                        child: DecoratedBox(
                          decoration: _qtyDeco,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                            child: Text('${product.availableFrom}-${product.availableTo}', style: _qtyStyle),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              // ═══ الاسم ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 0),
                  child: Text(
                    product.name,
                    style: isDark ? _nameDark : _nameLight,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ),

                // ═══ السعر + الأزرار ═══
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 4, 6, 5),
                  child: Row(
                    children: [
                      // السعر
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 2),
                          child: discount
                              ? Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(_fmt(_finalPrice), style: _discounted, maxLines: 1, overflow: TextOverflow.ellipsis),
                                    Text(_fmt(product.wholesalePrice), style: isDark ? _strikeDark : _strikeLight, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  ],
                                )
                              : Text(_fmt(product.wholesalePrice), style: _priceGold, maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ),

                      // ❤️ المفضلة
                      Selector<FavoritesService, bool>(
                        selector: (_, s) => s.isFavorite(product.id),
                        builder: (context, liked, _) => GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.read<FavoritesService>().toggleFavoriteSync(product.id);
                          },
                          child: DecoratedBox(
                            decoration: liked ? _heartLiked : (isDark ? _heartDark : _heartLight),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(
                                liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                                color: liked ? const Color(0xFFEF4444) : (isDark ? const Color(0xFF666680) : const Color(0xFFAAAAAA)),
                                size: 16,
                              ),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(width: 4),

                      // 🛒 السلة
                      Selector<CartService, ({bool inCart, bool full})>(
                        selector: (_, c) => (inCart: c.hasProduct(product.id), full: c.isFull),
                        builder: (context, s, _) => GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            final cart = context.read<CartService>();
                            if (!s.inCart) {
                              if (s.full) {
                                AppToast.show(context, message: 'السلة ممتلئة! ${CartService.maxCartItems} منتج فقط', type: ToastType.warning, icon: Icons.shopping_bag_rounded);
                                return;
                              }
                              cart.addItemSync(
                                productId: product.id,
                                name: product.name,
                                image: product.images.isNotEmpty ? product.images.first : '',
                                minPrice: product.minPrice.toInt(),
                                maxPrice: product.maxPrice.toInt(),
                                customerPrice: 0,
                                wholesalePrice: product.wholesalePrice.toInt(),
                                quantity: 1,
                              );
                            } else {
                              cart.removeByProductId(product.id);
                            }
                          },
                          child: DecoratedBox(
                            decoration: s.inCart ? _cartIn : (isDark ? _cartDark : _cartLight),
                            child: SizedBox(
                              width: 30,
                              height: 30,
                              child: Icon(
                                s.inCart ? Icons.check_rounded : Icons.add_rounded,
                                color: s.inCart ? const Color(0xFF10B981) : (isDark ? const Color(0xFF666680) : const Color(0xFFAAAAAA)),
                                size: 18,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
