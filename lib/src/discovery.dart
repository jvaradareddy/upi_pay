// lib/src/discovery.dart

import 'dart:convert';
import 'package:universal_io/io.dart' as io;
import 'package:upi_pay/src/platform_interface.dart';
import 'package:upi_pay/types/applications.dart';
import 'package:upi_pay/types/discovery.dart';
import 'package:upi_pay/types/status.dart';
import 'package:upi_pay/types/meta.dart';

class UpiApplicationDiscovery {
  final _discovery = io.Platform.isAndroid
      ? _AndroidDiscovery()
      : io.Platform.isIOS
          ? _IosDiscovery()
          : null;

  static final _singleton = UpiApplicationDiscovery._internal();

  factory UpiApplicationDiscovery() => _singleton;

  UpiApplicationDiscovery._internal();

  Future<List<ApplicationMeta>> discover({
    required Map<UpiApplication, UpiApplicationStatus> applicationStatusMap,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    UpiApplicationDiscoveryAppStatusType statusType =
        UpiApplicationDiscoveryAppStatusType.working,
  }) async {
    if (_discovery == null) {
      throw UnsupportedError('Discovery is only supported on Android and iOS');
    }
    return _discovery!.discover(
      applicationStatusMap: applicationStatusMap,
      paymentType: paymentType,
      statusType: statusType,
    );
  }
}

abstract class _PlatformDiscoveryBase {
  Future<List<ApplicationMeta>> discover({
    required Map<UpiApplication, UpiApplicationStatus> applicationStatusMap,
    UpiApplicationDiscoveryAppPaymentType paymentType,
    UpiApplicationDiscoveryAppStatusType statusType,
  });
}

class _AndroidDiscovery implements _PlatformDiscoveryBase {
  @override
  Future<List<ApplicationMeta>> discover({
    required Map<UpiApplication, UpiApplicationStatus> applicationStatusMap,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    UpiApplicationDiscoveryAppStatusType statusType =
        UpiApplicationDiscoveryAppStatusType.working,
  }) async {
    final appsList = await UpiPayPlatform.instance.getInstalledUpiApps();
    if (appsList == null) return [];

    final List<ApplicationMeta> retList = [];

    for (var app in appsList) {
      final packageName = _castToString(app['packageName']);
      final androidStatus = _getStatus(packageName, applicationStatusMap);
      if (androidStatus == null) continue;
      if (_canUseApp(statusType, androidStatus)) {
        final icon = _castToString(app['icon']);
        final priority = _castToInt(app['priority']);
        final preferredOrder = _castToInt(app['preferredOrder']);
        retList.add(ApplicationMeta.android(
          UpiApplication.lookUpMap[packageName]!,
          base64.decode(icon),
          priority,
          preferredOrder,
        ));
      }
    }

    return retList;
  }

  UpiApplicationAndroidStatus? _getStatus(
    String packageName,
    Map<UpiApplication, UpiApplicationStatus> applicationStatusMap,
  ) {
    final upiApp = UpiApplication.lookUpMap[packageName];
    return upiApp != null ? applicationStatusMap[upiApp]?.androidStatus : null;
  }

  bool _canUseApp(
    UpiApplicationDiscoveryAppStatusType statusType,
    UpiApplicationAndroidStatus androidStatus,
  ) {
    if (androidStatus.setup == UpiApplicationSetupStatus.success &&
        androidStatus.linkingSupport == UpiApplicationLinkingSupport.shows) {
      switch (statusType) {
        case UpiApplicationDiscoveryAppStatusType.working:
          return androidStatus.nonMerchantPaymentStatus ==
                  NonMerchantPaymentAndroidStatus.success &&
              !androidStatus.warnsUnverifiedSourceForNonMerchant;
        case UpiApplicationDiscoveryAppStatusType.workingWithWarnings:
          return androidStatus.nonMerchantPaymentStatus ==
              NonMerchantPaymentAndroidStatus.success;
        case UpiApplicationDiscoveryAppStatusType.all:
          return true;
      }
    }
    return false;
  }
}

class _IosDiscovery implements _PlatformDiscoveryBase {
  @override
  Future<List<ApplicationMeta>> discover({
    required Map<UpiApplication, UpiApplicationStatus> applicationStatusMap,
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    UpiApplicationDiscoveryAppStatusType statusType =
        UpiApplicationDiscoveryAppStatusType.working,
  }) async {
    Map<String, UpiApplication> discoveryMap = {};
    List<UpiApplication> discovered = [];

    applicationStatusMap.forEach((app, status) {
      final bundleId = app.iosBundleId;
      if (bundleId != null) {
        final iosStatus = status.iosStatus;
        if (iosStatus != null && _canUseApp(statusType, iosStatus)) {
          if (app.discoveryCustomScheme != null) {
            discoveryMap[app.discoveryCustomScheme!] = app;
          } else {
            discovered.add(app);
          }
        }
      }
    });

    for (var scheme in discoveryMap.keys) {
      try {
        final canLaunch = await UpiPayPlatform.instance.canLaunch(scheme);
        if (canLaunch == true) {
          discovered.add(discoveryMap[scheme]!);
        }
      } catch (_) {}
    }

    return discovered.map((app) => ApplicationMeta.ios(app)).toList();
  }

  bool _canUseApp(
    UpiApplicationDiscoveryAppStatusType statusType,
    UpiApplicationIosStatus iosStatus,
  ) {
    if (iosStatus.setup == UpiApplicationSetupStatus.success &&
        iosStatus.linkingSupport == UpiApplicationLinkingSupport.shows) {
      switch (statusType) {
        case UpiApplicationDiscoveryAppStatusType.working:
          return iosStatus.nonMerchantPaymentStatus ==
                  NonMerchantPaymentIosStatus.success &&
              !iosStatus.warnsUnverifiedSourceForNonMerchant;
        case UpiApplicationDiscoveryAppStatusType.workingWithWarnings:
          return iosStatus.nonMerchantPaymentStatus ==
              NonMerchantPaymentIosStatus.success;
        case UpiApplicationDiscoveryAppStatusType.all:
          return true;
      }
    }
    return false;
  }
}

String _castToString(dynamic value) {
  if (value is String) return value;
  throw TypeError();
}

int _castToInt(dynamic value) {
  if (value is int) return value;
  throw TypeError();
}
