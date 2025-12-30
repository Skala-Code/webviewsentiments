import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
// import 'package:firebase_data_connect/firebase_data_connect.dart';  // Temporarily disabled
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter_dynamic_icon_plus/flutter_dynamic_icon_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:gal/gal.dart';
import 'package:image/image.dart' as img;
import 'firebase_options.dart';
import 'services/iap_service.dart';
import 'services/first_run_manager.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'utils/device_info.dart';
import 'services/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Note: In-App Purchase initialization is handled automatically by the plugin
  
  // Lock screen orientation to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);
  
  // Warm up services
  await _warmUpServices();
  
  runApp(const MyApp());
}

Future<void> _warmUpServices() async {
  // Pre-initialize critical services to reduce first-load time
  try {
    // Warm up HTTP client
    final client = http.Client();
    client.close();
    
    // Pre-warm image cache
    PaintingBinding.instance.imageCache.clear();
  } catch (e) {
    // Ignore warm-up errors
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sentiments',
      debugShowCheckedModeBanner: false, // Remove banner DEBUG em produção
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;
  
  bool _isInitialized = false;
  final Completer<void> _webViewLoadedCompleter = Completer<void>();
  Timer? _timeoutTimer;
  bool _webViewLoaded = false;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    ));

    _fadeController.forward();
  }


  Future<void> _initializeApp() async {
    try {
      if (kDebugMode) print('🚀 Iniciando inicialização do app...');
      
      // Start Firebase initialization immediately in background
      _initializeFirebaseInBackground();
      
      // Wait for animation to complete first (minimum time)
      await Future.delayed(const Duration(milliseconds: 1200));
      
      if (kDebugMode) print('✅ Animação completa, navegando para WebView...');
      
      if (mounted) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) => WebViewScreen(
              onWebViewReady: () {
                if (kDebugMode) print('✅ WebView pronto!');
              },
            ),
            transitionsBuilder: (context, animation, secondaryAnimation, child) {
              return FadeTransition(opacity: animation, child: child);
            },
            transitionDuration: const Duration(milliseconds: 200),
          ),
        );
        
        if (kDebugMode) print('✅ Navegação iniciada');
      } else {
        if (kDebugMode) print('❌ Widget não está mounted');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro na inicialização: $e');
    }
  }
  
  void _startWebViewPreloading() {
    // Set timeout for safety (maximum 20 seconds - increased timeout)
    _timeoutTimer = Timer(const Duration(seconds: 20), () {
      if (!_webViewLoadedCompleter.isCompleted) {
        if (kDebugMode) print('⚠️ WebView loading timeout after 20s, proceeding anyway');
        _webViewLoadedCompleter.complete();
      }
    });
  }
  
  void _initializeFirebaseInBackground() async {
    try {
      // Initialize Firebase in background
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      // Request notification permissions
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      
      if (kDebugMode) print('Firebase initialized in background');
    } catch (e) {
      if (kDebugMode) print('Firebase background initialization failed: $e');
    }
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _timeoutTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9F9F9),
      body: Stack(
        children: [
          Center(
            child: AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return Opacity(
                  opacity: _fadeAnimation.value,
                  child: Image.asset(
                    'assets/images/logo.png',
                    width: 200,
                    height: 200,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class WebViewScreen extends StatefulWidget {
  final VoidCallback? onWebViewReady;
  
  const WebViewScreen({super.key, this.onWebViewReady});

  @override
  State<WebViewScreen> createState() => _WebViewScreenState();
}

class _WebViewScreenState extends State<WebViewScreen> {
  late InAppWebViewController _webViewController;
  String? _userEmail;
  String? _currentIcon;
  bool _iconInitialized = false;
  bool _isMonitoring = true;
  String _currentUrl = "https://testesentiments.skalacode.com"; // URL inicial (sem barra no final)
  bool _tokenValidated = false;
  Timer? _tokenSaveTimer;
  Timer? _purchaseTimeoutTimer; // Timer para timeout de compra
  late IAPService _iapService;
  bool _hasCheckedPremium = false; // Flag para marcar quando premium foi verificado
  bool _isProcessingRestore = false; // Flag para evitar múltiplos processamentos
  bool _hasNavigatedToDashboard = false; // Flag para evitar múltiplas navegações
  bool _purchaseAlreadyProcessed = false; // Flag para evitar processamento duplicado
  String? _lastProcessedTransactionId; // ID da última transação processada
  bool _isPurchasing = false; // Flag para bloquear navegações durante compra
  bool _restoreProcessedOnce = false; // Flag para processar apenas uma vez por sessão
  
  /// Resetar estado de compra com segurança
  void _resetPurchaseState({String reason = 'unknown'}) {
    print('🔄 [PURCHASE] Resetando estado de compra - Razão: $reason');
    
    // Cancelar timer se existir
    _purchaseTimeoutTimer?.cancel();
    _purchaseTimeoutTimer = null;
    
    // Resetar flags
    _isPurchasing = false;
    
    print('✅ [PURCHASE] Estado resetado - navegações liberadas');
  }

  @override
  void initState() {
    super.initState();
    _initializeFirebaseServices();
    _validateTokenOnStartup();
    // IAP service will be initialized after WebView is created
  }
  
  Future<void> _initializeFirebaseServices() async {
    // Wait for Firebase to be initialized from splash screen
    await _waitForFirebase();
    
    _startMonitoring();
    _setupTokenRefreshListener();
    _startPeriodicTokenSave();
  }
  
  Future<void> _validateTokenOnStartup() async {
    debugPrint('[AUTH] Validando token ao iniciar o app...');
    
    try {
      final validationResult = await AuthService.validateToken();
      
      if (validationResult['success'] == true) {
        _tokenValidated = true;
        final perguntasCompletas = validationResult['perguntas_completas'] ?? false;
        
        debugPrint('[AUTH] Token válido, perguntas completas: $perguntasCompletas');
        
        // Atualizar URL inicial baseado no status
        final token = await AuthService.getToken();
        if (token != null) {
          if (perguntasCompletas) {
            _currentUrl = 'https://testesentiments.skalacode.com/dashboard?token=$token';
          } else {
            _currentUrl = 'https://testesentiments.skalacode.com/perguntas-iniciais?token=$token';
          }
          debugPrint('[AUTH] URL inicial atualizada para: $_currentUrl');
        }
      } else {
        debugPrint('[AUTH] Token inválido ou ausente, limpando storage');
        await AuthService.clearAuth();
        _tokenValidated = false;
      }
    } catch (e) {
      debugPrint('[AUTH] Erro ao validar token: $e');
      _tokenValidated = false;
    }
    
    // Força atualização da UI se necessário
    if (mounted) {
      setState(() {});
    }
  }
  
  Future<void> _waitForFirebase() async {
    // Wait for Firebase to be initialized (max 10 seconds)
    for (int i = 0; i < 50; i++) {
      try {
        if (Firebase.apps.isNotEmpty) {
          return;
        }
      } catch (e) {
        // Firebase not ready yet
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    
    // If Firebase is not ready after 10 seconds, initialize it now
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      if (kDebugMode) print('Fallback Firebase initialization failed: $e');
    }
  }

  void _initializeIAPService() async {
    print('🚀 [MAIN] Inicializando IAP Service...');
    
    _iapService = IAPService();
    
    // Verificar status da assinatura ao iniciar o app
    _checkSubscriptionOnStartup();
    
    // Configurar callbacks para WebView
    _iapService.onPurchaseSuccess = (purchaseData) async {
      print('✅ [MAIN] Purchase SUCCESS - enviando callback para WebView');
      print('📦 [MAIN] Dados da compra: $purchaseData');
      
      // Enviar receipt para o backend Laravel
      await _sendReceiptToBackend(purchaseData);
      
      // Verificar se WebView está inicializado antes de chamar JavaScript
      try {
        await _webViewController.evaluateJavascript(source: '''
          console.log('✅ Flutter: Purchase Success', ${jsonEncode(purchaseData)});
          console.log('🚫 [FIX] Comentando window.onPurchaseSuccess para evitar auto-register 500');
          // COMENTADO TEMPORARIAMENTE - evita chamada desnecessária para /api/auto-register
          // if (window.onPurchaseSuccess) {
          //   window.onPurchaseSuccess(${jsonEncode(purchaseData)});
          // } else {
          //   console.error('❌ window.onPurchaseSuccess não definido!');
          // }
        ''');
      } catch (e) {
        print('⚠️ [MAIN] Erro ao enviar callback para WebView: $e');
      }
    };
    
    _iapService.onPurchaseError = (errorData) {
      print('❌ [MAIN] Purchase ERROR - enviando callback para WebView');
      print('📦 [MAIN] Erro: $errorData');
      
      // Resetar estado de compra com método seguro
      final errorCode = errorData['code'] ?? 'unknown_error';
      final errorMessage = errorData['message'] ?? 'Erro desconhecido';
      _resetPurchaseState(reason: 'error: $errorCode - $errorMessage');
      
      try {
        _webViewController.evaluateJavascript(source: '''
          console.log('❌ Flutter: Purchase Error', ${jsonEncode(errorData)});
          console.log('🚫 [FIX] Comentando window.onPurchaseError para evitar redirecionamento');
          // COMENTADO TEMPORARIAMENTE - evita redirecionamento não autenticado para /dashboard
          // if (window.onPurchaseError) {
          //   window.onPurchaseError(${jsonEncode(errorData)});
          // } else {
          //   console.error('❌ window.onPurchaseError não definido!');
          // }
        ''');
      } catch (e) {
        print('⚠️ [MAIN] Erro ao enviar callback de erro para WebView: $e');
      }
    };
    
    _iapService.onProductsLoaded = (productsData) {
      print('📦 [MAIN] Products LOADED - enviando callback para WebView');
      print('📦 [MAIN] ${productsData.length} produtos: $productsData');
      
      try {
        _webViewController.evaluateJavascript(source: '''
          console.log('📦 Flutter: Products Loaded', ${jsonEncode(productsData)});
          if (window.onProductsLoaded) {
            window.onProductsLoaded(${jsonEncode(productsData)});
          } else {
            console.error('❌ window.onProductsLoaded não definido!');
          }
        ''');
      } catch (e) {
        print('⚠️ [MAIN] Erro ao enviar callback de produtos para WebView: $e');
      }
    };
    
    _iapService.onRestoreSuccess = (restoreData) async {
      print('🔄 [MAIN] ===============================');
      print('🔄 [MAIN] RESTORE SUCCESS EXECUTADO!!!');
      print('📦 [MAIN] Compras restauradas: ${restoreData.length} transações');
      print('🔄 [MAIN] Processing flags: _isProcessingRestore=$_isProcessingRestore, _restoreProcessedOnce=$_restoreProcessedOnce');
      
      // 🚨 EVITAR PROCESSAMENTO MÚLTIPLO - Crítico para evitar loop infinito
      if (_isProcessingRestore) {
        print('⚠️ [MAIN] Restauração já em andamento - ignorando');
        return;
      }
      
      // Resetar flags para permitir nova verificação e navegação
      _restoreProcessedOnce = false;
      _hasNavigatedToDashboard = false; // Resetar flag de navegação para permitir redirecionamento
      
      // Marcar como processando
      _isProcessingRestore = true;
      _restoreProcessedOnce = true;
      
      try {
        // Enviar receipt para o backend Laravel quando restaurar compra (APENAS O PRIMEIRO)
        if (restoreData.isNotEmpty) {
          // 📝 Processar apenas a transação mais recente
          final mostRecentTransaction = restoreData.first;
          print('📤 [MAIN] Enviando APENAS a primeira transação para verificação...');
          print('📦 [MAIN] Transaction ID: ${mostRecentTransaction['transactionId']}');
          
          await _sendReceiptToBackend(mostRecentTransaction);
          print('✅ [MAIN] Receipt verification concluída');
          
          // Apenas notificar JavaScript sobre a restauração - não redirecionar
          try {
            await _webViewController.evaluateJavascript(source: '''
              console.log('✅ [Flutter] Chamando onPurchaseSuccess com dados da restauração');
              
              console.log('🚫 [FIX] Comentando onPurchaseSuccess na restauração para evitar auto-register');
              // COMENTADO TEMPORARIAMENTE - evita chamada desnecessária para /api/auto-register
              // if (window.onPurchaseSuccess) {
              //   window.onPurchaseSuccess({
              //     transactionId: "${mostRecentTransaction['transactionId'] ?? 'restored'}",
              //     productId: "${mostRecentTransaction['productId'] ?? (Platform.isIOS ? 'com.mycompany.sentiments.premium_yearly' : 'premium_yearly')}",
              //     receipt: "${mostRecentTransaction['serverReceipt'] ?? mostRecentTransaction['receipt'] ?? ''}",
              //     purchaseToken: "${mostRecentTransaction['purchaseToken'] ?? ''}",
              //     platform: "${Platform.isIOS ? 'ios' : 'android'}",
              //     verified: true,
              //     restored: true
              //   });
              //   console.log('📱 onPurchaseSuccess chamado com dados da restauração');
              // } else 
              if (window.onRestoreSuccess) {
                window.onRestoreSuccess(${jsonEncode(mostRecentTransaction)});
                console.log('📱 onRestoreSuccess chamado');
              } else {
                console.error('❌ Nenhum handler encontrado!');
              }
            ''');
          } catch (e) {
            print('⚠️ [MAIN] Erro ao notificar WebView sobre restauração: $e');
          }
        } else {
          print('⚠️ [MAIN] restoreData está vazio!');
        }
      } finally {
        // Liberar flag após processamento
        _isProcessingRestore = false;
      }
      
      print('✅ [MAIN] onRestoreSuccess processado completamente');
    };
    
    // Debug callback para mostrar logs na WebView
    _iapService.onDebugLog = (String debugMessage) {
      try {
        _webViewController.evaluateJavascript(source: '''
          console.log('[DEBUG IAP] $debugMessage');
          if (window.showIAPDebug) {
            window.showIAPDebug('$debugMessage');
          } else {
          // Debug div desabilitado em produção
          console.log('IAP Debug:', '$debugMessage');
        }
      ''');
      } catch (e) {
        print('⚠️ [MAIN] Erro ao enviar debug log para WebView: $e');
      }
    };
    
    // Inicializar o serviço
    await _iapService.initialize();
    print('✅ [MAIN] IAP Service inicializado');
  }

  Future<void> _checkSubscriptionOnStartup() async {
    print('🔍 [MAIN] Verificando status da assinatura ao iniciar...');

    // AGUARDAR O EMAIL DO USUÁRIO SER CARREGADO PRIMEIRO
    // Isso evita o erro "faça login ou crie uma conta" ao abrir o app
    int attempts = 0;
    while (_userEmail == null && attempts < 10) { // Máximo 5 segundos (10 x 500ms)
      print('⏳ [MAIN] Aguardando email do usuário ser carregado... tentativa ${attempts + 1}/10');
      await Future.delayed(Duration(milliseconds: 500));
      attempts++;

      // Tentar forçar a verificação do localStorage
      if (attempts == 5) { // Na metade das tentativas, forçar uma verificação
        print('🔄 [MAIN] Forçando verificação do localStorage...');
        try {
          final result = await _webViewController.evaluateJavascript(
            source: "localStorage.getItem('user_email')"
          );

          if (result != null && result.toString().isNotEmpty && result != 'null') {
            String newEmail = result.toString().replaceAll('"', '');
            _userEmail = newEmail;
            print('✅ [MAIN] Email encontrado via verificação forçada: $_userEmail');
          }
        } catch (e) {
          print('⚠️ [MAIN] Erro ao forçar verificação: $e');
        }
      }
    }

    // Se após 5 segundos ainda não tiver email, não verificar assinatura
    if (_userEmail == null || _userEmail == 'lois@lois.com') {
      print('⚠️ [MAIN] Email não carregado ou é usuário de teste após ${attempts * 500}ms');
      print('⚠️ [MAIN] Pulando verificação de assinatura para evitar erro de autenticação');
      // Não mostrar erro, apenas ignorar silenciosamente
      return;
    }

    print('✅ [MAIN] Email do usuário carregado: $_userEmail');
    print('🔍 [MAIN] Continuando com verificação de assinatura...');

    try {
      // Aguardar IAP estar inicializado
      bool initialized = await _iapService.initialize();
      if (!initialized) {
        print('⚠️ [MAIN] IAP não disponível, assumindo usuário sem assinatura');
        await _notifyBackendSubscriptionStatus(false);
        return;
      }

      // Verificar status da assinatura
      final status = await _iapService.checkSubscriptionStatus();
      
      if (status['hasActiveSubscription'] == true) {
        print('✅ [MAIN] Usuário tem assinatura ativa!');
        
        // Notificar WebView que usuário é premium
        await _webViewController.evaluateJavascript(source: '''
          console.log('✅ Assinatura ativa detectada ao iniciar');
          if (window.onSubscriptionStatusChecked) {
            window.onSubscriptionStatusChecked({
              isActive: true,
              purchases: ${jsonEncode(status['purchases'] ?? [])}
            });
          }
          
          // Atualizar interface se necessário
          if (window.updateUserPremiumStatus) {
            window.updateUserPremiumStatus(true);
          }
        ''');
        
        // Notificar backend
        await _notifyBackendSubscriptionStatus(true, status['purchases']);
        
      } else {
        print('⚠️ [MAIN] Usuário não tem assinatura ativa - revertendo ao plano básico');
        
        // Notificar WebView que usuário não é premium
        await _webViewController.evaluateJavascript(source: '''
          console.log('⚠️ Nenhuma assinatura ativa detectada');
          if (window.onSubscriptionStatusChecked) {
            window.onSubscriptionStatusChecked({
              isActive: false,
              message: '${status['message'] ?? 'Assinatura expirada ou cancelada'}'
            });
          }
          
          // Reverter para plano básico
          if (window.revertToBasicPlan) {
            window.revertToBasicPlan();
          }
        ''');
        
        // Notificar backend para reverter ao plano básico
        await _notifyBackendSubscriptionStatus(false);
      }
      
    } catch (e) {
      print('❌ [MAIN] Erro ao verificar assinatura: $e');
    }
  }
  
  Future<void> _notifyBackendSubscriptionStatus(bool isActive, [List<dynamic>? purchases]) async {
    try {
      // Obter token de autenticação do WebView
      final authToken = await _webViewController.evaluateJavascript(source: '''
        (function() {
          const token = localStorage.getItem('auth_token') || 
                       sessionStorage.getItem('auth_token') ||
                       document.querySelector('meta[name="api-token"]')?.content;
          return token;
        })();
      ''');
      
      if (authToken != null && authToken != 'null') {
        print('📤 [MAIN] Enviando status da assinatura para o backend...');
        
        // Chamar API do Laravel para atualizar status
        await _webViewController.evaluateJavascript(source: '''
          fetch('/api/user/subscription-status', {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
              'X-CSRF-TOKEN': document.querySelector('meta[name="csrf-token"]')?.content || ''
            },
            body: JSON.stringify({
              is_active: $isActive,
              checked_at: new Date().toISOString(),
              purchases: ${jsonEncode(purchases ?? [])}
            })
          })
          .then(response => response.json())
          .then(data => {
            console.log('✅ Status da assinatura atualizado no backend:', data);
          })
          .catch(error => {
            console.error('❌ Erro ao atualizar status no backend:', error);
          });
        ''');
      }
    } catch (e) {
      print('❌ [MAIN] Erro ao notificar backend: $e');
    }
  }
  
  Future<Map<String, dynamic>?> _sendReceiptToBackend(Map<String, dynamic> purchaseData) async {
    try {
      // Verificar se esta transação já foi processada
      final transactionId = purchaseData['transactionId']?.toString();
      if (transactionId != null && _lastProcessedTransactionId == transactionId) {
        print('⚠️ [MAIN] Transação $transactionId já foi processada - ignorando');
        return null;
      }
      
      // Verificar se já está sendo processado
      if (_purchaseAlreadyProcessed) {
        print('⚠️ [MAIN] Compra já está sendo processada - ignorando');
        return null;
      }
      
      // Marcar como sendo processado
      _purchaseAlreadyProcessed = true;
      if (transactionId != null) {
        _lastProcessedTransactionId = transactionId;
      }
      
      print('📤 [MAIN] ================================');
      print('📤 [MAIN] _sendReceiptToBackend INICIADO');
      print('🔢 [MAIN] Transaction ID: $transactionId');
      print('📦 [MAIN] Receipt data: ${purchaseData['receipt']}');
      print('📧 [MAIN] User email: $_userEmail');
      print('📤 [MAIN] ================================');

      // AGUARDAR EMAIL SER CARREGADO (mesma proteção do _checkSubscriptionOnStartup)
      if (_userEmail == null) {
        print('⏳ [RECEIPT] Email não carregado, aguardando...');
        int attempts = 0;
        while (_userEmail == null && attempts < 10) { // Máximo 5 segundos
          print('⏳ [RECEIPT] Aguardando email... tentativa ${attempts + 1}/10');
          await Future.delayed(Duration(milliseconds: 500));
          attempts++;

          // Tentar forçar verificação do localStorage na metade das tentativas
          if (attempts == 5) {
            try {
              print('🔄 [RECEIPT] Forçando verificação do localStorage...');
              final result = await _webViewController.evaluateJavascript(
                source: "localStorage.getItem('user_email')"
              );
              if (result != null && result.toString().isNotEmpty && result != 'null') {
                String newEmail = result.toString().replaceAll('"', '');
                _userEmail = newEmail;
                print('✅ [RECEIPT] Email encontrado: $_userEmail');
              }
            } catch (e) {
              print('⚠️ [RECEIPT] Erro ao verificar localStorage: $e');
            }
          }
        }

        // Se após 5 segundos ainda não tiver email no primeiro acesso, ignorar silenciosamente
        if (_userEmail == null) {
          print('⚠️ [RECEIPT] Email não carregado após ${attempts * 500}ms - assumindo primeiro acesso');
          print('⚠️ [RECEIPT] Pulando processamento de compra para evitar erro de autenticação');
          // Resetar flags e retornar silenciosamente
          _purchaseAlreadyProcessed = false;
          return null;
        }
      }

      if (_userEmail == 'lois@lois.com') {
        print('❌ [MAIN] Compra bloqueada - usuário não autenticado');
        
        // Notificar JavaScript que precisa fazer login primeiro
        await _webViewController.evaluateJavascript(source: '''
          console.error('❌ Usuário não autenticado - necessário fazer login antes da compra');
          
          // Resetar estado de compra
          if (window.resetPurchaseState) {
            window.resetPurchaseState();
          }
          
          // Mostrar mensagem e redirecionar para login
          if (window.onPurchaseRequiresAuth) {
            window.onPurchaseRequiresAuth();
          } else {
            alert('Por favor, faça login ou crie uma conta antes de fazer a compra.');
            window.location.href = '/premium-login';
          }
        ''');
        
        // Retornar erro para não processar a compra
        return {
          'success': false,
          'error': 'Usuário não autenticado',
          'requiresAuth': true,
          'message': 'É necessário fazer login antes de realizar a compra'
        };
      }
      
      // Construir a URL para o endpoint de verificação de receipt
      final url = Uri.parse('https://testesentiments.skalacode.com/api/ios-purchase-verify');
      
      print('🔄 [MAIN] Enviando dados para backend...');
      print('📧 [MAIN] Email: $_userEmail');
      print('🆔 [MAIN] Product ID: ${purchaseData['productId'] ?? (Platform.isIOS ? 'com.mycompany.sentiments.premium_yearly' : 'premium_yearly')}');
      
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'receipt_data': purchaseData['serverReceipt'] ?? purchaseData['receipt'],
          'email': _userEmail,
          'product_id': purchaseData['productId'] ?? (Platform.isIOS ? 'com.mycompany.sentiments.premium_yearly' : 'premium_yearly'),
          'platform': Platform.isIOS ? 'ios' : 'android',
          'is_jwt': Platform.isIOS, // iOS usa JWT, Android usa JSON
          'transaction_id': purchaseData['transactionId'],
          'purchase_token': purchaseData['purchaseToken'], // Para Android
          'is_restore': purchaseData['isRestore'] ?? false, // Indicar se é uma restauração
        }),
      );
      
      print('📡 [MAIN] Resposta recebida - Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('✅ [MAIN] Receipt verificado com sucesso!');
        print('📦 [MAIN] Resposta do backend: $responseData');
        
        // 🎯 SOLUÇÃO DIRETA: Flutter navega imediatamente quando backend confirma premium
        if (responseData['success'] == true && responseData['active_plan'] == true) {
          print('🎉 [MAIN] Premium confirmado pelo backend! User ID: ${responseData['user_id']}');
          
          // 🚨 EVITAR MÚLTIPLAS NAVEGAÇÕES - Crítico para evitar conflitos
          if (_hasNavigatedToDashboard) {
            print('⚠️ [MAIN] Navegação já realizada - ignorando nova tentativa');
            // Ainda assim, resetar flag de processamento
            _purchaseAlreadyProcessed = false;
            return null;
          }
          
          _hasNavigatedToDashboard = true;
          print('🚀 [MAIN] Navegando para premium-login para autenticação automática');
          
          try {
            // Em vez de navegar direto para dashboard, primeiro autenticar
            final userId = responseData['user_id'];
            final userEmail = _userEmail ?? 'user@sentiments.app'; // Fallback se email não disponível
            final loginUrl = 'https://testesentiments.skalacode.com/premium-login?email=${Uri.encodeComponent(userEmail)}&user_id=$userId&from_app=true';
            
            print('🔐 [MAIN] Navegando para autenticação: $loginUrl');
            
            // Navegar para premium-login que automaticamente autentica e vai para dashboard
            await _webViewController.loadUrl(
              urlRequest: URLRequest(url: WebUri(loginUrl))
            );
            
            // Aguardar um pouco para a página carregar
            await Future.delayed(Duration(milliseconds: 500));
            
            // Chamar JavaScript com dados reais da compra
            await _webViewController.evaluateJavascript(source: '''
              console.log('✅ [Flutter] Chamando onPurchaseSuccess após navegação para premium-login');
              
              console.log('🚫 [FIX] Comentando onPurchaseSuccess após login para evitar auto-register');
              // COMENTADO TEMPORARIAMENTE - evita chamada desnecessária para /api/auto-register
              // if (window.onPurchaseSuccess) {
              //   window.onPurchaseSuccess({
              //     transactionId: "${purchaseData['transactionId'] ?? 'unknown'}",
              //     productId: "${purchaseData['productId'] ?? (Platform.isIOS ? 'com.mycompany.sentiments.premium_yearly' : 'premium_yearly')}",
              //     receipt: "${purchaseData['serverReceipt'] ?? purchaseData['receipt'] ?? ''}",
              //     purchaseToken: "${purchaseData['purchaseToken'] ?? ''}",
              //     platform: "${Platform.isIOS ? 'ios' : 'android'}",
              //     verified: true,
              //     backendUserId: $userId,
              //     authenticatedLogin: true
              //   });
              //   console.log('📱 onPurchaseSuccess chamado com dados completos da compra');
              // } else {
              //   console.log('ℹ️ window.onPurchaseSuccess não definido - normal em página premium-login');
              // }
              console.log('ℹ️ [FIX] onPurchaseSuccess desabilitado - compra já processada pelo Flutter');
            ''');
          } catch (e) {
            print('❌ [MAIN] Erro na navegação: $e');
            _hasNavigatedToDashboard = false; // Reset flag em caso de erro
            _purchaseAlreadyProcessed = false; // Reset flag de processamento
          }
          
          // Resetar flags após processamento bem-sucedido
          _purchaseAlreadyProcessed = false;
          _resetPurchaseState(reason: 'purchase completed successfully');
          return {'success': true, 'message': 'Purchase completed successfully'};
        }
      } else {
        // Resetar flag em caso de erro
        _purchaseAlreadyProcessed = false;
        print('❌ [MAIN] Erro ao verificar receipt: ${response.statusCode}');
        print('📦 [MAIN] Resposta: ${response.body}');
        
        // Resetar estado após erro na verificação
        _resetPurchaseState(reason: 'verification error: ${response.statusCode}');
        
        // Notificar JavaScript sobre erro na verificação
        try {
          await _webViewController.evaluateJavascript(source: '''
            console.log('❌ [Flutter] Erro na verificação do receipt');
            console.log('🚫 [FIX] Comentando window.onPurchaseError na verificação');
            // COMENTADO TEMPORARIAMENTE - evita redirecionamento não autenticado
            // if (window.onPurchaseError) {
            //   window.onPurchaseError({
            //     message: "Erro ao verificar compra - Status: ${response.statusCode}",
            //     statusCode: ${response.statusCode}
            //   });
            // }
          ''');
        } catch (jsError) {
          print('⚠️ [MAIN] Erro ao notificar JavaScript: $jsError');
        }
      }
    } catch (e) {
      // Resetar flag em caso de erro
      _purchaseAlreadyProcessed = false;
      print('❌ [MAIN] Erro ao enviar receipt: $e');
      
      // Resetar estado após erro de conexão
      _resetPurchaseState(reason: 'connection error');
      
      // Notificar JavaScript sobre erro de conexão
      try {
        await _webViewController.evaluateJavascript(source: '''
          console.log('❌ [Flutter] Erro de conexão ao verificar receipt');
          console.log('🚫 [FIX] Comentando window.onPurchaseError na conexão');
          // COMENTADO TEMPORARIAMENTE - evita redirecionamento não autenticado
          // if (window.onPurchaseError) {
          //   window.onPurchaseError({
          //     message: "Erro de conexão ao verificar compra: $e"
          //   });
          // }
        ''');
      } catch (jsError) {
        print('⚠️ [MAIN] Erro ao notificar JavaScript: $jsError');
      }
    }
    
    // Retornar null como fallback
    return null;
  }

  /// Verificar se o usuário tem premium ativo
  Future<bool> checkIfUserHasPremium() async {
    try {
      final response = await http.get(
        Uri.parse('https://testesentiments.skalacode.com/api/premium/status'),
        headers: {'Accept': 'application/json'}
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['success'] == true && data['data']['is_premium'] == true;
      }
      return false; // Em caso de erro, assumir que não é premium
    } catch (e) {
      print('❌ [MAIN] Erro ao verificar status premium: $e');
      return false; // Em caso de erro, assumir que não é premium
    }
  }

  /// Fluxo premium - verifica automaticamente se usuário tem assinatura
  Future<void> handlePremiumFlow() async {
    print('🎯 [MAIN] handlePremiumFlow - DESABILITADO (evitar loop infinito)');
    
    // 🚨 RESTAURAÇÃO AUTOMÁTICA DESABILITADA para evitar loop infinito
    // A restauração agora só ocorre quando usuário clica explicitamente em "Restaurar Compras"
    print('ℹ️ [MAIN] Restauração automática desabilitada. Use o botão "Restaurar Compras" se necessário.');
    
    // Se quiser verificar status premium sem restaurar, use checkIfUserHasPremium()
    // try {
    //   bool hasPremium = await checkIfUserHasPremium();
    //   print('🔍 [MAIN] Status premium via API: $hasPremium');
    // } catch (e) {
    //   print('⚠️ [MAIN] Erro ao verificar status premium: $e');
    // }
  }

  void _startPeriodicTokenSave() {
    _tokenSaveTimer = Timer.periodic(const Duration(seconds: 60), (timer) async {
      await _saveFCMTokenPeriodically();
    });
  }

  Future<void> _handleUserChange(String newEmail) async {
    // Clear any existing timer
    _tokenSaveTimer?.cancel();
    
    // Sign out from Firebase to clear previous user session
    try {
      await FirebaseAuth.instance.signOut();
      if (kDebugMode) print('Signed out previous user');
    } catch (e) {
      if (kDebugMode) print('Error signing out: $e');
    }
    
    // Update user email
    _userEmail = newEmail;
    
    // Restart authentication process for new user
    await _handleFirebaseAuth();
    
    // Restart periodic token saving
    _startPeriodicTokenSave();
  }

  Future<void> _saveFCMTokenPeriodically() async {
    if (_userEmail == null) {
      if (kDebugMode) print('No user email available for periodic token save');
      return;
    }

    try {
      String? fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken != null && !fcmToken.startsWith('unsupported')) {
        // Get current token from localStorage to avoid overwriting valid tokens
        String? currentToken = await _webViewController.evaluateJavascript(
          source: "localStorage.getItem('fcm_token')"
        );

        // Only update if new token is different and valid
        if (currentToken != fcmToken) {
          // Save to localStorage
          await _webViewController.evaluateJavascript(
            source: "localStorage.setItem('fcm_token', '$fcmToken')"
          );
          if (kDebugMode) print('FCM token saved periodically to localStorage');

          // Send to API
          await _sendFCMTokenToAPI(fcmToken);
        }
      } else if (fcmToken != null && fcmToken.startsWith('unsupported')) {
        if (kDebugMode) print('⚠️ Ignoring invalid FCM token: $fcmToken');
      }
    } catch (e) {
      if (kDebugMode) print('Error in periodic FCM token save: $e');
    }
  }

  Future<void> _handleDownload(String url) async {
    try {
      if (kDebugMode) print('📥 Iniciando download: $url');
      
      // Abrir URL de download no app nativo (Safari/Chrome)
      // Isso permite ao iOS/Android gerenciar o download nativamente
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(
          Uri.parse(url),
          mode: LaunchMode.externalApplication,
        );
        
        // Mostrar feedback ao usuário
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('📥 Download iniciado no navegador'),
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro no download: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao iniciar download'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _handleExternalLink(String url) async {
    try {
      // Links para apps específicos
      if (url.contains('tel:')) {
        // Telefone
        await launchUrl(Uri.parse(url));
      } else if (url.contains('mailto:')) {
        // Email
        await launchUrl(Uri.parse(url));
      } else if (url.contains('whatsapp://') || url.contains('wa.me/')) {
        // WhatsApp
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else if (url.contains('instagram.com') || url.contains('facebook.com') || 
                 url.contains('twitter.com') || url.contains('linkedin.com')) {
        // Redes sociais - tentar abrir no app nativo primeiro
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      } else {
        // Outros links externos - abrir no navegador
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao abrir link externo: $e');
    }
  }

  void _showImageContextMenu(String imageUrl) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.download),
                title: const Text('Salvar Imagem'),
                onTap: () {
                  Navigator.pop(context);
                  _handleDownload(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Compartilhar'),
                onTap: () {
                  Navigator.pop(context);
                  _shareUrl(imageUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Abrir no Navegador'),
                onTap: () {
                  Navigator.pop(context);
                  _handleExternalLink(imageUrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLinkContextMenu(String linkUrl) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.open_in_browser),
                title: const Text('Abrir no Navegador'),
                onTap: () {
                  Navigator.pop(context);
                  _handleExternalLink(linkUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.share),
                title: const Text('Compartilhar Link'),
                onTap: () {
                  Navigator.pop(context);
                  _shareUrl(linkUrl);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy),
                title: const Text('Copiar Link'),
                onTap: () {
                  Navigator.pop(context);
                  _copyToClipboard(linkUrl);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _shareUrl(String url) async {
    // Implementar compartilhamento nativo
    try {
      await launchUrl(Uri.parse('https://share.apple.com/share?url=$url'));
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao compartilhar: $e');
    }
  }

  Future<void> _copyToClipboard(String text) async {
    try {
      // Implementar cópia para clipboard
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📋 Link copiado para a área de transferência'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao copiar: $e');
    }
  }

  Future<void> _handleAffirmationShare(String affirmationData) async {
    try {
      if (kDebugMode) print('📋 Processing affirmation share...');
      if (kDebugMode) print('📋 Raw data received: $affirmationData');
      
      // Parse the affirmation data (expecting JSON with blobUrl and text)
      Map<String, dynamic> data = jsonDecode(affirmationData);
      
      // DEBUG: Mostrar TODOS os campos recebidos
      // _addDebugLog('🔍 [DEBUG] TODOS os dados recebidos do Laravel:');
      data.forEach((key, value) {
        // _addDebugLog('🔍 [DEBUG] $key: $value');
      });
      
      String blobUrl = data['blobUrl'] ?? data['imageUrl'] ?? data['image_url'] ?? '';
      String text = data['text'] ?? data['texto'] ?? data['message'] ?? '';
      
      // _addDebugLog('📋 [FINAL] blobUrl extraído: $blobUrl');
      // _addDebugLog('📋 [FINAL] text extraído: $text');
      
      if (blobUrl.isEmpty) {
        if (kDebugMode) print('❌ No blob URL provided, trying to share only text...');
        
        // If no image, just share the text
        if (text.isNotEmpty) {
          await Share.share(
            text,
            subject: 'Afirmação Sentiments',
          );
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📤 Texto compartilhado'),
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
        return;
      }
      
      // Se tem imagem, usar o compartilhamento direto para WhatsApp
      if (kDebugMode) print('📱 Redirecionando para compartilhamento WhatsApp com imagem');
      await _handleShareToWhatsApp({
        'imageUrl': blobUrl,
        'texto': text,
        'fileName': 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png',
      });
      return;
      
    } catch (e) {
      if (kDebugMode) print('❌ Error processing affirmation share: $e');
      if (kDebugMode) print('❌ Stack trace: ${StackTrace.current}');
      
      // Try to share text only as fallback
      try {
        Map<String, dynamic> data = jsonDecode(affirmationData);
        String text = data['text'] ?? '';
        
        if (text.isNotEmpty) {
          // Remove debug info em produção
          if (kDebugMode) {
            String debugInfo = "\n\n[DEBUG] Erro no processamento principal\nErro: $e\nDados originais: ${affirmationData.substring(0, affirmationData.length < 100 ? affirmationData.length : 100)}...";
            await Share.share(
              "$text$debugInfo",
              subject: 'Afirmação Sentiments',
            );
          } else {
            // Em produção, compartilhar apenas o texto limpo
            await Share.share(
              text,
              subject: 'Afirmação Sentiments',
            );
          }
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📤 Texto compartilhado (erro na imagem)'),
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      } catch (fallbackError) {
        if (kDebugMode) print('❌ Fallback sharing also failed: $fallbackError');
      }
      
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao compartilhar afirmação'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _shareAffirmationWithNativeSharing(String imagePath, String text) async {
    try {
      if (kDebugMode) print('📤 Sharing via native system...');
      
      final List<XFile> files = [XFile(imagePath)];
      final file = File(imagePath);
      final fileSize = await file.length();
      
      String shareText = text.isNotEmpty ? text : 'Confira esta afirmação do Sentiments! 🌟';
      
      // Compartilhar com ou sem debug info dependendo do modo
      if (kDebugMode) {
        String debugInfo = "\n\n[DEBUG] Compartilhamento com imagem\nArquivo: ${imagePath.split('/').last}\nTamanho: $fileSize bytes";
        await Share.shareXFiles(
          files,
          text: "$shareText$debugInfo",
          subject: 'Afirmação Sentiments',
        );
      } else {
        // Em produção, compartilhar apenas o texto limpo
        await Share.shareXFiles(
          files,
          text: shareText,
          subject: 'Afirmação Sentiments',
        );
      }
      
      if (kDebugMode) print('✅ Native sharing completed');
      
      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📤 Afirmação compartilhada com sucesso!'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      
    } catch (e) {
      if (kDebugMode) print('❌ Error in native sharing: $e');
      throw e;
    }
  }

  Future<void> _cleanupTempFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        if (kDebugMode) print('🗑️ Temporary file cleaned up: $filePath');
      }
    } catch (e) {
      if (kDebugMode) print('⚠️ Warning: Could not clean up temporary file: $e');
    }
  }

  Future<String?> _detectWhatsAppType() async {
    try {
      // Verificar WhatsApp Business primeiro (menos comum)
      final businessUrl = 'https://wa.me/message/';
      if (await canLaunchUrl(Uri.parse(businessUrl))) {
        return 'business';
      }
      
      // Verificar WhatsApp regular
      final regularUrl = 'whatsapp://';
      if (await canLaunchUrl(Uri.parse(regularUrl))) {
        return 'regular';
      }
      
      // Verificar alternativa web
      final webUrl = 'https://wa.me/';
      if (await canLaunchUrl(Uri.parse(webUrl))) {
        return 'web';
      }
      
      return null;
    } catch (e) {
      // _addDebugLog('⚠️ [WHATSAPP] Erro ao detectar tipo: $e');
      return null;
    }
  }

  Future<Map<String, dynamic>> _handleShareToWhatsAppWithData(Map<String, dynamic> data) async {
    try {
      // _addDebugLog('📱 [WHATSAPP-DATA] Iniciando compartilhamento com dados base64...');
      
      final base64Data = data['base64Data'] as String?;
      final fileName = data['fileName'] as String? ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png';
      final texto = data['texto'] as String? ?? '';
      
      if (base64Data == null || base64Data.isEmpty) {
        // _addDebugLog('❌ [WHATSAPP-DATA] Dados base64 não fornecidos');
        return {'success': false, 'error': 'Dados da imagem não fornecidos'};
      }

      // _addDebugLog('📱 [WHATSAPP-DATA] Dados base64 recebidos: ${base64Data.length} caracteres');
      // _addDebugLog('📱 [WHATSAPP-DATA] Texto: ${texto.substring(0, texto.length < 50 ? texto.length : 50)}...');

      // Decodificar base64 diretamente
      Uint8List? imageBytes;
      try {
        imageBytes = base64Decode(base64Data);
        // _addDebugLog('✅ [WHATSAPP-DATA] Base64 decodificado: ${imageBytes.length} bytes');
      } catch (e) {
        // _addDebugLog('❌ [WHATSAPP-DATA] Erro ao decodificar base64: $e');
        return {'success': false, 'error': 'Falha ao decodificar imagem'};
      }

      // Redimensionar imagem para formato 16:9 mobile
      imageBytes = await _resizeImageTo16x9(imageBytes);

      // Criar arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // _addDebugLog('💾 [WHATSAPP-DATA] Arquivo criado: ${tempFile.path}');
      
      // REMOVIDO: Não salvar na galeria para compartilhamento WhatsApp
      // O objetivo é apenas compartilhar, não salvar

      // Compartilhar com texto separado
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: texto.isNotEmpty ? texto : '🌟 Confira esta frase inspiradora que encontrei no Sentiments App!\n\n✨ Enviado via Sentiments App',
      );
      // _addDebugLog('✅ [WHATSAPP-DATA] Compartilhamento: ${result.status}');
      
      // Limpar arquivo temporário depois de um tempo maior
      Future.delayed(const Duration(seconds: 30), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
          // _addDebugLog('🗑️ [WHATSAPP-DATA] Arquivo temporário limpo após 30s');
        }
      });
      
      return {'success': true, 'message': 'Compartilhamento iniciado'};
    } catch (e) {
      // _addDebugLog('❌ [WHATSAPP-DATA] Erro: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _handleShareToWhatsApp(Map<String, dynamic> data) async {
    try {
      // _addDebugLog('📱 [WHATSAPP] Iniciando compartilhamento no WhatsApp...');
      // _addDebugLog('📱 [WHATSAPP] Dados recebidos: ${data.toString()}');
      
      // Detectar qual WhatsApp está instalado
      final whatsappType = await _detectWhatsAppType();
      // _addDebugLog('📱 [WHATSAPP] Tipo detectado: ${whatsappType ?? "nenhum"}');
      
      // Verificar diferentes possíveis nomes de campos
      final imageUrl = data['imageUrl'] ?? data['image_url'] ?? data['blobUrl'] ?? data['blob_url'] ?? '';
      final fileName = data['fileName'] ?? data['file_name'] ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png';
      final texto = data['texto'] ?? data['text'] ?? data['message'] ?? '';
      
      if (imageUrl == null || imageUrl.isEmpty) {
        // _addDebugLog('❌ [WHATSAPP] URL da imagem não fornecida');
        return {'success': false, 'error': 'URL da imagem não fornecida'};
      }

      // _addDebugLog('📱 [WHATSAPP] Processando imagem: ${imageUrl.substring(0, 50)}...');
      // _addDebugLog('📱 [WHATSAPP] Texto: ${texto.substring(0, texto.length < 50 ? texto.length : 50)}...');

      // Baixar e processar a imagem
      Uint8List? imageBytes;
      if (imageUrl.startsWith('blob:')) {
        imageBytes = await _getBlobImageBytes(imageUrl);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes == null) {
        // _addDebugLog('❌ [WHATSAPP] Falha ao obter bytes da imagem');
        return {'success': false, 'error': 'Falha ao baixar imagem'};
      }

      // Redimensionar imagem para formato 16:9 mobile
      imageBytes = await _resizeImageTo16x9(imageBytes);

      // Criar arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // _addDebugLog('💾 [WHATSAPP] Arquivo temporário criado: ${tempFile.path}');
      
      // REMOVIDO: Não salvar na galeria para compartilhamento WhatsApp
      // O objetivo é apenas compartilhar, não salvar

      // Compartilhar imagem com texto como mensagem
      // _addDebugLog('📤 [WHATSAPP] Compartilhando imagem com texto separado');
      
      // Compartilhar imagem + texto na mensagem
      final result = await Share.shareXFiles(
        [XFile(tempFile.path)],
        text: texto.isNotEmpty ? texto : '🌟 Confira esta frase inspiradora que encontrei no Sentiments App!\n\n✨ Enviado via Sentiments App',
      );
      
      // _addDebugLog('✅ [WHATSAPP] Compartilhamento iniciado com resultado: ${result.status}');
      
      // Limpar arquivo temporário depois de um tempo maior
      Future.delayed(const Duration(seconds: 30), () {
        if (tempFile.existsSync()) {
          tempFile.deleteSync();
          // _addDebugLog('🗑️ [WHATSAPP] Arquivo temporário limpo após 30s');
        }
      });
      
      // Verificar se compartilhamento foi bem sucedido
      if (result.status == ShareResultStatus.success) {
        // _addDebugLog('✅ [WHATSAPP] Compartilhamento confirmado pelo sistema');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Imagem e texto compartilhados com sucesso!'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else if (result.status == ShareResultStatus.dismissed) {
        // _addDebugLog('⚠️ [WHATSAPP] Usuário cancelou o compartilhamento');
      }

      // Limpar arquivo temporário após delay
      Future.delayed(const Duration(seconds: 10), () {
        _cleanupTempFile(tempFile.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('📱 Escolha o WhatsApp no menu de compartilhamento'),
            backgroundColor: Colors.blue,
            duration: Duration(seconds: 3),
          ),
        );
      }

      return {'success': true, 'message': 'Menu de compartilhamento aberto'};
      
    } catch (e) {
      // _addDebugLog('❌ [WHATSAPP] Erro crítico: $e');
      // _addDebugLog('❌ [WHATSAPP] Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao abrir WhatsApp'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Map<String, dynamic>> _handleShareToSocialMedia(Map<String, dynamic> data) async {
    try {
      // _addDebugLog('📤 [SOCIAL] Iniciando compartilhamento social...');
      
      final platform = data['platform'] as String? ?? 'general';
      final imageUrl = data['imageUrl'] as String?;
      final fileName = data['fileName'] as String? ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png';
      final texto = data['texto'] as String? ?? '';
      
      if (imageUrl == null || imageUrl.isEmpty) {
        // _addDebugLog('❌ [SOCIAL] URL da imagem não fornecida');
        return {'success': false, 'error': 'URL da imagem não fornecida'};
      }

      // Baixar e processar a imagem
      Uint8List? imageBytes;
      if (imageUrl.startsWith('blob:')) {
        imageBytes = await _getBlobImageBytes(imageUrl);
      } else {
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          imageBytes = response.bodyBytes;
        }
      }

      if (imageBytes == null) {
        // _addDebugLog('❌ [SOCIAL] Falha ao obter bytes da imagem');
        return {'success': false, 'error': 'Falha ao baixar imagem'};
      }

      // Redimensionar imagem para formato 16:9 mobile
      imageBytes = await _resizeImageTo16x9(imageBytes);

      // Criar arquivo temporário
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      await tempFile.writeAsBytes(imageBytes);

      // _addDebugLog('💾 [SOCIAL] Arquivo temporário criado: ${tempFile.path}');

      // Compartilhar conforme a plataforma usando URLs e Share Plus
      String result = 'opened';
      switch (platform.toLowerCase()) {
        case 'instagram':
          // Instagram Stories não suporta URL scheme confiável, usar share padrão
          await Share.shareXFiles([XFile(tempFile.path)], text: texto);
          break;
        case 'facebook':
          // Facebook: tentar URL primeiro, fallback para share
          try {
            final fbUrl = 'fb://facewebmodal/f?href=${Uri.encodeComponent('https://sentiments.app')}';
            if (await canLaunchUrl(Uri.parse(fbUrl))) {
              await launchUrl(Uri.parse(fbUrl), mode: LaunchMode.externalApplication);
            } else {
              await Share.shareXFiles([XFile(tempFile.path)], text: texto);
            }
          } catch (e) {
            await Share.shareXFiles([XFile(tempFile.path)], text: texto);
          }
          break;
        case 'twitter':
          // Twitter: URL com texto
          try {
            final twitterUrl = 'twitter://post?message=${Uri.encodeComponent(texto)}';
            if (await canLaunchUrl(Uri.parse(twitterUrl))) {
              await launchUrl(Uri.parse(twitterUrl), mode: LaunchMode.externalApplication);
            } else {
              await Share.shareXFiles([XFile(tempFile.path)], text: texto);
            }
          } catch (e) {
            await Share.shareXFiles([XFile(tempFile.path)], text: texto);
          }
          break;
        case 'telegram':
          // Telegram: URL com texto
          try {
            final telegramUrl = 'tg://msg?text=${Uri.encodeComponent(texto)}';
            if (await canLaunchUrl(Uri.parse(telegramUrl))) {
              await launchUrl(Uri.parse(telegramUrl), mode: LaunchMode.externalApplication);
            } else {
              await Share.shareXFiles([XFile(tempFile.path)], text: texto);
            }
          } catch (e) {
            await Share.shareXFiles([XFile(tempFile.path)], text: texto);
          }
          break;
        default:
          // Compartilhamento geral
          await Share.shareXFiles(
            [XFile(tempFile.path)],
            text: texto,
            subject: 'Afirmação Sentiments',
          );
      }

      // _addDebugLog('✅ [SOCIAL] Compartilhamento iniciado para $platform');

      // Limpar arquivo temporário após delay
      Future.delayed(const Duration(seconds: 10), () {
        _cleanupTempFile(tempFile.path);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('📤 ${platform.toUpperCase()} aberto com sucesso!'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
      }

      return {'success': true, 'message': '${platform.toUpperCase()} aberto com sucesso'};
      
    } catch (e) {
      // _addDebugLog('❌ [SOCIAL] Erro crítico: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro ao compartilhar'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<Uint8List?> _getBlobImageBytes(String blobUrl) async {
    try {
      // _addDebugLog('🔄 [BLOB] Convertendo blob para bytes...');
      
      // Primeiro, converter o blob e armazenar globalmente
      final setupCode = '''
        (async function() {
          try {
            console.log('🔄 Convertendo blob:', '$blobUrl');
            const response = await fetch('$blobUrl');
            
            if (!response.ok) {
              console.log('❌ Response não OK:', response.status);
              return false;
            }
            
            const blob = await response.blob();
            console.log('✅ Blob obtido, tamanho:', blob.size);
            
            if (blob.size === 0) {
              console.log('❌ Blob vazio');
              return false;
            }
            
            return new Promise((resolve) => {
              const reader = new FileReader();
              reader.onloadend = () => {
                try {
                  if (reader.result && typeof reader.result === 'string') {
                    const dataUrl = reader.result;
                    if (dataUrl.includes(',')) {
                      const base64 = dataUrl.split(',')[1];
                      console.log('✅ Base64 gerado, tamanho:', base64.length);
                      // Armazenar globalmente
                      window.tempImageData = base64;
                      resolve(true);
                    } else {
                      console.log('❌ DataURL inválido');
                      resolve(false);
                    }
                  } else {
                    console.log('❌ Reader result inválido');
                    resolve(false);
                  }
                } catch (parseError) {
                  console.log('❌ Erro de parse:', parseError);
                  resolve(false);
                }
              };
              reader.onerror = () => {
                console.log('❌ Erro no FileReader');
                resolve(false);
              };
              reader.readAsDataURL(blob);
            });
          } catch (error) {
            console.log('❌ Erro principal:', error);
            return false;
          }
        })();
      ''';
      
      final setupResult = await _webViewController.evaluateJavascript(source: setupCode);
      // _addDebugLog('🔄 [BLOB] Setup resultado: $setupResult');
      
      if (setupResult == true) {
        // Agora recuperar os dados armazenados
        final getDataCode = '''
          (function() {
            const data = window.tempImageData;
            if (data && data.length > 0) {
              console.log('✅ Recuperando dados, tamanho:', data.length);
              // Limpar dados temporários
              delete window.tempImageData;
              return data;
            }
            console.log('❌ Nenhum dado encontrado');
            return null;
          })();
        ''';
        
        final base64Result = await _webViewController.evaluateJavascript(source: getDataCode);
        
        if (base64Result != null && base64Result.toString() != 'null' && base64Result.toString().trim().isNotEmpty) {
          final resultString = base64Result.toString().trim();
          // _addDebugLog('✅ [BLOB] Dados recuperados - tamanho: ${resultString.length}');
          
          try {
            return base64Decode(resultString);
          } catch (decodeError) {
            // _addDebugLog('❌ [BLOB] Erro ao decodificar: $decodeError');
            return null;
          }
        }
      }
      
      // _addDebugLog('❌ [BLOB] Falha na conversão');
      return null;
    } catch (e) {
      // _addDebugLog('❌ [BLOB] Erro na conversão: $e');
      return null;
    }
  }

  Future<void> _changeAppIcon(String iconName) async {
    try {
      if (Platform.isIOS) {
        // iOS implementation
        String? iconPath;
        switch (iconName.toLowerCase()) {
          case 'logo2':
          case 'blue':
            iconPath = 'AppIcon2';
            break;
          case 'logo3':
          case 'green':
            iconPath = 'AppIcon3';
            break;
          case 'logo4':
          case 'yellow':
            iconPath = 'AppIcon4';
            break;
          case 'logo':
          case 'default':
          default:
            iconPath = null; // null = Original icon
            break;
        }

        bool isSupported = await FlutterDynamicIconPlus.supportsAlternateIcons;
        if (isSupported) {
          // VERIFICAR ÍCONE ATUAL ANTES DE TROCAR
          // Isso evita o alerta "You have changed the icon" desnecessário
          String? currentIcon;
          try {
            currentIcon = await FlutterDynamicIconPlus.alternateIconName;
            print('🎨 [IOS-ICON] Ícone atual do sistema: ${currentIcon ?? "default"}');
            print('🎨 [IOS-ICON] Ícone desejado: ${iconPath ?? "default"}');
          } catch (e) {
            print('⚠️ [IOS-ICON] Não foi possível obter ícone atual: $e');
            currentIcon = null;
          }

          // Só trocar se for diferente do atual
          bool needsChange = currentIcon != iconPath;

          if (needsChange) {
            print('🔄 [IOS-ICON] Trocando ícone de "${currentIcon ?? "default"}" para "${iconPath ?? "default"}"');
            await FlutterDynamicIconPlus.setAlternateIconName(iconName: iconPath);

            // Salvar o novo ícone em SharedPreferences
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('app_icon_ios', iconName.toLowerCase());
            print('✅ [IOS-ICON] Ícone trocado e salvo com sucesso');
          } else {
            print('✅ [IOS-ICON] Ícone já está correto, não precisa trocar');
            // Marcar como inicializado mesmo sem trocar
            _iconInitialized = true;

            // Salvar em SharedPreferences para futuras verificações
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('app_icon_ios', iconName.toLowerCase());
          }
        }
      } else if (Platform.isAndroid) {
        // Android implementation - aguardando pesquisa de referência
        await _changeAndroidIcon(iconName);
      }
    } catch (e) {
      // _addDebugLog('❌ Erro ao trocar ícone: $e');
      print('❌ [IOS-ICON] Erro ao trocar ícone: $e');
    }
  }

  Future<void> _changeAndroidIcon(String iconName) async {
    try {
      print('🤖 [ANDROID-ICON] === TROCA DE ÍCONE SOLICITADA ===');
      print('🤖 [ANDROID-ICON] Nome do ícone: $iconName');

      // Verificar se o ícone já foi configurado anteriormente
      final prefs = await SharedPreferences.getInstance();
      String? savedIcon = prefs.getString('app_icon_android');

      if (savedIcon == iconName.toLowerCase()) {
        print('✅ [ANDROID-ICON] Ícone já está correto (${iconName}), pulando troca');
        _currentIcon = iconName.toLowerCase();
        _iconInitialized = true;
        return;
      }

      // Map icon names to activity aliases (formato correto)
      Map<String, String> iconMap = {
        'logo2': '.MainActivityLogo2',
        'blue': '.MainActivityLogo2',
        'logo3': '.MainActivityLogo3',
        'green': '.MainActivityLogo3',
        'logo4': '.MainActivityLogo4',
        'yellow': '.MainActivityLogo4',
        'logo': '.MainActivity',
        'default': '.MainActivity',
        // Adicionar variações comuns
        '2': '.MainActivityLogo2',
        '3': '.MainActivityLogo3',
        '4': '.MainActivityLogo4',
      };

      String targetAlias = iconMap[iconName.toLowerCase()] ?? '.MainActivity';
      print('🤖 [ANDROID-ICON] Mapeado para alias: $targetAlias');

      // Salvar o ícone atual para controle
      _currentIcon = iconName.toLowerCase();
      await prefs.setString('app_icon_android', _currentIcon!);
      print('🤖 [ANDROID-ICON] Ícone atual salvo: $_currentIcon');
      
      // JavaScript to call native Android method
      await _webViewController.evaluateJavascript(source: '''
        console.log('🤖 [JS] Chamando handler changeAndroidIcon com: $targetAlias');
        if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
          window.flutter_inappwebview.callHandler('changeAndroidIcon', '$targetAlias')
            .then(result => console.log('✅ [JS] Resultado:', result))
            .catch(error => console.error('❌ [JS] Erro:', error));
        } else {
          console.error('❌ [JS] Handler não disponível');
        }
      ''');
      
      print('✅ [ANDROID-ICON] Comando JavaScript enviado');
    } catch (e) {
      print('❌ [ANDROID-ICON] Erro: $e');
    }
  }

  Future<Map<String, dynamic>> _handleAndroidIconChange(String aliasName) async {
    try {
      print('🤖 [ANDROID-HANDLER] === INICIANDO TROCA DE ÍCONE ===');
      print('🤖 [ANDROID-HANDLER] Alias recebido: $aliasName');
      
      final packageName = 'com.mycompany.sentiments';
      final targetAlias = '${packageName}${aliasName}';
      
      print('🤖 [ANDROID-HANDLER] Target completo: $targetAlias');
      print('🤖 [ANDROID-HANDLER] Chamando método nativo...');
      
      // Use platform channel to enable/disable activity aliases
      const platform = MethodChannel('app_icon_channel');
      
      try {
        final result = await platform.invokeMethod('changeIcon', {
          'packageName': packageName,
          'currentAlias': targetAlias, // Nome correto do parâmetro
          'aliases': []  // Simplified - let native code handle the logic
        }).timeout(Duration(seconds: 10)); // Mais tempo para completar
        
        print('✅ [ANDROID-HANDLER] Sucesso: $result');
        
        // Pequeno delay para garantir propagação
        await Future.delayed(Duration(milliseconds: 500));
        
        print('✅ [ANDROID-HANDLER] Ícone alterado com sucesso!');
        return {'success': true, 'message': 'Ícone alterado com sucesso'};
      } catch (e) {
        // _addDebugLog('❌ [ANDROID-HANDLER] Erro no platform channel: $e');
        
        // Show error message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('❌ Erro ao alterar ícone'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        return {'success': false, 'error': e.toString()};
      }
    } catch (e) {
      // _addDebugLog('❌ [ANDROID-HANDLER] Erro geral: $e');
      return {'success': false, 'error': e.toString()};
    }
  }


  void _setupTokenRefreshListener() {
    // Listen for token refresh
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      if (kDebugMode) print('FCM Token refreshed: $newToken');

      // Validate token before saving
      if (newToken.startsWith('unsupported')) {
        if (kDebugMode) print('⚠️ Invalid refreshed token, ignoring: $newToken');
        return;
      }

      // Save to localStorage
      try {
        await _webViewController.evaluateJavascript(
          source: "localStorage.setItem('fcm_token', '$newToken')"
        );
        if (kDebugMode) print('Refreshed FCM token saved to localStorage');

        // Send to API if user email is available
        if (_userEmail != null) {
          await _sendFCMTokenToAPI(newToken);
        }
      } catch (e) {
        if (kDebugMode) print('Error handling token refresh: $e');
      }
    });
  }

  void _startMonitoring() async {
    // _addDebugLog('🔍 Monitoramento iniciado');
    // Start monitoring for email in localStorage
    Future.delayed(const Duration(seconds: 2), () {
      if (_isMonitoring) {
        _checkLocalStorage();
      }
    });
  }

  void _checkLocalStorage() async {
    if (!_isMonitoring) return;

    try {
      // Check localStorage for user_email
      final result = await _webViewController.evaluateJavascript(
        source: "localStorage.getItem('user_email')"
      );
      
      if (result != null && result.toString().isNotEmpty && result != 'null') {
        String newEmail = result.toString().replaceAll('"', '');
        
        // Check if this is a different user email
        if (_userEmail != null && _userEmail != newEmail) {
          // _addDebugLog('👤 Usuário mudou: $newEmail');
          await _handleUserChange(newEmail);
        } else if (_userEmail == null) {
          _userEmail = newEmail;
          // _addDebugLog('👤 Email encontrado: $_userEmail');
          await _handleFirebaseAuth();
        }
      }
      
      // Check for app icon changes
      try {
        final iconResult = await _webViewController.evaluateJavascript(
          source: "localStorage.getItem('app_icon')"
        );

        if (iconResult != null && iconResult.toString().isNotEmpty && iconResult != 'null') {
          String newIcon = iconResult.toString().replaceAll('"', '');

          // VERIFICAÇÃO MELHORADA: Só tentar trocar se:
          // 1. É um ícone diferente do que está salvo em memória OU
          // 2. Ainda não foi inicializado (primeira verificação após abrir o app)
          if (_currentIcon != newIcon || !_iconInitialized) {
            print('🎨 [ICON-CHECK] Ícone no localStorage: $newIcon');
            print('🎨 [ICON-CHECK] Ícone em memória: $_currentIcon');
            print('🎨 [ICON-CHECK] Inicializado: $_iconInitialized');

            // Chamar _changeAppIcon que agora verifica internamente se precisa trocar
            await _changeAppIcon(newIcon);
            _currentIcon = newIcon;
            _iconInitialized = true;
          }
        }
      } catch (e) {
        // Silently ignore icon errors
        if (kDebugMode) print('⚠️ [ICON-CHECK] Erro ao verificar ícone: $e');
      }
      
      // Check for affirmation to share
      try {
        final affirmationResult = await _webViewController.evaluateJavascript(
          source: "localStorage.getItem('affirmation_to_share')"
        );
        
        if (affirmationResult != null && affirmationResult.toString().isNotEmpty && affirmationResult != 'null') {
          String rawAffirmationData = affirmationResult.toString();
          if (kDebugMode) print('🎯 Raw localStorage data: $rawAffirmationData');
          
          // Handle both quoted and unquoted JSON strings
          String affirmationData = rawAffirmationData;
          if (rawAffirmationData.startsWith('"') && rawAffirmationData.endsWith('"')) {
            affirmationData = rawAffirmationData.substring(1, rawAffirmationData.length - 1);
            // Unescape any escaped quotes
            affirmationData = affirmationData.replaceAll('\\"', '"');
          }
          
          if (kDebugMode) print('🎯 Processed data to share: ${affirmationData.substring(0, affirmationData.length < 100 ? affirmationData.length : 100)}...');
          
          // Process the affirmation sharing
          await _handleAffirmationShare(affirmationData);
          
          // Clear the localStorage item after processing
          await _webViewController.evaluateJavascript(
            source: "localStorage.removeItem('affirmation_to_share')"
          );
        }
      } catch (e) {
        if (kDebugMode) print('Error checking affirmation: $e');
      }
      
      // Check for WhatsApp share request
      try {
        final whatsappResult = await _webViewController.evaluateJavascript(
          source: "localStorage.getItem('whatsapp_share')"
        );
        
        if (whatsappResult != null && whatsappResult.toString().isNotEmpty && whatsappResult != 'null') {
          String rawData = whatsappResult.toString();
          // _addDebugLog('📱 WhatsApp share detectado via localStorage');
          
          // Handle both quoted and unquoted JSON strings
          String jsonData = rawData;
          if (rawData.startsWith('"') && rawData.endsWith('"')) {
            jsonData = rawData.substring(1, rawData.length - 1);
            jsonData = jsonData.replaceAll('\\"', '"');
          }
          
          final data = jsonDecode(jsonData);
          
          // Verificar se tem base64 ou URL
          if (data['base64Data'] != null) {
            // Usar handler com base64
            await _handleShareToWhatsAppWithData({
              'base64Data': data['base64Data'],
              'texto': data['texto'] ?? data['text'] ?? '',
              'fileName': data['fileName'] ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png',
            });
          } else {
            // Usar handler com URL (fallback)
            await _handleShareToWhatsApp({
              'imageUrl': data['imageUrl'] ?? data['blobUrl'] ?? '',
              'texto': data['texto'] ?? data['text'] ?? '',
              'fileName': data['fileName'] ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png',
            });
          }
          
          // Limpar localStorage
          await _webViewController.evaluateJavascript(
            source: "localStorage.removeItem('whatsapp_share')"
          );
        }
      } catch (e) {
        if (kDebugMode) print('Error checking WhatsApp share: $e');
      }
      
      // Check for pending image save
      try {
        await _checkPendingImageSave();
      } catch (e) {
        if (kDebugMode) print('Error checking pending image save: $e');
      }
      
      // Always continue monitoring for changes
      Future.delayed(const Duration(seconds: 2), () {
        if (_isMonitoring) {
          _checkLocalStorage();
        }
      });
    } catch (e) {
      if (kDebugMode) print('Error checking localStorage: $e');
      // Continue monitoring
      Future.delayed(const Duration(seconds: 2), () {
        if (_isMonitoring) {
          _checkLocalStorage();
        }
      });
    }
  }

  Future<void> _handleFirebaseAuth() async {
    if (_userEmail == null) return;
    
    // Não autenticar emails temporários ou inválidos no Firebase
    if (_userEmail!.contains('temp_user_') || _userEmail == 'lois@lois.com') {
      print('⚠️ [AUTH] Pulando autenticação Firebase para email temporário: $_userEmail');
      return;
    }

    try {
      // Try to sign in first
      UserCredential? userCredential;
      bool isNewUser = false;
      
      try {
        userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _userEmail!,
          password: 'mudar123',
        );
        if (kDebugMode) print('User signed in successfully');
      } catch (e) {
        // If sign in fails, create new user
        if (e is FirebaseAuthException && 
            (e.code == 'user-not-found' || e.code == 'invalid-credential')) {
          if (kDebugMode) print('User not found or invalid credential, creating new user...');
          try {
            userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
              email: _userEmail!,
              password: 'mudar123',
            );
            if (kDebugMode) print('New user created successfully');
            isNewUser = true;
          } catch (createError) {
            if (createError is FirebaseAuthException && createError.code == 'email-already-in-use') {
              if (kDebugMode) print('Email already exists in Firebase, attempting login with retry...');
              // User was created by Laravel, wait and try login with retries
              bool loginSuccess = false;
              for (int attempt = 1; attempt <= 3; attempt++) {
                try {
                  if (kDebugMode) print('Login attempt $attempt/3...');
                  await Future.delayed(Duration(seconds: attempt)); // Increasing delay
                  userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
                    email: _userEmail!,
                    password: 'mudar123',
                  );
                  if (kDebugMode) print('User signed in successfully after creation conflict (attempt $attempt)');
                  loginSuccess = true;
                  break;
                } catch (retryError) {
                  if (kDebugMode) print('Login attempt $attempt failed: ${retryError}');
                  if (attempt == 3) {
                    if (kDebugMode) print('All login attempts failed, throwing error');
                    throw retryError;
                  }
                }
              }
            } else {
              if (kDebugMode) print('Error creating user: ${createError}');
              throw createError;
            }
          }
        } else {
          if (kDebugMode) print('Firebase Auth Error - Code: ${(e as FirebaseAuthException).code}, Message: ${e.message}');
          throw e;
        }
      }

      // If this is a new user, create in API first
      if (isNewUser && userCredential?.user != null) {
        await _createUserInAPI(userCredential!.user!.uid, _userEmail!);
      }
      
      // Always get FCM token after auth (for both login and signup)
      await _getFCMToken();

    } catch (e) {
      if (kDebugMode) print('Firebase Auth Error: $e');
    }
  }

  Future<Map<String, dynamic>> _saveNotificationSchedules(List<dynamic> schedules) async {
    if (_userEmail == null) {
      return {'success': false, 'error': 'Usuário não identificado'};
    }

    try {
      // Get Firebase UID
      String? firebaseUid;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        firebaseUid = currentUser.uid;
      }

      if (firebaseUid == null) {
        return {'success': false, 'error': 'Firebase UID não encontrado'};
      }

      // Format schedules for API - APENAS horários como string
      List<String> formattedSchedules = [];
      for (var schedule in schedules) {
        if (schedule is Map<String, dynamic> && schedule['time'] != null) {
          formattedSchedules.add(schedule['time'].toString());
        } else if (schedule is String) {
          formattedSchedules.add(schedule);
        }
      }

      if (kDebugMode) print('📨 Enviando horários para API: $formattedSchedules');

      final response = await http.post(
        Uri.parse('https://testesentiments.skalacode.com/api/notification-schedules'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'firebase_uid': firebaseUid,
          'email': _userEmail,
          'schedules': formattedSchedules,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('✅ Horários salvos na API: ${data['message']}');
        return {'success': true, 'message': data['message']};
      } else {
        final errorData = jsonDecode(response.body);
        if (kDebugMode) print('❌ Erro ao salvar horários: ${response.statusCode} - $errorData');
        return {'success': false, 'error': errorData['message'] ?? 'Erro desconhecido'};
      }
    } catch (e) {
      if (kDebugMode) print('❌ Erro ao salvar horários de notificação: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<void> _createUserInAPI(String firebaseUid, String email) async {
    try {
      if (kDebugMode) print('Creating user in API with Firebase UID: $firebaseUid');
      
      final response = await http.post(
        Uri.parse('https://testesentiments.skalacode.com/api/users'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'firebase_uid': firebaseUid,
          'name': email.split('@')[0], // Use email prefix as name
        }),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('User created successfully in API: ${data['user']['id']}');
      } else if (response.statusCode == 409) {
        if (kDebugMode) print('User already exists in API');
      } else {
        if (kDebugMode) print('Failed to create user in API: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) print('Error creating user in API: $e');
    }
  }

  Future<void> _getFCMToken() async {
    try {
      // Request permissions first
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      String? fcmToken;
      
      if (Theme.of(context).platform == TargetPlatform.iOS) {
        // Wait for APNS token on physical device
        if (kDebugMode) print('Waiting for APNS token...');
        String? apnsToken;
        
        // Try multiple times to get APNS token
        for (int i = 0; i < 10; i++) {
          try {
            apnsToken = await FirebaseMessaging.instance.getAPNSToken();
            if (apnsToken != null) {
              if (kDebugMode) print('APNS Token obtained: ${apnsToken.substring(0, 20)}...');
              break;
            }
          } catch (e) {
            if (kDebugMode) print('APNS attempt $i failed: $e');
          }
          await Future.delayed(const Duration(seconds: 1));
        }
        
        if (apnsToken == null) {
          if (kDebugMode) print('APNS token not available after retries');
        }
      }
      
      // Delete existing token to force refresh
      await FirebaseMessaging.instance.deleteToken();
      
      // Get new FCM token
      fcmToken = await FirebaseMessaging.instance.getToken();
      if (kDebugMode) print('FCM Token: $fcmToken');

      // Save FCM token to localStorage
      if (fcmToken != null && !fcmToken.startsWith('unsupported')) {
        await _webViewController.evaluateJavascript(
          source: "localStorage.setItem('fcm_token', '$fcmToken')"
        );
        if (kDebugMode) print('FCM token saved to localStorage');

        // Send FCM token to API
        await _sendFCMTokenToAPI(fcmToken);
      } else if (fcmToken != null && fcmToken.startsWith('unsupported')) {
        if (kDebugMode) print('⚠️ Invalid FCM token generated, not saving: $fcmToken');
      }
    } catch (e) {
      if (kDebugMode) print('FCM Token Error: $e');
    }
  }

  Future<void> _sendFCMTokenToAPI(String fcmToken) async {
    // Validate token format - reject invalid tokens
    if (fcmToken.isEmpty || fcmToken.startsWith('unsupported')) {
      if (kDebugMode) print('⚠️ Invalid FCM token format, not sending: $fcmToken');
      return;
    }

    if (_userEmail == null) {
      if (kDebugMode) print('No user email available to send FCM token');
      return;
    }

    try {
      // Get current user's Firebase UID
      String? firebaseUid;
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        firebaseUid = currentUser.uid;
        if (kDebugMode) print('Firebase UID: $firebaseUid');
      } else {
        if (kDebugMode) print('Warning: No Firebase user authenticated');
      }

      final response = await http.post(
        Uri.parse('https://testesentiments.skalacode.com/api/fcm-flutter'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': _userEmail,
          'fcm_token': fcmToken,
          'firebase_uid': firebaseUid ?? '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('FCM token sent successfully: ${data['message']}');
        if (kDebugMode) print('User ID: ${data['user_id']}, Token preview: ${data['token_preview']}');
      } else if (response.statusCode == 404) {
        if (kDebugMode) print('User not found in API, attempting to create...');
        // Try to create user in API and retry FCM token
        if (firebaseUid != null) {
          await _createUserInAPI(firebaseUid, _userEmail!);
          // Retry sending FCM token
          await _sendFCMTokenToAPI(fcmToken);
        }
      } else if (response.statusCode == 422) {
        final data = jsonDecode(response.body);
        if (kDebugMode) print('Validation error: ${data['message']}');
        if (kDebugMode) print('Errors: ${data['errors']}');
      } else {
        if (kDebugMode) print('Failed to send FCM token. Status: ${response.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) print('Error sending FCM token to API: $e');
    }
  }






  void _setupPurchaseHandlers() {
    print('🎯 [MAIN] Configurando IAP JavaScript Handlers...');
    
    // Handler para carregar produtos disponíveis (iOS App Store / Android Google Play)
    _webViewController.addJavaScriptHandler(
      handlerName: 'loadProducts',
      callback: (args) async {
        try {
          print('📦 [HANDLER] loadProducts chamado com args: $args');
          
          List<String> productIds = [];
          if (args.isNotEmpty && args[0] is List) {
            productIds = List<String>.from(args[0]);
          }
          
          final platform = Platform.isIOS ? 'App Store' : 'Google Play Store';
          print('📦 [HANDLER] Carregando produtos da $platform: $productIds');
          await _iapService.loadProducts(productIds);
          
          // Resposta será enviada via callback onProductsLoaded
          return {'success': true, 'message': 'Products loading initiated'};
        } catch (e) {
          print('❌ [HANDLER] Erro loadProducts: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    // Handler para iniciar compra REAL (iOS App Store / Android Google Play)
    _webViewController.addJavaScriptHandler(
      handlerName: 'purchaseProduct',
      callback: (args) async {
        try {
          print('💳 [HANDLER] purchaseProduct chamado com args: $args');

          if (args.isEmpty || args[0] == null) {
            print('❌ [HANDLER] Product ID não fornecido');
            return {'success': false, 'error': 'Product ID required'};
          }

          // Ativar flag de compra para bloquear navegações
          _isPurchasing = true;
          print('🚫 [HANDLER] Flag _isPurchasing ativada - bloqueando navegações automáticas');

          // Configurar timeout de segurança de 30 segundos
          _purchaseTimeoutTimer = Timer(Duration(seconds: 30), () {
            if (_isPurchasing) {
              print('⏱️ [PURCHASE] TIMEOUT - cancelando processamento após 30s');
              _resetPurchaseState(reason: 'timeout after 30 seconds');
            }
          });

          final productId = args[0] as String;
          final platform = Platform.isIOS ? 'App Store' : 'Google Play Store';
          print('💳 [HANDLER] === PURCHASE PRODUCT CHAMADO ===');
          print('💳 [HANDLER] Product ID recebido do JavaScript: "$productId"');
          print('💳 [HANDLER] Plataforma: $platform');
          print('💰 [HANDLER] ⚠️  ATENÇÃO: PAGAMENTO REAL SERÁ PROCESSADO!');

          await _iapService.purchaseProduct(productId);
          
          // Resposta será enviada via callbacks onPurchaseSuccess/onPurchaseError
          final storeMessage = Platform.isIOS ? 'Apple Store will open' : 'Google Play Store will open';
          return {'success': true, 'message': 'Real purchase initiated - $storeMessage'};
        } catch (e) {
          print('❌ [HANDLER] Erro purchaseProduct: $e');
          _resetPurchaseState(reason: 'purchase method exception: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );

    // Handler para compra com oferta promocional (iOS App Store)
    _webViewController.addJavaScriptHandler(
      handlerName: 'purchaseProductWithOffer',
      callback: (args) async {
        try {
          print('💳 [HANDLER] purchaseProductWithOffer chamado com args: $args');

          if (args.isEmpty || args[0] == null) {
            print('❌ [HANDLER] Dados não fornecidos');
            return {'success': false, 'error': 'Data required'};
          }

          final data = args[0] as Map<String, dynamic>;
          final productId = data['productId'] as String;
          final offerData = data['offerData'] as Map<String, dynamic>;

          print('🎁 [HANDLER] === PURCHASE WITH PROMOTIONAL OFFER ===');
          print('🎁 [HANDLER] Product ID: $productId');
          print('🎁 [HANDLER] Offer Code: ${offerData['offerIdentifier']}');

          // Ativar flag de compra
          _isPurchasing = true;
          print('🚫 [HANDLER] Flag _isPurchasing ativada - bloqueando navegações automáticas');

          // Configurar timeout
          _purchaseTimeoutTimer = Timer(Duration(seconds: 30), () {
            if (_isPurchasing) {
              print('⏱️ [PURCHASE] TIMEOUT - cancelando processamento após 30s');
              _resetPurchaseState(reason: 'timeout after 30 seconds');
            }
          });

          if (Platform.isIOS) {
            // iOS: Usar oferta promocional
            await _iapService.purchaseProductWithOffer(
              productId,
              offerData['signature'],
              offerData['nonce'],
              offerData['timestamp'],
              offerData['keyIdentifier'],
              offerData['offerIdentifier']
            );
          } else {
            // Android: Compra normal (não suporta promotional offers da Apple)
            await _iapService.purchaseProduct(productId);
          }

          return {'success': true, 'message': 'Purchase with offer initiated'};
        } catch (e) {
          print('❌ [HANDLER] Erro purchaseProductWithOffer: $e');
          _resetPurchaseState(reason: 'purchase with offer exception: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );

    // Handler para apresentar folha de código promocional (iOS)
    _webViewController.addJavaScriptHandler(
      handlerName: 'presentOfferCodeSheet',
      callback: (args) async {
        try {
          print('🎫 [HANDLER] presentOfferCodeSheet chamado');

          if (!Platform.isIOS) {
            print('❌ [HANDLER] Offer Code Sheet é apenas para iOS');
            return {'success': false, 'error': 'iOS only feature'};
          }

          final data = args.isNotEmpty ? args[0] as Map<String, dynamic> : {};
          final offerCode = data['offerCode'] ?? 'PROMO30';

          print('🎫 [HANDLER] === PRESENT OFFER CODE SHEET ===');
          print('🎫 [HANDLER] Código sugerido: $offerCode');

          // Apresentar folha nativa de resgate de código
          await _iapService.presentCodeRedemptionSheet();

          return {'success': true, 'message': 'Offer code sheet presented'};
        } catch (e) {
          print('❌ [HANDLER] Erro presentOfferCodeSheet: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );

    // Handler para restaurar compras anteriores
    _webViewController.addJavaScriptHandler(
      handlerName: 'restorePurchases',
      callback: (args) async {
        try {
          print('🔄 [HANDLER] ===============================');
          print('🔄 [HANDLER] RESTORE PURCHASES CHAMADO!!!');
          print('🔄 [HANDLER] Usuário clicou no botão de restaurar');
          print('🔄 [HANDLER] ===============================');
          
          await _iapService.restorePurchases();
          
          // Resposta será enviada via callback onRestoreSuccess
          print('✅ [HANDLER] restorePurchases executado com sucesso');
          return {'success': true, 'message': 'Restore initiated'};
        } catch (e) {
          print('❌ [HANDLER] Erro restorePurchases: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    // Handler para debug - listar todos os produtos disponíveis
    _webViewController.addJavaScriptHandler(
      handlerName: 'listProducts',
      callback: (args) async {
        try {
          print('🔍 [HANDLER] listProducts chamado - listando produtos para debug');
          await _iapService.listAllAvailableProducts();
          return {'success': true, 'message': 'Products listed in console'};
        } catch (e) {
          print('❌ [HANDLER] Erro listProducts: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    final platform = Platform.isIOS ? 'iOS (App Store)' : 'Android (Google Play)';
    print('✅ [MAIN] IAP handlers configurados para $platform:');
    print('   📦 loadProducts - Carregar produtos da loja');
    print('   💳 purchaseProduct - Iniciar compra REAL');
    print('   🔄 restorePurchases - Restaurar compras');
    print('   🔍 listProducts - Debug: listar produtos disponíveis');
    print('🎯 [MAIN] Product ID: ${Platform.isIOS ? "com.mycompany.sentiments.premium_yearly" : "premium_yearly"}');
    print('💰 [MAIN] ⚠️  MODO: PAGAMENTO REAL (não simulação)');
  }

  void _setupImageSaveHandlers() {
    // Handler direto para salvar imagem
    _webViewController.addJavaScriptHandler(
      handlerName: 'saveImageToGallery',
      callback: (args) async {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          print('💾 [FLUTTER] saveImageToGallery chamado com dados: ${data.keys.join(', ')}');
          if (data.containsKey('base64Data')) {
            final base64Length = data['base64Data']?.toString().length ?? 0;
            print('💾 [FLUTTER] base64Data recebido com $base64Length caracteres');
          }
          return await _handleSaveImageToGallery(data);
        }
        return {'success': false, 'error': 'No data provided'};
      },
    );

    // Handler para notificar sobre imagens pendentes
    _webViewController.addJavaScriptHandler(
      handlerName: 'notifyPendingImageSave',
      callback: (args) async {
        await _checkPendingImageSave();
        return {'received': true};
      },
    );

    // Handler para compartilhamento direto no WhatsApp
    _webViewController.addJavaScriptHandler(
      handlerName: 'shareToWhatsApp',
      callback: (args) async {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          return await _handleShareToWhatsApp(data);
        }
        return {'success': false, 'error': 'No data provided'};
      },
    );

    // Handler para compartilhamento com dados base64 já convertidos
    _webViewController.addJavaScriptHandler(
      handlerName: 'shareToWhatsAppWithData',
      callback: (args) async {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          print('🎯 [FLUTTER] shareToWhatsAppWithData chamado com dados: ${data.keys.join(', ')}');
          if (data.containsKey('base64Data')) {
            final base64Length = data['base64Data']?.toString().length ?? 0;
            print('🎯 [FLUTTER] base64Data recebido com $base64Length caracteres');
          }
          return await _handleShareToWhatsAppWithData(data);
        }
        return {'success': false, 'error': 'No data provided'};
      },
    );



    // Handler para compartilhamento em redes sociais
    _webViewController.addJavaScriptHandler(
      handlerName: 'shareToSocialMedia',
      callback: (args) async {
        if (args.isNotEmpty) {
          final data = args[0] as Map<String, dynamic>;
          return await _handleShareToSocialMedia(data);
        }
        return {'success': false, 'error': 'No data provided'};
      },
    );

    // Handler específico para Android icon change
    if (Platform.isAndroid) {
      _webViewController.addJavaScriptHandler(
        handlerName: 'changeAndroidIcon',
        callback: (args) async {
          if (args.isNotEmpty) {
            final aliasName = args[0] as String;
            return await _handleAndroidIconChange(aliasName);
          }
          return {'success': false, 'error': 'No alias provided'};
        },
      );
    }

    // Handler para capturar nome do usuário e gerar email
    _webViewController.addJavaScriptHandler(
      handlerName: 'setUserName',
      callback: (args) async {
        try {
          if (args.isNotEmpty) {
            String userName = args[0].toString().trim();
            
            if (userName.isNotEmpty) {
              // Limpar nome: remover espaços, caracteres especiais, minúsculas
              String cleanName = userName
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]'), '') // Remove tudo exceto letras e números
                  .trim();
              
              if (cleanName.isEmpty) cleanName = 'user';
              
              // Gerar email único baseado no nome limpo
              String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
              String generatedEmail = '${cleanName}_$timestamp@sentiments.app';
              
              print('👤 [HANDLER] Nome original: $userName');
              print('🧹 [HANDLER] Nome limpo: $cleanName');
              print('📧 [HANDLER] Email gerado: $generatedEmail');
              
              // Atualizar email do usuário
              _userEmail = generatedEmail;
              
              // Salvar no localStorage
              await _webViewController.evaluateJavascript(
                source: "localStorage.setItem('user_email', '$generatedEmail')"
              );
              
              // Iniciar autenticação Firebase
              await _handleFirebaseAuth();
              
              return {'success': true, 'email': generatedEmail};
            }
          }
          return {'success': false, 'error': 'Nome inválido'};
        } catch (e) {
          print('❌ [HANDLER] Erro setUserName: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    // Handlers para In-App Purchases
    _setupPurchaseHandlers();
    
    // Handlers para capturar logs do JavaScript
    _webViewController.addJavaScriptHandler(
      handlerName: 'webConsoleLog',
      callback: (args) {
        print('🌐 JS LOG: ${args.isNotEmpty ? args[0] : ''}');
        return null;
      },
    );
    
    _webViewController.addJavaScriptHandler(
      handlerName: 'webConsoleError',
      callback: (args) {
        print('🌐 JS ERROR: ${args.isNotEmpty ? args[0] : ''}');
        return null;
      },
    );

    // 🧪 Handler para debug - resetar primeira execução (apenas debug mode)
    _webViewController.addJavaScriptHandler(
      handlerName: 'debugResetFirstRun',
      callback: (args) async {
        await _debugResetFirstRun();
      },
    );
    
    // Handler para limpar cache de usuário
    // 🔐 Handler para salvar dados de autenticação
    _webViewController.addJavaScriptHandler(
      handlerName: 'saveAuthData',
      callback: (args) async {
        try {
          if (args.isNotEmpty) {
            final data = args[0] as Map<String, dynamic>;
            
            // Verificar se não é um usuário temporário
            final email = data['email']?.toString() ?? '';
            if (email.contains('temp_user_') || email.contains('tempuser')) {
              print('❌ [AUTH] Bloqueando salvamento de usuário temporário: $email');
              return {
                'success': false, 
                'error': 'Usuários temporários não podem ser salvos',
                'isTemporary': true
              };
            }
            
            // Salvar token usando AuthService
            if (data['auth_token'] != null || data['token'] != null) {
              final token = data['auth_token'] ?? data['token'];
              await AuthService.saveToken(token.toString());
              debugPrint('[AUTH] Token salvo via WebView');
            }
            
            // Salvar dados do usuário
            final userData = {
              'id': data['user_id'] ?? data['id'],
              'email': data['email'],
              'nome': data['nome'] ?? data['name'],
              'perguntas_completas': data['perguntas_completas'] ?? false,
              'plano_id': data['plano_id'],
              'tema_id': data['tema_id'],
            };
            
            await AuthService.saveUserData(userData);
            
            print('✅ [AUTH] Dados salvos via WebView: ${userData['email']}');
            return {'success': true, 'message': 'Dados salvos com sucesso'};
          }
          return {'success': false, 'error': 'Dados não fornecidos'};
        } catch (e) {
          print('❌ [AUTH] Erro ao salvar dados: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );

    // 🔍 Handler para recuperar dados de autenticação
    _webViewController.addJavaScriptHandler(
      handlerName: 'getAuthData',
      callback: (args) async {
        try {
          final token = await AuthService.getToken();
          final userData = await AuthService.getUserData();

          if (token != null && userData != null) {
            print('✅ [AUTH] Dados recuperados: ${userData['email']}');
            return {
              'user_id': userData['id'],
              'email': userData['email'],
              'auth_token': token,
              'perguntas_completas': userData['perguntas_completas'],
              'plano_id': userData['plano_id'],
              'tema_id': userData['tema_id']
            };
          }
          
          print('ℹ️ [AUTH] Nenhum dado salvo encontrado');
          return null;
        } catch (e) {
          print('❌ [AUTH] Erro ao recuperar dados: $e');
          return null;
        }
      },
    );

    // 🚪 Handler para logout completo
    _webViewController.addJavaScriptHandler(
      handlerName: 'userLogout',
      callback: (args) async {
        try {
          print('🚪 [AUTH] Usuário fazendo logout...');
          
          // Chamar logout do AuthService (invalida token no backend)
          await AuthService.logout();
          
          // Limpar SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.clear();
          
          // Limpar localStorage do WebView
          await _clearOldUserData();
          await _webViewController.clearCache();
          
          // Limpar cookies
          final cookieManager = CookieManager.instance();
          await cookieManager.deleteAllCookies();
          
          print('✅ [AUTH] Logout completo realizado');
          return {'success': true, 'message': 'Logout realizado com sucesso'};
        } catch (e) {
          print('❌ [AUTH] Erro ao fazer logout: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    _webViewController.addJavaScriptHandler(
      handlerName: 'clearUserCache',
      callback: (args) async {
        try {
          print('🧹 [HANDLER] Limpando cache de usuário...');
          await _clearOldUserData();
          return {'success': true, 'message': 'Cache limpo com sucesso'};
        } catch (e) {
          print('❌ [HANDLER] Erro ao limpar cache: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    // Handler para salvar horários de notificação
    _webViewController.addJavaScriptHandler(
      handlerName: 'saveNotificationSchedules',
      callback: (args) async {
        try {
          if (args.isNotEmpty) {
            final schedules = args[0] as List<dynamic>;
            if (kDebugMode) print('⏰ [HANDLER] Salvando horários de notificação: $schedules');
            
            return await _saveNotificationSchedules(schedules);
          }
          return {'success': false, 'error': 'Nenhum horário fornecido'};
        } catch (e) {
          if (kDebugMode) print('❌ [HANDLER] Erro ao salvar horários: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    // Handler para criar usuário com nome e horários (PLANO GRATUITO)
    _webViewController.addJavaScriptHandler(
      handlerName: 'createUserWithSchedules',
      callback: (args) async {
        try {
          if (args.length >= 2) {
            String userName = args[0].toString().trim();
            List<dynamic> schedules = args[1] as List<dynamic>;
            
            if (userName.isNotEmpty) {
              if (kDebugMode) {
                print('👤 [HANDLER] Criando usuário GRATUITO: $userName');
                print('⏰ [HANDLER] Horários: $schedules');
              }
              
              // 1. Criar usuário anônimo no Firebase Auth
              String? firebaseUid;
              try {
                final userCredential = await FirebaseAuth.instance.signInAnonymously();
                firebaseUid = userCredential.user?.uid;
                print('✅ [HANDLER] Firebase UID criado: $firebaseUid');
              } catch (e) {
                print('❌ [HANDLER] Erro ao criar usuário anônimo Firebase: $e');
              }
              
              // 2. Obter FCM Token
              String? fcmToken;
              try {
                fcmToken = await FirebaseMessaging.instance.getToken();
                print('✅ [HANDLER] FCM Token obtido: ${fcmToken?.substring(0, 20)}...');
              } catch (e) {
                print('❌ [HANDLER] Erro ao obter FCM Token: $e');
              }
              
              // 3. Chamar API Laravel para criar usuário
              Map<String, dynamic> laravelResponse = {};
              try {
                final response = await http.post(
                  Uri.parse('https://testesentiments.skalacode.com/api/flutter/create-user'),
                  headers: {'Content-Type': 'application/json'},
                  body: jsonEncode({
                    'nome': userName,
                    'firebase_uid': firebaseUid ?? '',
                    'fcm_token': fcmToken ?? '',
                  }),
                );
                
                if (response.statusCode == 200 || response.statusCode == 201) {
                  laravelResponse = jsonDecode(response.body);
                  print('✅ [HANDLER] Usuário criado no Laravel: ${laravelResponse['email']}');
                  
                  // Atualizar email do usuário com o que veio do Laravel
                  _userEmail = laravelResponse['email'] ?? 'user_${DateTime.now().millisecondsSinceEpoch}@sentiments.app';
                  
                  // Salvar no localStorage
                  await _webViewController.evaluateJavascript(
                    source: "localStorage.setItem('user_email', '$_userEmail')"
                  );
                  
                  // Salvar user_id localmente se retornado
                  if (laravelResponse['user_id'] != null) {
                    await _webViewController.evaluateJavascript(
                      source: "localStorage.setItem('user_id', '${laravelResponse['user_id']}')"
                    );
                  }
                } else {
                  print('❌ [HANDLER] Erro na API Laravel: ${response.statusCode}');
                }
              } catch (e) {
                print('❌ [HANDLER] Erro ao chamar API Laravel: $e');
                // Se Laravel falhar, usar email local
                _userEmail = 'user_${DateTime.now().millisecondsSinceEpoch}@sentiments.app';
              }
              
              // 4. Salvar horários
              final scheduleResult = await _saveNotificationSchedules(schedules);
              
              // 5. Redirecionar para URL do Laravel se fornecido
              if (laravelResponse['redirect_url'] != null) {
                final redirectUrl = 'https://testesentiments.skalacode.com${laravelResponse['redirect_url']}';
                print('🔄 [HANDLER] Redirecionando para: $redirectUrl');
                await _webViewController.loadUrl(
                  urlRequest: URLRequest(url: WebUri(redirectUrl))
                );
              }
              
              return {
                'success': true, 
                'email': _userEmail,
                'schedules': scheduleResult,
                'userId': laravelResponse['user_id'] ?? null
              };
            }
          }
          return {'success': false, 'error': 'Nome e horários são obrigatórios'};
        } catch (e) {
          if (kDebugMode) print('❌ [HANDLER] Erro createUserWithSchedules: $e');
          return {'success': false, 'error': e.toString()};
        }
      },
    );
    
    if (kDebugMode) {
      // _addDebugLog('✅ Handlers de salvamento e compartilhamento configurados');
    }
  }

  /// Limpar dados antigos do usuário (localStorage e variáveis)
  Future<void> _clearOldUserData() async {
    try {
      print('🧹 [CLEAR] Limpando dados antigos do usuário...');
      
      // Limpar email atual
      _userEmail = null;
      
      // Limpar localStorage específico do usuário
      await _webViewController.evaluateJavascript(
        source: '''
          console.log('🧹 Limpando localStorage antigo...');
          localStorage.removeItem('user_email');
          localStorage.removeItem('fcm_token');
          console.log('✅ localStorage limpo');
        '''
      );
      
      // Fazer logout do Firebase se houver usuário autenticado
      if (FirebaseAuth.instance.currentUser != null) {
        await FirebaseAuth.instance.signOut();
        print('🔓 [CLEAR] Firebase logout realizado');
      }
      
      print('✅ [CLEAR] Dados antigos limpos com sucesso');
    } catch (e) {
      print('❌ [CLEAR] Erro ao limpar dados: $e');
    }
  }


  Future<Map<String, dynamic>> _handleSaveImageToGallery(Map<String, dynamic> data) async {
    try {
      // _addDebugLog('📸 [HANDLER] Salvando imagem via handler');
      // _addDebugLog('📸 [HANDLER] Dados recebidos: ${data.keys.join(', ')}');
      
      final imageUrl = data['imageUrl'] as String?;
      final base64Data = data['base64Data'] as String?;
      final fileName = data['fileName'] as String? ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png';
      final texto = data['texto'] as String? ?? '';
      
      bool success = false;
      
      // Priorizar base64 se disponível
      if (base64Data != null && base64Data.isNotEmpty) {
        // _addDebugLog('📸 [HANDLER] Salvando via base64 (${base64Data.length} chars)');
        try {
          final imageBytes = base64Decode(base64Data);
          success = await _saveImageDirectlyToGallery(imageBytes, fileName, texto);
        } catch (e) {
          // _addDebugLog('❌ [HANDLER] Erro ao decodificar base64: $e');
          return {'success': false, 'error': 'Erro ao decodificar base64: $e'};
        }
      } else if (imageUrl != null && imageUrl.isNotEmpty) {
        // _addDebugLog('📸 [HANDLER] Salvando via URL: $imageUrl');
        success = await _saveImageFromUrl(imageUrl, fileName, texto);
      } else {
        // _addDebugLog('❌ [HANDLER] Nem URL nem base64 fornecidos');
        return {'success': false, 'error': 'URL da imagem ou base64 não fornecidos'};
      }
      
      if (success) {
        // _addDebugLog('✅ Imagem processada com sucesso');
        if (mounted) {
          String message = '📸 Imagem salva na galeria com sucesso!';
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 3),
            ),
          );
        }
        String message = 'Imagem salva na galeria com sucesso!';
        return {'success': true, 'message': message};
      } else {
        return {'success': false, 'error': 'Falha ao processar imagem'};
      }
      
    } catch (e) {
      // _addDebugLog('❌ Erro ao salvar imagem: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  Future<bool> _saveImageFromUrl(String imageUrl, String fileName, [String texto = '']) async {
    try {
      // _addDebugLog('🔄 Baixando imagem de: ${imageUrl.substring(0, 50)}...');
      
      if (imageUrl.startsWith('blob:')) {
        // Para blob URLs, usar JavaScript para converter
        return await _saveImageFromBlob(imageUrl, fileName, texto);
      } else {
        // Para URLs HTTP normais
        final response = await http.get(Uri.parse(imageUrl));
        if (response.statusCode == 200) {
          return await _saveImageBytes(response.bodyBytes, fileName, texto);
        }
        return false;
      }
    } catch (e) {
      // _addDebugLog('❌ Erro ao baixar imagem: $e');
      return false;
    }
  }

  Future<bool> _saveImageFromBlob(String blobUrl, String fileName, [String texto = '']) async {
    try {
      // _addDebugLog('🔄 Convertendo blob para base64...');
      
      // Método alternativo - usar callback em vez de Promise
      final jsCode = '''
        (async function() {
          try {
            console.log('🔄 Iniciando conversão blob para base64...');
            const response = await fetch('$blobUrl');
            
            if (!response.ok) {
              console.error('❌ Falha ao buscar blob:', response.status);
              return null;
            }
            
            console.log('✅ Blob obtido, convertendo para base64...');
            const blob = await response.blob();
            
            return new Promise((resolve, reject) => {
              const reader = new FileReader();
              reader.onloadend = function() {
                try {
                  const base64 = reader.result.split(',')[1];
                  console.log('✅ Base64 convertido, tamanho:', base64.length);
                  resolve(base64);
                } catch (error) {
                  console.error('❌ Erro ao processar base64:', error);
                  reject(error);
                }
              };
              reader.onerror = function() {
                console.error('❌ FileReader error:', reader.error);
                reject(reader.error);
              };
              reader.readAsDataURL(blob);
            });
          } catch (error) {
            console.error('❌ Erro geral na conversão:', error);
            return null;
          }
        })();
      ''';
      
      final base64Result = await _webViewController.evaluateJavascript(source: jsCode);
      
      if (base64Result != null && base64Result.toString() != 'null') {
        try {
          // _addDebugLog('✅ Blob convertido para base64, tamanho: ${base64Result.toString().length}');
          final imageBytes = base64Decode(base64Result.toString());
          return await _saveImageBytes(imageBytes, fileName, texto);
        } catch (decodeError) {
          // _addDebugLog('❌ Erro ao decodificar base64: $decodeError');
        }
      }
      
      // _addDebugLog('❌ Falha na conversão blob->base64, tentando método alternativo...');
      
      // Fallback: tentar método mais simples
      try {
        final alternativeJs = '''
          (function() {
            try {
              var xhr = new XMLHttpRequest();
              xhr.open('GET', '$blobUrl', false);
              xhr.overrideMimeType('text/plain; charset=x-user-defined');
              xhr.send();
              
              if (xhr.status === 200) {
                var binary = '';
                for (var i = 0; i < xhr.responseText.length; i++) {
                  binary += String.fromCharCode(xhr.responseText.charCodeAt(i) & 255);
                }
                return btoa(binary);
              }
              return null;
            } catch (error) {
              console.error('Fallback method failed:', error);
              return null;
            }
          })();
        ''';
        
        final alternativeResult = await _webViewController.evaluateJavascript(source: alternativeJs);
        
        if (alternativeResult != null && alternativeResult.toString() != 'null') {
          // _addDebugLog('✅ Método alternativo funcionou!');
          final imageBytes = base64Decode(alternativeResult.toString());
          return await _saveImageBytes(imageBytes, fileName, texto);
        }
      } catch (e) {
        // _addDebugLog('❌ Método alternativo também falhou: $e');
      }
      
      // Último recurso: informar problema
      // _addDebugLog('❌ Todos os métodos falharam - blob não pode ser convertido');
      return false;
      
    } catch (e) {
      // _addDebugLog('❌ Erro crítico ao converter blob: $e');
      // _addDebugLog('❌ Stack: ${StackTrace.current}');
      
      return false;
    }
  }


  Future<Uint8List> _resizeImageTo16x9(Uint8List imageBytes) async {
    try {
      // Verificar se os dados da imagem são válidos
      if (imageBytes.isEmpty) {
        // _addDebugLog('⚠️ [RESIZE] Imagem vazia, retornando original');
        return imageBytes;
      }
      
      // _addDebugLog('🔄 [RESIZE] Iniciando redimensionamento (${imageBytes.length} bytes)...');
      
      // Tentar decodificar a imagem com timeout para evitar travamento
      img.Image? image;
      try {
        image = img.decodeImage(imageBytes);
      } catch (decodeError) {
        // _addDebugLog('❌ [RESIZE] Erro na decodificação: $decodeError');
        return imageBytes;
      }
      
      if (image == null) {
        // _addDebugLog('❌ [RESIZE] Imagem não pôde ser decodificada, retornando original');
        return imageBytes;
      }
      
      // _addDebugLog('✅ [RESIZE] Imagem decodificada: ${image.width}x${image.height}');
      
      // Definir tamanhos ideais para mobile (formato 16:9) - HD mobile
      const targetWidth = 720;   // HD mobile width
      const targetHeight = 1280; // HD mobile height (16:9)
      
      const double targetAspect = targetWidth / targetHeight;
      final double currentAspect = image.width / image.height;
      
      // _addDebugLog('🔍 [RESIZE] Formato atual: ${image.width}x${image.height} (${currentAspect.toStringAsFixed(2)})');
      // _addDebugLog('🎯 [RESIZE] Formato desejado: ${targetWidth}x${targetHeight} (${targetAspect.toStringAsFixed(2)})');
      
      // Sempre redimensionar se não estiver no tamanho exato
      if (image.width == targetWidth && image.height == targetHeight) {
        // _addDebugLog('✅ [RESIZE] Imagem já está no tamanho exato, mantendo original');
        
        
        return imageBytes;
      }
      
      // _addDebugLog('🔄 [RESIZE] Redimensionamento necessário...');
      
      // Realizar redimensionamento
      img.Image resizedImage;
      
      try {
        if (currentAspect > targetAspect) {
          // Imagem mais larga - usar altura como base
          // _addDebugLog('📐 [RESIZE] Imagem mais larga, redimensionando por altura ($targetHeight)');
          resizedImage = img.copyResize(
            image,
            height: targetHeight,
            maintainAspect: true,
          );
        } else {
          // Imagem mais alta - usar largura como base  
          // _addDebugLog('📐 [RESIZE] Imagem mais alta, redimensionando por largura ($targetWidth)');
          resizedImage = img.copyResize(
            image,
            width: targetWidth,
            maintainAspect: true,
          );
        }
        
        // _addDebugLog('✅ [RESIZE] Redimensionamento inicial: ${resizedImage.width}x${resizedImage.height}');
      } catch (resizeError) {
        // _addDebugLog('❌ [RESIZE] Erro no redimensionamento: $resizeError');
        return imageBytes;
      }
      
      // Ajustar para formato exato 16:9 se necessário
      if (resizedImage.width != targetWidth || resizedImage.height != targetHeight) {
        // _addDebugLog('✂️ [RESIZE] Crop necessário de ${resizedImage.width}x${resizedImage.height} para ${targetWidth}x${targetHeight}');
        
        try {
          final int cropX = ((resizedImage.width - targetWidth) / 2).round().clamp(0, resizedImage.width - targetWidth);
          final int cropY = ((resizedImage.height - targetHeight) / 2).round().clamp(0, resizedImage.height - targetHeight);
          
          // _addDebugLog('✂️ [RESIZE] Cortando em X:$cropX, Y:$cropY');
          
          resizedImage = img.copyCrop(
            resizedImage,
            x: cropX,
            y: cropY,
            width: targetWidth.clamp(1, resizedImage.width),
            height: targetHeight.clamp(1, resizedImage.height),
          );
          
          // _addDebugLog('✅ [RESIZE] Crop concluído: ${resizedImage.width}x${resizedImage.height}');
        } catch (cropError) {
          // _addDebugLog('❌ [RESIZE] Erro no crop: $cropError');
          // Continuar com a imagem redimensionada mesmo sem o crop
        }
      } else {
        // _addDebugLog('✅ [RESIZE] Crop não necessário, tamanho já é perfeito!');
      }
      
      // Codificar de volta
      try {
        final resizedBytes = img.encodePng(resizedImage);
        // _addDebugLog('✅ [RESIZE] Codificação concluída: ${imageBytes.length} → ${resizedBytes.length} bytes');
        
        
        return Uint8List.fromList(resizedBytes);
      } catch (encodeError) {
        // _addDebugLog('❌ [RESIZE] Erro na codificação: $encodeError');
        
        
        return imageBytes;
      }
      
    } catch (e, stackTrace) {
      // _addDebugLog('❌ [RESIZE] Erro geral no redimensionamento: $e');
      if (kDebugMode) {
        // _addDebugLog('❌ [RESIZE] Stack trace: $stackTrace');
      }
      return imageBytes; // Retorna original em qualquer erro
    }
  }

  Future<bool> _saveImageBytes(Uint8List imageBytes, String fileName, [String texto = '']) async {
    try {
      // _addDebugLog('💾 [MAIN] Processando salvamento da imagem...');
      // _addDebugLog('💾 [MAIN] Plataforma detectada: ${Platform.isIOS ? "iOS" : "Android"}');
      // _addDebugLog('💾 [MAIN] Arquivo: $fileName (${imageBytes.length} bytes)');
      
      // Redimensionar imagem para formato 16:9 mobile
      final resizedImageBytes = await _resizeImageTo16x9(imageBytes);
      
      // Tentar salvamento direto na galeria primeiro (iOS e Android)
      // _addDebugLog('📱 [MAIN] Tentando salvamento direto na galeria...');
      return await _saveImageDirectlyToGallery(resizedImageBytes, fileName, texto);
    } catch (e) {
      // _addDebugLog('❌ [MAIN] Erro crítico ao processar imagem: $e');
      // _addDebugLog('❌ [MAIN] Stack trace: ${StackTrace.current}');
      return false;
    }
  }

  Future<bool> _saveImageDirectlyToGallery(Uint8List imageBytes, String fileName, [String texto = '']) async {
    try {
      final platform = Platform.isIOS ? "iOS" : "Android";
      // _addDebugLog('📱 [$platform] Iniciando salvamento direto na galeria...');
      // _addDebugLog('📱 [$platform] Arquivo: $fileName (${imageBytes.length} bytes)');
      
      // Criar arquivo temporário primeiro
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');
      // _addDebugLog('📂 [$platform] Caminho do arquivo: ${tempFile.path}');
      
      await tempFile.writeAsBytes(imageBytes);
      // _addDebugLog('📂 [$platform] Arquivo criado com ${imageBytes.length} bytes');
      
      // Verificar se arquivo foi criado corretamente
      final fileExists = await tempFile.exists();
      final fileSize = fileExists ? await tempFile.length() : 0;
      // _addDebugLog('📂 [$platform] Verificação - Existe: $fileExists, Tamanho: $fileSize bytes');
      
      if (!fileExists || fileSize == 0) {
        // _addDebugLog('❌ [$platform] Falha na criação do arquivo temporário');
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Erro ao criar arquivo temporário'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 2),
            ),
          );
        }
        
        return false;
      }
      
      // Para Android 13+ (API 33+), não precisamos solicitar permissão para adicionar à galeria
      // A permissão READ_MEDIA_IMAGES já permite isso via MediaStore API
      if (Platform.isAndroid) {
        // _addDebugLog('🤖 [$platform] Salvando via MediaStore API (Android 13+)...');
        
        try {
          // Tentar salvar diretamente na galeria
          await Gal.putImage(tempFile.path);
          // _addDebugLog('✅ [$platform] Imagem salva via MediaStore com sucesso!');
          
          // Mostrar feedback ao usuário  
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('📸 Imagem salva na galeria com sucesso!'),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Limpar arquivo temporário
          if (await tempFile.exists()) {
            await tempFile.delete();
            // _addDebugLog('🗑️ [$platform] Arquivo temporário removido');
          }
          
          return true;
        } catch (galError) {
          // _addDebugLog('❌ [$platform] Erro do Gal: $galError');
          
          // Mostrar erro - não usar compartilhamento como fallback para salvamento
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Erro ao salvar na galeria'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
          
          // Limpar arquivo temporário
          if (await tempFile.exists()) {
            await tempFile.delete();
            // _addDebugLog('🗑️ [$platform] Arquivo temporário removido após erro');
          }
          
          return false;
        }
      } else {
        // iOS - verificar permissão como antes
        // _addDebugLog('🔐 [$platform] Verificando permissão para iOS...');
        final hasAccess = await Gal.hasAccess();
        // _addDebugLog('🔐 [$platform] Permissão atual: ${hasAccess ? "CONCEDIDA" : "NEGADA"}');
        
        if (!hasAccess) {
          // _addDebugLog('🔐 [$platform] Solicitando permissão para galeria...');
          final accessGranted = await Gal.requestAccess();
          // _addDebugLog('🔐 [$platform] Resultado da solicitação: ${accessGranted ? "CONCEDIDA" : "NEGADA"}');
          
          if (!accessGranted) {
            // _addDebugLog('❌ [$platform] Usuário negou permissão para galeria');
            
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('❌ Permissão negada para salvar na galeria'),
                  backgroundColor: Colors.red,
                  duration: Duration(seconds: 2),
                ),
              );
            }
            
            return false;
          }
        }
        
        // _addDebugLog('💾 [$platform] Chamando Gal.putImage() para iOS...');
        await Gal.putImage(tempFile.path);
        // _addDebugLog('✅ [$platform] Imagem salva na galeria do iOS!');
        
        // Limpar arquivo temporário
        if (await tempFile.exists()) {
          await tempFile.delete();
          // _addDebugLog('🗑️ [$platform] Arquivo temporário removido');
        }
        
        return true;
      }
    } catch (e) {
      final platform = Platform.isIOS ? "iOS" : "Android";
      // _addDebugLog('❌ [$platform] ERRO CRÍTICO no salvamento: $e');
      // _addDebugLog('❌ [$platform] Stack trace: ${StackTrace.current}');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('❌ Erro crítico ao salvar na galeria'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
          ),
        );
      }
      
      return false;
    }
  }


  Future<void> _checkPendingImageSave() async {
    try {
      final result = await _webViewController.evaluateJavascript(
        source: "localStorage.getItem('pending_image_save')"
      );
      
      if (result != null && result.toString().isNotEmpty && result != 'null') {
        String rawData = result.toString();
        // _addDebugLog('📋 Processando imagem pendente');
        
        // LIMPAR IMEDIATAMENTE para evitar loops infinitos
        await _webViewController.evaluateJavascript(
          source: "localStorage.removeItem('pending_image_save')"
        );
        // _addDebugLog('🗑️ localStorage limpo preventivamente para evitar loops');
        
        // Handle both quoted and unquoted JSON strings
        String jsonData = rawData;
        if (rawData.startsWith('"') && rawData.endsWith('"')) {
          jsonData = rawData.substring(1, rawData.length - 1);
          jsonData = jsonData.replaceAll('\\"', '"');
        }
        
        final data = jsonDecode(jsonData);
        
        // Processar imagem independente do status (para compatibilidade)
        final imageUrl = data['imageUrl'] as String?;
        final base64Data = data['base64Data'] as String?;
        final fileName = data['fileName'] as String? ?? 'sentiments_${DateTime.now().millisecondsSinceEpoch}.png';
        final texto = data['texto'] as String? ?? '';
        
        bool success = false;
        
        // Priorizar base64 se disponível
        if (base64Data != null && base64Data.isNotEmpty) {
          // _addDebugLog('🔄 Processando imagem pendente (base64)...');
          try {
            final imageBytes = base64Decode(base64Data);
            success = await _saveImageDirectlyToGallery(imageBytes, fileName, texto);
          } catch (e) {
            // _addDebugLog('❌ Erro ao decodificar base64: $e');
          }
        } else if (imageUrl != null && imageUrl.isNotEmpty) {
          // _addDebugLog('🔄 Processando imagem pendente (URL)...');
          success = await _saveImageFromUrl(imageUrl, fileName, texto);
        } else {
          // _addDebugLog('❌ Nem URL nem base64 fornecidos na imagem pendente');
        }
        
        if (success) {
          // _addDebugLog('✅ Imagem pendente processada com sucesso');
            
          // Mostrar notificação de sucesso
          if (mounted) {
            String message = '📸 Imagem salva na galeria com sucesso!';
              
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(message),
                backgroundColor: Colors.green,
                duration: Duration(seconds: 3),
              ),
            );
          }
        } else {
          // _addDebugLog('❌ Falha ao processar imagem pendente');
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('❌ Erro ao processar imagem'),
                backgroundColor: Colors.red,
                duration: Duration(seconds: 2),
              ),
            );
          }
        }
      }
    } catch (e) {
      // _addDebugLog('❌ Erro ao verificar imagem pendente: $e');
    }
  }

  // 🧪 Método para testar funcionalidade de primeira execução (apenas para debug)
  Future<void> _debugResetFirstRun() async {
    if (kDebugMode) {
      final firstRunManager = FirstRunManager.instance;
      await firstRunManager.resetForTesting();
      await firstRunManager.clearWebViewData(_webViewController);
      
      // Recarregar a página para testar o comportamento
      await _webViewController.reload();
      
      print('🧪 [DEBUG] Primeira execução simulada - dados limpos e página recarregada');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: InAppWebView(
          initialUrlRequest: URLRequest(
            url: WebUri(_currentUrl),
          ),
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            domStorageEnabled: true,
            allowFileAccess: true,
            allowContentAccess: true,
            
            // ⚡ CONFIGURAÇÕES DE REDE - CRÍTICO PARA REQUESTS
            allowUniversalAccessFromFileURLs: true,
            allowFileAccessFromFileURLs: true,
            mixedContentMode: MixedContentMode.MIXED_CONTENT_ALWAYS_ALLOW,
            
            // 🔐 Configurações críticas para manter sessão
            thirdPartyCookiesEnabled: true,
            sharedCookiesEnabled: true,
            clearCache: false,
            clearSessionCache: false,
            incognito: false,
            cacheEnabled: true,
            cacheMode: CacheMode.LOAD_DEFAULT,
            // Zoom desabilitado para comportamento mais nativo
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,
            // Transições mais suaves
            allowsBackForwardNavigationGestures: true,
            allowsInlineMediaPlayback: true,
            mediaPlaybackRequiresUserGesture: false,
            // Performance melhorada
            suppressesIncrementalRendering: false,
            allowsLinkPreview: true,
            // User Agent customizado
            applicationNameForUserAgent: "SentimentsApp/1.0",
            // Background transparente para melhor integração
            transparentBackground: true,
            // Gestos nativos adicionais
            allowsAirPlayForMediaPlayback: true,
            allowsPictureInPictureMediaPlayback: true,
            // Comportamento de scroll mais nativo
            verticalScrollBarEnabled: false,
            horizontalScrollBarEnabled: false,
          ),
          onWebViewCreated: (controller) async {
            _webViewController = controller;
            _setupImageSaveHandlers();
            
            // 🆕 Verificar se é primeira execução do app
            final firstRunManager = FirstRunManager.instance;
            final isFirstRun = await firstRunManager.isFirstRun();
            
            if (isFirstRun) {
              print('🆕 [FIRST_RUN] Primeira execução detectada - limpando dados do WebView');
              
              // Aguardar um momento para o WebView estar totalmente pronto
              await Future.delayed(Duration(milliseconds: 500));
              
              // Limpar todos os dados do WebView para nova instalação
              await firstRunManager.clearWebViewData(controller);
              
              // Marcar primeira execução como concluída
              await firstRunManager.markFirstRunCompleted();
              
              print('✅ [FIRST_RUN] Dados limpos, redirecionando para onboarding');
            } else {
              print('🔄 [RETURNING_USER] Usuário retornando - preservando dados de sessão');
              
              // Aguardar um momento para o WebView carregar
              await Future.delayed(Duration(milliseconds: 500));
              
              // Verificar dados salvos e mostrar debug na tela
              try {
                // Primeiro verificar SharedPreferences
                final prefs = await SharedPreferences.getInstance();
                final savedUserId = prefs.getString('user_id');
                final savedEmail = prefs.getString('email');
                final savedToken = prefs.getString('auth_token');
                
                // DEBUG DIV DESABILITADO EM PRODUÇÃO - evita overlay debug na tela
                // await controller.evaluateJavascript(source: '''
                //   (function() {
                //     const auth = localStorage.getItem('auth_token');
                //     const userData = localStorage.getItem('user_data');
                //     const userEmail = localStorage.getItem('user_email');
                //     // ... debug div code comentado ...
                //   })();
                // ''');
                
              } catch (e) {
                print('⚠️ [DEBUG] Erro ao mostrar debug na tela: $e');
              }
            }
            
            // 🚀 Inicializar IAP Service após WebView estar pronto
            _initializeIAPService();
            
            // 🎯 NÃO chamar handlePremiumFlow aqui para evitar conflito
            // O fluxo premium será gerenciado apenas quando houver restauração de compra
            print('✅ [MAIN] WebView criado, aguardando página carregar...');
          },
          onLoadStart: (controller, url) async {
            print('🌐 WebView começou a carregar: $url');
          },
          onLoadStop: (controller, url) async {
            print('✅ WebView carregou: $url');
            
            // Mark WebView as successfully loaded
            print('✅ WebView completamente carregada');
            
            // 🔑 Sincronizar token com localStorage do JavaScript
            final token = await AuthService.getToken();
            final userData = await AuthService.getUserData();
            
            if (token != null) {
              await controller.evaluateJavascript(source: '''
                localStorage.setItem('auth_token', '$token');
                ${userData?['id'] != null ? "localStorage.setItem('user_id', '${userData!['id']}');" : ""}
                ${userData?['email'] != null ? "localStorage.setItem('user_email', '${userData!['email']}');" : ""}
                console.log('[AUTH] Token sincronizado com localStorage');
              ''');
              debugPrint('[AUTH] Token sincronizado com WebView localStorage');
            }
            
            // Injetar informação do dispositivo
            final deviceDetails = DeviceInfo.getDeviceDetails();
            await controller.evaluateJavascript(source: '''
              window.deviceInfo = ${jsonEncode(deviceDetails)};
              console.log('📱 Device Info injected:', window.deviceInfo);
            ''');
            
            // Interceptar console.log/error do JavaScript
            await controller.evaluateJavascript(source: '''
              // Override console para capturar logs
              const originalLog = console.log;
              const originalError = console.error;
              
              console.log = function(...args) {
                window.flutter_inappwebview?.callHandler('webConsoleLog', args.join(' '));
                originalLog.apply(console, args);
              };
              
              console.error = function(...args) {
                window.flutter_inappwebview?.callHandler('webConsoleError', args.join(' '));
                originalError.apply(console, args);
              };
              
              console.log('🔍 Verificando Flutter handlers...');
              console.log('flutter_inappwebview disponível?', typeof window.flutter_inappwebview !== 'undefined');
              console.log('callHandler disponível?', typeof window.flutter_inappwebview?.callHandler === 'function');
              
              if (window.flutter_inappwebview && window.flutter_inappwebview.callHandler) {
                console.log('✅ Flutter handlers estão disponíveis!');
              } else {
                console.error('❌ Flutter handlers NÃO estão disponíveis!');
              }
              
              // Interceptar fetch para debug
              const originalFetch = window.fetch;
              window.fetch = function(...args) {
                console.log('🌐 FETCH REQUEST:', args[0], args[1] ? JSON.stringify(args[1]) : '');
                return originalFetch.apply(this, args)
                  .then(response => {
                    console.log('✅ FETCH SUCCESS:', args[0], response.status);
                    return response;
                  })
                  .catch(error => {
                    console.error('❌ FETCH ERROR:', args[0], error.message);
                    throw error;
                  });
              };
            ''');
            
            _checkLocalStorage();
          },
          onProgressChanged: (controller, progress) {
            // Progresso suave sem indicadores visuais intrusivos
            if (progress == 100) {
              // Página totalmente carregada
            }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            var url = navigationAction.request.url.toString();

            // 🔑 ADICIONAR TOKEN EM NAVEGAÇÕES INTERNAS
            if (url.contains('sentiments.skalacode.com') && !url.contains('token=')) {
              final urlWithToken = await AuthService.getUrlWithToken(url);
              if (urlWithToken != url) {
                debugPrint('[AUTH] Adicionando token à navegação: $url');
                await controller.loadUrl(
                  urlRequest: URLRequest(url: WebUri(urlWithToken))
                );
                return NavigationActionPolicy.CANCEL;
              }
            }
            
            // 🚫 BLOQUEAR NAVEGAÇÃO DURANTE COMPRAS
            if (_isPurchasing) {
              // Permitir navegação para premium-login E dashboard (autenticação após compra)
              if (url.contains('/premium-login') || url.contains('/dashboard')) {
                print('✅ [NAVIGATION] Permitindo navegação pós-compra: $url');
                return NavigationActionPolicy.ALLOW;
              }
              
              // Bloquear outras navegações problemáticas
              print('🚫 [NAVIGATION] Navegação bloqueada durante compra: $url');
              return NavigationActionPolicy.CANCEL;
            }
            
            // Interceptar URLs blob que são imagens geradas
            if (url.startsWith('blob:') && url.contains('sentiments.skalacode.com')) {
              // _addDebugLog('🚫 [INTERCEPT] URL blob interceptada: ${url.substring(0, 80)}...');
              // _addDebugLog('🚫 [INTERCEPT] Cancelando navegação - imagem deve ser salva via handler');
              
              // Tentar chamar o JavaScript para verificar handlers disponíveis
              try {
                final handlerTest = await _webViewController.evaluateJavascript(
                  source: "typeof window.flutter_inappwebview !== 'undefined' ? 'handlers_available' : 'handlers_missing'"
                );
                // _addDebugLog('🧪 [TEST] Handlers Flutter disponíveis: $handlerTest');
                
                // Verificar se saveImageToGallery está disponível
                final handlerCheck = await _webViewController.evaluateJavascript(
                  source: "typeof window.flutter_inappwebview.callHandler !== 'undefined' ? 'callHandler_available' : 'callHandler_missing'"
                );
                // _addDebugLog('🧪 [TEST] callHandler disponível: $handlerCheck');
              } catch (e) {
                // _addDebugLog('❌ [TEST] Erro ao testar handlers: $e');
              }
              
              // Verificar se há imagem pendente no localStorage
              await _checkPendingImageSave();
              
              return NavigationActionPolicy.CANCEL;
            }
            
            // Links especiais (telefone, email, etc.)
            if (url.startsWith('tel:') || url.startsWith('mailto:') || 
                url.contains('whatsapp://') || url.contains('wa.me/')) {
              await _handleExternalLink(url);
              return NavigationActionPolicy.CANCEL;
            }
            
            // Detectar downloads de arquivos
            if (url.contains('download') || 
                url.endsWith('.pdf') || url.endsWith('.jpg') || url.endsWith('.jpeg') || 
                url.endsWith('.png') || url.endsWith('.gif') || url.endsWith('.zip') || 
                url.endsWith('.doc') || url.endsWith('.docx') || url.endsWith('.xls') || 
                url.endsWith('.xlsx') || url.endsWith('.mp4') || url.endsWith('.mp3')) {
              
              await _handleDownload(url);
              return NavigationActionPolicy.CANCEL;
            }
            
            // Links externos (fora do domínio do app)
            if (!url.contains('sentiments.skalacode.com') && 
                (url.startsWith('http://') || url.startsWith('https://'))) {
              await _handleExternalLink(url);
              return NavigationActionPolicy.CANCEL;
            }
            
            // Permitir navegação normal para URLs do app
            return NavigationActionPolicy.ALLOW;
          },
          onLongPressHitTestResult: (controller, hitTestResult) async {
            // Context menu nativo para imagens e links
            if (hitTestResult.type == InAppWebViewHitTestResultType.SRC_IMAGE_ANCHOR_TYPE ||
                hitTestResult.type == InAppWebViewHitTestResultType.IMAGE_TYPE) {
              
              final imageUrl = hitTestResult.extra;
              if (imageUrl != null) {  
                // Mostrar opções nativas para imagem
                _showImageContextMenu(imageUrl);
              }
            } else if (hitTestResult.type == InAppWebViewHitTestResultType.SRC_ANCHOR_TYPE) {
              final linkUrl = hitTestResult.extra;
              if (linkUrl != null) {
                // Mostrar opções nativas para link
                _showLinkContextMenu(linkUrl);
              }
            }
          },
          onCreateWindow: (controller, createWindowAction) async {
            // Abrir novas janelas no navegador nativo (pop-ups, target="_blank")
            final url = createWindowAction.request.url.toString();
            if (await canLaunchUrl(Uri.parse(url))) {
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
            }
            return false;
          },
          onReceivedError: (controller, request, error) async {
            print('❌ WebView erro: ${error.description}');
            
            // 🛡️ IGNORAR ERROS DE REDIRECIONAMENTO
            // -999 = request cancelled (múltiplos loadUrl)
            // -1007 = too many redirects
            if (error.type == WebResourceErrorType.CANCELLED || 
                error.description?.contains('-999') == true ||
                error.description?.contains('-1007') == true ||
                error.description?.contains('cancelled') == true ||
                error.description?.contains('redirect') == true) {
              print('⚠️ [MAIN] Erro de redirecionamento ignorado: ${error.description}');
              return; // NÃO recarregar quando for erro de redirecionamento
            }
            
            // Se for erro real (não relacionado a redirect), tentar recarregar UMA vez
            if (request.url.toString().contains('sentiments.skalacode.com')) {
              // Apenas recarregar se for erro de conexão real
              if (error.description?.contains('connection') == true ||
                  error.description?.contains('network') == true ||
                  error.description?.contains('internet') == true) {
                print('🔄 Erro de conexão - tentando recarregar...');
                await Future.delayed(Duration(seconds: 2));
                await controller.reload();
              }
            }
          },
          onReceivedHttpError: (controller, request, errorResponse) async {
            print('❌ WebView HTTP erro: ${errorResponse.statusCode}');
          },
        ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isMonitoring = false;
    _tokenSaveTimer?.cancel();
    _purchaseTimeoutTimer?.cancel(); // Limpar timer de timeout de compra
    super.dispose();
  }
}