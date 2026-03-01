// Copyright (c) 2026 Walsong Group. All rights reserved.
// Walsong Group — Unnati Retail OS

/// Fonepay QR Service
///
/// Generates Fonepay-compatible QR payload strings for payment collection.
/// The QR is displayed on the POS screen; customer scans with their banking app.
///
/// Fonepay QR format (simplified merchant QR):
/// Reference: https://fonepay.com/developer/merchant-qr
class FonepayService {
  final String merchantCode;
  final String merchantName;
  final String terminalID;

  FonepayService({
    required this.merchantCode,
    required this.merchantName,
    required this.terminalID,
  });

  /// Generate the QR payload string for a given amount.
  ///
  /// Format (Fonepay Merchant QR v2):
  ///   P2M|{merchantCode}|{terminalID}|{amount}|{txnId}|{merchantName}
  String generateQRPayload({
    required double amount,
    required String txnId,
    String? remarks,
  }) {
    final amountStr = amount.toStringAsFixed(2);
    final rem = remarks ?? 'Payment';
    return 'P2M|$merchantCode|$terminalID|$amountStr|$txnId|$merchantName|$rem';
  }

  /// Verify a Fonepay transaction by reference ID.
  /// In production, this calls the Fonepay API to confirm payment.
  /// Returns the transaction status.
  Future<FonepayTxnStatus> verifyTransaction(String fonepayTxnId) async {
    // TODO: Call Fonepay verification API in production
    // POST https://dev-clientapi.fonepay.com/api/merchantRequest
    await Future.delayed(const Duration(milliseconds: 500));
    return FonepayTxnStatus(
      txnId: fonepayTxnId,
      status: 'SUCCESS',
      amount: 0,
      remarks: 'Verified',
    );
  }
}

class FonepayTxnStatus {
  final String txnId;
  final String status; // SUCCESS | FAILED | PENDING
  final double amount;
  final String remarks;

  FonepayTxnStatus({
    required this.txnId,
    required this.status,
    required this.amount,
    required this.remarks,
  });

  bool get isSuccess => status == 'SUCCESS';
}
