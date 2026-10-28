import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/invoice.dart';
import '../models/invoice_item.dart';
import '../models/payment.dart';

class InvoiceController extends GetxController {
  final SupabaseClient _db = Supabase.instance.client;

  final RxList<Invoice> invoices = <Invoice>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;
  final RxBool isRecordingPayment = false.obs;

  static const _invoicesTable = 'Invoices';
  static const _itemsTable = 'Invoice_items';
  static const _paymentsTable = 'Payments';

  @override
  void onInit() {
    super.onInit();
    fetchInvoices();
  }

  Future<void> fetchInvoices() async {
    isLoading.value = true;
    try {
      final data = await _db
          .from(_invoicesTable)
          .select()
          .order('date', ascending: false);
      invoices.assignAll(
        List<Map<String, dynamic>>.from(data).map(Invoice.fromMap),
      );
    } on PostgrestException catch (e) {
      _snack('Error loading invoices', e.message, isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<List<InvoiceItem>> fetchItems(int invoiceId) async {
    try {
      final data = await _db
          .from(_itemsTable)
          .select()
          .eq('invoice_id', invoiceId)
          .order('id');
      return List<Map<String, dynamic>>.from(data)
          .map(InvoiceItem.fromMap)
          .toList();
    } on PostgrestException catch (e) {
      _snack('Error loading items', e.message, isError: true);
      return const [];
    }
  }

  Future<Map<int, List<InvoiceItem>>> fetchItemsForInvoiceIds(
    List<int> invoiceIds,
  ) async {
    if (invoiceIds.isEmpty) return const {};
    try {
      final data = await _db
          .from(_itemsTable)
          .select()
          .inFilter('invoice_id', invoiceIds)
          .order('id');
      final result = <int, List<InvoiceItem>>{};
      for (final row in List<Map<String, dynamic>>.from(data)) {
        final item = InvoiceItem.fromMap(row);
        final id = item.invoiceId;
        if (id == null) continue;
        result.putIfAbsent(id, () => <InvoiceItem>[]).add(item);
      }
      return result;
    } on PostgrestException catch (e) {
      _snack('Error loading items', e.message, isError: true);
      return const {};
    }
  }

  Future<List<Payment>> fetchPaymentsForInvoiceIds(List<int> invoiceIds) async {
    if (invoiceIds.isEmpty) return const [];
    try {
      final data = await _db
          .from(_paymentsTable)
          .select()
          .inFilter('invoice_id', invoiceIds)
          .order('paid_at', ascending: true);
      return List<Map<String, dynamic>>.from(data)
          .map(Payment.fromMap)
          .toList();
    } on PostgrestException catch (e) {
      _snack('Error loading payments', e.message, isError: true);
      return const [];
    }
  }

  Future<List<Payment>> fetchPayments(int invoiceId) async {
    try {
      final data = await _db
          .from(_paymentsTable)
          .select()
          .eq('invoice_id', invoiceId)
          .order('paid_at', ascending: false);
      return List<Map<String, dynamic>>.from(data)
          .map(Payment.fromMap)
          .toList();
    } on PostgrestException catch (e) {
      _snack('Error loading payments', e.message, isError: true);
      return const [];
    }
  }

  Future<List<Payment>> fetchPaymentsForClient(int clientId) async {
    try {
      final data = await _db
          .from(_paymentsTable)
          .select()
          .eq('client_id', clientId)
          .order('paid_at', ascending: false);
      return List<Map<String, dynamic>>.from(data)
          .map(Payment.fromMap)
          .toList();
    } on PostgrestException catch (e) {
      _snack('Error loading payments', e.message, isError: true);
      return const [];
    }
  }

  Future<bool> recordPayment({
    required int invoiceId,
    required double amount,
    String? method,
    String? referenceNo,
    String? note,
    DateTime? paidAt,
  }) async {
    final invoice = invoices.firstWhereOrNull((i) => i.id == invoiceId);
    if (invoice == null) {
      _snack('Invoice not found', 'Could not find invoice #$invoiceId.',
          isError: true);
      return false;
    }
    final cleanAmount = double.parse(amount.toStringAsFixed(2));
    if (cleanAmount <= 0) {
      _snack('Invalid amount', 'Payment amount must be greater than zero.',
          isError: true);
      return false;
    }
    // Allow tiny rounding overshoot but block clear overpayments.
    if (cleanAmount - invoice.balance > 0.009) {
      _snack(
        'Amount exceeds balance',
        'Balance is ${invoice.balance.toStringAsFixed(2)}.',
        isError: true,
      );
      return false;
    }

    isRecordingPayment.value = true;
    try {
      final payment = Payment(
        invoiceId: invoiceId,
        clientId: invoice.clientId,
        amount: cleanAmount,
        paidAt: paidAt ?? DateTime.now(),
        method: method,
        referenceNo: referenceNo,
        note: note,
      );
      await _db.from(_paymentsTable).insert(payment.toInsert());

      // Recompute totals from server so the row stays consistent even if
      // multiple payments were inserted concurrently.
      final paymentsData = await _db
          .from(_paymentsTable)
          .select('amount')
          .eq('invoice_id', invoiceId);
      final totalPaid = double.parse(
        List<Map<String, dynamic>>.from(paymentsData)
            .fold<double>(
              0,
              (s, p) => s + ((p['amount'] as num?) ?? 0).toDouble(),
            )
            .toStringAsFixed(2),
      );
      final newBalance = double.parse(
        (invoice.amount - totalPaid)
            .clamp(0, double.infinity)
            .toStringAsFixed(2),
      );
      final newStatus = totalPaid + 0.009 >= invoice.amount
          ? 'paid'
          : (totalPaid > 0 ? 'partial' : 'due');

      final updated = await _db
          .from(_invoicesTable)
          .update({
            'paid_amount': totalPaid,
            'balance': newBalance,
            'status': newStatus,
          })
          .eq('id', invoiceId)
          .select()
          .single();

      final newInv = Invoice.fromMap(updated);
      final idx = invoices.indexWhere((i) => i.id == invoiceId);
      if (idx >= 0) {
        invoices[idx] = newInv;
      } else {
        invoices.insert(0, newInv);
      }
      _snack(
        newInv.isPaid ? 'Invoice fully paid' : 'Payment recorded',
        '₹${cleanAmount.toStringAsFixed(2)} on INV-$invoiceId',
        isError: false,
      );
      return true;
    } on PostgrestException catch (e) {
      _snack('Could not record payment', e.message, isError: true);
      return false;
    } finally {
      isRecordingPayment.value = false;
    }
  }

  Future<bool> recordClientPayment({
    required int clientId,
    required double amount,
    String? method,
    String? referenceNo,
    String? note,
    DateTime? paidAt,
  }) async {
    final cleanAmount = double.parse(amount.toStringAsFixed(2));
    if (cleanAmount <= 0) {
      _snack('Invalid amount', 'Payment amount must be greater than zero.',
          isError: true);
      return false;
    }

    isRecordingPayment.value = true;
    try {
      final payment = Payment(
        clientId: clientId,
        amount: cleanAmount,
        paidAt: paidAt ?? DateTime.now(),
        method: method,
        referenceNo: referenceNo,
        note: note,
      );
      await _db.from(_paymentsTable).insert(payment.toInsert());
      _snack(
        'Payment recorded',
        '₹${cleanAmount.toStringAsFixed(2)} received',
        isError: false,
      );
      return true;
    } on PostgrestException catch (e) {
      _snack('Could not record payment', e.message, isError: true);
      return false;
    } finally {
      isRecordingPayment.value = false;
    }
  }

  Future<Invoice?> createInvoice({
    required int clientId,
    required List<InvoiceItem> items,
    String status = 'due',
    DateTime? date,
  }) async {
    if (items.isEmpty) {
      _snack('No items', 'Add at least one item to the invoice.', isError: true);
      return null;
    }
    final amount = items.fold<double>(0, (sum, i) => sum + i.totalAmount);
    isSaving.value = true;
    try {
      final dateStr = (date ?? DateTime.now()).toIso8601String().split('T').first;
      final inserted = await _db
          .from(_invoicesTable)
          .insert({
            'client_id': clientId,
            'amount': amount,
            'status': status,
            'date': dateStr,
            'paid_amount': 0,
            'balance': amount,
          })
          .select()
          .single();
      final invoice = Invoice.fromMap(inserted);

      try {
        await _db
            .from(_itemsTable)
            .insert(items.map((i) => i.toInsert(invoice.id)).toList());
      } on PostgrestException catch (e) {
        await _db.from(_invoicesTable).delete().eq('id', invoice.id);
        _snack('Could not save items', e.message, isError: true);
        return null;
      }

      invoices.insert(0, invoice);
      return invoice;
    } on PostgrestException catch (e) {
      _snack('Could not create invoice', e.message, isError: true);
      return null;
    } finally {
      isSaving.value = false;
    }
  }

  void _snack(String title, String message, {required bool isError}) {
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(16),
      backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
      colorText: Colors.white,
      duration: const Duration(seconds: 3),
    );
  }
}
