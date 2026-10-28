import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/client.dart';

class ClientController extends GetxController {
  final SupabaseClient _db = Supabase.instance.client;

  final RxList<Client> clients = <Client>[].obs;
  final RxBool isLoading = false.obs;
  final RxBool isSaving = false.obs;

  static const _table = 'Clients';

  @override
  void onInit() {
    super.onInit();
    fetchClients();
  }

  Future<void> fetchClients() async {
    isLoading.value = true;
    try {
      final data = await _db.from(_table).select().order('name');
      clients.assignAll(
        List<Map<String, dynamic>>.from(data).map(Client.fromMap),
      );
    } on PostgrestException catch (e) {
      _snack('Error loading clients', e.message, isError: true);
    } finally {
      isLoading.value = false;
    }
  }

  Future<bool> createClient({
    required String name,
    String? phone,
    String? email,
    String? label,
    double openingBalance = 0,
  }) async {
    if (name.trim().isEmpty) {
      _snack('Missing name', 'Please enter a client name.', isError: true);
      return false;
    }
    isSaving.value = true;
    try {
      final inserted = await _db
          .from(_table)
          .insert({
            'name': name.trim(),
            if (phone != null && phone.trim().isNotEmpty)
              'phone': num.tryParse(phone.trim()),
            if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
            if (label != null && label.trim().isNotEmpty) 'lable': label.trim(),
            'opening_balance':
                double.parse(openingBalance.toStringAsFixed(2)),
          })
          .select()
          .single();
      clients.add(Client.fromMap(inserted));
      clients.sort((a, b) => a.name.compareTo(b.name));
      _snack('Client added', name.trim(), isError: false);
      return true;
    } on PostgrestException catch (e) {
      _snack('Could not add client', e.message, isError: true);
      return false;
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
