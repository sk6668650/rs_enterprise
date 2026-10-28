import 'package:get/get.dart';

import '../bindings/initial_binding.dart';
import '../screens/client_detail_screen.dart';
import '../screens/client_screen.dart';
import '../screens/client_statement_screen.dart';
import '../screens/invoice_detail_screen.dart';
import '../screens/invoice_preview_screen.dart';
import '../screens/invoice_screen.dart';

abstract class Routes {
  static const clients = '/';
  static const clientDetail = '/clients/detail';
  static const clientStatement = '/clients/statement';
  static const invoiceDetail = '/invoices/detail';
  static const invoicePreview = '/invoices/preview';
  static const createInvoice = '/invoices/new';
}

class AppPages {
  static final pages = [
    GetPage(
      name: Routes.clients,
      page: () => const ClientScreen(),
      binding: InitialBinding(),
    ),
    GetPage(
      name: Routes.clientDetail,
      page: () => const ClientDetailScreen(),
    ),
    GetPage(
      name: Routes.clientStatement,
      page: () => const ClientStatementScreen(),
    ),
    GetPage(
      name: Routes.invoiceDetail,
      page: () => const InvoiceDetailScreen(),
    ),
    GetPage(
      name: Routes.invoicePreview,
      page: () => const InvoicePreviewScreen(),
    ),
    GetPage(
      name: Routes.createInvoice,
      page: () => const InvoiceScreen(),
    ),
  ];
}
