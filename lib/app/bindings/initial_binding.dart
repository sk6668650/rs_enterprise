import 'package:get/get.dart';

import '../controllers/client_controller.dart';
import '../controllers/invoice_controller.dart';

class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put(ClientController(), permanent: true);
    Get.put(InvoiceController(), permanent: true);
  }
}
