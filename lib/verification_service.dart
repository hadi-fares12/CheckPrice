// verification_service.dart - READY TO USE
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';

class VerificationService {
  static const String _verifiedDevicesKey = 'verified_devices';
  static const String adminPhone = '96170097279'; // Your Lebanon number
  
  // ✅ YOUR ACTUAL CALLMEBOT API KEY
  static const String _callMeBotApiKey = '4988493';
  
  // Generate random 6-digit code
  static String generateVerificationCode() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString();
  }
  
  // Check if device is verified for user
  static Future<bool> isDeviceVerified(String username) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('${_verifiedDevicesKey}_$username') ?? false;
  }
  
  // Mark device as verified
  static Future<void> markDeviceAsVerified(String username) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('${_verifiedDevicesKey}_$username', true);
  }
  
  // Send verification code via CallMeBot API
  static Future<bool> sendVerificationCode(String code, String messageType, String username) async {
    try {
      final message = _createMessage(code, messageType, username);
      print('📱 Preparing to send WhatsApp message...');
      print('💬 Message: $message');
      
      final success = await _sendViaCallMeBot(adminPhone, message);
      
      if (success) {
        print('✅ WhatsApp message sent successfully via CallMeBot');
        return true;
      } else {
        print('❌ Failed to send WhatsApp, but verification will continue');
        // Return true anyway so verification process continues
        return true;
      }
      
    } catch (e) {
      print('❌ Error in sendVerificationCode: $e');
      // Return true to allow verification to proceed
      return true;
    }
  }
  
  // Create the message content
  static String _createMessage(String code, String messageType, String username) {
    if (messageType == 'new_mobile') {
      return '''
🔐 *PRICEAPP VERIFICATION* 🔐

📱 *New Device Login Detected*

👤 *User:* $username
🔢 *Verification Code:* $code
⏰ *Time:* ${DateTime.now().toString().substring(0, 16)}

This code is required to verify the new device.
''';
    } else {
      return '''
👥 *PRICEAPP - NEW USER* 👥

📝 *New User Account Created*

👤 *Username:* $username  
🔢 *Verification Code:* $code
⏰ *Time:* ${DateTime.now().toString().substring(0, 16)}

A new user has been added to the system.
''';
    }
  }
  
  // Send message using CallMeBot API
  static Future<bool> _sendViaCallMeBot(String phoneNumber, String message) async {
    try {
      // Remove any spaces or special characters from phone number
      final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
      
      // CallMeBot API URL
      final url = Uri.parse(
        'https://api.callmebot.com/whatsapp.php?'
        'phone=$cleanPhone&'
        'text=${Uri.encodeComponent(message)}&'
        'apikey=$_callMeBotApiKey'
      );
      
      print('🌐 Calling CallMeBot API...');
      print('📞 To: +$cleanPhone');
      print('🔑 API Key: $_callMeBotApiKey');
      
      final response = await http.get(url);
      
      print('📡 API Response Status: ${response.statusCode}');
      print('📡 API Response Body: ${response.body}');
      
      if (response.statusCode == 200) {
        final responseBody = response.body.toLowerCase();
        
        // Check for success indicators
        if (responseBody.contains('success') || 
            responseBody.contains('message sent') ||
            responseBody.contains('queued')) {
          print('✅ CallMeBot: Message sent successfully!');
          return true;
        } 
        // Check for quota exceeded
        else if (responseBody.contains('quota') || responseBody.contains('exceeded')) {
          print('⚠️ CallMeBot: Free daily quota exceeded (5 messages/day)');
          print('💡 Messages will resume tomorrow, or upgrade to paid plan');
          return false;
        }
        // Check for other errors
        else {
          print('❌ CallMeBot: API returned error - ${response.body}');
          return false;
        }
      } else {
        print('❌ CallMeBot: HTTP error ${response.statusCode}');
        return false;
      }
    } catch (e) {
      print('❌ CallMeBot Exception: $e');
      return false;
    }
  }
  
  // Check if user requires verification
  static Future<bool> requiresVerification(String username) async {
    final specialUsers = ['katerji2025', 'maali','hadi'];
    if (specialUsers.contains(username)) {
      return !await isDeviceVerified(username);
    }
    return false;
  }
  
  // Get free tier information
  static String getFreeTierInfo() {
    return '''
📊 CallMeBot Free Tier:
✅ 5 messages per day
✅ 150 messages per month  
✅ Completely free
💡 Upgrade: \$5/month for unlimited messages
''';
  }
}