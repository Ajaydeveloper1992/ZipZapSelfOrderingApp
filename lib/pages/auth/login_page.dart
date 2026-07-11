import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:zipzap_pos_self_orders/core/services/auth_service.dart';
import 'package:zipzap_pos_self_orders/pages/auth/widgets/numeric_keypad.dart';
import 'package:zipzap_pos_self_orders/widgets/app_version_text.dart';

class LoginPage extends StatefulWidget {
  final VoidCallback? onLoginSuccess;

  const LoginPage({super.key, this.onLoginSuccess});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _storeIdController = TextEditingController();
  final _usernameController = TextEditingController();
  final _pinController = TextEditingController();
  final _authService = AuthService();
  bool _isPinVisible = false;
  bool _isLoading = false;
  String _currentDateTime = '';
  String? _errorMessage;
  Map<String, String?> _fieldErrors = {};

  @override
  void initState() {
    super.initState();
    _updateDateTime();
    // Update date/time every second
    _startDateTimeTimer();
    // Load last login credentials for auto-population
    _loadLastLoginCredentials();
  }

  Future<void> _loadLastLoginCredentials() async {
    try {
      // Ensure AuthService is initialized
      await _authService.initializeProfile();

      final lastStoreSlug = _authService.getLastStoreSlug();
      final lastUsername = _authService.getLastUsername();

      if (mounted) {
        setState(() {
          if (lastStoreSlug != null) {
            _storeIdController.text = lastStoreSlug;
          }
          if (lastUsername != null) {
            _usernameController.text = lastUsername;
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading last login credentials: $e');
    }
  }

  void _startDateTimeTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (mounted) {
        setState(() {
          _updateDateTime();
        });
        _startDateTimeTimer();
      }
    });
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final day = now.day;
    final suffix = _getDaySuffix(day);
    final month = DateFormat('MMM').format(now);
    final year = now.year;
    final time = DateFormat('h:mm:ss a').format(now);
    _currentDateTime = '$day$suffix $month, $year | $time';
  }

  String _getDaySuffix(int day) {
    if (day >= 11 && day <= 13) {
      return 'th';
    }
    switch (day % 10) {
      case 1:
        return 'st';
      case 2:
        return 'nd';
      case 3:
        return 'rd';
      default:
        return 'th';
    }
  }

  @override
  void dispose() {
    _storeIdController.dispose();
    _usernameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _onKeypadNumber(String number) {
    final currentText = _pinController.text;
    _pinController.text = currentText + number;
    _pinController.selection = TextSelection.fromPosition(
      TextPosition(offset: _pinController.text.length),
    );
  }

  void _onKeypadBackspace() {
    final currentText = _pinController.text;
    if (currentText.isNotEmpty) {
      _pinController.text = currentText.substring(0, currentText.length - 1);
      _pinController.selection = TextSelection.fromPosition(
        TextPosition(offset: _pinController.text.length),
      );
    }
  }

  void _validateFields() {
    setState(() {
      _fieldErrors = {};

      if (_storeIdController.text.isEmpty) {
        _fieldErrors['storeId'] = 'Please enter Store Slug';
      }

      if (_usernameController.text.isEmpty) {
        _fieldErrors['username'] = 'Please enter username or email';
      }

      if (_pinController.text.isEmpty) {
        _fieldErrors['pin'] = 'Please enter PIN';
      } else if (_pinController.text.length < 4) {
        _fieldErrors['pin'] = 'PIN must be at least 4 digits';
      }
    });
  }

  Future<void> _handleLogin() async {
    _validateFields();

    if (_fieldErrors.isNotEmpty) {
      setState(() {
        _errorMessage = 'Please fill in all fields correctly';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Call pin-login API
      await _authService.pinLogin(
        user: _usernameController.text.trim(),
        pin: _pinController.text,
        storeSlug: _storeIdController.text
            .trim(), // Store slug (e.g., "hakkaheritage")
      );

      widget.onLoginSuccess?.call();
    } catch (e) {
      setState(() {
        _errorMessage = e.toString().replaceFirst('Exception: ', '');
        if (_errorMessage!.isEmpty) {
          _errorMessage = 'Login failed. Please check your credentials.';
        }
        _isLoading = false;
      });
      debugPrint('Login error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    color: Colors.white,
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Title and Subtitle
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(
                                'Welcome to ZipZap',
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 22,
                                      color: Colors.grey.shade900,
                                    ),
                              ),
                              Text(
                                _currentDateTime,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                      letterSpacing: 0.3,
                                    ),
                              ),
                            ],
                          ),
                          SizedBox(height: _errorMessage != null ? 4 : 16),

                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: Colors.red.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: Colors.red.shade700,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      // _errorMessage!,
                                      'Login failed. Please check your credentials.',
                                      style: TextStyle(
                                        color: Colors.red.shade700,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                          // Store ID Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Store Slug',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CupertinoTextField(
                                controller: _storeIdController,
                                placeholder:
                                    'Enter Store Slug (e.g., hakkaheritage)',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                prefix: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Icon(
                                    Icons.store,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 15),
                                textInputAction: TextInputAction.next,
                              ),
                              if (_fieldErrors['storeId'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _fieldErrors['storeId']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Username or Email Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Username or Email',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CupertinoTextField(
                                controller: _usernameController,
                                placeholder: 'Enter username or email',
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                prefix: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Icon(
                                    Icons.person,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 15),
                                keyboardType: TextInputType.emailAddress,
                                textInputAction: TextInputAction.next,
                              ),
                              if (_fieldErrors['username'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _fieldErrors['username']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // PIN Field
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Enter PIN',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const SizedBox(height: 6),
                              CupertinoTextField(
                                controller: _pinController,
                                placeholder: 'Tap to enter PIN',
                                readOnly: true,
                                showCursor: false,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                                prefix: Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Icon(
                                    Icons.lock,
                                    size: 20,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  ),
                                ),
                                suffix: Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: CupertinoButton(
                                    padding: EdgeInsets.zero,
                                    onPressed: () {
                                      setState(() {
                                        _isPinVisible = !_isPinVisible;
                                      });
                                    },
                                    minimumSize: Size(0, 0),
                                    child: Icon(
                                      _isPinVisible
                                          ? Icons.visibility
                                          : Icons.visibility_off,
                                      size: 20,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                                obscureText: !_isPinVisible,
                                style: const TextStyle(fontSize: 15),
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                              ),
                              if (_fieldErrors['pin'] != null)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    left: 4,
                                  ),
                                  child: Text(
                                    _fieldErrors['pin']!,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red.shade700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Numeric Keypad
                          const SizedBox(height: 8),
                          NumericKeypad(
                            onNumberPressed: _onKeypadNumber,
                            onBackspace: _onKeypadBackspace,
                            onEnter: _handleLogin,
                            isLoading: _isLoading,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            // Version at bottom
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: AppVersionText(color: Colors.white.withOpacity(0.7)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
