import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../../../../core/theme/app_theme.dart';

class SupportBottomSheet extends StatefulWidget {
  const SupportBottomSheet({super.key});

  @override
  State<SupportBottomSheet> createState() => _SupportBottomSheetState();
}

class _SupportBottomSheetState extends State<SupportBottomSheet> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  List<ProductDetails> _products = [];
  bool _isAvailable = false;
  bool _isLoading = true;

  final Map<String, Map<String, dynamic>> _productMeta = {
    'support_small': {
      'icon': Icons.code,
      'title': 'Fund a late-night commit',
      'price': '₹49',
    },
    'support_medium': {
      'icon': Icons.bolt,
      'title': 'Keep the dev in flow state',
      'price': '₹149',
    },
    'support_large': {
      'icon': Icons.rocket_launch,
      'title': 'Support the studio',
      'price': '₹299',
    }
  };

  @override
  void initState() {
    super.initState();
    final purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {
      // handle error here.
    });
    _initStoreInfo();
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      if (mounted) {
        setState(() {
          _isAvailable = false;
          _isLoading = false;
        });
      }
      return;
    }

    const Set<String> _kIds = <String>{'support_small', 'support_medium', 'support_large'};
    final ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(_kIds);

    if (mounted) {
      setState(() {
        _isAvailable = true;
        _products = productDetailResponse.productDetails;
        _isLoading = false;
      });
    }
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // show pending UI
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          // handle error
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          _inAppPurchase.completePurchase(purchaseDetails).then((_) {
            if (mounted) {
              Navigator.pop(context);
              _showThankYouDialog();
            }
          });
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  void _showThankYouDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.black,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Colors.white24, width: 1),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.favorite, color: Colors.orangeAccent, size: 48),
              const SizedBox(height: 24),
              Text(
                'Thank you so much',
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Your support keeps Intent free for everyone. This means everything to me as a solo developer.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                '— Shri Ram A U',
                style: GoogleFonts.caveat(
                  color: Colors.orangeAccent,
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.surfaceElevated,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  minimumSize: const Size(double.infinity, 48),
                ),
                child: Text(
                  'Close',
                  style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  void _buyProduct(String id) {
    if (!_isAvailable) return;
    final ProductDetails? product = _products.firstWhere((p) => p.id == id, orElse: () => _products.firstOrNull!);
    if (product != null) {
      final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
      _inAppPurchase.buyConsumable(purchaseParam: purchaseParam, autoConsume: true);
    } else {
      // Mock flow if testing without actual Play Store sync
      Navigator.pop(context);
      _showThankYouDialog();
    }
  }

  Widget _buildSupportOption({
    required IconData icon,
    required String title,
    required String defaultPrice,
    required String productId,
  }) {
    // If we have actual pricing from store, use it, else default
    String price = defaultPrice;
    if (_products.isNotEmpty) {
      try {
        final p = _products.firstWhere((element) => element.id == productId);
        price = p.price;
        // ensure rupee symbol explicitly attached if the store only gives amount (or format explicitly)
        if (!price.contains('₹')) {
          price = '₹$price';
        }
      } catch (_) {}
    } else {
      if (!price.contains('₹')) {
        price = '₹$price';
      }
    }

    return InkWell(
      onTap: () => _buyProduct(productId),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: AppTheme.surfaceElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white10),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orangeAccent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.orangeAccent, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                price,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surfaceDark,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 24, right: 24, bottom: 24, top: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 48,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.favorite_outline, color: Colors.orangeAccent),
                  const SizedBox(width: 12),
                  Text(
                    'Support Intent Labs',
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Intent is free and always will be. If it\'s helped your focus, consider supporting its development.',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Colors.white70,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              _buildSupportOption(
                icon: _productMeta['support_small']!['icon'],
                title: _productMeta['support_small']!['title'],
                defaultPrice: _productMeta['support_small']!['price'],
                productId: 'support_small',
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: _productMeta['support_medium']!['icon'],
                title: _productMeta['support_medium']!['title'],
                defaultPrice: _productMeta['support_medium']!['price'],
                productId: 'support_medium',
              ),
              const SizedBox(height: 12),
              _buildSupportOption(
                icon: _productMeta['support_large']!['icon'],
                title: _productMeta['support_large']!['title'],
                defaultPrice: _productMeta['support_large']!['price'],
                productId: 'support_large',
              ),
              const SizedBox(height: 32),
              Center(
                child: Text(
                  'Built with ❤️ by Shri Ram',
                  style: GoogleFonts.inter(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
