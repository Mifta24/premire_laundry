import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/auth/splash_page.dart';
import '../pages/auth/login_page.dart';
import '../pages/auth/register_page.dart';
import '../pages/auth/forgot_password_page.dart';
import '../pages/auth/reset_password_page.dart';
import '../pages/customer/customer_home_page.dart';
import '../pages/customer/order/create_order_page.dart';
import '../pages/customer/order/order_detail_page.dart';
import '../pages/customer/address/address_list_page.dart';
import '../pages/customer/address/add_address_page.dart';
import '../pages/customer/payment/payment_page.dart';
import '../pages/customer/payment/qris_page.dart';
import '../pages/customer/voucher/voucher_list_page.dart';
import '../pages/customer/profile/customer_profile_page.dart';
import '../pages/customer/profile/about_page.dart';
import '../pages/customer/profile/help_faq_page.dart';
import '../pages/courier/courier_home_page.dart';
import '../pages/courier/task_detail_page.dart';
import '../pages/courier/task_status_page.dart';
import '../pages/admin/admin_home_page.dart';
import '../pages/admin/courier/admin_courier_detail_page.dart';
import '../pages/admin/courier/add_courier_page.dart';
import '../pages/admin/order/admin_order_detail_page.dart';
import '../pages/admin/payment/admin_payment_detail_page.dart';
import '../pages/admin/service/manage_services_page.dart';
import '../pages/admin/delivery/delivery_fee_page.dart';
import '../pages/admin/settings/admin_settings_page.dart';
import '../pages/admin/voucher/admin_voucher_list_page.dart';
import '../pages/shared/notifications_page.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

class AppRouter {
  static GoRouter createRouter(BuildContext context) {
    return GoRouter(
      navigatorKey: _rootNavigatorKey,
      initialLocation: '/splash',
      onException: (context, state, router) {
        // Handle custom deep link schemes, for example:
        // premierlaundry://payment-success?orderId=xxx
        // premierlaundry://reset-password
        final uri = state.uri;
        final orderId = uri.queryParameters['orderId'];
        final deepLinkTarget = uri.host.isNotEmpty ? uri.host : uri.path;
        if (deepLinkTarget == 'reset-password') {
          router.go('/reset-password');
        } else if (orderId != null && orderId.isNotEmpty) {
          router.go('/customer/order/$orderId');
        } else {
          router.go('/customer/home');
        }
      },
      redirect: (BuildContext ctx, GoRouterState state) {
        final session = Supabase.instance.client.auth.currentSession;
        final isAuthenticated = session != null;
        final isAuthRoute =
            state.matchedLocation == '/login' ||
            state.matchedLocation == '/register' ||
            state.matchedLocation == '/forgot-password' ||
            state.matchedLocation == '/reset-password' ||
            state.matchedLocation == '/splash';

        if (!isAuthenticated && !isAuthRoute) {
          return '/login';
        }
        return null;
      },
      routes: [
        GoRoute(
          path: '/splash',
          builder: (context, state) => const SplashPage(),
        ),
        GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
        GoRoute(
          path: '/notifications',
          builder: (context, state) => const NotificationsPage(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterPage(),
        ),
        GoRoute(
          path: '/forgot-password',
          builder: (context, state) => const ForgotPasswordPage(),
        ),
        GoRoute(
          path: '/reset-password',
          builder: (context, state) => const ResetPasswordPage(),
        ),
        // Customer routes
        GoRoute(
          path: '/customer',
          redirect: (context, state) => '/customer/home',
        ),
        GoRoute(
          path: '/customer/home',
          builder: (context, state) => const CustomerHomePage(),
        ),
        GoRoute(
          path: '/customer/order/create',
          builder: (context, state) {
            final explicitType = state.uri.queryParameters['type'];
            return CreateOrderPage(
              orderType: explicitType ?? 'kiloan',
              lockType: explicitType != null,
            );
          },
        ),
        GoRoute(
          path: '/customer/order/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return OrderDetailPage(orderId: id);
          },
        ),
        GoRoute(
          path: '/customer/address',
          builder: (context, state) => const AddressListPage(),
        ),
        GoRoute(
          path: '/customer/address/add',
          builder: (context, state) => const AddAddressPage(),
        ),
        GoRoute(
          path: '/customer/payment/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return PaymentPage(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/customer/payment/qris/:orderId',
          builder: (context, state) {
            final orderId = state.pathParameters['orderId']!;
            return QrisPage(orderId: orderId);
          },
        ),
        GoRoute(
          path: '/customer/vouchers',
          builder: (context, state) => const VoucherListPage(),
        ),
        GoRoute(
          path: '/customer/profile',
          builder: (context, state) => const CustomerProfilePage(),
        ),
        GoRoute(
          path: '/customer/about',
          builder: (context, state) => const AboutPage(),
        ),
        GoRoute(
          path: '/customer/help',
          builder: (context, state) => const HelpFaqPage(),
        ),
        // Courier routes
        GoRoute(
          path: '/courier',
          builder: (context, state) => const CourierHomePage(),
        ),
        GoRoute(
          path: '/courier/task/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskDetailPage(taskId: id);
          },
        ),
        GoRoute(
          path: '/courier/task/:id/status',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return TaskStatusPage(taskId: id);
          },
        ),
        // Admin routes
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminHomePage(),
        ),
        GoRoute(
          path: '/admin/order/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminOrderDetailPage(orderId: id);
          },
        ),
        GoRoute(
          path: '/admin/payment/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminPaymentDetailPage(paymentId: id);
          },
        ),
        GoRoute(
          path: '/admin/courier/add',
          builder: (context, state) => const AddCourierPage(),
        ),
        GoRoute(
          path: '/admin/courier/:id',
          builder: (context, state) {
            final id = state.pathParameters['id']!;
            return AdminCourierDetailPage(courierId: id);
          },
        ),
        GoRoute(
          path: '/admin/services',
          builder: (context, state) => const ManageServicesPage(),
        ),
        GoRoute(
          path: '/admin/delivery-fees',
          builder: (context, state) => const DeliveryFeePage(),
        ),
        GoRoute(
          path: '/admin/settings',
          builder: (context, state) => const AdminSettingsPage(),
        ),
        GoRoute(
          path: '/admin/vouchers',
          builder: (context, state) => const AdminVoucherListPage(),
        ),
      ],
    );
  }
}
