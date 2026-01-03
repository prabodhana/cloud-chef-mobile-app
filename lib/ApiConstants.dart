// API CONSTANTS (Centralized API URLs)
// =============================
class ApiConstants {
  static const String baseUrl = 'https://api-kafenio.sltcloud.lk';  

  // Stock endpoints
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

  // Category endpoints
  static String categoryCreate = '/api/stock/create-data/category/create';
  static String categoryGet = '/api/stock/create-data/category/get';
  static String categoryRemove(int id) => '/api/stock/create-data/category/$id/remove';

  // Location endpoints
  static String locationCreate = '/api/stock/create-data/location/create';
  static String locationGet = '/api/stock/create-data/location/get';
  static String locationRemove(int id) => '/api/stock/create-data/location/$id/remove';

  // Suppliers endpoint
  static const String suppliers = '/api/suppliers';

  // Payment endpoints
  static const String ledgerAccountPayment = '/api/ledger-account';
  static const String createPayment = '/api/payment';
  static const String bankList = '/api/bank-list';
  // Stock master endpoints
  static const String stockMaster = '/api/stock-master';
  static String stockMasterId(String id) => '$stockMaster/$id';
  static String stockMasterQuery(String query) => '$stockMaster?q=$query';

  // Direct GRN endpoints
  static const String directGrn = '/api/direct-grn';
  static String getDirectGrnDelete(String id) => '$directGrn/$id';
  static String getStockMasterWithQuery(String query) => '$stockMaster?q=$query';

  // Damage stock endpoints
  static const String damageStock = '/api/damageStock';
  static String getDamageStockWithPage(int page) => '$damageStock?page=$page';

  // Invoice management endpoints
  static const String invoiceManagementFilter = '/api/invoice-management/filter-code';
  static const String generateInvoiceNumber = '/api/invoice/generate-invoice-number';
  static const String getInvoices = '/api/invoice-management';
  static const String searchInvoices = '/api/invoice-management/search';
  static String getCancelInvoiceUrl(String id) => '/api/admin/invoice-management/cancel/$id';
  static const String invoiceCancel = '/api/invoice_cancel';
  static const String canceledInvoices = '/api/invoice-management/cancel';

  // Existing endpoints from the provided snippet (kept as-is, even if not used in this code)
  static const String users = '/api/users';
  static const String customers = '/api/customers';
  static const String authBase = '/api/auth';
  static const String authLogin = '$authBase/login';
  static const String authRegister = '$authBase/register';
  static const String authMe = '$authBase/me';
  static const String mainCashbook = '/api/main-cashbook';
  static const String mainCashbookPrint = '/api/main-cashbook/print';
  static const String mainCashbookDeposit = '/api/main-cashbook/deposit-cashbook';
  static const String cashbookData = '/api/Ref-CashBook/get-data-date';
  static const String cashbookPrint = '/api/Ref-CashBook/print';

  
static const String invoiceManagementBase = '/api/invoice-management';
  // static const String getInvoices = '$invoiceManagementBase/get-data';
  // static const String searchInvoices = '$invoiceManagementBase/search';
  static const String cancelInvoice = '$invoiceManagementBase/cancel/{id}';

  // Added missing endpoints
  // static const String bankList = '/api/bank-list';
  static const String stockMasterData = '/api/invoice-create/stock-master-data';
  static const String payment = '/api/payment';
  static const String bankBook = '/api/bank-book';
  static const String ledgerAccount = '/api/ledger-account';
  static const String cardBook = '/api/card-book';
  static const String debtorManagement = '/api/debtor-management';
  static const String creditorManagement = '/api/creditor-management';
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
  static String getSupplierBillsUrl(String supplierId, {bool unpaidOnly = true}) {
    return '$creditorManagement/$supplierId/get-grns?paid=${unpaidOnly ? 0 : 1}';
  }
  static String getSupplierChequesUrl(String supplierId) {
    return '$creditorManagement/$supplierId/get-chqs';
  }


  
  // Ledger account endpoints
  static String getLedgerAccountUrl() => ledgerAccount;
  static String getLedgerAccountByIdUrl(String id) => '$ledgerAccount/$id';

  // Card book endpoint
  static String getCardBookUrl(String fromDate, String toDate, String bankCode, int page) {
    return '$cardBook?from_date=$fromDate&to_date=$toDate&bank_code=$bankCode&page=$page';
  }


// Customer specific endpoints
  static String getCustomerLedgerUrl(String customerId) {
    return '$debtorManagement/$customerId/get-ledger';
  }
 

  static String getFullUrl(String endpoint) {
    return baseUrl + endpoint;
  }
}
