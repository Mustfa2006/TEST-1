import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../models/product.dart';
import '../router.dart';
import '../services/api/products_api.dart';
import '../services/local/products_cache_service.dart';

/// ⚡ ProductsProvider - محسّن للأداء
/// ✅ قائمة واحدة فقط (_products) + computed getter للفلترة
/// ✅ لا نسخ متكرر = توفير ذاكرة
class ProductsProvider extends ChangeNotifier {
  final ProductsApi _api;

  // ⚡ قائمة واحدة فقط - لا تكرار
  List<Product> _products = [];

  bool _isLoading = false;
  bool _isLoadingMore = false;
  bool _hasError = false;
  String _errorMessage = '';
  int _currentPage = 1;
  bool _hasMore = true;
  String _searchQuery = '';
  String _selectedCategory = ''; // فئة مختارة للفلترة

  // ⚡ نتائج البحث من API - فقط عند البحث النشط
  List<Product>? _searchResults;

  static const int _itemsPerPage = 10;

  ProductsProvider({ProductsApi? api}) : _api = api ?? ProductsApi();

  // ⚡ PERFORMANCE: متغير يحتفظ بالقائمة الجاهزة للعرض (تحديث فقط عند الحاجة) لمنع GC Spikes
  List<Product> _currentDisplayList = [];

  List<Product> get products => _currentDisplayList;

  List<Product> get allProducts => _products;

  /// الفئات المتوفرة (مستخرجة من المنتجات المحمّلة)
  List<String> get categories {
    final cats = <String>{};
    for (final p in _products) {
      if (p.category.isNotEmpty) cats.add(p.category);
    }
    return cats.toList();
  }

  String get selectedCategory => _selectedCategory;
  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  bool get hasError => _hasError;
  String get errorMessage => _errorMessage;
  bool get hasMore => _hasMore;

  bool get isEmpty => _currentDisplayList.isEmpty && !_isLoading;

  String get searchQuery => _searchQuery;

  int _version = 0;
  int get version => _version;

  void setCategory(String? category) {
    if (_selectedCategory == (category ?? '')) return;
    _selectedCategory = category ?? '';
    // Clear search when clicking a category, per normal UX rules
    if (_selectedCategory.isNotEmpty) {
      _searchQuery = '';
      _searchResults = null;
    }
    notifyListeners();
  }

  void _updateDisplayList() {
    if (_searchResults != null) {
      _currentDisplayList = _searchResults!;
    } else if (_searchQuery.trim().isNotEmpty) {
      _currentDisplayList = _products.where((p) => p.name.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
    } else if (_selectedCategory.isNotEmpty) {
      _currentDisplayList = _products.where((p) => p.category == _selectedCategory).toList();
    } else {
      _currentDisplayList = List.unmodifiable(_products);
    }
  }

  @override
  void notifyListeners() {
    _version++;
    _updateDisplayList(); // ⚡ تحديث القائمة المعروضة قبل إشعار الواجهة
    super.notifyListeners();
  }

  Future<void> loadProducts({bool forceRefresh = false}) async {
    if (_isLoading) return;

    _hasError = false;
    _errorMessage = '';
    _searchResults = null; // ⚡ مسح نتائج البحث

    if (forceRefresh) {
      await ProductsCacheService.clearCache();
    }

    final cachedProducts = await ProductsCacheService.getCachedProducts();
    if (cachedProducts != null && cachedProducts.isNotEmpty && !forceRefresh) {
      _products = cachedProducts.where((p) => p.availableQuantity > 0).toList();
      _isLoading = false;
      _hasMore = true;
      // ⚡ الإصلاح الجذري: حساب الصفحة الحالية بناءً على عدد المنتجات في الكاش
      _currentPage = (_products.length / _itemsPerPage).ceil();
      if (_currentPage == 0) _currentPage = 1;

      notifyListeners();

      // ⚡ Precache أول 6 صور باستخدام thumbnailUrl (الأخف) بدلاً من الصورة الكاملة
      _precacheTopImages();

      // ⚡ FAST BACKGROUND INJECTION:
      _checkForNewProductsSilently();
      return;
    }

    _isLoading = true;
    _currentPage = 1;
    _products = [];
    _hasMore = true;
    notifyListeners();

    await _fetchFromServer();
  }

  Future<void> _fetchFromServer() async {
    try {
      final products = await _api.fetchProducts(page: _currentPage, limit: _itemsPerPage);

      await ProductsCacheService.cacheProducts(products);

      _products = products.where((p) => p.availableQuantity > 0).toList();
      _isLoading = false;
      _hasMore = products.length >= _itemsPerPage;
      
      // ⚡ Precache أول 6 صور
      _precacheTopImages();
      
    } catch (e) {
      _isLoading = false;
      _hasMore = false;
      _hasError = true;
      _errorMessage = 'لا يوجد اتصال بالإنترنت';
    }

    notifyListeners();
  }

  /// ⚡ تحميل مسبق لأول 6 صور مصغرة (thumbnailUrl أولاً، ثم images.first كاحتياط)
  void _precacheTopImages() {
    final ctx = AppRouter.navigatorKey.currentContext;
    if (ctx == null) return;
    for (final p in _products.take(6)) {
      final url = (p.thumbnailUrl?.isNotEmpty == true) ? p.thumbnailUrl! : (p.images.isNotEmpty ? p.images.first : null);
      if (url != null) {
        precacheImage(CachedNetworkImageProvider(url), ctx);
      }
    }
  }

  // ⚡ فحص فائق السرعة عن أي منتجات جديدة أضيفت للمتجر ودمجها في الأعلى بصمت
  Future<void> _checkForNewProductsSilently() async {
    try {
      final latestProducts = await _api.fetchProducts(page: 1, limit: _itemsPerPage);
      final availableLatest = latestProducts.where((p) => p.availableQuantity > 0).toList();

      if (availableLatest.isEmpty) return;

      // أوجد المنتجات التي جاءت للتو من السيرفر وليست موجودة حالياً في القائمة أو الكاش
      final newItems = availableLatest.where((newP) => !_products.any((oldP) => oldP.id == newP.id)).toList();

      // 🚀 تحديث المنتجات الموجودة التي ربما تغيرت (مثل تغيير الصورة الرئيسية أو السعر)
      bool hasUpdates = false;
      for (var serverProduct in availableLatest) {
        final existingIndex = _products.indexWhere((p) => p.id == serverProduct.id);
        if (existingIndex != -1) {
          // مقارنة سريعة لمعرفة إذا كان هناك تغيير (يمكن الاعتماد على updatedAt إذا كانت دقيقة، أو استبدالها للضمان)
          final localProduct = _products[existingIndex];
          if (localProduct.updatedAt.isBefore(serverProduct.updatedAt) ||
              localProduct.thumbnailUrl != serverProduct.thumbnailUrl) {
            _products[existingIndex] = serverProduct;
            hasUpdates = true;
          }
        }
      }

      if (newItems.isNotEmpty || hasUpdates) {
        // إضافة المنتجات الجديدة في قمة القائمة
        if (newItems.isNotEmpty) {
           _products.insertAll(0, newItems);
        }
        
        // تحديث الكاش بالمعلومات الجديدة فوراً
        await ProductsCacheService.cacheProducts(_products);

        // إشعار الواجهة برفق لتظهر المنتجات الجديدة بسلاسة
        notifyListeners();
      }
    } catch (_) {
      // تجاهل صامت في حالة عدم وجود إنترنت (يستمر عرض الكاش)
    }
  }

  Future<void> loadMore() async {
    // ⚡ PERFORMANCE: لا تنفذ التحميل الإضافي الأساسي إذا كان هناك بحث نشط
    if (_searchQuery.isNotEmpty || _searchResults != null) return;

    if (_isLoading || _isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;
    notifyListeners();

    try {
      _currentPage++;
      final products = await _api.fetchProducts(page: _currentPage, limit: _itemsPerPage);
      final availableProducts = products.where((p) => p.availableQuantity > 0).toList();

      // ⚡ تصفية المنتجات لمنع التكرار (Duplicate Prevention)
      final newUniqueProducts = availableProducts
          .where((newProduct) => !_products.any((existingProduct) => existingProduct.id == newProduct.id))
          .toList();

      if (newUniqueProducts.isEmpty) {
        // إذا كانت كل المنتجات مكررة، نوقف التحميل الإضافي
        _hasMore = false;
      } else {
        _products.addAll(newUniqueProducts);
        _hasMore = products.length >= _itemsPerPage;
      }
      _isLoadingMore = false;

      await ProductsCacheService.cacheProducts(_products);
    } catch (e) {
      _currentPage--;
      _isLoadingMore = false;
    }

    notifyListeners();
  }

  // ⚡ نظام الإصدارات لمنع تضارب البحث (Race Condition Prevention)
  int _searchVersion = 0;

  Future<void> search(String query) async {
    // ✅ زيادة الإصدار في كل بحث جديد
    final currentVersion = ++_searchVersion;

    _searchQuery = query;
    _searchResults = null; // ⚡ مسح النتائج القديمة

    // ✅ إذا كان النص فارغاً أو يحتوي على فراغات فقط = إظهار المنتجات الأصلية
    if (_searchQuery.trim().isEmpty) {
      _searchQuery = ''; // تنظيف
      notifyListeners();
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final searchResults = await _api.searchProducts(_searchQuery, limit: 50);

      // ✅ تجاهل النتائج إذا تم بحث جديد بعد هذا البحث
      if (currentVersion != _searchVersion) {
        return; // نتائج قديمة - تجاهلها
      }

      _searchResults = searchResults.where((p) {
        // ⚡ فلترة إضافية للتأكد من النتائج (Client-Side Check)
        final matchesQuery = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
        return p.availableQuantity > 0 && matchesQuery;
      }).toList();
    } catch (e) {
      // ✅ تجاهل الخطأ إذا كان البحث قديماً
      if (currentVersion != _searchVersion) {
        return;
      }
      _searchResults = null; // ⚡ Fallback: استخدم البحث المحلي عند فشل السيرفر
    } finally {
      // ✅ فقط إذا كان هذا آخر بحث
      if (currentVersion == _searchVersion) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> retry() async {
    await loadProducts(forceRefresh: true);
  }

  void clearSearch() {
    _searchVersion++;
    _searchQuery = '';
    _searchResults = null;
    _isLoading = false;
    notifyListeners();
  }

  /// فلترة بالفئة
  void filterByCategory(String category) {
    if (_selectedCategory == category) {
      _selectedCategory = ''; // إلغاء الفلتر عند الضغط مجدداً
    } else {
      _selectedCategory = category;
    }
    _searchResults = null;
    _searchQuery = '';
    notifyListeners();
  }
}
