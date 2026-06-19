import 'dart:async';
import 'dart:developer';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_tabler_icons/flutter_tabler_icons.dart';
import 'package:dkstore/l10n/app_localizations.dart';
import 'package:dkstore/utils/widgets/custom_button.dart';
import 'package:dkstore/utils/widgets/custom_shimmer.dart';
import 'package:latlong2/latlong.dart';
import 'package:dkstore/config/theme.dart';
import 'package:dkstore/screens/my_orders/bloc/delivery_tracking/delivery_tracking_bloc.dart';
import 'package:dkstore/screens/my_orders/model/delivery_tracking_model.dart';
import 'package:confetti/confetti.dart';
import '../widgets/order_summary_widget.dart';
import '../widgets/road_route.dart';
import '../utils/delivery_icon_painter.dart';
import '../utils/delivery_math_utils.dart';
import '../utils/delivery_route_utils.dart';

import '../widgets/delivery_success_card.dart';
import '../widgets/delivery_partner_section.dart';
import '../widgets/delivery_partner_not_assigned.dart';
import '../widgets/delivery_details_section.dart';
import '../widgets/order_details_section.dart';

class DeliveryTrackingPage extends StatefulWidget {
  final String orderSlug;
  const DeliveryTrackingPage({super.key, required this.orderSlug});

  @override
  State<DeliveryTrackingPage> createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage>
    with TickerProviderStateMixin {
  // ── Map ───────────────────────────────────────────────────────────────────
  late final MapController mapController;
  Timer? _refreshTimer;
  late final MapOptions _mapOptions;

  final LatLng _initialPosition = const LatLng(28.6139, 77.2090);

  LatLng? _pickupLocation;      // first uncollected store (or customer if all collected)
  LatLng? _currentLocation;     // customer / final destination
  LatLng? _deliveryPartnerLocation;

  // ── Icon bytes ────────────────────────────────────────────────────────────
  Uint8List? _meIconBytes;
  Uint8List? _storeIconBytes;
  Uint8List? _deliveryBoyIconBytes;

  // ── Map layer state ───────────────────────────────────────────────────────
  final Set<Marker> _markers = {};

  // Two-polyline system (Google Maps style):
  //   _travelledPolyline  — grey,   the path the rider has already passed
  //   _remainingPolyline  — colored, the route still ahead to destination
  Polyline? _travelledPolyline;
  Polyline? _remainingPolyline;

  // Accumulated GPS breadcrumbs of where the rider has physically been.
  final List<LatLng> _travelledPath = [];

  DeliveryBoyTrackingModel? _currentTracking;

  // ── Animation & rotation ──────────────────────────────────────────────────
  late AnimationController _deliveryAnimationController;
  List<LatLng> _deliveryPath = [];
  double _currentBearing = 0.0;

  // ── Route tracking ────────────────────────────────────────────────────────
  List<LatLng> _staticRoutePoints = [];
  int _lastRouteIndex = 0;

  // ── Camera follow ─────────────────────────────────────────────────────────
  final bool _cameraFollowEnabled = true;
  double _followZoom = 15.5;

  // ── Misc flags ────────────────────────────────────────────────────────────
  bool _isInitialLoad = true;
  bool _hasDrawnStaticRoute = false;

  // ── Rerouting state ───────────────────────────────────────────────────────
  static const double _offRouteThresholdMeters = 50.0;
  static const int _offRouteConsecutiveLimit = 2;
  int _offRouteCount = 0;
  bool _isRerouting = false;

  /// Flag for when the order is delivered
  bool _isDelivered = false;
  late ConfettiController _confettiController;

  /// Points for the curved dashed line when delivery boy is not assigned.
  List<LatLng> _curvedPathPoints = [];

  bool _pickupReached = false;

  /// Tracks which stop IDs were already collected on the last refresh.
  /// Used to detect newly-collected stops and silently rebuild the route.
  Set<dynamic> _previouslyCollectedStopIds = {};

  static const double _minMovementMeters = 2.0;

  // ==========================================================================
  //  Lifecycle
  // ==========================================================================

  @override
  void initState() {
    super.initState();
    mapController = MapController();

    _deliveryAnimationController = AnimationController(
      duration: const Duration(seconds: 15),
      vsync: this,
    )
      ..addListener(_onDeliveryAnimationTick)
      ..addStatusListener(_onDeliveryAnimationStatusChanged);

    _loadDeliveryBoyIcon();
    _buildAndCacheCustomerIcon();
    _buildAndCacheStoreIcon();

    _mapOptions = MapOptions(
      initialCenter: _initialPosition,
      initialZoom: 15.0,
      minZoom: 3,
      maxZoom: 18,
      keepAlive: true,
      interactionOptions: const InteractionOptions(),
      onMapEvent: (event) {
        if (event is MapEventMove && event.camera.zoom.isFinite) {
          _followZoom = event.camera.zoom;
        }
      },
    );

    context.read<DeliveryTrackingBloc>().add(
      FetchDeliveryTracking(orderSlug: widget.orderSlug),
    );

    _confettiController =
        ConfettiController(duration: const Duration(seconds: 10));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startPeriodicRefresh();
  }

  void _startPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted) {
        context.read<DeliveryTrackingBloc>().add(
          FetchDeliveryTracking(orderSlug: widget.orderSlug),
        );
      }
    });
  }

  // ==========================================================================
  //  Camera follow
  // ==========================================================================

  void _followRider(LatLng position) {
    if (!_cameraFollowEnabled || !mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted ||
          !position.latitude.isFinite ||
          !position.longitude.isFinite ||
          !_followZoom.isFinite) {
        return;
      }
      mapController.move(position, _followZoom);
    });
  }

  // ==========================================================================
  //  Icon loading
  // ==========================================================================

  Future<void> _loadDeliveryBoyIcon() async {
    try {
      final data =
      await rootBundle.load('assets/images/delivery-boy-top-view.png');
      final resized = await _resizeImage(data.buffer.asUint8List(), 100, 100);
      if (mounted) setState(() => _deliveryBoyIconBytes = resized);
    } catch (e) {
      debugPrint('Delivery icon load failed: $e');
    }
  }

  Future<void> _buildAndCacheCustomerIcon() async {
    final bytes = await buildCustomerIconBytes(size: 80);
    if (mounted) setState(() => _meIconBytes = bytes);
  }

  Future<void> _buildAndCacheStoreIcon() async {
    final bytes = await buildStoreIconBytes(size: 80);
    if (mounted) setState(() => _storeIconBytes = bytes);
  }

  Future<Uint8List> _resizeImage(Uint8List data, int w, int h) async {
    final codec =
    await ui.instantiateImageCodec(data, targetWidth: w, targetHeight: h);
    final frame = await codec.getNextFrame();
    final byteData =
    await frame.image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  // ==========================================================================
  //  Route helpers — isCollected aware
  // ==========================================================================


  /// Returns the customer stop from allStops (last stop named "customer").
  RouteDetail? _getCustomerStop(List<RouteDetail> allStops) {
    final reversed = allStops.reversed.toList();
    try {
      return reversed.firstWhere(
            (s) =>
        (s.storeName ?? '').toLowerCase().contains('customer') ||
            (s.storeName ?? '').toLowerCase().contains('custom'),
      );
    } catch (_) {
      return allStops.isNotEmpty ? allStops.last : null;
    }
  }

  /// Returns intermediate store stops (not the customer stop) that are
  /// still uncollected — these are the stops that still need a pickup.
  List<RouteDetail> _getPendingStoreStops(List<RouteDetail> allStops) {
    return allStops.where((s) {
      final name = (s.storeName ?? '').toLowerCase();
      final isCustomer =
          name.contains('customer') || name.contains('custom');
      return !isCustomer && !(s.isCollected ?? false);
    }).toList();
  }

  /// Builds the ordered waypoint list for the OSRM route call:
  ///   [deliveryBoyGPS, store1, store2, …, storeN, customerLocation]
  ///
  /// If all stores are collected → [deliveryBoyGPS, customerLocation]
  List<LatLng> _buildOrderedWaypoints(LatLng riderGPS) {
    final allStops = _currentTracking?.data?.route?.routeDetails ?? [];
    final pendingStores = _getPendingStoreStops(allStops);
    final customerStop = _getCustomerStop(allStops);

    final waypoints = <LatLng>[riderGPS];

    // Add each pending store in order
    for (final store in pendingStores) {
      final lat = store.latitude;
      final lng = store.longitude;
      if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
        waypoints.add(LatLng(lat, lng));
      }
    }

    // Always end at the customer location
    if (customerStop != null &&
        customerStop.latitude != null &&
        customerStop.longitude != null &&
        customerStop.latitude!.isFinite &&
        customerStop.longitude!.isFinite) {
      final customerLatLng =
      LatLng(customerStop.latitude!, customerStop.longitude!);
      // Avoid duplicate if customer is already last
      if (waypoints.isEmpty || waypoints.last != customerLatLng) {
        waypoints.add(customerLatLng);
      }
    }

    log('Waypoints built: ${waypoints.length} points '
        '(${pendingStores.length} pending stores)');
    return waypoints;
  }

  // ==========================================================================
  //  Marker management  — only show uncollected stops on map
  // ==========================================================================

  /// Builds markers for:
  ///   • Delivery boy (animated, rotating)
  ///   • Customer / destination
  ///   • Each UNCOLLECTED store stop  (isCollected == false)
  ///
  /// Collected stops are intentionally excluded from the map.
  void _updateMarkers() {
    _markers.clear();

    // ── Customer marker ────────────────────────────────────────────────────
    if (_currentLocation != null && _meIconBytes != null) {
      _markers.add(Marker(
        point: _currentLocation!,
        width: 40,
        height: 40,
        child: Image.memory(_meIconBytes!),
      ));
    }

    // ── Delivery boy marker (rotating) ────────────────────────────────────
    if (_deliveryPartnerLocation != null && _deliveryBoyIconBytes != null) {
      _markers.add(Marker(
        point: _deliveryPartnerLocation!,
        width: 50,
        height: 50,
        child: Transform.rotate(
          angle: _currentBearing * math.pi / 180,
          alignment: Alignment.center,
          child: Image.memory(_deliveryBoyIconBytes!),
        ),
      ));
    }

    // ── Store markers — ONLY uncollected stops ────────────────────────────
    if (_storeIconBytes != null && _currentTracking != null) {
      final allStops = _currentTracking!.data?.route?.routeDetails ?? [];
      final pendingStores = _getPendingStoreStops(allStops);

      for (final store in pendingStores) {
        final lat = store.latitude;
        final lng = store.longitude;
        if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
          _markers.add(Marker(
            point: LatLng(lat, lng),
            width: 40,
            height: 40,
            child: Image.memory(_storeIconBytes!),
          ));
        }
      }
    } else if (_pickupLocation != null && _storeIconBytes != null) {
      // Fallback: show the cached first store marker
      _markers.add(Marker(
        point: _pickupLocation!,
        width: 40,
        height: 40,
        child: Image.memory(_storeIconBytes!),
      ));
    }

    // Rebuild both polyline layers then trigger a single repaint.
    _rebuildPolylines();
    if (mounted) setState(() {});
  }

  // ==========================================================================
  //  Polyline management
  // ==========================================================================

  void _rebuildPolylines() {
    if (!mounted) return;

    if (_travelledPath.length >= 2) {
      _travelledPolyline = Polyline(
        points: _travelledPath,
        color: Colors.grey.shade400,
        strokeWidth: 5.5,
      );
    }

    if (_staticRoutePoints.isNotEmpty) {
      final remainingPoints = _staticRoutePoints.sublist(_lastRouteIndex);
      final pts = <LatLng>[];
      if (_deliveryPartnerLocation != null) pts.add(_deliveryPartnerLocation!);
      pts.addAll(remainingPoints);

      if (pts.length >= 2) {
        _remainingPolyline = Polyline(
          points: pts,
          color: AppTheme.primaryColor,
          strokeWidth: 5.5,
        );
      }
    }
  }

  // ==========================================================================
  //  Curve dashed line (no delivery boy assigned)
  // ==========================================================================

  List<Polyline> _buildCurvedDashedPolylines() {
    if (_curvedPathPoints.isEmpty) return [];

    final List<Polyline> dashes = [];
    const int dashLength = 2;
    const int gapLength = 2;

    for (int i = 0;
    i < _curvedPathPoints.length - 1;
    i += (dashLength + gapLength)) {
      final int end = math.min(i + dashLength, _curvedPathPoints.length - 1);
      if (end > i) {
        dashes.add(Polyline(
          points: _curvedPathPoints.sublist(i, end + 1),
          color: AppTheme.primaryColor,
          strokeWidth: 3,
        ));
      }
    }
    return dashes;
  }

  // ==========================================================================
  //  Delivery animation
  // ==========================================================================

  void _onDeliveryAnimationTick() {
    if (_deliveryPath.length < 2) return;
    final t = _deliveryAnimationController.value;
    if (t >= 1.0) return;

    final pos = _interpolatePosition(t, _deliveryPath);
    final total = _deliveryPath.length - 1;
    final idx = (t * total).floor().clamp(0, total - 1);

    _currentBearing =
        calculateBearing(_deliveryPath[idx], _deliveryPath[idx + 1]);
    _deliveryPartnerLocation = pos;

    _followRider(pos);

    if (_staticRoutePoints.isNotEmpty) {
      _lastRouteIndex = findClosestIndexForward(
        route: _staticRoutePoints,
        target: pos,
        fromIdx: _lastRouteIndex,
        searchWindow: 30,
      );
    }

    if (_travelledPath.isEmpty ||
        calculateDistance(_travelledPath.last, pos) > 5.0) {
      _travelledPath.add(pos);
    }

    _updateMarkers();
  }

  void _onDeliveryAnimationStatusChanged(AnimationStatus status) {
    if (status == AnimationStatus.completed) _deliveryPath.clear();
  }

  LatLng _interpolatePosition(double t, List<LatLng> path) {
    final total = path.length - 1;
    final idx = (t * total).floor().clamp(0, total - 1);
    final segT = (t * total - idx).clamp(0.0, 1.0);
    final p1 = path[idx];
    final p2 = path[idx + 1];
    return LatLng(
      p1.latitude + segT * (p2.latitude - p1.latitude),
      p1.longitude + segT * (p2.longitude - p1.longitude),
    );
  }

  // ==========================================================================
  //  Pickup-reached detection
  // ==========================================================================

  void _checkPickupReached(LatLng riderPos) {
    if (_pickupReached || _pickupLocation == null) return;
    final dist = calculateDistance(riderPos, _pickupLocation!);
    if (dist <= 30.0) {
      _pickupReached = true;
      log('Pickup reached — will be excluded from future reroutes');
    }
  }

  // ==========================================================================
  //  Core reroute
  // ==========================================================================

  Future<void> _executeReroute(LatLng riderGPS) async {
    if (_isRerouting || !mounted) return;

    setState(() => _isRerouting = true);
    log('Rerouting from $riderGPS …');

    try {
      // Use the new isCollected-aware waypoint builder
      final waypoints = _buildOrderedWaypoints(riderGPS);

      if (waypoints.length < 2) {
        if (mounted) setState(() => _isRerouting = false);
        return;
      }

      final rawRoutePoints = await getRoadRoute(waypoints);
      if (!mounted) return;

      final newRoutePoints = rawRoutePoints
          .where((p) => p.latitude.isFinite && p.longitude.isFinite)
          .toList();

      if (newRoutePoints.length < 2) {
        if (mounted) setState(() => _isRerouting = false);
        return;
      }

      _deliveryAnimationController.stop();
      _deliveryPath.clear();

      _staticRoutePoints = newRoutePoints;
      _offRouteCount = 0;
      _lastRouteIndex = 0;

      final animFrom = _deliveryPartnerLocation ?? riderGPS;
      if (_travelledPath.isEmpty ||
          calculateDistance(_travelledPath.last, animFrom) > 1.0) {
        _travelledPath.add(animFrom);
      }

      setState(() {
        _remainingPolyline = null;
        _isRerouting = false;
        _hasDrawnStaticRoute = true;
      });

      const double bridgeThreshold = 50.0;
      final distToNewRoute = calculateDistance(animFrom, newRoutePoints[0]);
      final routeAnimEnd = math.min(20, newRoutePoints.length);

      List<LatLng> animPath;

      if (distToNewRoute > bridgeThreshold) {
        List<LatLng> bridgePoints = [];
        try {
          final rawBridge = await getRoadRoute([animFrom, newRoutePoints[0]]);
          bridgePoints = rawBridge
              .where((p) => p.latitude.isFinite && p.longitude.isFinite)
              .toList();
        } catch (_) {
          bridgePoints = [animFrom, newRoutePoints[0]];
        }

        if (bridgePoints.isNotEmpty) bridgePoints.removeLast();
        animPath = [
          ...bridgePoints,
          ...newRoutePoints.sublist(0, routeAnimEnd),
        ];
      } else {
        _deliveryPartnerLocation = newRoutePoints[0];
        if (_travelledPath.isEmpty ||
            calculateDistance(_travelledPath.last, newRoutePoints[0]) > 1.0) {
          _travelledPath.add(newRoutePoints[0]);
        }
        animPath = newRoutePoints.sublist(0, routeAnimEnd);
      }

      if (animPath.length < 2) {
        _deliveryPartnerLocation = newRoutePoints[0];
        _updateMarkers();
        return;
      }

      final animDist = calculateDistance(animPath.first, animPath.last);
      final animSecs = (animDist / 8).clamp(1.0, 8.0).toInt();

      _deliveryPath = animPath;
      _deliveryAnimationController
        ..duration = Duration(seconds: animSecs)
        ..reset()
        ..forward();

      _updateMarkers();
    } catch (e) {
      log('Reroute failed: $e');
      if (mounted) setState(() => _isRerouting = false);
    }
  }

  // ==========================================================================
  //  Off-route check + reroute trigger
  // ==========================================================================

  Future<void> _checkAndReroute(LatLng riderGPS) async {
    if (_isRerouting) return;

    final distFromRoute = distanceFromRoute(
      point: riderGPS,
      route: _staticRoutePoints,
      nearIdx: _lastRouteIndex,
      searchWindow: 60,
    );

    log('Distance from route: ${distFromRoute.toStringAsFixed(1)} m '
        '(threshold: $_offRouteThresholdMeters m)');

    if (distFromRoute > _offRouteThresholdMeters) {
      _offRouteCount++;
      log('Off-route count: $_offRouteCount / $_offRouteConsecutiveLimit');
      if (_offRouteCount >= _offRouteConsecutiveLimit) {
        await _executeReroute(riderGPS);
      }
    } else {
      _offRouteCount = 0;
    }
  }

  // ==========================================================================
  //  Main tracking logic  ← KEY CHANGES HERE
  // ==========================================================================

  Future<void> _onTrackingLoaded(DeliveryTrackingLoaded state) async {
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() => _currentTracking = state.tracking);
      }
    });

    // ── Validate delivery boy GPS ─────────────────────────────────────────
    final deliveryBoys = state.tracking.data?.deliveryBoys ?? [];
    LatLng? newPos;

    if (deliveryBoys.isNotEmpty) {
      final boyData = deliveryBoys.first.data;
      final latStr = boyData?.latitude;
      final lngStr = boyData?.longitude;
      final lat = double.tryParse(latStr?.toString() ?? '');
      final lng = double.tryParse(lngStr?.toString() ?? '');

      if (lat != null && lng != null && lat.isFinite && lng.isFinite) {
        newPos = LatLng(lat, lng);
        log('New GPS of delivery boy: $newPos');
      } else {
        log('Invalid or non-finite GPS coordinates: $lat, $lng');
      }
    }

    final allStops = _currentTracking?.data?.route?.routeDetails ?? [];

    // ── Detect newly-collected stops ──────────────────────────────────────
    final nowCollectedIds = <dynamic>{};
    for (int i = 0; i < allStops.length; i++) {
      final s = allStops[i];
      if (s.isCollected == true) {
        nowCollectedIds.add(s.storeId ?? i);
      }
    }
    final newlyCollected =
    nowCollectedIds.difference(_previouslyCollectedStopIds);
    final collectionsChanged = newlyCollected.isNotEmpty;
    _previouslyCollectedStopIds = nowCollectedIds;

    if (collectionsChanged) {
      log('Stop(s) newly collected: $newlyCollected — will rebuild route');
    }

    // ── Extract customer & store locations once ───────────────────────────
    // These are cached for use in markers and the curved dashed line.
    if (_currentLocation == null) {
      final customerStop = _getCustomerStop(allStops);
      if (customerStop != null &&
          customerStop.latitude != null &&
          customerStop.longitude != null &&
          customerStop.latitude!.isFinite &&
          customerStop.longitude!.isFinite) {
        _currentLocation =
            LatLng(customerStop.latitude!, customerStop.longitude!);
      }
    }

    // Cache first pending store as _pickupLocation for fallback use
    if (_pickupLocation == null) {
      final pendingStores = _getPendingStoreStops(allStops);
      if (pendingStores.isNotEmpty) {
        final first = pendingStores.first;
        if (first.latitude != null &&
            first.longitude != null &&
            first.latitude!.isFinite &&
            first.longitude!.isFinite) {
          _pickupLocation = LatLng(first.latitude!, first.longitude!);
        }
      }
    }

    // ── No delivery boy assigned yet ──────────────────────────────────────
    if (newPos == null) {
      if (_pickupLocation != null && _currentLocation != null) {
        _curvedPathPoints =
            generateCurvedPath(_pickupLocation!, _currentLocation!);
        final bounds = LatLngBounds(_pickupLocation!, _currentLocation!);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            mapController.fitCamera(
              CameraFit.bounds(
                bounds: bounds,
                padding: const EdgeInsets.all(50),
              ),
            );
          }
        });
      } else {
        _curvedPathPoints = [];
      }
      _updateMarkers();
      return;
    }

    // Delivery boy is assigned — clear the curved placeholder line
    _curvedPathPoints = [];

    // ── Track whether rider has passed the first pickup stop ──────────────
    _checkPickupReached(newPos);

    // ── 1. Initial full route — drawn only once OR when a stop is newly
    //       collected (which changes the waypoint sequence).
    // ─────────────────────────────────────────────────────────────────────
    final bool needsInitialRoute = !_hasDrawnStaticRoute;
    final bool needsRouteRebuildDueToCollection =
        collectionsChanged && _hasDrawnStaticRoute;

    if (needsInitialRoute || needsRouteRebuildDueToCollection) {
      if (needsRouteRebuildDueToCollection) {
        log('Rebuilding route silently because a stop was collected');
      }

      // Build ordered waypoints:
      //   deliveryBoy → store1 → store2 → … → storeN → customer
      // If all stores collected:
      //   deliveryBoy → customer
      final waypoints = _buildOrderedWaypoints(newPos);

      if (waypoints.length >= 2) {
        try {
          final routePoints = await getRoadRoute(waypoints);
          if (!mounted) return;

          final validPoints = routePoints
              .where((p) => p.latitude.isFinite && p.longitude.isFinite)
              .toList();

          if (validPoints.length >= 2) {
            if (needsRouteRebuildDueToCollection) {
              // Silent rebuild — do NOT move the rider marker, just
              // swap the static route and redraw the polylines.
              _staticRoutePoints = validPoints;
              _lastRouteIndex = 0;
              _offRouteCount = 0;
              _rebuildPolylines();
              if (mounted) setState(() {});
              log('Silent route rebuild complete');
            } else {
              // Initial placement
              _staticRoutePoints = validPoints;

              final initialIdx = _findClosestIndexBidirectional(
                route: _staticRoutePoints,
                target: newPos,
                centerIdx: 0,
                searchWindow: _staticRoutePoints.length,
              );
              _lastRouteIndex = initialIdx;
              _deliveryPartnerLocation = _staticRoutePoints[initialIdx];

              _travelledPath
                ..clear()
                ..add(_deliveryPartnerLocation!);

              setState(() {
                _travelledPolyline = null;
                _remainingPolyline = Polyline(
                  points: validPoints
                      .map((e) => LatLng(e.latitude, e.longitude))
                      .toList(),
                  color: AppTheme.primaryColor,
                  strokeWidth: 5.5,
                );
              });
            }
          }
        } catch (e) {
          log('Route fetch failed: $e');
        }
      }
      _hasDrawnStaticRoute = true;
    }

    // ── 2. Position update on subsequent GPS refreshes ────────────────────
    if (_staticRoutePoints.isEmpty) {
      final currentPos = _deliveryPartnerLocation ?? newPos;
      final dist = calculateDistance(currentPos, newPos);
      if (dist > _minMovementMeters) {
        _deliveryPath = [currentPos, newPos];
        final secs = (dist / 8).clamp(4.0, 12.0).toInt();
        _deliveryAnimationController
          ..duration = Duration(seconds: secs)
          ..reset()
          ..forward();
      } else {
        _deliveryPartnerLocation = newPos;
      }
    } else {
      final newIdx = findClosestIndexForward(
        route: _staticRoutePoints,
        target: newPos,
        fromIdx: _lastRouteIndex,
        searchWindow: 120,
      );
      final projectedNewPos = _staticRoutePoints[newIdx];

      if (_deliveryPartnerLocation == null) {
        _deliveryPartnerLocation = projectedNewPos;
        _lastRouteIndex = newIdx;
      } else {
        final dist =
        calculateDistance(_deliveryPartnerLocation!, projectedNewPos);

        if (dist < _minMovementMeters) {
          _deliveryPartnerLocation = projectedNewPos;
          _lastRouteIndex = newIdx;
        } else {
          final segmentPoints =
          _staticRoutePoints.sublist(_lastRouteIndex, newIdx + 1);

          if (segmentPoints.length >= 2) {
            _deliveryPath = segmentPoints;
            final secs = (dist / 8).clamp(4.0, 12.0).toInt();
            _deliveryAnimationController
              ..duration = Duration(seconds: secs)
              ..reset()
              ..forward();
          } else {
            _deliveryPartnerLocation = projectedNewPos;
            _lastRouteIndex = newIdx;
          }
        }
      }

      // Off-route / wrong-road check (only when no collection rebuild just happened)
      if (!needsRouteRebuildDueToCollection) {
        if (_staticRoutePoints.isEmpty) {
          await _executeReroute(newPos);
        } else {
          await _checkAndReroute(newPos);
        }
      }
    }

    // ── Initial camera placement ──────────────────────────────────────────
    if (_isInitialLoad && mounted) {
      _followZoom = 15.5;
      _isInitialLoad = false;
      _followRider(_deliveryPartnerLocation ?? newPos);

      if (_pickupLocation != null) {
        _currentBearing = calculateBearing(
            _pickupLocation!, _deliveryPartnerLocation ?? newPos);
      } else if (_currentLocation != null) {
        _currentBearing = calculateBearing(
            _currentLocation!, _deliveryPartnerLocation ?? newPos);
      }
    }

    _followRider(_deliveryPartnerLocation ?? newPos);
    _updateMarkers();
  }


  int _findClosestIndexBidirectional({
    required List<LatLng> route,
    required LatLng target,
    required int centerIdx,
    int searchWindow = 120,
  }) {
    final start = (centerIdx - searchWindow).clamp(0, route.length - 1);
    final end = (centerIdx + searchWindow).clamp(0, route.length - 1);
    double minDist = double.infinity;
    int closestIdx = centerIdx;

    for (int i = start; i <= end; i++) {
      final d = calculateDistance(route[i], target);
      if (d < minDist) {
        minDist = d;
        closestIdx = i;
      }
    }
    return closestIdx;
  }

  // ==========================================================================
  //  Build
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    log('BUIld for checking slug ${widget.orderSlug}');
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      appBar: AppBar(
          backgroundColor: AppTheme.primaryColor,
          title: Text(
            _isDelivered || _currentTracking?.data?.order?.status == 'delivered'
                ? 'Order Delivered'
                : _getStatusText(_currentTracking?.data?.order?.status),
            style: const TextStyle(fontSize: 15, color: Colors.white),
          ),
          leading: IconButton(
              onPressed: () {
                Navigator.pop(context);
              },
              icon: Icon(
                TablerIcons.arrow_narrow_left,
                size: 30,
                color: Colors.white,
              )),
          centerTitle: true,
          bottom: PreferredSize(
            preferredSize: Size(double.infinity, 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _isDelivered ||
                      _currentTracking?.data?.order?.status == 'delivered'
                      ? 'Successfully Delivered'
                      : _currentTracking == null ? AppLocalizations.of(context)!.somethingWentWrong : 'Arriving in ${_getETAText()}',
                  style: const TextStyle(
                      fontSize: 22,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2),
                ),
                SizedBox(
                  height: 10,
                )
              ],
            ),
          )),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.only(
                top: 12,
                left: 12,
                right: 12,
              ),
              child: Material(
                clipBehavior: Clip.antiAlias,
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 250,
                  child: Stack(
                    children: [
                      (_isDelivered ||
                          _currentTracking?.data?.order?.status ==
                              'delivered')
                          ? _buildSuccessAnimation()
                          : _buildMap(),

                      if (!(_isDelivered ||
                          _currentTracking?.data?.order?.status == 'delivered'))
                        PositionedDirectional(
                          top: 12,
                          end: 10,
                          child: Column(
                            children: [
                              /*_buildFollowButton(),
                              const SizedBox(height: 8),*/
                              _buildRefreshButton(),
                              // if (_isRerouting) ...[
                              //   const SizedBox(height: 8),
                              //   _buildReroutingIndicator(),
                              // ],
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            BlocConsumer<DeliveryTrackingBloc, DeliveryTrackingState>(
              listener: (context, state) {
                log('DeliveryTrackingBloc state: $state');
                if (state is DeliveryTrackingLoaded) {
                  if (state.tracking.data?.order?.status == 'delivered') {
                    if (!_isDelivered) {
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          setState(() {
                            _isDelivered = true;
                          });
                          _confettiController.play();
                          _refreshTimer?.cancel();
                        }
                      });
                    }
                  }
                  _onTrackingLoaded(state);
                }
              },
              builder: (context, state) {
                log('Bloc State $state');
                log('Bloc State $_currentTracking');
                final isFirstLoad = _currentTracking == null &&
                    state is DeliveryTrackingLoading;
                if (isFirstLoad) return _buildLoadingScreen();
                if (state is DeliveryTrackingFailed &&
                    _currentTracking == null) {
                  return _buildErrorScreen(context, state.error);
                }
                return _buildMainUI(context, state);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() => SingleChildScrollView(
    child: Column(
      children: [
        Padding(
          padding: EdgeInsets.only(top: 12, left: 12, right: 12),
          child: ShimmerWidget.rectangular(isBorder: true, height: 100),
        ),
        Padding(
          padding: EdgeInsets.only(top: 12, left: 12, right: 12),
          child: ShimmerWidget.rectangular(isBorder: true, height: 180),
        ),
        Padding(
          padding: EdgeInsets.only(top: 12, left: 12, right: 12),
          child: ShimmerWidget.rectangular(isBorder: true, height: 120),
        ),
        Padding(
          padding: EdgeInsets.only(top: 12, left: 12, right: 12),
          child: ShimmerWidget.rectangular(isBorder: true, height: 100),
        ),
        SizedBox(height: 20),
      ],
    ),
  );

  Widget _buildErrorScreen(BuildContext context, String errorMsg) => Stack(
    children: [
      // if (_currentLocation != null || _pickupLocation != null) _buildMap(),
      Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(TablerIcons.shopping_bag, size: 80, color: AppTheme.primaryColor),
            const SizedBox(height: 16),
            Text(errorMsg,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 18),
            CustomButton(
              onPressed: () => context.read<DeliveryTrackingBloc>().add(
                FetchDeliveryTracking(orderSlug: widget.orderSlug),
              ),
              child: Text(AppLocalizations.of(context)!.retry),
            ),
          ],
        ),
      ),
    ],
  );

  Widget _buildMainUI(BuildContext context, DeliveryTrackingState state) {
    final tracking =
    (state is DeliveryTrackingLoaded) ? state.tracking : _currentTracking;

    if (tracking == null || tracking.data?.order == null) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: ShimmerWidget.rectangular(
                height: 60, borderRadius: 12, isBorder: true),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Column(
              children: List.generate(
                  4,
                      (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ShimmerWidget.rectangular(
                      height: [80, 140, 100, 120][index % 4].toDouble(),
                      isBorder: true,
                      borderRadius: 16,
                    ),
                  )),
            ),
          ),
          const SizedBox(height: 40),
        ],
      );
    }

    final order = tracking.data!.order;
    final routeDetails = tracking.data?.route?.routeDetails ?? [];
    final deliveryBoys = tracking.data?.deliveryBoys ?? const [];

    final partnerName = order?.deliveryBoyName ??
        (deliveryBoys.isNotEmpty
            ? deliveryBoys.first.data?.deliveryBoy?.fullName
            : null) ??
        'Delivery Partner';
    final partnerPhone = order?.deliveryBoyPhone?.toString();
    final deliveryPartnerProfile = order?.deliveryBoyProfile ?? '';

    final destTitle = order?.shippingAddressType ?? 'Destination';
    final destSubtitle = [
      order?.shippingAddress1,
      order?.shippingLandmark,
      order?.shippingCity,
    ].whereType<String>().where((s) => s.trim().isNotEmpty).join(', ');

    final orderIdText = order?.id?.toString() ?? '';
    final paymentText = (order?.paymentStatus?.toLowerCase() == 'paid')
        ? 'Paid ${order?.paymentMethod ?? ''}'.trim()
        : (order?.paymentMethod ?? '');
    final placedAtText = order?.createdAt ?? '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        if (_isDelivered)
          const DeliverySuccessCard()
        else if (deliveryBoys.isEmpty)
          const DeliveryPartnerNotAssigned()
        else
          DeliveryPartnerSection(
            name: partnerName,
            phone: partnerPhone,
            deliveryBoyProfile: deliveryPartnerProfile,
          ),
        DeliveryDetailsSection(
          stops: routeDetails,
          destTitle: destTitle,
          destSubtitle: destSubtitle,
          isDelivered: _isDelivered,
        ),
        OrderSummaryWidget(
          orderData: order ?? TrackedOrder(),
        ),
        OrderDetailsSection(
          orderId: orderIdText,
          payment: paymentText,
          orderPlaced: paymentText,
          placedAt: placedAtText,
        ),
        const SizedBox(height: 80),
      ],
    );
  }

  // ==========================================================================
  //  Helpers
  // ==========================================================================

  String _getStatusText(String? status) {
    if (status == null || status.isEmpty) return 'Tracking Order';
    final result = status.replaceAll('_', ' ').replaceAll('-', ' ');
    if (result.isEmpty) return 'Tracking Order';
    return result[0].toUpperCase() + result.substring(1).toLowerCase();
  }

  String _getETAText() {
    final eta = _currentTracking?.data?.order?.estimatedDeliveryTime;
    if (eta == null || eta == 0) return 'shortly';
    return '$eta minutes';
  }

  // ==========================================================================
  //  Success animation
  // ==========================================================================

  Widget _buildSuccessAnimation() {
    return Container(
      width: double.infinity,
      height: 250,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          ConfettiWidget(
            confettiController: _confettiController,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            colors: const [
              Colors.green,
              Colors.blue,
              Colors.pink,
              Colors.orange,
              Colors.purple
            ],
            createParticlePath: _drawStar,
          ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.green,
                  size: 80,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Delivered!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.green,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your order has been successfully delivered',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  ui.Path _drawStar(Size size) {
    double degToRad(double deg) => deg * (math.pi / 180.0);
    const numberOfPoints = 5;
    final halfWidth = size.width / 2;
    final externalRadius = halfWidth;
    final internalRadius = halfWidth / 2.5;
    final degreesPerStep = degToRad(360 / numberOfPoints);
    final halfDegreesPerStep = degreesPerStep / 2;
    final path = ui.Path();
    final fullAngle = degToRad(360);
    path.moveTo(size.width, halfWidth);
    for (double step = 0; step < fullAngle; step += degreesPerStep) {
      path.lineTo(halfWidth + externalRadius * math.cos(step),
          halfWidth + externalRadius * math.sin(step));
      path.lineTo(
          halfWidth + internalRadius * math.cos(step + halfDegreesPerStep),
          halfWidth + internalRadius * math.sin(step + halfDegreesPerStep));
    }
    path.close();
    return path;
  }

  // ==========================================================================
  //  Map widget
  // ==========================================================================

  Widget _buildMap() {
    log('Build MAPP ');
    if (_initialPosition.latitude.isNaN || _initialPosition.longitude.isNaN) {
      return const Center(child: Icon(Icons.map_outlined));
    }
    return FlutterMap(
      mapController: mapController,
      options: _mapOptions,
      children: [
        TileLayer(
          urlTemplate: 'https://server.arcgisonline.com/ArcGIS/rest/services/'
              'World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.hyperlocal.app',
        ),
        PolylineLayer(
          polylines: [
            if (_travelledPolyline != null) _travelledPolyline!,
            if (_remainingPolyline != null) _remainingPolyline!,
            ..._buildCurvedDashedPolylines(),
          ],
        ),
        MarkerLayer(markers: _markers.toList()),
      ],
    );
  }

  // ==========================================================================
  //  Overlay buttons
  // ==========================================================================

/*  Widget _buildFollowButton() {
    return InkWell(
      onTap: () {
        setState(() => _cameraFollowEnabled = true);
        if (_deliveryPartnerLocation != null) {
          _followRider(_deliveryPartnerLocation!);
        }
      },
      child: Container(
        height: 35,
        width: 35,
        decoration: BoxDecoration(
          color: _cameraFollowEnabled ? AppTheme.primaryColor : Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        alignment: Alignment.center,
        child: Icon(
          Icons.my_location,
          color: _cameraFollowEnabled ? Colors.white : AppTheme.primaryColor,
          size: 22,
        ),
      ),
    );
  }*/

  Widget _buildRefreshButton() {
    return InkWell(
      onTap: () => context.read<DeliveryTrackingBloc>().add(
        FetchDeliveryTracking(orderSlug: widget.orderSlug),
      ),
      child: Container(
        height: 35,
        width: 35,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 6)],
        ),
        child: const Icon(Icons.refresh),
      ),
    );
  }

  /*Widget _buildReroutingIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.orange.shade700,
        borderRadius: BorderRadius.circular(30),
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 14,
            height: 14,
            child:
            CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
          ),
          SizedBox(width: 6),
          Text('Rerouting…',
              style: TextStyle(color: Colors.white, fontSize: 12)),
        ],
      ),
    );
  }*/

  // ==========================================================================
  //  Dispose
  // ==========================================================================

  @override
  void dispose() {
    _confettiController.dispose();
    _deliveryAnimationController.dispose();
    _refreshTimer?.cancel();
    mapController.dispose();
    super.dispose();
  }
}