import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF005A9C);
  static const Color background = Color(0xFFF5F7FA);
  static const Color error = Colors.red;
  static const Color success = Colors.green;
}

class AppStyles {
  static const titleStyle = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.bold,
    color: AppColors.primary,
  );

  static const subTitleStyle = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.bold,
  );

  static final buttonStyle = ElevatedButton.styleFrom(
    backgroundColor: AppColors.primary,
    foregroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
  );

  static const inputDecoration = InputDecoration(
    border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(10))),
    filled: true,
    fillColor: Colors.white,
  );
}

class ValidationUtils {
  // 비밀번호: 영문 대소문자, 숫자, 특수문자 포함 8자 이상
  static bool isPasswordValid(String password) {
    final regex = RegExp(r'^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[@$!%*?&])[A-Za-z\d@$!%*?&]{8,}$');
    return regex.hasMatch(password);
  }

  static String get passwordHint => '8자 이상, 영문 대소문자, 숫자, 특수문자를 모두 포함해야 합니다.';
}
