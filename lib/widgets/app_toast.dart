import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

// Defeault configuration for toastification
final toastConfig = {
  'style': ToastificationStyle.minimal,
  'alignment': Alignment.topCenter,
  'showProgressBar': false,
  'autoCloseDuration': const Duration(seconds: 3),
  'borderRadius': BorderRadius.circular(4.0),
  'applyBlurEffect': false,
  'closeOnClick': true,
};

/// A utility class for showing consistent toast notifications throughout the app
class AppToast {
  /// Show a success toast
  static void success({
    required BuildContext context,
    required String title,
    required String description,
    Duration? autoCloseDuration,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: toastConfig['style'] as ToastificationStyle,
      title: Text(title),
      description: Text(description),
      alignment: toastConfig['alignment'] as Alignment,
      showProgressBar: toastConfig['showProgressBar'] as bool,
      autoCloseDuration:
          autoCloseDuration ?? toastConfig['autoCloseDuration'] as Duration,
      borderRadius: toastConfig['borderRadius'] as BorderRadius,
      applyBlurEffect: toastConfig['applyBlurEffect'] as bool,
      closeOnClick: toastConfig['closeOnClick'] as bool,
    );
  }

  /// Show an error toast
  static void error({
    required BuildContext context,
    required String title,
    required String description,
    Duration? autoCloseDuration,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: toastConfig['style'] as ToastificationStyle,
      title: Text(title),
      description: Text(description),
      alignment: toastConfig['alignment'] as Alignment,
      showProgressBar: toastConfig['showProgressBar'] as bool,
      autoCloseDuration:
          autoCloseDuration ?? toastConfig['autoCloseDuration'] as Duration,
      borderRadius: toastConfig['borderRadius'] as BorderRadius,
      applyBlurEffect: toastConfig['applyBlurEffect'] as bool,
      closeOnClick: toastConfig['closeOnClick'] as bool,
    );
  }

  /// Show a warning toast
  static void warning({
    required BuildContext context,
    required String title,
    required String description,
    Duration? autoCloseDuration,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.warning,
      style: toastConfig['style'] as ToastificationStyle,
      title: Text(title),
      description: Text(description),
      alignment: toastConfig['alignment'] as Alignment,
      showProgressBar: toastConfig['showProgressBar'] as bool,
      autoCloseDuration:
          autoCloseDuration ?? toastConfig['autoCloseDuration'] as Duration,
      borderRadius: toastConfig['borderRadius'] as BorderRadius,
      applyBlurEffect: toastConfig['applyBlurEffect'] as bool,
      closeOnClick: toastConfig['closeOnClick'] as bool,
    );
  }

  /// Show an info toast
  static void info({
    required BuildContext context,
    required String title,
    required String description,
    Duration? autoCloseDuration,
  }) {
    toastification.show(
      context: context,
      type: ToastificationType.info,
      style: toastConfig['style'] as ToastificationStyle,
      title: Text(title),
      description: Text(description),
      alignment: toastConfig['alignment'] as Alignment,
      showProgressBar: toastConfig['showProgressBar'] as bool,
      autoCloseDuration:
          autoCloseDuration ?? toastConfig['autoCloseDuration'] as Duration,
      borderRadius: toastConfig['borderRadius'] as BorderRadius,
      applyBlurEffect: toastConfig['applyBlurEffect'] as bool,
      closeOnClick: toastConfig['closeOnClick'] as bool,
    );
  }
}
