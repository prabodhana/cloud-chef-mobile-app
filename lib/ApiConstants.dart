// API CONSTANTS (Centralized API URLs)
// =============================
class ApiConstants {
  // Base URLs
  static const String baseUrl = 'https://api-cloudchef.sltcloud.lk';
  static const String refererHeader = 'https://api-cloudchef.sltcloud.lk';
  static const String REFERER_HEADER = 'https://api-cloudchef.sltcloud.lk';

  // static const String baseUrl = 'https://api-kafenio.sltcloud.lk';
  // static const String refererHeader = 'https://api-kafenio.sltcloud.lk';
  // static const String REFERER_HEADER = 'https://api-kafenio.sltcloud.lk';

  // Helper method to get full URL
  static String getFullUrl(String endpoint) {
    return baseUrl + endpoint;
  }

  // Auth endpoints
  static const String authLogin = '/api/auth/login';
  static const String getUser = '/api/user';
  static const String authBase = '/api/auth';
  static const String authRegister = '$authBase/register';
  static const String authMe = '$authBase/me';

  // Users endpoints
  static const String users = '/api/users';

  // Stock/Category endpoints
  static const String getCategories = '/api/stock/create-data/category/get';
  static const String categoryCreate = '/api/stock/create-data/category/create';
  static String categoryRemove(int id) => '/api/stock/create-data/category/$id/remove';

  // Products/Stock endpoints
  static const String getProducts = '/api/invoice-create/stock-master-data';
  static const String stockMasterData = '/api/invoice-create/stock-master-data';
  static const String stockMaster = '/api/stock-master';
  static String stockMasterId(String id) => '$stockMaster/$id';
  static String stockMasterQuery(String query) => '$stockMaster?q=$query';

  // Stock management endpoints
  static String stockCreate = '/api/stock/create-data/stock/create';
  static String stockUpdate(int id) => '/api/stock/create-data/stock/$id/update';
  static String stockGet = '/api/stock/create-data/stock/get';
  static String stockRemove(int id) => '/api/stock/create-data/stock/$id/remove';

  // Make endpoints
  static String makeCreate = '/api/stock/create-data/make/create';
  static String makeUpdate(int id) => '/api/stock/create-data/make/$id/update';
  static String makeGet = '/api/stock/create-data/make/get';
  static String makeRemove(int id) => '/api/stock/create-data/make/$id/remove';

  // Type endpoints
  static String typeCreate = '/api/stock/create-data/type/create';
  static String typeGet = '/api/stock/create-data/type/get';
  static String typeRemove(int id) => '/api/stock/create-data/type/$id/remove';

  // Location endpoints
  static String locationCreate = '/api/stock/create-data/location/create';
  static String locationGet = '/api/stock/create-data/location/get';
  static String locationRemove(int id) => '/api/stock/create-data/location/$id/remove';

  // Tables endpoints
  static const String getTables = '/api/table-name';
  static const String tableBillFind = '/api/invoice-create/table-bill-find';
  static const String getDueTables = '/api/invoice-create/get-due-tables';
  static const String getDueTableItems = '/api/invoice-create/get-due-table-items';
  static const String markTablePaid = '/api/invoice-create/mark-table-paid';

  // Waiters endpoints
  static const String getWaiters = '/api/waiters';

  // Orders endpoints
  static const String getOrders = '/api/order';

  // Customer endpoints
  static const String getCustomers = '/api/customers';
  static const String validateCustomer = '/api/customers';
  static const String customers = '/api/customers';

  // Invoice/Payment endpoints
  static const String saveInvoice = '/api/invoice-create/dine-in-store';
  static const String processPayment = '/api/payment';
  static const String payment = '/api/payment';
  static const String createPayment = '/api/payment';
  static const String bankList = '/api/bank-list';

  // Invoice management endpoints
  static const String invoiceManagementBase = '/api/invoice-management';
  static const String getInvoices = '/api/invoice-management';
  static const String searchInvoices = '/api/invoice-management/search';
  static const String invoiceManagementFilter = '/api/invoice-management/filter-code';
  static const String generateInvoiceNumber = '/api/invoice/generate-invoice-number';
  static String getCancelInvoiceUrl(String id) => '/api/admin/invoice-management/cancel/$id';
  static const String invoiceCancel = '/api/invoice_cancel';
  static const String canceledInvoices = '/api/invoice-management/cancel';
  static const String cancelInvoice = '$invoiceManagementBase/cancel/{id}';

  // Stock/Lot endpoints
  static const String updateLotQuantity = '/api/lot/update-qty';


  // Suppliers endpoint
  static const String suppliers = '/api/suppliers';

  // Payment/Cashbook endpoints
  static const String ledgerAccountPayment = '/api/ledger-account';
  static const String mainCashbook = '/api/main-cashbook';
  static const String mainCashbookPrint = '/api/main-cashbook/print';
  static const String mainCashbookDeposit = '/api/main-cashbook/deposit-cashbook';
  static const String cashbookData = '/api/Ref-CashBook/get-data-date';
  static const String cashbookPrint = '/api/Ref-CashBook/print';
  static const String ledgerAccount = '/api/ledger-account';
  static String getLedgerAccountUrl() => ledgerAccount;
  static String getLedgerAccountByIdUrl(String id) => '$ledgerAccount/$id';

  // Direct GRN endpoints
  static const String directGrn = '/api/direct-grn';
  static String getDirectGrnDelete(String id) => '$directGrn/$id';
  static String getStockMasterWithQuery(String query) => '$stockMaster?q=$query';

  // Damage stock endpoints
  static const String damageStock = '/api/damageStock';
  static String getDamageStockWithPage(int page) => '$damageStock?page=$page';

  // Bank/Card book endpoints
  static const String bankBook = '/api/bank-book';
  static const String cardBook = '/api/card-book';
  static String getCardBookUrl(String fromDate, String toDate, String bankCode, int page) {
    return '$cardBook?from_date=$fromDate&to_date=$toDate&bank_code=$bankCode&page=$page';
  }




  // Debtor/Creditor management endpoints
  static const String debtorManagement = '/api/debtor-management';
  static const String creditorManagement = '/api/creditor-management';

  // Customer specific endpoints
  static String getCustomerLedgerUrl(String customerId) {
    return '$debtorManagement/$customerId/get-ledger';
  }

  static String getCustomerInvoicesUrl(String customerId, {bool unpaidOnly = true}) {
    return '$debtorManagement/$customerId/get-invoices?paid=${unpaidOnly ? 0 : 1}';
  }

  static String getCustomerChequesUrl(String customerId) {
    return '$debtorManagement/$customerId/get-chqs';
  }

  // Supplier specific endpoints
  static String getSupplierLedgerUrl(String supplierId) {
    return '$creditorManagement/$supplierId/get-ledger';
  }

  // Cancellation endpoint
  static const String cancelItem = '/api/invoice/cancel-item';

  static String getSupplierBillsUrl(String supplierId, {bool unpaidOnly = true}) {
    return '$creditorManagement/$supplierId/get-grns?paid=${unpaidOnly ? 0 : 1}';
  }

  static String getSupplierChequesUrl(String supplierId) {
    return '$creditorManagement/$supplierId/get-chqs';
  }
}