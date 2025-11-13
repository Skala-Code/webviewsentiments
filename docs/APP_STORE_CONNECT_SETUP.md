# Guia de Configuração - In-App Purchases no App Store Connect

## 📋 Pré-requisitos

1. **Conta de Desenvolvedor Apple** ativa ($99/ano)
2. **App criado no App Store Connect**
3. **Agreements, Tax, and Banking** configurado (IMPORTANTE!)
   - Vá em "Agreements, Tax, and Banking"
   - Aceite o "Paid Applications Agreement"
   - Configure informações bancárias e fiscais

## 🚀 Passo 1: Acessar App Store Connect

1. Acesse: https://appstoreconnect.apple.com
2. Faça login com sua Apple ID de desenvolvedor
3. Clique em "My Apps"
4. Selecione o app "Sentiments"

## 💰 Passo 2: Criar Compras dentro do app

### Na página do seu app:

1. No menu lateral, clique em **"Monetização"** > **"Compras dentro do app"**
2. Clique no botão **"+"** para criar novo produto

### Tipos de produtos disponíveis:

- **Consumível**: Pode ser comprado múltiplas vezes (ex: moedas, vidas)
- **Não consumível**: Comprado uma vez, permanente (ex: remover anúncios)
- **Assinatura com renovação automática**: Assinatura que renova automaticamente
- **Assinatura sem renovação automática**: Assinatura manual

## 📦 Passo 3: Configurar Produtos (Exemplo com Assinatura)

### Para criar uma assinatura Premium Mensal:

1. **Tipo**: Selecione "Assinatura com renovação automática"

2. **Nome de referência**: `Premium Mensal`
   - Nome interno, só você vê

3. **ID do produto**: `com.mycompany.sentiments.premium_monthly`
   - DEVE ser exatamente igual ao código
   - Não pode ser alterado depois
   - Use formato: com.suaempresa.app.produto

4. **Grupo de assinatura**: 
   - Criar novo grupo: "Premium Access"
   - Produtos no mesmo grupo compartilham período de teste

### Configurar Duração da assinatura:
- **Duração**: 1 mês
- **Preços**: Clique em "Adicionar preço de assinatura"
  - Selecione país base (ex: Brasil)
  - Defina preço (ex: R$ 19,90)
  - Apple calculará preços para outros países

### Adicionar Localização:

1. Clique em **"Adicionar localização"**
2. Selecione **Português (Brasil)**
3. Preencha:
   - **Nome de exibição**: "Assinatura Premium Mensal"
   - **Descrição**: "Acesso completo a todas as funcionalidades premium por 1 mês"

### Captura de tela de revisão:
- Obrigatório para aprovação
- Tamanho: 640x920px mínimo
- Mostre a tela de compra do app

## 🎁 Passo 4: Configurar Período de Teste (Opcional)

1. Em "Preços de assinatura", clique em "Ver todos os preços de assinatura"
2. Clique em "Oferta introdutória"
3. Escolha tipo:
   - **Teste gratuito**: Período gratuito (ex: 7 dias grátis)
   - **Pagar conforme usar**: Preço reduzido inicial
   - **Pagamento antecipado**: Desconto por período

## 👥 Passo 5: Configurar Testadores Sandbox

### Criar contas de teste:

1. Vá em **"Usuários e acesso"**
2. Clique em **"Sandbox"** > **"Testadores"**
3. Clique **"+"** para adicionar testador
4. Preencha:
   - Email fictício (ex: teste1@example.com)
   - Senha forte
   - Nome/Sobrenome
   - País/Região

### No iPhone de teste:

1. Vá em **Ajustes** > **App Store**
2. Role até o final
3. Em "Sandbox Account", faça login com conta teste
4. NÃO use conta real Apple ID para testes!

## 🔍 Passo 6: Status e Revisão

### Status dos produtos:

- **Missing Metadata**: Falta informação
- **Waiting for Review**: Aguardando revisão
- **Ready to Submit**: Pronto para enviar
- **Approved**: Aprovado e disponível
- **Developer Action Needed**: Precisa de correção

### Para aprovação rápida:

1. Screenshots claros mostrando a compra
2. Descrições precisas do que o usuário recebe
3. Preços justos e competitivos
4. Não prometa funcionalidades futuras

## 📱 Passo 7: Testar no App

### No código Flutter, use os IDs criados:

```dart
// No arquivo purchase_service.dart
final List<String> _productIds = [
  'com.mycompany.sentiments.premium_monthly',
  'com.mycompany.sentiments.premium_yearly',
  'com.mycompany.sentiments.lifetime'
];
```

### No JavaScript do seu site:

```javascript
// Carregar produtos
const produtos = await window.flutter_inappwebview.callHandler('loadProducts', [
  'com.mycompany.sentiments.premium_monthly',
  'com.mycompany.sentiments.premium_yearly'
]);

// Mostrar produtos na interface
produtos.forEach(produto => {
  console.log(`${produto.title}: ${produto.price}`);
  // Criar botões de compra
});
```

## ⚠️ Problemas Comuns e Soluções

### Produtos não aparecem no app:

1. **Verificar Agreements**: "Paid Applications Agreement" deve estar ativo
2. **Aguardar propagação**: Pode levar até 24h para produtos aparecerem
3. **Product ID incorreto**: Deve ser idêntico no código e App Store Connect
4. **Sandbox account**: Certifique-se de estar usando conta teste

### Erro "No products found":

```swift
// Verificar no Xcode:
// 1. Capabilities > In-App Purchase está ativado
// 2. Bundle ID correto (com.mycompany.sentiments)
```

### Compra não funciona:

1. Verificar conexão internet
2. Conta Sandbox configurada corretamente
3. Produto aprovado no App Store Connect
4. Região da conta compatível com produto

## 📊 Passo 8: Analytics e Relatórios

### Acompanhar vendas:

1. **App Analytics**: Ver métricas de uso
2. **Sales and Trends**: Relatórios de vendas
3. **Payments and Financial Reports**: Pagamentos recebidos

### Métricas importantes:

- **Conversion Rate**: Taxa de conversão trial > pago
- **Churn Rate**: Taxa de cancelamento
- **MRR**: Receita mensal recorrente
- **LTV**: Lifetime value do cliente

## 🎯 Produtos Recomendados para Sentiments

```javascript
// Sugestão de estrutura de produtos:

1. ASSINATURAS (Auto-Renewable):
   - com.mycompany.sentiments.premium_monthly (R$ 19,90/mês)
   - com.mycompany.sentiments.premium_yearly (R$ 199,90/ano - 17% desconto)

2. COMPRA ÚNICA (Non-Consumable):
   - com.mycompany.sentiments.lifetime (R$ 399,90 - acesso vitalício)
   - com.mycompany.sentiments.remove_ads (R$ 9,90 - remove anúncios)

3. CONSUMÍVEIS (Consumable):
   - com.mycompany.sentiments.credits_10 (R$ 4,90 - 10 créditos)
   - com.mycompany.sentiments.credits_50 (R$ 19,90 - 50 créditos)
```

## 🚦 Checklist Final

- [ ] Agreements, Tax, and Banking configurado
- [ ] Produtos criados com IDs corretos
- [ ] Preços definidos para todas regiões
- [ ] Localizações adicionadas (PT-BR)
- [ ] Screenshots de revisão enviados
- [ ] Descrições claras e completas
- [ ] Contas Sandbox criadas
- [ ] Product IDs adicionados no código
- [ ] Teste com conta Sandbox funcionando
- [ ] Produtos com status "Ready to Submit"

## 📞 Suporte

Se tiver problemas:
1. Apple Developer Support: https://developer.apple.com/support/
2. Forums: https://developer.apple.com/forums/
3. Documentation: https://developer.apple.com/in-app-purchase/

## 🎉 Próximos Passos

Após configurar tudo:

1. **Testar compras** com conta Sandbox
2. **Implementar verificação** de receipt no servidor
3. **Monitorar métricas** após lançamento
4. **Otimizar preços** baseado em conversão
5. **Criar ofertas promocionais** para aumentar vendas

---

💡 **Dica**: Comece com poucos produtos e adicione mais conforme necessidade. É mais fácil gerenciar e aprovar!