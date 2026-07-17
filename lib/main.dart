import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:toastification/toastification.dart';
import 'package:zipzap_pos_self_orders/core/services/http_service.dart';
import 'package:zipzap_pos_self_orders/services/notification_service.dart';
import 'package:zipzap_pos_self_orders/services/audio_service.dart';
import 'package:zipzap_pos_self_orders/widgets/auth_wrapper.dart';
import 'package:zipzap_pos_self_orders/pages/printers/printers_page.dart';
import 'package:zipzap_pos_self_orders/pages/takeouts/takeout_page.dart';
import 'package:zipzap_pos_self_orders/pages/orders/new/new_order_page.dart';
import 'package:zipzap_pos_self_orders/pages/orders/checkout/checkout_page.dart';
import 'package:zipzap_pos_self_orders/pages/orders/list/orders_page.dart';
import 'package:zipzap_pos_self_orders/pages/orders/details/order_details_page.dart';
import 'package:zipzap_pos_self_orders/models/cart_item_model.dart';
import 'package:zipzap_pos_self_orders/pages/reports/reports_page.dart';
import 'package:zipzap_pos_self_orders/pages/customers/list/customers_page.dart';
import 'package:zipzap_pos_self_orders/pages/products/list/products_page.dart';
import 'package:zipzap_pos_self_orders/pages/categories/list/categories_page.dart';
import 'package:zipzap_pos_self_orders/pages/profile/profile_page.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/dinein_page.dart';
import 'package:zipzap_pos_self_orders/pages/dinein/new/new_dinein_page.dart';
import 'package:zipzap_pos_self_orders/core/constants/app_constants.dart';
import 'package:zipzap_pos_self_orders/utils/timezone_utils.dart';

// Global navigator key for app-wide navigation (e.g., auto-logout on 401)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();

  // Preserve native splash screen while app initializes
  if (!kIsWeb) {
    FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);
  }

  // Load environment variables from .env for runtime configuration
  await dotenv.load(fileName: '.env');

  // Initialize HTTP service
  await HttpService().initialize();

  // Initialize notification service
  await NotificationService().initialize();

  // Initialize audio service
  await AudioService().initialize();

  // Initialize timezone database for consistent date/time display
  TimezoneUtils.initialize();

  // Note: DataProvider will be initialized only after successful authentication
  // in AuthWrapper to prevent API calls when logged out

  runApp(const MainApp());
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ToastificationWrapper(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: AppConstants.appName,
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.teal,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        home: const AuthWrapper(),
        onGenerateRoute: (settings) {
          // Handle dynamic routes like /orders/{id}/details
          final uri = Uri.parse(settings.name ?? '');
          final pathSegments = uri.pathSegments;

          // Route: /orders/{orderId}/details
          if (pathSegments.length == 3 &&
              pathSegments[0] == 'orders' &&
              pathSegments[2] == 'details') {
            final orderId = pathSegments[1];
            return MaterialPageRoute(
              builder: (context) => OrderDetailsPage(orderId: orderId),
              settings: settings,
            );
          }

          // Fallback to null (will use routes map below)
          return null;
        },
        routes: {
          '/printers': (context) => const PrintersPage(),
          '/takeout': (context) => const TakeoutPage(),
          '/dinein': (context) => const DineInPage(),
          '/dinein/new': (context) => const NewDineInPage(),
          '/orders': (context) => const OrdersPage(),
          '/orders/new': (context) => const NewOrderPage(),
          '/orders/checkout': (context) {
            final args = ModalRoute.of(context)?.settings.arguments;
            if (args is Map<String, dynamic>) {
              final cartItemsList = args['cartItems'] as List?;
              final cartItems = cartItemsList != null
                  ? cartItemsList.cast<CartItem>()
                  : <CartItem>[];
              return CheckoutPage(
                cartItems: cartItems,
                cartData: args['cartData'],
                customer: args['customer'],
                orderType: args['orderType'] as String?,
                orderId: args['orderId'] as String?,
                orderNumber: args['orderNumber'] as String?,
                isEditMode: args['isEditMode'] as bool? ?? false,
              );
            }
            return const CheckoutPage(cartItems: []);
          },
          '/report': (context) => const ReportsPage(),
          '/customers': (context) => const CustomersPage(),
          '/products/list': (context) => const ProductsPage(),
          '/categories/list': (context) => const CategoriesPage(),
          '/profile': (context) => const ProfilePage(),
        },
      ),
    );
  }
}
