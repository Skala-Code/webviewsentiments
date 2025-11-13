import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class FirstRunManager {
  static const String _firstRunKey = 'app_first_run_completed';
  static const String _installIdKey = 'app_install_id';
  static FirstRunManager? _instance;
  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();
  
  FirstRunManager._internal();
  
  static FirstRunManager get instance {
    _instance ??= FirstRunManager._internal();
    return _instance!;
  }
  
  /// Verifica se é a primeira execução do app após instalação
  /// Usa combinação de SharedPreferences + Secure Storage para detectar reinstalação
  Future<bool> isFirstRun() async {
    final prefs = await SharedPreferences.getInstance();
    final hasCompletedBefore = prefs.getBool(_firstRunKey) ?? false;
    
    // Verificar ID único da instalação
    final currentInstallId = DateTime.now().millisecondsSinceEpoch.toString();
    final savedInstallId = await _secureStorage.read(key: _installIdKey);
    
    if (savedInstallId == null) {
      // Primeira instalação ou app foi desinstalado
      await _secureStorage.write(key: _installIdKey, value: currentInstallId);
      print('🆕 [FIRST_RUN] Nova instalação detectada - ID: $currentInstallId');
      return true;
    } else if (!hasCompletedBefore) {
      // App já instalado mas primeira execução não foi marcada
      print('🔄 [FIRST_RUN] App reinstalado - ID anterior: $savedInstallId, novo: $currentInstallId');
      await _secureStorage.write(key: _installIdKey, value: currentInstallId);
      return true;
    }
    
    print('👤 [FIRST_RUN] Usuário retornando - ID: $savedInstallId');
    return false;
  }
  
  /// Marca que a primeira execução foi completada
  Future<void> markFirstRunCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_firstRunKey, true);
  }
  
  /// Limpa todos os dados persistentes do WebView e storages seguros
  Future<void> clearWebViewData(InAppWebViewController controller) async {
    try {
      print('🧹 [FIRST_RUN] Iniciando limpeza completa de dados...');
      
      // 1. Limpar localStorage
      await controller.evaluateJavascript(source: '''
        if (typeof(Storage) !== "undefined") {
          console.log('🧹 Limpando localStorage...');
          localStorage.clear();
        }
      ''');
      
      // 2. Limpar sessionStorage
      await controller.evaluateJavascript(source: '''
        if (typeof(Storage) !== "undefined") {
          console.log('🧹 Limpando sessionStorage...');
          sessionStorage.clear();
        }
      ''');
      
      // 3. Limpar IndexedDB (pode armazenar dados persistentes)
      await controller.evaluateJavascript(source: '''
        if ('indexedDB' in window) {
          console.log('🧹 Limpando IndexedDB...');
          try {
            // Deletar todas as databases IndexedDB
            if (typeof indexedDB.databases === 'function') {
              indexedDB.databases().then(databases => {
                databases.forEach(db => {
                  if (db.name) indexedDB.deleteDatabase(db.name);
                });
              });
            }
          } catch(e) {
            console.warn('Erro ao limpar IndexedDB:', e);
          }
        }
      ''');
      
      // 4. Limpar dados específicos que podem persistir temp_users
      await controller.evaluateJavascript(source: '''
        console.log('🧹 Removendo dados específicos de usuários...');
        const keysToRemove = [];
        for (let i = 0; i < localStorage.length; i++) {
          const key = localStorage.key(i);
          if (key && (
            key.includes('user') || 
            key.includes('auth') || 
            key.includes('token') ||
            key.includes('email') ||
            key.includes('login') ||
            key.includes('temp_')
          )) {
            keysToRemove.push(key);
          }
        }
        keysToRemove.forEach(key => localStorage.removeItem(key));
        console.log('🧹 Removidos', keysToRemove.length, 'itens relacionados a usuários');
      ''');
      
      // 5. Limpar cookies através do CookieManager
      final cookieManager = CookieManager.instance();
      await cookieManager.deleteAllCookies();
      
      // 6. Limpar cache do WebView
      await controller.clearCache();
      
      print('✅ [FIRST_RUN] Limpeza completa realizada com sucesso');
    } catch (e) {
      print('❌ [FIRST_RUN] Erro ao limpar dados do WebView: $e');
    }
  }
  
  /// Força a limpeza de dados para teste (apenas debug)
  Future<void> resetForTesting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_firstRunKey);
    print('🧪 [FIRST_RUN] Flag de primeira execução resetado para teste');
  }
}