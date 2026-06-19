import 'dart:async';
import 'dart:developer';
import 'package:app_links/app_links.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:dkstore/router/app_routes.dart';
import 'config/global_keys.dart';

class AppLinksDeepLink {
  AppLinksDeepLink._privateConstructor();

  static final AppLinksDeepLink _instance =
  AppLinksDeepLink._privateConstructor();
  static AppLinksDeepLink get instance => _instance;

  late final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;
  bool _isInitialized = false;
  Uri? _lastProcessedUri;
  bool _hasPendingLink = false;

  bool get hasPendingLink => _hasPendingLink;

  void clearPendingLink() {
    _hasPendingLink = false;
  }

  Future<void> initDeepLinks(BuildContext context) async {
    if (_isInitialized) {
      log('Deep links already initialized, skipping');
      return;
    }
    _isInitialized = true;

    try {
      log('NAVIGATOR CONTEXT INITIALIZED');

      // Handle initial link if the app was opened via a link
      final initialUri = await _appLinks.getInitialLink();
      if (initialUri != null) {
        log('Initial deep link: $initialUri');
        _hasPendingLink = true;
        if (context.mounted) {
          await _handleDeepLink(initialUri, context);
        }
      }

      // Listen for subsequent links while the app is running
      _linkSubscription = _appLinks.uriLinkStream.listen(
            (Uri? uri) async {
          log('Received deep link: $uri');
          if (uri != null) {
            _hasPendingLink = true;
            if (context.mounted) {
              await _handleDeepLink(uri, context);
            }
          }
        },
        onError: (err) {
          log('Deep link error: $err');
        },
      );
    } catch (e, stack) {
      log('Deep link initialization error: $e');
      log('Stack trace: $stack');
    }
  }

  Future<void> _handleDeepLink(Uri uri, BuildContext context) async {
    if (_lastProcessedUri == uri) {
      log('URI $uri was just processed, skipping');
      return;
    }
    _lastProcessedUri = uri;
    _hasPendingLink = true;

    // Clear the last processed URI after a short delay to allow re-processing the same link later
    Future.delayed(const Duration(seconds: 2), () {
      if (_lastProcessedUri == uri) {
        _lastProcessedUri = null;
      }
    });

    final navigatorContext = GlobalKeys.navigatorKey.currentContext;
    if (navigatorContext == null) {
      log('Navigator context is null, skipping deep link handling');
      return;
    }

    debugPrint('Processing deep link URI: ${uri.toString()}');

    try {
      String? productSlug = _extractProductSlug(uri);

      if (productSlug != null && productSlug.isNotEmpty) {
        log('Redirecting to product detail page with slug: $productSlug');

        // Ensure we're on the main thread and context is still valid
        await WidgetsBinding.instance.endOfFrame;
        if (!navigatorContext.mounted) return;

        final router = GoRouter.of(navigatorContext);

        // Ensure Home is the base route
        router.go(AppRoutes.home);

        // Navigate to product detail page on top of Home
        router.push(
          AppRoutes.productDetailPage,
          extra: {'productSlug': productSlug},
        );
        _hasPendingLink = false; // Successfully handled
      } else {
        log('No product slug found in deep link: $uri');
        _hasPendingLink = false;
      }
    } catch (e, stack) {
      _hasPendingLink = false;
      debugPrint('Navigation error: $e');
      debugPrint('Stack trace: $stack');
    }
  }

  String? _extractProductSlug(Uri uri) {
    if (uri.pathSegments.contains('product') ||
        uri.pathSegments.contains('p')) {
      final index = uri.pathSegments.contains('product')
          ? uri.pathSegments.indexOf('product')
          : uri.pathSegments.indexOf('p');

      if (index != -1 && index + 1 < uri.pathSegments.length) {
        final slug = uri.pathSegments[index + 1];
        if (slug.isNotEmpty) return slug;
      }
    }

    // 2. Check query parameters (e.g., ?slug=my-slug or ?product_slug=my-slug)
    if (uri.queryParameters.containsKey('slug')) {
      return uri.queryParameters['slug'];
    }
    if (uri.queryParameters.containsKey('product_slug')) {
      return uri.queryParameters['product_slug'];
    }

    // 3. Check if the last segment looks like a slug (generic fallback)
    // Avoid returning common keywords as slugs
    const keywords = {'product', 'p', 'home', 'shop', 'categories', 'cart'};
    if (uri.pathSegments.isNotEmpty) {
      final lastSegment = uri.pathSegments.last;
      if (lastSegment.isNotEmpty &&
          !keywords.contains(lastSegment.toLowerCase())) {
        return lastSegment;
      }
    }

    return null;
  }

  void dispose() {
    _linkSubscription?.cancel();
  }
}
