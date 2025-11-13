// Exemplo de integração com In-App Purchases no lado Web
// Este arquivo mostra como chamar as funções de compra do Flutter via JavaScript

// ===========================================
// CONFIGURAÇÃO INICIAL
// ===========================================

// Verificar se o handler do Flutter está disponível
function isFlutterHandlerAvailable() {
  return typeof window.flutter_inappwebview !== 'undefined' && 
         typeof window.flutter_inappwebview.callHandler === 'function';
}

// ===========================================
// FUNÇÕES DE COMPRA
// ===========================================

// 1. Carregar produtos disponíveis
async function loadProducts(productIds = []) {
  if (!isFlutterHandlerAvailable()) {
    console.error('Flutter handler não disponível');
    return null;
  }
  
  try {
    // productIds: Array com IDs dos produtos configurados no App Store Connect
    // Exemplo: ['com.mycompany.sentiments.premium_monthly', 'com.mycompany.sentiments.premium_yearly']
    const result = await window.flutter_inappwebview.callHandler('loadProducts', productIds);
    
    if (result.success) {
      console.log('Produtos carregados:', result.products);
      // result.products contém array com objetos:
      // {
      //   id: 'com.mycompany.sentiments.premium_monthly',
      //   title: 'Premium Mensal',
      //   description: 'Acesso completo por 1 mês',
      //   price: 'R$ 9,90',
      //   rawPrice: 9.90,
      //   currencyCode: 'BRL'
      // }
      return result.products;
    } else {
      console.error('Erro ao carregar produtos:', result.error);
      return null;
    }
  } catch (error) {
    console.error('Erro ao chamar handler:', error);
    return null;
  }
}

// 2. Iniciar compra de um produto
async function purchaseProduct(productId) {
  if (!isFlutterHandlerAvailable()) {
    console.error('Flutter handler não disponível');
    return false;
  }
  
  try {
    // productId: ID do produto a ser comprado
    const result = await window.flutter_inappwebview.callHandler('purchaseProduct', productId);
    
    if (result.success) {
      console.log('Compra iniciada');
      // A confirmação virá via callback (veja seção de callbacks abaixo)
      return true;
    } else {
      console.error('Erro ao iniciar compra:', result.error);
      return false;
    }
  } catch (error) {
    console.error('Erro ao chamar handler:', error);
    return false;
  }
}

// 3. Restaurar compras anteriores
async function restorePurchases() {
  if (!isFlutterHandlerAvailable()) {
    console.error('Flutter handler não disponível');
    return false;
  }
  
  try {
    const result = await window.flutter_inappwebview.callHandler('restorePurchases');
    
    if (result.success) {
      console.log('Restauração iniciada');
      // Os resultados virão via callback
      return true;
    } else {
      console.error('Erro ao restaurar compras:', result.error);
      return false;
    }
  } catch (error) {
    console.error('Erro ao chamar handler:', error);
    return false;
  }
}

// ===========================================
// CALLBACKS DE RESPOSTA
// ===========================================

// Configurar callbacks para receber respostas do Flutter
window.onPurchaseSuccess = function(data) {
  console.log('✅ Compra bem-sucedida:', data);
  // data contém informações sobre a compra:
  // - productId: ID do produto comprado
  // - transactionId: ID da transação
  // - status: Status da compra
  // - verificationData: Dados para verificação no servidor
  
  // Exemplo de uso:
  // - Atualizar interface do usuário
  // - Desbloquear conteúdo premium
  // - Salvar estado no localStorage ou servidor
  
  // Notificar usuário
  alert('Compra realizada com sucesso! Obrigado!');
  
  // Atualizar estado premium no localStorage
  localStorage.setItem('isPremium', 'true');
  localStorage.setItem('premiumProductId', data.productId);
};

window.onPurchaseError = function(error) {
  console.error('❌ Erro na compra:', error);
  
  // Tratar diferentes tipos de erro
  if (error.includes('canceled')) {
    alert('Compra cancelada');
  } else if (error.includes('network')) {
    alert('Erro de conexão. Tente novamente.');
  } else {
    alert('Erro ao processar compra: ' + error);
  }
};

window.onProductsLoaded = function(products) {
  console.log('📦 Produtos carregados via callback:', products);
  
  // Atualizar interface com lista de produtos
  // Exemplo: mostrar botões de compra com preços
  products.forEach(product => {
    console.log(`${product.title}: ${product.price}`);
    // Criar botão de compra para cada produto
  });
};

// ===========================================
// EXEMPLO DE USO COMPLETO
// ===========================================

// Exemplo de página de assinatura
async function initializePurchasePage() {
  // 1. Verificar se está no app Flutter
  if (!isFlutterHandlerAvailable()) {
    console.log('Executando fora do app - compras não disponíveis');
    document.getElementById('purchase-section').style.display = 'none';
    return;
  }
  
  // 2. IDs dos produtos (devem estar configurados no App Store Connect)
  const productIds = [
    'com.mycompany.sentiments.premium_monthly',
    'com.mycompany.sentiments.premium_yearly',
    'com.mycompany.sentiments.lifetime'
  ];
  
  // 3. Carregar produtos disponíveis
  const products = await loadProducts(productIds);
  
  if (products && products.length > 0) {
    // 4. Criar interface de compra
    const container = document.getElementById('products-container');
    container.innerHTML = '';
    
    products.forEach(product => {
      const button = document.createElement('button');
      button.className = 'purchase-button';
      button.innerHTML = `
        <h3>${product.title}</h3>
        <p>${product.description}</p>
        <strong>${product.price}</strong>
      `;
      button.onclick = () => purchaseProduct(product.id);
      container.appendChild(button);
    });
    
    // 5. Adicionar botão de restaurar compras
    const restoreButton = document.createElement('button');
    restoreButton.className = 'restore-button';
    restoreButton.textContent = 'Restaurar Compras';
    restoreButton.onclick = restorePurchases;
    container.appendChild(restoreButton);
  } else {
    console.error('Nenhum produto disponível');
    document.getElementById('products-container').innerHTML = 
      '<p>Produtos não disponíveis no momento</p>';
  }
}

// Inicializar quando a página carregar
document.addEventListener('DOMContentLoaded', initializePurchasePage);

// ===========================================
// NOTAS IMPORTANTES
// ===========================================

/*
1. CONFIGURAÇÃO NO APP STORE CONNECT:
   - Criar produtos In-App Purchase no App Store Connect
   - Usar os mesmos IDs configurados aqui no código
   - Aguardar aprovação dos produtos pela Apple

2. TESTES:
   - Usar conta de teste (Sandbox) para iOS
   - Não usar conta real da App Store durante desenvolvimento
   - Configurar testadores no App Store Connect

3. VERIFICAÇÃO NO SERVIDOR:
   - Sempre verificar compras no servidor backend
   - Usar receipt validation da Apple
   - Nunca confiar apenas na validação client-side

4. ESTADOS DE COMPRA:
   - pending: Compra em processamento
   - purchased: Compra concluída
   - restored: Compra restaurada
   - error: Erro na compra
   - canceled: Compra cancelada pelo usuário

5. TIPOS DE PRODUTO:
   - Consumable: Pode ser comprado múltiplas vezes
   - Non-Consumable: Comprado uma vez, permanente
   - Auto-Renewable Subscription: Assinatura renovável
   - Non-Renewable Subscription: Assinatura não renovável
*/