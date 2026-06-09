import 'package:flutter/material.dart';
import 'package:parkirboss/presentation/screens/onboarding/onboarding_screen.dart';
import 'package:parkirboss/presentation/screens/home/home_screen.dart';
import 'package:parkirboss/presentation/screens/auth/login_screen.dart';
import 'package:parkirboss/presentation/screens/auth/sign_up_screen.dart';
import 'package:parkirboss/presentation/screens/parking/active_session_screen.dart';
import 'package:parkirboss/presentation/screens/parking/payment_confirmation_screen.dart';
import 'package:parkirboss/presentation/screens/parking/digital_receipt_screen.dart';
import 'package:parkirboss/presentation/screens/parking/exit_billing_screen.dart';
import 'package:parkirboss/presentation/screens/parking/claim_confirmed_screen.dart';
import 'package:parkirboss/presentation/screens/notifications/notifications_screen.dart';
import 'package:parkirboss/presentation/screens/profile/top_up_screen.dart';
import 'package:parkirboss/presentation/screens/profile/top_up_success_screen.dart';
import 'package:parkirboss/presentation/screens/profile/vehicle_management_screen.dart';
import 'package:parkirboss/presentation/screens/profile/add_vehicle_step1_screen.dart';
import 'package:parkirboss/presentation/screens/profile/add_vehicle_step2_screen.dart';
import 'package:parkirboss/presentation/screens/profile/add_vehicle_step3_screen.dart';
import 'package:parkirboss/presentation/screens/profile/change_password_screen.dart';

/// Centralized route configuration for the app.
class AppRouter {
  AppRouter._();

  static const String onboarding = '/onboarding';
  static const String home = '/home';
  static const String login = '/login';
  static const String signup = '/signup';
  static const String activeSession = '/active-session';
  static const String paymentConfirmation = '/payment-confirmation';
  static const String digitalReceipt = '/digital-receipt';
  static const String exitBilling = '/exit-billing';
  static const String claimConfirmed = '/claim-confirmed';
  static const String notifications = '/notifications';
  static const String topUp = '/top-up';
  static const String topUpSuccess = '/top-up-success';
  static const String vehicleManagement = '/vehicle-management';
  static const String addVehicleStep1 = '/add-vehicle-step1';
  static const String addVehicleStep2 = '/add-vehicle-step2';
  static const String addVehicleStep3 = '/add-vehicle-step3';
  static const String changePassword = '/change-password';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case onboarding:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomeScreen(),
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const LoginScreen(),
        );
      case signup:
        return MaterialPageRoute(
          builder: (_) => const SignUpScreen(),
        );
      case activeSession:
        final activeArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ActiveSessionScreen(sessionData: activeArgs),
        );
      case paymentConfirmation:
        return MaterialPageRoute(
          builder: (_) => const PaymentConfirmationScreen(),
        );
      case digitalReceipt:
        final receiptArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DigitalReceiptScreen(receiptData: receiptArgs),
        );
      case exitBilling:
        final billingArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ExitBillingScreen(billingData: billingArgs),
        );
      case claimConfirmed:
        return MaterialPageRoute(
          builder: (_) => const ClaimConfirmedScreen(),
        );
      case notifications:
        return MaterialPageRoute(
          builder: (_) => const NotificationsScreen(),
        );
      case topUp:
        return MaterialPageRoute(
          builder: (_) => const TopUpScreen(),
        );
      case topUpSuccess:
        final topUpArgs = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => TopUpSuccessScreen(topUpData: topUpArgs),
        );
      case vehicleManagement:
        return MaterialPageRoute(
          builder: (_) => const VehicleManagementScreen(),
        );
      case addVehicleStep1:
        return MaterialPageRoute(
          builder: (_) => const AddVehicleStep1Screen(),
        );
      case addVehicleStep2:
        final step2Args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddVehicleStep2Screen(args: step2Args),
        );
      case addVehicleStep3:
        final step3Args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => AddVehicleStep3Screen(args: step3Args),
        );
      case changePassword:
        return MaterialPageRoute(
          builder: (_) => const ChangePasswordScreen(),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const OnboardingScreen(),
        );
    }
  }
}
