import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthService {
  static const String baseUrl = 'https://sentiments.skalacode.com';
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'user_id';
  static const String _userEmailKey = 'user_email';
  static const String _userNameKey = 'user_name';
  static const String _perguntasCompletasKey = 'perguntas_completas';
  static const String _planoIdKey = 'plano_id';
  static const String _temaIdKey = 'tema_id';
  
  static Future<String?> getToken() async {
    try {
      final token = await _secureStorage.read(key: _tokenKey);
      if (token != null) {
        debugPrint('[AUTH] Token recuperado: ${token.substring(0, 10)}...');
      } else {
        debugPrint('[AUTH] Nenhum token encontrado no storage');
      }
      return token;
    } catch (e) {
      debugPrint('[AUTH] Erro ao recuperar token: $e');
      return null;
    }
  }
  
  static Future<void> saveToken(String token) async {
    try {
      await _secureStorage.write(key: _tokenKey, value: token);
      debugPrint('[AUTH] Token salvo: ${token.substring(0, 10)}...');
    } catch (e) {
      debugPrint('[AUTH] Erro ao salvar token: $e');
    }
  }
  
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      if (userData['id'] != null) {
        await prefs.setInt(_userIdKey, userData['id']);
      }
      
      if (userData['email'] != null) {
        await prefs.setString(_userEmailKey, userData['email']);
      }
      
      if (userData['nome'] != null) {
        await prefs.setString(_userNameKey, userData['nome']);
      }
      
      if (userData['perguntas_completas'] != null) {
        await prefs.setBool(_perguntasCompletasKey, userData['perguntas_completas']);
      }
      
      if (userData['plano_id'] != null) {
        await prefs.setInt(_planoIdKey, userData['plano_id']);
      }
      
      if (userData['tema_id'] != null) {
        await prefs.setInt(_temaIdKey, userData['tema_id']);
      }
      
      debugPrint('[AUTH] Dados do usuário salvos: ID=${userData['id']}, Email=${userData['email']}, Perguntas=${userData['perguntas_completas']}');
    } catch (e) {
      debugPrint('[AUTH] Erro ao salvar dados do usuário: $e');
    }
  }
  
  static Future<Map<String, dynamic>?> getUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final userId = prefs.getInt(_userIdKey);
      if (userId == null) return null;
      
      return {
        'id': userId,
        'email': prefs.getString(_userEmailKey),
        'nome': prefs.getString(_userNameKey),
        'perguntas_completas': prefs.getBool(_perguntasCompletasKey) ?? false,
        'plano_id': prefs.getInt(_planoIdKey),
        'tema_id': prefs.getInt(_temaIdKey),
      };
    } catch (e) {
      debugPrint('[AUTH] Erro ao recuperar dados do usuário: $e');
      return null;
    }
  }
  
  static Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      debugPrint('[AUTH] Tentando login com email: $email');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/login'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      );
      
      debugPrint('[AUTH] Resposta do login: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['token'] != null) {
          await saveToken(data['token']);
          await saveUserData(data['user']);
          
          debugPrint('[AUTH] Login bem-sucedido, token salvo');
          return {
            'success': true,
            'token': data['token'],
            'user': data['user'],
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Credenciais inválidas',
      };
    } catch (e) {
      debugPrint('[AUTH] Erro no login: $e');
      return {
        'success': false,
        'message': 'Erro de conexão: $e',
      };
    }
  }
  
  static Future<Map<String, dynamic>> register(Map<String, dynamic> registrationData) async {
    try {
      debugPrint('[AUTH] Tentando registro com dados: $registrationData');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode(registrationData),
      );
      
      debugPrint('[AUTH] Resposta do registro: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['success'] == true && data['token'] != null) {
          await saveToken(data['token']);
          await saveUserData(data['user']);
          
          debugPrint('[AUTH] Registro bem-sucedido, token salvo');
          return {
            'success': true,
            'token': data['token'],
            'user': data['user'],
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Erro ao registrar usuário',
      };
    } catch (e) {
      debugPrint('[AUTH] Erro no registro: $e');
      return {
        'success': false,
        'message': 'Erro de conexão: $e',
      };
    }
  }
  
  static Future<Map<String, dynamic>> autoRegister({
    required String nomeUsuario,
    required String deviceId,
    String? fcmToken,
    List<String>? horariosNotificacao,
    String? appVersion,
  }) async {
    try {
      debugPrint('[AUTH] Tentando auto-registro para usuário: $nomeUsuario');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/auto-register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'nome_usuario': nomeUsuario,
          'device_id': deviceId,
          'device_platform': Platform.isIOS ? 'ios' : 'android',
          'app_version': appVersion ?? '1.1.0',
          'fcm_token': fcmToken,
          'horarios_notificacao': horariosNotificacao,
        }),
      );
      
      debugPrint('[AUTH] Resposta do auto-registro: ${response.statusCode}');
      
      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        
        if (data['token'] != null) {
          await saveToken(data['token']);
          await saveUserData(data['user'] ?? {});
          
          debugPrint('[AUTH] Auto-registro bem-sucedido, token salvo');
          return {
            'success': true,
            'token': data['token'],
            'user': data['user'],
          };
        }
      }
      
      return {
        'success': false,
        'message': 'Erro ao criar conta gratuita',
      };
    } catch (e) {
      debugPrint('[AUTH] Erro no auto-registro: $e');
      return {
        'success': false,
        'message': 'Erro de conexão: $e',
      };
    }
  }
  
  static Future<Map<String, dynamic>> validateToken() async {
    try {
      final token = await getToken();
      
      if (token == null) {
        debugPrint('[AUTH] Nenhum token para validar');
        return {'success': false, 'message': 'No token found'};
      }
      
      // Verificar se há dados de usuário temporário e limpar
      final userData = await getUserData();
      if (userData != null && userData['email'] != null) {
        final email = userData['email'].toString();
        if (email.contains('temp_user_') || email.contains('tempuser')) {
          debugPrint('[AUTH] Detectado usuário temporário inválido: $email - limpando dados');
          await clearAuth();
          return {'success': false, 'message': 'Temporary user detected and removed'};
        }
      }
      
      debugPrint('[AUTH] Validando token ao abrir app...');
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/auth/validate'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      debugPrint('[AUTH] Resposta validação: ${response.statusCode}');
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        
        if (data['user'] != null) {
          // Verificar novamente se o usuário retornado não é temporário
          final userEmail = data['user']['email']?.toString() ?? '';
          if (userEmail.contains('temp_user_') || userEmail.contains('tempuser')) {
            debugPrint('[AUTH] Servidor retornou usuário temporário - limpando dados');
            await clearAuth();
            return {'success': false, 'message': 'Invalid temporary user'};
          }
          
          await saveUserData(data['user']);
        }
        
        debugPrint('[AUTH] Token válido, usuário autenticado');
        return {
          'success': true,
          'user': data['user'],
          'perguntas_completas': data['user']['perguntas_completas'] ?? false,
        };
      } else if (response.statusCode == 401) {
        debugPrint('[AUTH] Token inválido ou expirado');
        await clearAuth();
        return {'success': false, 'message': 'Token expired'};
      }
      
      return {'success': false, 'message': 'Validation failed'};
    } catch (e) {
      debugPrint('[AUTH] Erro ao validar token: $e');
      return {'success': false, 'message': 'Connection error: $e'};
    }
  }
  
  static Future<void> logout() async {
    try {
      final token = await getToken();
      
      if (token != null) {
        debugPrint('[AUTH] Fazendo logout no servidor...');
        
        await http.post(
          Uri.parse('$baseUrl/api/auth/logout'),
          headers: {
            'Authorization': 'Bearer $token',
            'Accept': 'application/json',
          },
        ).timeout(const Duration(seconds: 5), onTimeout: () {
          debugPrint('[AUTH] Timeout no logout do servidor');
          return http.Response('', 408);
        });
      }
      
      await clearAuth();
      debugPrint('[AUTH] Logout completo, storage limpo');
    } catch (e) {
      debugPrint('[AUTH] Erro no logout: $e');
      await clearAuth();
    }
  }
  
  static Future<void> clearAuth() async {
    try {
      await _secureStorage.delete(key: _tokenKey);
      
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_userIdKey);
      await prefs.remove(_userEmailKey);
      await prefs.remove(_userNameKey);
      await prefs.remove(_perguntasCompletasKey);
      await prefs.remove(_planoIdKey);
      await prefs.remove(_temaIdKey);
      
      debugPrint('[AUTH] Storage local limpo');
    } catch (e) {
      debugPrint('[AUTH] Erro ao limpar storage: $e');
    }
  }
  
  static String addTokenToUrl(String url) {
    return _addTokenToUrlAsync(url);
  }
  
  static String _addTokenToUrlAsync(String url) {
    getToken().then((token) {
      if (token == null) return url;
      
      final uri = Uri.parse(url);
      final params = Map<String, String>.from(uri.queryParameters);
      params['token'] = token;
      
      final newUri = uri.replace(queryParameters: params);
      debugPrint('[AUTH] URL com token: ${newUri.toString()}');
      return newUri.toString();
    });
    
    return url;
  }
  
  static Future<String> getUrlWithToken(String url) async {
    final token = await getToken();
    
    if (token == null) {
      debugPrint('[AUTH] Sem token para adicionar à URL');
      return url;
    }
    
    final uri = Uri.parse(url);
    final params = Map<String, String>.from(uri.queryParameters);
    params['token'] = token;
    
    final newUri = uri.replace(queryParameters: params);
    debugPrint('[AUTH] URL com token: ${newUri.toString()}');
    return newUri.toString();
  }
  
  static Future<bool> checkSession() async {
    try {
      final token = await getToken();
      
      if (token == null) {
        debugPrint('[AUTH] Sem token para verificar sessão');
        return false;
      }
      
      final response = await http.get(
        Uri.parse('$baseUrl/api/auth/check-session'),
        headers: {
          'Authorization': 'Bearer $token',
          'Accept': 'application/json',
        },
      );
      
      debugPrint('[AUTH] Status da sessão: ${response.statusCode}');
      return response.statusCode == 200;
    } catch (e) {
      debugPrint('[AUTH] Erro ao verificar sessão: $e');
      return false;
    }
  }
  
  static Map<String, String> getAuthHeaders() {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    getToken().then((token) {
      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }
    });
    
    return headers;
  }
  
  static Future<Map<String, String>> getAuthHeadersAsync() async {
    final token = await getToken();
    
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };
    
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
}