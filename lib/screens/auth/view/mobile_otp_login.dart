import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import '../../../config/global.dart';
import '../../../config/helper.dart';
import '../../../config/theme.dart';
import '../../../router/app_routes.dart';
import '../../../l10n/app_localizations.dart';
import '../../../utils/widgets/custom_button.dart';
import '../../../utils/widgets/custom_image_container.dart';
import '../../../utils/widgets/custom_toast.dart';
import '../../../utils/widgets/whole_page_progress.dart';
import '../bloc/auth/auth_bloc.dart';
import '../bloc/auth/auth_event.dart';
import '../bloc/auth/auth_state.dart';
import '../bloc/user_verification/user_verification_bloc.dart';
import '../bloc/user_verification/user_verification_event.dart';
import '../bloc/user_verification/user_verification_state.dart';

class MobileOtpLoginPage extends StatefulWidget {
  const MobileOtpLoginPage({super.key});

  @override
  State<MobileOtpLoginPage> createState() => _MobileOtpLoginPageState();
}

class _MobileOtpLoginPageState extends State<MobileOtpLoginPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();

  String? _completePhoneNumber;
  String _phoneNumber = '';
  String? _countryCode;
  String? _countryIso2;

  // Verification feedback (same as login_page.dart)
  bool? isUserVerified;
  String? helperText;
  Widget? statusIcon;

  // Debounce for verification
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 800);

  // Animation controllers
  late AnimationController _slideController;

  @override
  void initState() {
    super.initState();
    _slideController = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _slideController.forward();
      // Reset verification state when page opens
      context.read<UserVerificationBloc>().add(ResetVerification());
    });
  }

  void _handlePhoneNumberChange(String value) {
    _debounceTimer?.cancel();

    if (value.isEmpty) {
      context.read<UserVerificationBloc>().add(ResetVerification());
      return;
    }

    _debounceTimer = Timer(_debounceDuration, () {
      if (_phoneNumber == value) {
        String cleanPhone = value.replaceAll(RegExp(r'[^\d]'), '');
        if (cleanPhone.startsWith('62')) {
          cleanPhone = cleanPhone.substring(2);
        } else if (cleanPhone.startsWith('0')) {
          cleanPhone = cleanPhone.substring(1);
        }
        context
            .read<UserVerificationBloc>()
            .add(VerifyUser(value: cleanPhone, type: 'mobile'));
      }
    });
  }

  void _sendOtp() {
    if (!_formKey.currentState!.validate()) return;

    if (isUserVerified != true) {
      final l10n = AppLocalizations.of(context)!;
      ToastManager.show(
        context: context,
        message: l10n.thisPhoneNumberIsNotRegistered,
        type: ToastType.error,
      );
      return;
    }

    if (_completePhoneNumber == null || _phoneNumber.isEmpty) {
      return;
    }

    // Trigger AuthBloc to send OTP
    String normalizedPhone = _phoneNumber.replaceAll(RegExp(r'[^\d]'), '');
    if (normalizedPhone.startsWith('62')) {
      normalizedPhone = normalizedPhone.substring(2);
    } else if (normalizedPhone.startsWith('0')) {
      normalizedPhone = normalizedPhone.substring(1);
    }
    context.read<AuthBloc>().add(SendOtpToPhoneEvent(
          number: normalizedPhone,
          countryCode: _countryCode!,
          isoCode: _countryIso2!,
          isLogin: true,
        ));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: true,
        top: false,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          body: BlocConsumer<AuthBloc, AuthState>(
            listener: (context, state) {
              if (state is LoginPhoneCodeSentState) {
                // Navigate to OTP verification page
                GoRouter.of(context).push(
                  AppRoutes.otpVerification,
                  extra: {
                    'phoneNumber': _completePhoneNumber,
                    'registrationData': <String, dynamic>{}, // Empty for login
                    'verificationId': state.verificationId,
                    'userNumber': _phoneNumber,
                    'countryCode': _countryCode,
                    'isoCode': _countryIso2,
                    'isLogin':
                        true, // Pass as extra if needed, or handle in page
                  },
                );
              } else if (state is AuthFailed) {
                ToastManager.show(
                    context: context,
                    message: state.error,
                    type: ToastType.error);
              }
            },
            builder: (context, authState) {
              return Stack(
                children: [
                  _buildStaticBackground(),
                  _buildScrollableContent(),
                  if (authState is AuthLoading ||
                      authState is LoginCodeSentProgress)
                    const WholePageProgress(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStaticBackground() {
    return Container(
      width: double.infinity,
      height: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.primaryColor,
        image: DecorationImage(
          image: AssetImage('assets/images/doodle.png'),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildScrollableContent() {
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

    return SafeArea(
      child: Stack(
        children: [
          // Fixed Logo
          Positioned(
            top: 70.h,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              child: CustomImageContainer(
                imagePath: getAppLogoUrl(context),
                height: 120,
              ),
            ),
          ),

          // Skip Button
          Positioned(
            top: 10.h,
            right: 20.w,
            child: InkWell(
              onTap: () {
                Global.setIsFirstTime(false);
                GoRouter.of(context).go(AppRoutes.home);
              },
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
                child: Builder(
                  builder: (context) {
                    final l10n = AppLocalizations.of(context)!;
                    return Text(
                      l10n.skip,
                      style: TextStyle(
                        color: AppTheme.primaryColor,
                        fontSize: isTablet(context) ? 18 : 14.sp,
                        fontWeight: FontWeight.w400,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Main Content
          Positioned.fill(
            top: MediaQuery.of(context).size.height * 0.32,
            child: keyboardOpen
                ? SingleChildScrollView(
                    padding: const EdgeInsets.only(bottom: 40),
                    child: _buildFormContainer(),
                  )
                : _buildFormContainer(),
          ),
        ],
      ),
    );
  }

  Widget _buildFormContainer() {
    return BlocBuilder<UserVerificationBloc, UserVerificationState>(
      builder: (context, verificationState) {
        final isVerifying = verificationState is VerifyingUser;

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(16.r),
              topRight: Radius.circular(16.r),
            ),
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(16.w, 18.h, 16.w, 18.h + MediaQuery.of(context).viewInsets.bottom),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return Text(
                        l10n.welcomeBack,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: isTablet(context) ? 32 : 22.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 2.h),
                  Builder(
                    builder: (context) {
                      final l10n = AppLocalizations.of(context)!;
                      return Text(
                        l10n.enterYourPhoneNumberToReceiveOtp,
                        style: TextStyle(
                          fontFamily: AppTheme.fontFamily,
                          fontSize: isTablet(context) ? 18 : 12.sp,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w400,
                        ),
                      );
                    },
                  ),
                  SizedBox(height: 32.h),
                  _buildPhoneField(verificationState),
                  SizedBox(height: 48.h),
                  SizedBox(
                    width: double.infinity,
                    child: CustomButton(
                      onPressed: isVerifying || isUserVerified != true
                          ? null
                          : _sendOtp,
                      child: Builder(
                        builder: (context) {
                          final l10n = AppLocalizations.of(context)!;
                          return Text(
                            isVerifying ? l10n.verifying : l10n.sendOtp,
                            style: TextStyle(
                              fontSize: isTablet(context) ? 28 : 16,
                              fontFamily: AppTheme.fontFamily,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(height: 24.h),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPhoneField(UserVerificationState state) {
    final l10n = AppLocalizations.of(context)!;

    // Logic for verification feedback (matched from login_page.dart)
    if (_phoneNumber.isEmpty) {
      isUserVerified = null;
      helperText = null;
      statusIcon = null;
    } else if (state is VerifyingUser) {
      isUserVerified = null;
      helperText = l10n.verifying;
      statusIcon = const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orange),
      );
    } else if (state is UserVerified) {
      isUserVerified = state.isUserVerified;
      if (isUserVerified == true) {
        helperText = l10n.phoneNumberVerifiedSuccessfully;
      } else {
        helperText = l10n.thisPhoneNumberIsNotRegistered;
      }
      statusIcon = Icon(
        isUserVerified == true ? Icons.check_circle : Icons.cancel,
        color: isUserVerified == true ? Colors.green : Colors.red,
        size: 16,
      );
    } else if (state is UserVerificationFailed) {
      isUserVerified = false;
      helperText = l10n.unableToVerifyUser;
      statusIcon =
          const Icon(Icons.error, color: AppTheme.errorColor, size: 16);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntlPhoneField(
          showDropdownIcon: false,
          showCountryFlag: false,
          cursorColor: Theme.of(context).colorScheme.tertiary,
          decoration: InputDecoration(
            labelText: l10n.phoneNumber,
            labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: isTablet(context) ? 20 : 16,
                ),
            contentPadding: EdgeInsets.symmetric(vertical: 14.h),
            hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: isTablet(context) ? 20 : 16,
                ),
            hintText: l10n.enterYourPhoneNumber,
            prefixIcon: Icon(
              Icons.phone,
              color: Theme.of(context)
                  .colorScheme
                  .onSurface
                  .withValues(alpha: 0.5),
            ),
            prefixStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.5),
                  fontSize: isTablet(context) ? 20 : 16,
                ),
            border: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: const BorderRadius.all(Radius.circular(8)),
              borderSide:
                  BorderSide(color: Theme.of(context).colorScheme.outline),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(8)),
              borderSide: BorderSide(color: Colors.blue, width: 2),
            ),
          ),
          initialCountryCode: 'ID',
          textInputAction: TextInputAction.done,
          onChanged: (phone) {
            setState(() {
              _completePhoneNumber = phone.completeNumber;
              _countryCode = phone.countryCode;
              _phoneNumber = phone.number;
              _countryIso2 = phone.countryISOCode;
            });
            _handlePhoneNumberChange(phone.number);
          },
          validator: (phone) {
            if (phone == null || phone.number.isEmpty) {
              return l10n.pleaseEnterYourPhoneNumber;
            }
            return null;
          },
        ),
        if (helperText != null) ...[
          SizedBox(height: 6.h),
          Row(
            children: [
              if (statusIcon != null) ...[
                statusIcon!,
                SizedBox(width: 6.w),
              ],
              Expanded(
                child: Text(
                  helperText!,
                  style: TextStyle(
                    fontSize: isTablet(context) ? 18 : 12.sp,
                    color: isUserVerified == true
                        ? Colors.green
                        : isUserVerified == false
                            ? Colors.red
                            : Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _slideController.dispose();
    super.dispose();
  }
}
