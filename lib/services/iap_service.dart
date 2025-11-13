import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_storekit/in_app_purchase_storekit.dart';
import 'package:in_app_purchase_storekit/store_kit_wrappers.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
import 'package:in_app_purchase_android/billing_client_wrappers.dart';

/// Serviço profissional para gerenciar In-App Purchases
/// Suporta pagamentos REAIS e sandbox da Apple Store
class IAPService {
  static final IAPService _instance = IAPService._internal();
  factory IAPService() => _instance;
  IAPService._internal();

  // Plugin principal do In-App Purchase
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  
  // Estado do serviço
  bool _isInitialized = false;
  bool _storeAvailable = false;
  
  // Callbacks para comunicação com WebView
  Function(Map<String, dynamic>)? onPurchaseSuccess;
  Function(Map<String, dynamic>)? onPurchaseError;
  Function(List<Map<String, dynamic>>)? onProductsLoaded;
  Function(List<Map<String, dynamic>>)? onRestoreSuccess;
  Function(String)? onDebugLog;
  
  // Product IDs configurados no App Store Connect e Google Play Console
  static const String PREMIUM_YEARLY_IOS = 'com.mycompany.sentiments.premium_yearly'; // iOS usa formato completo
  static const String PREMIUM_YEARLY_ANDROID = 'premium_yearly'; // Android usa formato simples

  // Produto com desconto de 26% (oferta especial)
  static const String PREMIUM_YEARLY26_IOS = 'com.mycompany.sentiments.premium_yearly26'; // iOS usa formato completo
  static const String PREMIUM_YEARLY26_ANDROID = 'promo26'; // Android usa formato simples (ID básico)

  // Trial product (opcional)
  static const String PREMIUM_TRIAL = 'premium_yearly'; // Para Android, apenas o ID simples
  
  /// Normaliza qualquer variação de product ID para o formato correto da plataforma
  static String normalizeProductId(String inputId) {
    // Lista de todas as possíveis variações que o JavaScript pode enviar
    final premiumVariations = [
      'com.mycompany.sentiments.premium_yearly',
      'premium_yearly',
      'yearly',
      'PREMIUM_YEARLY',
      'Premium_Yearly',
      'com.mycompany.sentiments.premium_yearly:yearly',
      'sentiments.premium_yearly',
      'premium.yearly',
    ];

    // Variações para o produto com 26% de desconto
    final premium26Variations = [
      'com.mycompany.sentiments.premium_yearly26',
      'premium_yearly26',
      'promo26',
      'PROMO26',
      'premium26',
      'com.mycompany.sentiments.premium26',
    ];

    String normalizedInput = inputId.toLowerCase().trim();

    // Verificar se é o produto com desconto de 26%
    bool isPremium26 = premium26Variations.any((variation) =>
        normalizedInput == variation.toLowerCase() ||
        normalizedInput.contains('premium') && normalizedInput.contains('26') ||
        normalizedInput.contains('promo') && normalizedInput.contains('26')
    );

    if (isPremium26) {
      // Retornar formato correto para a plataforma atual
      return Platform.isIOS ? PREMIUM_YEARLY26_IOS : PREMIUM_YEARLY26_ANDROID;
    }

    // Verificar se é alguma variação do premium yearly normal
    bool isPremiumYearly = premiumVariations.any((variation) =>
        normalizedInput == variation.toLowerCase() ||
        (normalizedInput.contains('premium') && normalizedInput.contains('yearly') && !normalizedInput.contains('26')) ||
        (normalizedInput.contains('premium') && normalizedInput.contains('annual') && !normalizedInput.contains('26'))
    );

    if (isPremiumYearly) {
      // Retornar formato correto para a plataforma atual
      return Platform.isIOS ? PREMIUM_YEARLY_IOS : PREMIUM_YEARLY_ANDROID;
    }

    // Se não reconhecer, retornar o formato da plataforma atual
    print('⚠️ [IAP] Product ID não reconhecido: $inputId, usando default da plataforma');
    return Platform.isIOS ? PREMIUM_YEARLY_IOS : PREMIUM_YEARLY_ANDROID;
  }
  
  /// Inicializar o serviço de In-App Purchase
  Future<bool> initialize() async {
    if (_isInitialized) return _storeAvailable;
    
    try {
      print('🚀 [IAP] Inicializando In-App Purchase Service...');
      print('📱 [IAP] Plataforma: ${Platform.isAndroid ? "Android" : "iOS"}');
      onDebugLog?.call('🚀 Inicializando IAP - ${Platform.isAndroid ? "Android" : "iOS"}');
      
      // Verificar se a loja está disponível
      _storeAvailable = await _inAppPurchase.isAvailable();
      
      if (!_storeAvailable) {
        print('❌ [IAP] App Store não disponível');
        onDebugLog?.call('❌ Store não disponível');
        _callErrorCallback({
          'code': 'store_not_available',
          'message': 'App Store não está disponível'
        });
        return false;
      }
      
      print('✅ [IAP] App Store disponível');
      onDebugLog?.call('✅ Store disponível');
      
      // Configurar listener para mudanças de compra
      _subscription = _inAppPurchase.purchaseStream.listen(
        _handlePurchaseUpdate,
        onDone: () => _subscription.cancel(),
        onError: (error) {
          print('❌ [IAP] Erro no stream de compras: $error');
          _callErrorCallback({
            'code': 'purchase_stream_error',
            'message': error.toString()
          });
        },
      );
      
      // Configurações específicas por plataforma
      if (Platform.isIOS) {
        final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
            _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();
        await iosPlatformAddition.setDelegate(IAPPaymentQueueDelegate());
        print('🍎 [IAP] Configurações iOS aplicadas');
      } else if (Platform.isAndroid) {
        print('🤖 [IAP] Plataforma Android detectada');
        
        // Configurar Google Play Billing
        print('🤖 [IAP] Google Play Billing configurado automaticamente');
        onDebugLog?.call('🤖 Google Play Billing ativo');
        
        // O plugin gerencia automaticamente as compras pendentes para Android
      }
      
      _isInitialized = true;
      print('✅ [IAP] Serviço inicializado com sucesso');
      return true;
      
    } catch (e) {
      print('❌ [IAP] Erro na inicialização: $e');
      _callErrorCallback({
        'code': 'initialization_failed',
        'message': 'Falha na inicialização: $e'
      });
      return false;
    }
  }
  
  /// Carregar produtos disponíveis da App Store
  Future<void> loadProducts([List<String>? productIds]) async {
    if (!_storeAvailable) {
      await initialize();
    }
    
    try {
      print('📦 [IAP] Carregando produtos...');
      
      // Usar IDs específicos por plataforma
      List<String> ids;
      if (productIds != null) {
        // Normalizar todos os product IDs recebidos
        ids = productIds.map((id) {
          String normalizedId = normalizeProductId(id);
          if (id != normalizedId) {
            print('🔄 [IAP] loadProducts: "$id" → "$normalizedId"');
            onDebugLog?.call('🔄 Normalizando: $id → $normalizedId');
          }
          return normalizedId;
        }).toList();
      } else {
        // IDs específicos por plataforma
        if (Platform.isAndroid) {
          ids = [PREMIUM_YEARLY_ANDROID]; // Formato simples para Android
        } else {
          ids = [PREMIUM_YEARLY_IOS]; // Formato completo para iOS
        }
      }
      
      print('📦 [IAP] Platform: ${Platform.isAndroid ? "Android" : "iOS"}');
      print('📦 [IAP] Tentando carregar Product IDs: $ids');
      print('📦 [IAP] Package name: com.mycompany.sentiments');
      
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails(ids.toSet());
      
      if (response.error != null) {
        print('❌ [IAP] Erro ao carregar produtos: ${response.error}');
        _callErrorCallback({
          'code': 'products_load_failed',
          'message': response.error!.message
        });
        return;
      }
      
      if (response.notFoundIDs.isNotEmpty) {
        print('⚠️ [IAP] Produtos NÃO encontrados: ${response.notFoundIDs}');
        print('⚠️ [IAP] Verifique no Google Play Console:');
        print('   1. O produto está ATIVO?');
        print('   2. O app foi publicado no teste interno?');
        print('   3. Você está testando com conta de testador?');
        print('   4. Já esperou 30+ minutos após criar o produto?');
        onDebugLog?.call('❌ IDs não encontrados: ${response.notFoundIDs.join(", ")}');
      }
      
      if (response.productDetails.isEmpty) {
        print('⚠️ [IAP] Nenhum produto disponível');
        print('⚠️ [IAP] Todos os IDs testados falharam');
        _callErrorCallback({
          'code': 'no_products_available',
          'message': 'Nenhum produto encontrado. IDs testados: ${ids.join(", ")}'
        });
        return;
      }
      
      // Converter produtos para formato JavaScript
      final productsData = response.productDetails.map((product) => {
        'id': product.id,
        'title': product.title,
        'description': product.description,
        'price': product.price,
        'rawPrice': product.rawPrice,
        'currencyCode': product.currencyCode,
        'currencySymbol': product.currencySymbol,
      }).toList();
      
      print('✅ [IAP] ${response.productDetails.length} produtos carregados com sucesso!');
      print('✅ [IAP] IDs encontrados:');
      for (var product in response.productDetails) {
        print('   📋 ${product.id}: ${product.title} - ${product.price}');
      }
      
      // Notificar WebView
      onProductsLoaded?.call(productsData);
      
    } catch (e) {
      print('❌ [IAP] Erro ao carregar produtos: $e');
      _callErrorCallback({
        'code': 'products_load_exception',
        'message': e.toString()
      });
    }
  }
  
  /// Listar todos os produtos disponíveis para debug
  Future<void> listAllAvailableProducts() async {
    print('🔍 [IAP] === LISTANDO TODOS OS PRODUTOS DISPONÍVEIS ===');
    
    // Lista de possíveis IDs para testar
    List<String> possibleIds = [
      'com.mycompany.sentiments.premium_yearly',
      'premium_yearly',
      'yearly',
      'premium.yearly',
      'sentiments_premium_yearly',
      'sentiments.premium.yearly',
      'premium_annual',
      'annual',
    ];
    
    for (String testId in possibleIds) {
      try {
        final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({testId});
        if (response.productDetails.isNotEmpty) {
          final product = response.productDetails.first;
          print('✅ [IAP] PRODUTO ENCONTRADO: ${product.id} - ${product.title} - ${product.price}');
        } else {
          print('❌ [IAP] Produto não encontrado: $testId');
        }
      } catch (e) {
        print('⚠️ [IAP] Erro testando $testId: $e');
      }
    }
    print('🔍 [IAP] === FIM DA LISTAGEM DE PRODUTOS ===');
  }

  /// Iniciar compra com oferta promocional (iOS apenas)
  Future<void> purchaseProductWithOffer(
    String productId,
    String signature,
    String nonce,
    int timestamp,
    String keyIdentifier,
    String offerIdentifier,
  ) async {
    print('🎁 [IAP] purchaseProductWithOffer chamado');
    print('🎁 [IAP] Product ID: $productId');
    print('🎁 [IAP] Offer ID: $offerIdentifier');

    if (!Platform.isIOS) {
      print('❌ [IAP] Promotional offers são apenas para iOS');
      await purchaseProduct(productId);
      return;
    }

    if (!_storeAvailable) {
      await initialize();
    }

    try {
      // Normalizar product ID
      String actualProductId = normalizeProductId(productId);

      // Carregar detalhes do produto
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({actualProductId});

      if (response.productDetails.isEmpty) {
        print('❌ [IAP] Produto não encontrado: $actualProductId');
        _callErrorCallback({
          'code': 'product_not_found',
          'message': 'Produto não encontrado: $actualProductId'
        });
        return;
      }

      final ProductDetails productDetails = response.productDetails.first;
      print('💳 [IAP] Produto encontrado: ${productDetails.title}');

      // Criar wrapper do desconto promocional
      // IMPORTANTE: timestamp precisa ser em SEGUNDOS, não milissegundos
      final discount = SKPaymentDiscountWrapper(
        identifier: offerIdentifier,
        keyIdentifier: keyIdentifier,
        nonce: nonce.toString(),
        signature: signature,
        timestamp: timestamp ~/ 1000, // Converter de milissegundos para segundos
      );

      print('🎁 [IAP] Aplicando oferta promocional...');
      print('📝 [IAP] Discount Details:');
      print('  - Identifier: $offerIdentifier');
      print('  - Key ID: $keyIdentifier');
      print('  - Nonce: $nonce');
      print('  - Timestamp (seconds): ${timestamp ~/ 1000}');
      print('  - Signature length: ${signature.length} chars');

      // Criar parâmetros de compra com desconto para iOS
      final PurchaseParam purchaseParam = AppStorePurchaseParam(
        productDetails: productDetails,
        applicationUserName: null,
        discount: discount, // Adicionar o desconto aqui
      );

      // Iniciar compra com desconto
      print('💳 [IAP] Abrindo Apple Store com oferta promocional...');
      await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);

      print('✅ [IAP] Compra com oferta iniciada - aguardando resposta da Apple Store');
      onDebugLog?.call('🎁 Oferta promocional aplicada!');

    } catch (e) {
      print('❌ [IAP] Erro ao iniciar compra com oferta: $e');
      _callErrorCallback({
        'code': 'promotional_offer_failed',
        'message': 'Falha ao aplicar oferta promocional: $e'
      });
    }
  }

  /// Iniciar compra de um produto específico
  Future<void> purchaseProduct(String productId) async {
    print('🛒 [IAP] purchaseProduct chamado para: $productId');
    onDebugLog?.call('🛒 Iniciando compra: $productId');

    // Remover listagem desnecessária que deixa o processo lento
    // await listAllAvailableProducts();
    
    if (!_storeAvailable) {
      print('🔄 [IAP] Store não disponível, inicializando...');
      onDebugLog?.call('🔄 Store não disponível, inicializando...');
      await initialize();
    }
    
    if (!_storeAvailable) {
      print('❌ [IAP] Store ainda não disponível após inicialização');
      onDebugLog?.call('❌ Store não disponível após inicialização');
      _callErrorCallback({
        'code': 'store_not_available',
        'message': 'Loja não está disponível'
      });
      return;
    }
    
    try {
      print('💳 [IAP] Iniciando compra: $productId');
      onDebugLog?.call('💳 Buscando produto: $productId');
      
      // Normalizar product ID para formato correto da plataforma
      String actualProductId = normalizeProductId(productId);
      if (productId != actualProductId) {
        print('🔄 [IAP] purchaseProduct: "$productId" → "$actualProductId"');
        onDebugLog?.call('🔄 ID normalizado: $productId → $actualProductId');
      }
      
      // Carregar detalhes do produto
      final ProductDetailsResponse response = await _inAppPurchase.queryProductDetails({actualProductId});
      
      if (response.productDetails.isEmpty) {
        print('❌ [IAP] Produto não encontrado: $actualProductId (original: $productId)');
        print('🔍 [IAP] Tentando variações alternativas...');
        onDebugLog?.call('❌ PRODUTO NÃO ENCONTRADO: $actualProductId');
        
        // Tentar variações alternativas se o produto principal não for encontrado
        List<String> alternativeIds = [
          'com.mycompany.sentiments.premium_yearly', // iOS format
          'premium_yearly', // Android format
          'yearly', // Simple format
          'premium.yearly', // Dot format
          'sentiments_premium_yearly', // Underscore format
        ].where((id) => id != actualProductId).toList(); // Remove o que já tentamos
        
        print('🔍 [IAP] Tentando IDs alternativos: $alternativeIds');
        
        for (String altId in alternativeIds) {
          print('🔍 [IAP] Testando produto: $altId');
          final ProductDetailsResponse altResponse = await _inAppPurchase.queryProductDetails({altId});
          
          if (altResponse.productDetails.isNotEmpty) {
            print('✅ [IAP] Produto encontrado com ID alternativo: $altId');
            onDebugLog?.call('✅ ENCONTRADO COM ID: $altId');
            
            // Usar este produto encontrado
            final ProductDetails productDetails = altResponse.productDetails.first;
            print('💳 [IAP] Produto encontrado: ${productDetails.title} - ${productDetails.price}');
            onDebugLog?.call('✅ Produto encontrado: ${productDetails.title}');
            
            // Configurar parâmetros da compra com o produto encontrado
            final PurchaseParam purchaseParam = PurchaseParam(
              productDetails: productDetails,
              applicationUserName: null, // Opcional: ID do usuário
            );
            
            // Continuar com a compra
            print('🛒 [IAP] Iniciando compra: ${productDetails.id}');
            onDebugLog?.call('🛒 Iniciando compra...');
            
            bool success = await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
            if (!success) {
              print('❌ [IAP] buyNonConsumable retornou false');
              onDebugLog?.call('❌ Falha na compra');
              _callErrorCallback({
                'code': 'purchase_failed',
                'message': 'Falha ao iniciar compra na loja'
              });
            }
            return; // Sair da função após encontrar e tentar comprar
          }
        }
        
        // Se nenhuma variação funcionou
        print('❌ [IAP] Nenhum produto encontrado com todas as variações testadas');
        _callErrorCallback({
          'code': 'product_not_found',
          'message': 'Produto não encontrado: $actualProductId (testamos todas as variações)'
        });
        return;
      }
      
      final ProductDetails productDetails = response.productDetails.first;
      print('💳 [IAP] Produto encontrado: ${productDetails.title} - ${productDetails.price}');
      onDebugLog?.call('✅ Produto encontrado: ${productDetails.title}');
      
      // Configurar parâmetros da compra
      final PurchaseParam purchaseParam = PurchaseParam(
        productDetails: productDetails,
        applicationUserName: null, // Opcional: ID do usuário
      );
      
      // Iniciar compra
      final String storeName = Platform.isIOS ? 'Apple Store' : 'Google Play Store';
      print('💳 [IAP] Abrindo $storeName para pagamento...');
      onDebugLog?.call('💳 Abrindo $storeName...');
      
      if (productDetails.id == PREMIUM_YEARLY_IOS || productDetails.id == PREMIUM_YEARLY_ANDROID) {
        // Assinatura com renovação automática
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      } else {
        // Produto consumível ou não-consumível
        await _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
      }
      
      print('✅ [IAP] Compra iniciada - aguardando resposta da $storeName');
      onDebugLog?.call('⏳ Aguardando resposta da $storeName');
      
    } catch (e) {
      print('❌ [IAP] Erro ao iniciar compra: $e');
      _callErrorCallback({
        'code': 'purchase_initiation_failed',
        'message': 'Falha ao iniciar compra: $e'
      });
    }
  }
  
  /// Apresentar folha de resgate de código promocional (iOS apenas)
  Future<void> presentCodeRedemptionSheet() async {
    print('🎫 [IAP] presentCodeRedemptionSheet chamado');

    if (!Platform.isIOS) {
      print('❌ [IAP] Code redemption sheet é apenas para iOS');
      _callErrorCallback({
        'code': 'platform_not_supported',
        'message': 'Offer codes são suportados apenas no iOS'
      });
      return;
    }

    if (!_storeAvailable) {
      await initialize();
    }

    try {
      print('📱 [IAP] Apresentando folha nativa de código promocional...');
      onDebugLog?.call('🎫 Abrindo folha de código...');

      // Obter extensão iOS do plugin
      final InAppPurchaseStoreKitPlatformAddition iosPlatformAddition =
          _inAppPurchase.getPlatformAddition<InAppPurchaseStoreKitPlatformAddition>();

      // Apresentar a folha de resgate de código
      await iosPlatformAddition.presentCodeRedemptionSheet();

      print('✅ [IAP] Folha de código apresentada com sucesso');
      print('📝 [IAP] Usuário deve inserir o código: PROMO30');
      onDebugLog?.call('✅ Digite o código: PROMO30');

      // NOTA: O resultado será processado através do listener de compras normal
      // quando o usuário resgatar o código com sucesso

    } catch (e) {
      print('❌ [IAP] Erro ao apresentar folha de código: $e');
      _callErrorCallback({
        'code': 'code_sheet_failed',
        'message': 'Falha ao abrir folha de código: $e'
      });
    }
  }

  /// Restaurar compras anteriores
  Future<void> restorePurchases() async {
    print('🔄 [IAP] ===============================');
    print('🔄 [IAP] RESTORE PURCHASES SERVICE INICIADO');
    print('🔄 [IAP] Store available: $_storeAvailable');
    print('🔄 [IAP] ===============================');
    
    if (!_storeAvailable) {
      print('⚠️ [IAP] Store não disponível, inicializando...');
      await initialize();
    }
    
    try {
      print('🔄 [IAP] Chamando _inAppPurchase.restorePurchases()...');
      await _inAppPurchase.restorePurchases();
      print('✅ [IAP] Restauração enviada para Apple Store - aguardando resposta...');
      
    } catch (e) {
      print('❌ [IAP] Erro ao restaurar compras: $e');
      _callErrorCallback({
        'code': 'restore_failed',
        'message': 'Falha na restauração: $e'
      });
    }
  }
  
  /// Verificar status da assinatura ao abrir o app
  Future<Map<String, dynamic>> checkSubscriptionStatus() async {
    print('🔍 [IAP] ===============================');
    print('🔍 [IAP] VERIFICANDO STATUS DA ASSINATURA');
    print('🔍 [IAP] ===============================');
    
    if (!_storeAvailable) {
      print('⚠️ [IAP] Store não disponível, inicializando...');
      bool initialized = await initialize();
      if (!initialized) {
        return {
          'hasActiveSubscription': false,
          'error': 'Store não disponível'
        };
      }
    }
    
    try {
      // Para iOS, usar restore purchases para verificar assinaturas ativas
      if (Platform.isIOS) {
        print('🍎 [IAP] iOS: Verificando assinaturas via restore...');
        
        // Criar um completer para aguardar a resposta
        final completer = Completer<Map<String, dynamic>>();
        bool hasReceivedResponse = false;
        
        // Configurar callback temporário para capturar resultado
        final originalCallback = onRestoreSuccess;
        onRestoreSuccess = (restoredPurchases) {
          hasReceivedResponse = true;
          if (restoredPurchases.isNotEmpty) {
            print('✅ [IAP] Assinatura ativa encontrada');
            completer.complete({
              'hasActiveSubscription': true,
              'purchases': restoredPurchases
            });
          } else {
            print('⚠️ [IAP] Nenhuma assinatura ativa encontrada');
            completer.complete({
              'hasActiveSubscription': false,
              'message': 'Nenhuma assinatura ativa'
            });
          }
          // Restaurar callback original
          onRestoreSuccess = originalCallback;
        };
        
        // Iniciar restore
        await _inAppPurchase.restorePurchases();
        
        // Aguardar resposta com timeout de 10 segundos
        final result = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ [IAP] Timeout na verificação de assinatura');
            onRestoreSuccess = originalCallback;
            return {
              'hasActiveSubscription': false,
              'error': 'Timeout na verificação'
            };
          }
        );
        
        return result;
      }
      
      // Para Android, usar restore purchases igual ao iOS
      if (Platform.isAndroid) {
        print('🤖 [IAP] Android: Verificando assinaturas via restore...');
        
        // Criar um completer para aguardar a resposta
        final completer = Completer<Map<String, dynamic>>();
        
        // Configurar callback temporário para capturar resultado
        final originalCallback = onRestoreSuccess;
        onRestoreSuccess = (restoredPurchases) {
          if (restoredPurchases.isNotEmpty) {
            print('✅ [IAP] Assinatura ativa encontrada no Android');
            completer.complete({
              'hasActiveSubscription': true,
              'purchases': restoredPurchases
            });
          } else {
            print('⚠️ [IAP] Nenhuma assinatura ativa encontrada no Android');
            completer.complete({
              'hasActiveSubscription': false,
              'message': 'Nenhuma assinatura ativa'
            });
          }
          // Restaurar callback original
          onRestoreSuccess = originalCallback;
        };
        
        // Iniciar restore
        await _inAppPurchase.restorePurchases();
        
        // Aguardar resposta com timeout de 10 segundos
        final result = await completer.future.timeout(
          Duration(seconds: 10),
          onTimeout: () {
            print('⏱️ [IAP] Timeout na verificação de assinatura Android');
            onRestoreSuccess = originalCallback;
            return {
              'hasActiveSubscription': false,
              'error': 'Timeout na verificação'
            };
          }
        );
        
        return result;
      }
      
      return {
        'hasActiveSubscription': false,
        'error': 'Plataforma não suportada'
      };
      
    } catch (e) {
      print('❌ [IAP] Erro ao verificar status: $e');
      return {
        'hasActiveSubscription': false,
        'error': e.toString()
      };
    }
  }
  
  /// Processar atualizações de compra do Apple Store
  void _handlePurchaseUpdate(List<PurchaseDetails> purchaseDetailsList) {
    for (PurchaseDetails purchaseDetails in purchaseDetailsList) {
      print('📦 [IAP] Status da compra ${purchaseDetails.productID}: ${purchaseDetails.status}');
      
      switch (purchaseDetails.status) {
        case PurchaseStatus.pending:
          print('⏳ [IAP] Compra pendente - aguardando confirmação do usuário');
          break;
          
        case PurchaseStatus.purchased:
          print('✅ [IAP] Compra bem-sucedida!');
          _handleSuccessfulPurchase(purchaseDetails);
          break;
          
        case PurchaseStatus.restored:
          print('🔄 [IAP] Compra restaurada com sucesso!');
          _handleSuccessfulPurchase(purchaseDetails, isRestore: true);
          break;
          
        case PurchaseStatus.error:
          print('❌ [IAP] Erro na compra: ${purchaseDetails.error?.message}');
          _handlePurchaseError(purchaseDetails);
          break;
          
        case PurchaseStatus.canceled:
          print('🚫 [IAP] Compra cancelada pelo usuário');
          _callErrorCallback({
            'code': 'user_cancelled',
            'message': 'Compra cancelada pelo usuário'
          });
          _completePurchase(purchaseDetails);
          break;
      }
    }
  }
  
  /// Processar compra bem-sucedida
  void _handleSuccessfulPurchase(PurchaseDetails purchaseDetails, {bool isRestore = false}) async {
    try {
      print('🎉 [IAP] Processando compra bem-sucedida...');
      
      // Verificar compra (em produção, fazer verificação no servidor)
      bool isValid = await _verifyPurchase(purchaseDetails);
      
      if (!isValid) {
        print('❌ [IAP] Compra inválida - verificação falhou');
        _callErrorCallback({
          'code': 'purchase_verification_failed',
          'message': 'Falha na verificação da compra'
        });
        return;
      }
      
      // Preparar dados para WebView (compatível com iOS e Android)
      Map<String, dynamic> purchaseData;
      
      if (Platform.isAndroid) {
        // Android-specific data
        final androidDetails = purchaseDetails as GooglePlayPurchaseDetails;
        purchaseData = {
          'productId': purchaseDetails.productID,
          'transactionId': purchaseDetails.purchaseID ?? '',
          'originalTransactionId': androidDetails.billingClientPurchase.originalJson,
          'isActive': true,
          'purchaseDate': DateTime.now().toIso8601String(),
          'receipt': androidDetails.billingClientPurchase.originalJson, // JSON completo da compra
          'serverReceipt': androidDetails.billingClientPurchase.purchaseToken,
          'localVerificationData': androidDetails.billingClientPurchase.originalJson,
          'source': 'google_play',
          'isRestore': isRestore,
          'platform': 'android',
          'purchaseToken': androidDetails.billingClientPurchase.purchaseToken,
          'orderId': androidDetails.billingClientPurchase.orderId,
          'packageName': androidDetails.billingClientPurchase.packageName,
          'signature': androidDetails.billingClientPurchase.signature,
        };
      } else {
        // iOS data
        purchaseData = {
          'productId': purchaseDetails.productID,
          'transactionId': purchaseDetails.purchaseID ?? '',
          'originalTransactionId': purchaseDetails.purchaseID ?? '',
          'isActive': true,
          'purchaseDate': DateTime.now().toIso8601String(),
          'receipt': purchaseDetails.verificationData.localVerificationData,
          'serverReceipt': purchaseDetails.verificationData.serverVerificationData,
          'localVerificationData': purchaseDetails.verificationData.localVerificationData,
          'source': purchaseDetails.verificationData.source,
          'isRestore': isRestore,
          'platform': 'ios',
        };
      }
      
      print('✅ [IAP] Notificando WebView sobre compra bem-sucedida');
      
      if (isRestore) {
        onRestoreSuccess?.call([purchaseData]);
      } else {
        onPurchaseSuccess?.call(purchaseData);
      }
      
      // Completar a transação
      await _completePurchase(purchaseDetails);
      
    } catch (e) {
      print('❌ [IAP] Erro ao processar compra: $e');
      _callErrorCallback({
        'code': 'purchase_processing_failed',
        'message': 'Erro no processamento: $e'
      });
    }
  }
  
  /// Processar erro de compra
  void _handlePurchaseError(PurchaseDetails purchaseDetails) {
    final error = purchaseDetails.error;
    String errorCode = 'purchase_failed';
    String errorMessage = 'Falha na compra';
    
    if (error != null) {
      switch (error.code) {
        case 'storekit_duplicate_product_object':
          errorCode = 'duplicate_product';
          errorMessage = 'Produto duplicado';
          break;
        case 'storekit_invalid_payment_object':
          errorCode = 'invalid_payment';
          errorMessage = 'Pagamento inválido';
          break;
        case 'storekit_invalid_product_object':
          errorCode = 'invalid_product';
          errorMessage = 'Produto inválido';
          break;
        case 'storekit_product_not_available':
          errorCode = 'product_not_available';
          errorMessage = 'Produto não disponível';
          break;
        case 'storekit_unknown_error':
          errorCode = 'unknown_error';
          errorMessage = 'Erro desconhecido';
          break;
        default:
          errorMessage = error.message;
      }
    }
    
    _callErrorCallback({
      'code': errorCode,
      'message': errorMessage,
      'details': error?.details,
    });
    
    _completePurchase(purchaseDetails);
  }
  
  /// Verificar validade da compra
  Future<bool> _verifyPurchase(PurchaseDetails purchaseDetails) async {
    // Em produção, implementar verificação no servidor
    print('🔐 [IAP] Verificando compra...');
    
    if (Platform.isAndroid) {
      // Android: verificar purchase token
      try {
        final androidDetails = purchaseDetails as GooglePlayPurchaseDetails;
        if (androidDetails.billingClientPurchase.purchaseToken.isEmpty) {
          print('❌ [IAP] Android: Purchase token vazio');
          return false;
        }
        print('✅ [IAP] Android: Purchase token válido');
      } catch (e) {
        print('⚠️ [IAP] Android: Erro ao verificar token: $e');
      }
    }
    
    // Por enquanto, aceitar todas as compras com tokens válidos
    print('✅ [IAP] Compra verificada (modo desenvolvimento)');
    return true;
  }
  
  /// Completar transação
  Future<void> _completePurchase(PurchaseDetails purchaseDetails) async {
    if (purchaseDetails.pendingCompletePurchase) {
      await _inAppPurchase.completePurchase(purchaseDetails);
      print('✅ [IAP] Transação completada: ${purchaseDetails.productID}');
    }
  }
  
  /// Chamar callback de erro
  void _callErrorCallback(Map<String, dynamic> error) {
    onPurchaseError?.call(error);
  }
  
  /// Limpar recursos
  void dispose() {
    _subscription.cancel();
    _isInitialized = false;
    print('🧹 [IAP] Serviço finalizado');
  }
}

/// Delegate para gerenciar queue de pagamentos iOS
class IAPPaymentQueueDelegate implements SKPaymentQueueDelegateWrapper {
  @override
  bool shouldContinueTransaction(SKPaymentTransactionWrapper transaction, SKStorefrontWrapper storefront) {
    print('🍎 [IAP] Delegate: Continuando transação ${transaction.payment.productIdentifier}');
    return true;
  }

  @override
  bool shouldShowPriceConsent() {
    print('🍎 [IAP] Delegate: Não mostrar consentimento de preço');
    return false;
  }
}