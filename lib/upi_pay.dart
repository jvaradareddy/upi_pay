// lib/upi_pay.dart

library upi_pay;

export 'src/api.dart' show UpiPay;
export 'src/discovery.dart' show UpiApplicationDiscovery;
export 'types/applications.dart' show UpiApplication;
export 'types/response.dart' show UpiTransactionResponse, UpiTransactionStatus;
export 'types/meta.dart' show ApplicationMeta;
export 'types/discovery.dart'
    show UpiApplicationDiscoveryAppStatusType, UpiApplicationDiscoveryAppPaymentType;
export 'types/status.dart' show UpiApplicationStatus;
export 'src/platform_interface.dart' show UpiPayPlatform;

// Add this helper at bottom of the file:

class UpiAppDiscoveryHelper {
  static Future<List<ApplicationMeta>> getInstalledUpiApplications({
    UpiApplicationDiscoveryAppPaymentType paymentType =
        UpiApplicationDiscoveryAppPaymentType.nonMerchant,
    UpiApplicationDiscoveryAppStatusType statusType =
        UpiApplicationDiscoveryAppStatusType.working,
  }) async {
    final discovery = UpiApplicationDiscovery();
    final statusMap = await UpiPayPlatform.instance.getStatusMap();
    return discovery.discover(
      applicationStatusMap: statusMap,
      paymentType: paymentType,
      statusType: statusType,
    );
  }
}
