import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/banners_provider.dart';
import '../../../providers/products_provider.dart';
import '../../../services/favorites_service.dart';
import '../../../utils/theme_extension.dart';
import '../../../core/design_system.dart';
import 'widgets/products_search_bar.dart';
import 'package:flutter/physics.dart';
// 🚀 ULTRA PERFORMANCE: Removed dart:ui (BackdropFilter removed)
import 'widgets/product_card.dart';
import 'widgets/products_empty_state.dart';
import 'widgets/products_error_state.dart';
import 'widgets/products_loading.dart';
import '../../../widgets/sliding_drawer.dart';
import '../../../providers/user_provider.dart';
import '../../../utils/font_helper.dart';

class NewProductsPage extends StatefulWidget {
  const NewProductsPage({super.key});

  // ✅ للوصول من الخارج (FluidNavBar)
  static void scrollToTop() => _NewProductsPageState.scrollToTop();

  @override
  State<NewProductsPage> createState() => _NewProductsPageState();
}

class _NewProductsPageState extends State<NewProductsPage> {
  // ✅ Static للوصول من FluidNavBar عند إعادة النقر على نفس التبويب
  static ScrollController? _activeScrollCtrl;

  static void scrollToTop() {
    if (_activeScrollCtrl != null && _activeScrollCtrl!.hasClients) {
      _activeScrollCtrl!.animateTo(0, duration: const Duration(milliseconds: 400), curve: Curves.easeOutCubic);
    }
  }

  final _scrollCtrl = ScrollController();

  // ⚡ PERFORMANCE: كاش أبعاد الشاشة مرة واحدة
  double _screenWidth = 0;
  int _cols = 2;
  double _margin = 20;
  double _spacing = 12;

  @override
  void initState() {
    super.initState();
    _activeScrollCtrl = _scrollCtrl;
    _loadData();
    _scrollCtrl.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // ⚡ كاش الأبعاد مرة واحدة بدل كل build
    final sw = MediaQuery.sizeOf(context).width;
    if (sw != _screenWidth) {
      _screenWidth = sw;
      _cols = ProductCard.getSmartColumnCount(sw);
      _margin = sw > 600 ? 24.0 : (sw > 400 ? sw * 0.07 : 20.0);
      _spacing = sw > 600 ? 16.0 : (sw > 400 ? 14.0 : 12.0);
    }
  }

  @override
  void dispose() {
    if (_activeScrollCtrl == _scrollCtrl) _activeScrollCtrl = null;
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _loadData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ProductsProvider>().loadProducts();
      context.read<BannersProvider>().loadBanners();
      context.read<FavoritesService>().loadFavorites();
    });
  }

  void _onScroll() {
    if (!mounted) return;
    final pos = _scrollCtrl.position;
    if (pos.pixels >= pos.maxScrollExtent - 500) {
      final p = context.read<ProductsProvider>();
      if (!p.isLoading && !p.isLoadingMore && p.hasMore) p.loadMore();
    }
  }

  Future<void> _onRefresh() => Future.wait([
    context.read<ProductsProvider>().loadProducts(forceRefresh: true),
    context.read<BannersProvider>().loadBanners(),
  ]);

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBody: true,
      body: RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppDesignSystem.goldColor,
        backgroundColor: isDark ? const Color(0xFF1a1a2e) : Colors.white,
        child: Selector<ProductsProvider, ({bool loading, bool error, bool empty, bool loadingMore, int version})>(
          selector: (_, p) => (
            loading: p.isLoading,
            error: p.hasError,
            empty: p.isEmpty,
            loadingMore: p.isLoadingMore,
            version: p.version,
          ),
          builder: (context, s, _) {
            // 🚀 ULTRA PERFORMANCE: تم التخلص من Stack و AnimatedBuilder بالكامل!
            // وضع الهيدر كـ Sliver الأصلي في القائمة يمنع Rebuild مع كل بيكسل تمرير ويتركه لمحرك C++
            return CustomScrollView(
              controller: _scrollCtrl,
              clipBehavior: Clip.none,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: _ArcHeader(
                    isDark: isDark,
                    categories: const ['الكل', 'عام', 'أخرى', 'هدايا', 'الكترونيات', 'منزلية'],
                  ),
                ),
                const SliverToBoxAdapter(child: SizedBox(height: 32)),

                // ⚡ UI/UX: الانتقال السلس بين الحالات
                ..._buildContentSlivers(s, isDark),

                if (s.loadingMore) SliverToBoxAdapter(child: ProductsLoadingSkeleton(isDark: isDark, itemCount: 2)),
                const SliverToBoxAdapter(child: SizedBox(height: 160)),
              ],
            );
          },
        ),
      ),
    );
  }

  /// ⚡ ترجع Slivers بناءً على الحالة
  List<Widget> _buildContentSlivers(
    ({bool loading, bool error, bool empty, bool loadingMore, int version}) s,
    bool isDark,
  ) {
    // Loading
    if (s.loading && s.version <= 1) {
      return [const SliverToBoxAdapter(child: ProductsLoading())];
    }

    // Error
    if (s.error && s.version <= 1) {
      return [
        SliverToBoxAdapter(
          child: ProductsErrorState(
            message: context.read<ProductsProvider>().errorMessage,
            onRetry: context.read<ProductsProvider>().retry,
          ),
        ),
      ];
    }

    // Empty
    if (s.empty) {
      return [
        SliverToBoxAdapter(
          child: ProductsEmptyState(onRetry: () => context.read<ProductsProvider>().loadProducts(forceRefresh: true)),
        ),
      ];
    }

    // Grid — المنتجات الحقيقية
    return [_buildGrid(isDark)];
  }

  Widget _buildGrid(bool isDark) {
    final products = context.read<ProductsProvider>().products;
    final mainAxisSpacing = _spacing > 12 ? 14.0 : (_spacing > 10 ? 12.0 : 10.0);

    return SliverPadding(
      padding: EdgeInsets.symmetric(horizontal: _margin, vertical: _margin > 12 ? 8 : 4),
      sliver: SliverGrid(
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: _cols,
          mainAxisExtent: ProductCard.fixedCardHeight,
          crossAxisSpacing: _spacing,
          mainAxisSpacing: mainAxisSpacing,
        ),
        delegate: SliverChildBuilderDelegate(
          (_, i) => ProductCard(key: ValueKey(products[i].id), product: products[i], isDark: isDark),
          childCount: products.length,
          addAutomaticKeepAlives: false, // ⚡ لا تُبقِ البطاقات غير المرئية في الذاكرة
        ),
      ),
    );
  }
}

// ==========================================
// الهيدر بقوس مقلوب وكرات دائرية مع شريط التطبيق
// ==========================================

class _ArcHeader extends StatelessWidget {
  final bool isDark;
  final List<String> categories;

  const _ArcHeader({required this.isDark, required this.categories});

  Widget build(BuildContext context) {
    // Read the currently selected category from the provider
    final rawCategory = context.watch<ProductsProvider>().selectedCategory;
    final selectedCat = rawCategory.isEmpty ? 'الكل' : rawCategory;

    return _ArcCarousel(
      isDark: isDark,
      categories: categories,
      selectedCategory: selectedCat,
      onSelect: (cat) {
        // Update the provider when a category is tapped
        context.read<ProductsProvider>().setCategory(cat == 'الكل' ? '' : cat);
      },
    );
  }
}

class _ArcCarousel extends StatefulWidget {
  final bool isDark;
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onSelect;

  const _ArcCarousel({
    required this.isDark,
    required this.categories,
    required this.selectedCategory,
    required this.onSelect,
  });

  @override
  State<_ArcCarousel> createState() => _ArcCarouselState();
}

class _ArcCarouselState extends State<_ArcCarousel> with SingleTickerProviderStateMixin {
  late AnimationController _flingCtrl;

  // مساحة الهيدر أكبر قليلاً لاستيعاب شريط التطبيق المتكامل و استطالة القوس
  static const double _headerHeight = 205.0;
  static const double _iconSize = 52.0;

  static final _labelStyle = FontHelper.cairo(color: Colors.black87, fontSize: 11, fontWeight: FontWeight.w700);

  @override
  void initState() {
    super.initState();
    _flingCtrl = AnimationController.unbounded(vsync: this, value: 0.0);
  }

  @override
  void dispose() {
    _flingCtrl.dispose();
    super.dispose();
  }

  void _scrollToIndex(int index) {
    if (!mounted) return;
    _flingCtrl.stop(); // إيقاف أي أنميشن أو سحب سابق

    final targetOffset = index.toDouble();
    if ((_flingCtrl.value - targetOffset).abs() < 0.01) return; // بالفعل بالمنتصف

    // الانتقال بنعومة وسلاسة أكبر إلى المركز
    _flingCtrl.animateTo(targetOffset, duration: const Duration(milliseconds: 500), curve: Curves.easeOutCubic);
  }

  void _onCategoryTap(int index, String categoryName) {
    widget.onSelect(categoryName);
    _scrollToIndex(index);
  }

  void _onPanUpdate(DragUpdateDetails d) {
    _flingCtrl.stop();
    final maxOffset = (widget.categories.length - 1).toDouble();
    double newValue = _flingCtrl.value - d.delta.dx / 160;

    // أضف مقاومة مرنة خارج الحدود
    if (newValue < 0.0) {
      newValue = 0.0;
    } else if (newValue > maxOffset) {
      newValue = maxOffset;
    }

    _flingCtrl.value = newValue; // تحديث متواصل وسلس
  }

  void _onPanEnd(DragEndDetails d) {
    final velocity = -d.velocity.pixelsPerSecond.dx / 160;
    final currentOffset = _flingCtrl.value;
    final maxOffset = (widget.categories.length - 1).toDouble();
    final clampedTarget = currentOffset.clamp(0.0, maxOffset);

    if ((currentOffset - clampedTarget).abs() > 0.01) {
      _flingCtrl.animateTo(clampedTarget, duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    } else {
      // تقليل الاحتكاك (Friction) مع وضع حدود صارمة لمنع التجاوز (Overshoot)
      final simulation = BoundedFrictionSimulation(0.015, currentOffset, velocity, 0.0, maxOffset);

      _flingCtrl.animateWith(simulation).whenComplete(() {
        _snapToNearest();
      });
    }
  }

  void _snapToNearest() {
    if (!mounted) return;
    final count = widget.categories.length;
    double target = _flingCtrl.value.roundToDouble();
    if (target < 0) target = 0;
    if (target >= count) target = count - 1.0;

    _scrollToIndex(target.toInt());
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final count = widget.categories.length;

    // منحنى ضحل ومرفوع
    final double curveDepth = 25.0; // عمق القوس
    final double bottomY = _headerHeight - 20.0; // النقطة السفلى

    // معادلة المنحنى (Parabola): y = a * dx^2 + bottomY
    final a = -curveDepth / ((w / 2) * (w / 2));

    // المسافة بين الكرات لتبدو مثل نصف دائرة لكن بمسار مسطح قليلا (تم التقريب حسب طلب المستخدم)
    final itemSpacing = (w / 4.5).clamp(60.0, 95.0);

    // القيمة القصوى للتمرير
    final maxScroll = (count - 1).toDouble();

    return GestureDetector(
      onPanUpdate: _onPanUpdate,
      onPanEnd: _onPanEnd,
      child: Container(
        height: _headerHeight,
        width: w,
        // جعلنا الخلفية شفافة حتى لا يظهر أي لون مستطيل أسفل القوس
        color: Colors.transparent,
        clipBehavior: Clip.none, // السماح للضباب بالتمدد
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            // --- 0. خلفية القوس بلون صلب شبه شفاف ---
            // 🚀 ULTRA PERFORMANCE: No BackdropFilter - لون صلب بدل الضباب الذي يقتل الـ GPU
            Positioned.fill(
              child: CustomPaint(
                painter: _HeaderBgPainter(
                  isDark: widget.isDark,
                  curveDepth: curveDepth,
                  bottomY: bottomY,
                  statusBarHeight: MediaQuery.paddingOf(context).top,
                ),
              ),
            ),
            // --- محتويات السطر العلوي الثابتة (مثل GlobalAppBar) ---
            Positioned(
              top: MediaQuery.paddingOf(context).top,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  // السطر العلوي: نسخة 100% من GlobalAppBar مدمجة بالهيدر
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // عنوان "متـوفـر" بالوسط
                        const Text(
                          'متـوفـر',
                          style: TextStyle(
                            fontFamily: 'BadeenDisplay',
                            fontSize: 32,
                            fontWeight: FontWeight.w400,
                            color: Color(0xFFDAA520),
                            height: 1.0,
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // الجزء الأيمن (الترحيب) - يظهر دائماً في صفحة المنتجات (Home)
                            Expanded(child: _buildGreetingRow(context)),

                            // الجزء الأيسر (زر القائمة المنسدلة)
                            GestureDetector(
                              onTap: () {
                                context.read<SlidingDrawerController>().toggle();
                              },
                              child: Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: const Color(0x14FFFFFF), // نفس _darkBtnBg في GlobalAppBar
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: const Color(0x1FFFFFFF), width: 1.0),
                                ),
                                child: const Center(child: Icon(Icons.menu_rounded, color: Colors.white, size: 19)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),

                  // شريط البحث الأنيق (Theme فاتح أو داكن حسب الرغبة)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    // ⚡ نمرر isDark هنا لكي يتفاعل شريط البحث بقوة مع لون الخلفية الموحد
                    child: ProductsSearchBar(isDark: widget.isDark),
                  ),
                ],
              ),
            ),

            // --- كرات الفئات المتحركة (AnimatedBuilder واحد فقط!) ---
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _flingCtrl,
                builder: (context, _) {
                  double currentOffset = _flingCtrl.value.clamp(0.0, maxScroll);
                  return Stack(
                    clipBehavior: Clip.none,
                    children: List.generate(count, (i) {
                      final distance = i - currentOffset;
                      final dx = distance * itemSpacing;
                      final x = w / 2 + dx;
                      final y = a * dx * dx + bottomY + 12.0;

                      double scale = (1.0 - (distance.abs() * 0.15)).clamp(0.6, 1.0);
                      double opacity = (1.0 - (distance.abs() * 0.3)).clamp(0.0, 1.0);

                      if (opacity == 0) return const SizedBox.shrink();

                      final cat = widget.categories[i];
                      final isSelected = cat == widget.selectedCategory;

                      return Positioned(
                        left: x - 35,
                        top: y - 35,
                        child: Transform.scale(
                          scale: scale,
                          child: GestureDetector(
                            onTap: () => _onCategoryTap(i, cat),
                            child: SizedBox(
                              width: 70,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: _iconSize,
                                    height: _iconSize,
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? (widget.isDark ? const Color(0xFFF7D980) : const Color(0xFFDAA520))
                                          : (widget.isDark ? const Color(0x14FFFFFF) : Colors.white),
                                      shape: BoxShape.circle,
                                      border: isSelected
                                          ? null
                                          : Border.all(
                                              color: widget.isDark ? const Color(0x1FFFFFFF) : Colors.transparent,
                                              width: 1.0,
                                            ),
                                    ),
                                    child: Icon(
                                      _icon(cat),
                                      color:
                                          (isSelected
                                                  ? (widget.isDark ? const Color(0xFF1a1a2e) : Colors.white)
                                                  : (widget.isDark ? Colors.white70 : const Color(0xFF2c3e50)))
                                              .withValues(alpha: opacity),
                                      size: 22,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    cat,
                                    style:
                                        (widget.isDark
                                                ? _labelStyle.copyWith(color: isSelected ? Colors.white : Colors.white70)
                                                : _labelStyle.copyWith(
                                                    color: isSelected ? const Color(0xFF0F3B2E) : Colors.black87,
                                                  ))
                                            .copyWith(
                                              color:
                                                  (widget.isDark
                                                          ? (isSelected ? Colors.white : Colors.white70)
                                                          : (isSelected ? const Color(0xFF0F3B2E) : Colors.black87))
                                                      .withValues(alpha: opacity),
                                            ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.clip,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _icon(String cat) {
    switch (cat) {
      case 'الكل':
        return Icons.grid_view_rounded;
      case 'عام':
        return Icons.category_rounded;
      case 'أخرى':
        return Icons.bubble_chart_rounded;
      case 'هدايا':
        return Icons.card_giftcard_rounded;
      case 'الكترونيات':
        return Icons.computer_rounded;
      case 'منزلية':
        return Icons.home_rounded;
      default:
        return Icons.widgets_rounded;
    }
  }
}

// ---------------------------------------------------------
// 🚀 ULTRA PERFORMANCE: CustomPainter بدل BackdropFilter + ClipPath
// لون صلب بشكل القوس مع ثقب شريط البحث
// ---------------------------------------------------------
class _HeaderBgPainter extends CustomPainter {
  final bool isDark;
  final double curveDepth;
  final double bottomY;
  final double statusBarHeight;

  _HeaderBgPainter({
    required this.isDark,
    required this.curveDepth,
    required this.bottomY,
    required this.statusBarHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // ⚡ لون صلب 100% — بدون شفافية = بدون تضبيب = أخف أداء ممكن
    final paint = Paint()
      ..color = isDark ? const Color(0xFF1D1D1D) : const Color(0xFF1E1E1E)
      ..style = PaintingStyle.fill;

    // 1. مسار القوس
    final arcPath = Path();
    arcPath.lineTo(0, bottomY - curveDepth);
    arcPath.quadraticBezierTo(size.width / 2, size.height + (curveDepth * 0.8), size.width, bottomY - curveDepth);
    arcPath.lineTo(size.width, 0);
    arcPath.close();

    // 2. ثقب شريط البحث
    final searchBarTop = statusBarHeight + 72.0;
    final searchBarLeft = 36.0;
    final searchBarWidth = size.width - 72.0;
    const searchBarHeight = 56.0;

    final searchBarRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(searchBarLeft, searchBarTop, searchBarWidth, searchBarHeight),
      const Radius.circular(100),
    );
    final searchBarPath = Path()..addRRect(searchBarRect);

    // 3. رسم القوس مع ثقب البحث
    final combinedPath = Path.combine(PathOperation.difference, arcPath, searchBarPath);
    canvas.drawPath(combinedPath, paint);

    // 4. ⚡ شريط ذهبي أنيق على حافة القوس السفلية
    final goldPath = Path();
    goldPath.moveTo(0, bottomY - curveDepth);
    goldPath.quadraticBezierTo(size.width / 2, size.height + (curveDepth * 0.8), size.width, bottomY - curveDepth);

    final goldPaint = Paint()
      ..color = const Color(0xFFDAA520)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawPath(goldPath, goldPaint);
  }

  @override
  bool shouldRepaint(covariant _HeaderBgPainter old) =>
      old.isDark != isDark || old.curveDepth != curveDepth || old.bottomY != bottomY;
}

/// Helper method to build the exact greeting as GlobalAppBar
Widget _buildGreetingRow(BuildContext context) {
  // استخدام نفس المبدأ لجلب الترحيب
  final hour = DateTime.now().hour;
  String greeting = 'مساء الخير';
  String emoji = '🌙';
  if (hour >= 5 && hour < 12) {
    greeting = 'صباح الخير';
    emoji = '☀️';
  } else if (hour >= 12 && hour < 17) {
    greeting = 'مساء الخير';
    emoji = '🌤️';
  } else if (hour >= 17 && hour < 21) {
    greeting = 'مساء النور';
    emoji = '🌅';
  }

  return Selector<UserProvider, ({String firstName, String phone})>(
    selector: (_, p) => (firstName: p.firstName, phone: p.phoneNumber),
    builder: (context, data, _) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RichText(
          maxLines: 1,
          overflow: TextOverflow.clip,
          text: TextSpan(
            children: [
              TextSpan(
                text: '$greeting ${data.firstName} ',
                style: FontHelper.cairo(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: emoji, style: const TextStyle(fontSize: 12)),
            ],
          ),
        ),
        const SizedBox(height: 2),
        Text(
          data.phone,
          style: FontHelper.cairo(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.w400),
        ),
      ],
    ),
  );
}
