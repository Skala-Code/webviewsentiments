import 'dart:convert';
import 'package:http/http.dart' as http;

// Script para forçar atualização do FCM token no banco

void main() async {
  const String validToken = 'edSmo2QzIEJ5iy2GhRCZbm:APA91bFbUFmrvxjK4gMOeIVDLxVJ33AREz7QKLy4v6zmCCxBIHIzUnOVul9a0weym7_MUBBm7P7Z5_J9F_B11Nmsdho9KG7DPk1GP6c_-WXtVzhT_rxHMIs';
  const String userEmail = 'user_1757598149@sentiments.app';
  const String firebaseUid = 'ZEjl3cakjWbYNI6hZlyCvP2zVXh1';

  try {
    print('Enviando token válido para API...');

    final response = await http.post(
      Uri.parse('https://sentiments.skalacode.com/api/fcm-flutter'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': userEmail,
        'fcm_token': validToken,
        'firebase_uid': firebaseUid,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('✅ Token atualizado com sucesso!');
      print('Resposta: ${data['message']}');
      print('User ID: ${data['user_id']}');
      print('Token preview: ${data['token_preview']}');
    } else {
      print('❌ Erro ao atualizar token');
      print('Status code: ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Erro na requisição: $e');
  }
}