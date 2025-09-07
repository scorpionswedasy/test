// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';

class BuildMedia {
  /// It is a simplification of the **_MediaQuery.of(_context)_** statement.
  BuildMedia(BuildContext context) : data = MediaQuery.of(context);

  ///```dart
  ///return MediaQuery.of(context)
  ///```
  final MediaQueryData data;

  ///```dart
  ///return MediaQuery.of(context).size
  ///```
  Size get size => data.size;

  ///```dart
  ///return MediaQuery.of(context).size.width
  ///```
  double get width => data.size.width;

  ///```dart
  ///return MediaQuery.of(context).size.height
  ///```
  double get height => data.size.height;

  ///```dart
  ///return height - viewInsets.vertical
  ///```
  double get heightWithoutViewInsets => height - viewInsets.vertical;

  ///```dart
  ///return viewInsets.bottom > 0
  ///```
  bool get keyboardIsVisible => viewInsets.bottom > 0;

  ///```dart
  ///return MediaQuery.of(context).padding
  ///```
  EdgeInsets get padding => data.padding;

  ///```dart
  ///return MediaQuery.of(context).devicePixelRatio
  ///```
  double get devicePixelRatio => data.devicePixelRatio;

  ///```dart
  ///return MediaQuery.of(context).textScaleFactor
  ///```
  double get textScaleFactor => data.textScaleFactor;

  ///```dart
  ///return MediaQuery.of(context).platformBrightness
  ///```
  Brightness get platformBrightness => data.platformBrightness;

  ///```dart
  ///return MediaQuery.of(context).viewInsets
  ///```
  EdgeInsets get viewInsets => data.viewInsets;

  ///```dart
  ///return MediaQuery.of(context).systemGestureInsets
  ///```
  EdgeInsets get systemGestureInsets => data.systemGestureInsets;

  ///Do that:  MediaQuery.of(_context).viewPadding
  ///```
  EdgeInsets get viewPadding => data.viewPadding;

  ///```dart
  ///return MediaQuery.of(context).alwaysUse24HourFormat
  ///```
  bool get alwaysUse24HourFormat => data.alwaysUse24HourFormat;

  ///```dart
  ///return MediaQuery.of(context).accessibleNavigation
  ///```
  bool get accessibleNavigation => data.accessibleNavigation;

  ///```dart
  ///return MediaQuery.of(context).invertColors
  ///```
  bool get invertColors => data.invertColors;

  ///```dart
  ///return MediaQuery.of(context).highContrast
  ///```
  bool get highContrast => data.highContrast;

  ///```dart
  ///return MediaQuery.of(context).disableAnimations
  ///```
  bool get disableAnimations => data.disableAnimations;

  ///```dart
  ///return MediaQuery.of(context).boldText
  ///```
  bool get boldText => data.boldText;

  ///```dart
  ///return MediaQuery.of(context).navigationMode
  ///```
  NavigationMode get navigationMode => data.navigationMode;
}
