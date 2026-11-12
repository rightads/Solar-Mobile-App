// App-wide constants

class AppConstants {
  AppConstants._();

  // App Info
  static const String appName = 'SolarPro';
  static const String appTagline = 'Powering India\'s Solar Future';
  static const String companyName = 'SolarPro Management';

  // Production API (TLS only). Override per build with
  //   --dart-define=API_BASE_URL=https://<host>/api/v1
  //   --dart-define=API_LIVE_HOST=https://<host>
  // Release builds refuse non-https URLs (see ApiClient).
  static const String serverHost = 'https://api.solarpro-app.in';
  static const String serverBaseUrl = 'https://api.solarpro-app.in/api/v1';

  static const String _apiBaseUrlOverride =
      String.fromEnvironment('API_BASE_URL');
  static const String _apiLiveHostOverride =
      String.fromEnvironment('API_LIVE_HOST');

  static String get baseUrl =>
      _apiBaseUrlOverride.isNotEmpty ? _apiBaseUrlOverride : serverBaseUrl;
  static String get liveHost =>
      _apiLiveHostOverride.isNotEmpty ? _apiLiveHostOverride : serverHost;
  static String get remoteBaseUrl => baseUrl;
  static String get remoteLiveHost => liveHost;

  // Timeout settings for local API requests
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;


  // Storage keys
  static const String kAccessToken   = 'access_token';
  static const String kRefreshToken  = 'refresh_token';
  static const String kUserRole      = 'user_role';
  static const String kUserId        = 'user_id';
  static const String kUserName      = 'user_name';
  static const String kUserPhone     = 'user_phone';

  // Pagination
  static const int pageSize = 20;

  // OTP
  static const int otpLength    = 6;
  static const int otpTimerSecs = 60;

  // Image constraints
  static const int maxTicketImages = 10;
  static const int minTicketImages = 2;
}

class AppRoutes {
  AppRoutes._();
  static const String splash      = '/';
  static const String onboarding  = '/onboarding';
  static const String login       = '/login';
  static const String otp         = '/otp';
  // Vendor
  static const String vendorDash  = '/vendor/dashboard';
  static const String leads       = '/vendor/leads';
  static const String leadDetail  = '/vendor/leads/:id';
  static const String customers   = '/vendor/customers';
  static const String customerDetail = '/vendor/customers/:id';
  static const String addCustomer = '/vendor/customers/add';
  static const String payments    = '/vendor/payments';
  static const String users       = '/vendor/users';
  static const String teams       = '/vendor/teams';
  static const String workAssign  = '/vendor/work-assignments';
  static const String kedl        = '/vendor/kedl';
  static const String inventory   = '/vendor/inventory';
  static const String reports     = '/vendor/reports';
  static const String adminApprovals = '/admin/approvals';
  static const String adminEmployees = '/admin/employees';
  static const String notifications = '/notifications';
  // Client
  static const String clientDash  = '/client/dashboard';
  static const String clientStatus = '/client/status';
  static const String clientPay   = '/client/payment';
  static const String clientTickets = '/client/tickets';
  static const String newTicket   = '/client/tickets/new';
  // Employee Portal
  static const String employeeSalesman = '/employee/salesman';
  static const String employeeSite     = '/employee/site';
  static const String employeeKedl     = '/employee/kedl';
  static const String employeeService  = '/employee/service';
  static const String unsupportedRole  = '/unsupported-role';
}

/// Resolves the home landing route for a given user role & optional team type
String resolveRoleHomeRoute(String? role, {String? teamType}) {
  final cleanRole = role?.trim().toLowerCase() ?? '';
  final cleanTeam = teamType?.trim().toLowerCase() ?? '';

  switch (cleanRole) {
    case 'admin':
    case 'manager':
    case 'vendor':
      return AppRoutes.vendorDash;
    case 'client':
      return AppRoutes.clientDash;
    case 'sales':
    case 'salesman':
    case 'employee':
    case 'office_staff':
      return AppRoutes.employeeSalesman;
    case 'kedl':
      return AppRoutes.employeeKedl;
    case 'service':
      return AppRoutes.employeeService;
    case 'electrician':
    case 'structure':
    case 'civil':
    case 'site':
      return AppRoutes.employeeSite;
    case 'technician':
    case 'labour':
      if (cleanTeam.contains('elec') ||
          cleanTeam.contains('struc') ||
          cleanTeam.contains('civil') ||
          cleanTeam.contains('site') ||
          cleanTeam.contains('mount') ||
          cleanTeam.contains('install')) {
        return AppRoutes.employeeSite;
      }
      if (cleanRole == 'labour') {
        return AppRoutes.employeeSite;
      }
      return AppRoutes.employeeService;
    default:
      return AppRoutes.unsupportedRole;
  }
}


class AppAssets {
  AppAssets._();
  // Images
  static const String logo         = 'assets/images/logo.png';
  static const String solarPanel   = 'assets/images/solar_panel.png';
  static const String onboard1     = 'assets/images/onboard_1.png';
  static const String onboard2     = 'assets/images/onboard_2.png';
  static const String onboard3     = 'assets/images/onboard_3.png';
  // Animations (Lottie)
  static const String loadingAnim  = 'assets/animations/loading.json';
  static const String successAnim  = 'assets/animations/success.json';
  static const String solarAnim    = 'assets/animations/solar.json';
  static const String emptyAnim    = 'assets/animations/empty.json';
}
