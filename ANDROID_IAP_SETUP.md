# Configuração In-App Purchase Android

## Mudanças Implementadas no Código

### 1. Arquivo: `lib/services/iap_service.dart`
- ✅ Adicionado suporte completo para Android
- ✅ Importado `in_app_purchase_android` 
- ✅ Configurado Product ID específico para Android: `premium_yearly`
- ✅ Tratamento especial para GooglePlayPurchaseDetails
- ✅ Validação de purchase token para Android

### 2. Arquivo: `lib/main.dart`
- ✅ Importado pacote Android IAP
- ✅ Inicialização automática do Google Play Billing

### 3. Arquivo: `android/app/src/main/AndroidManifest.xml`
- ✅ Permissão BILLING já configurada

### 4. Arquivo: `android/app/src/main/res/values/strings.xml`
- ✅ Criado arquivo com configuração do Play Billing

## Configuração no Google Play Console

### 1. Upload do App Bundle
```bash
# O arquivo AAB gerado está em:
build/app/outputs/bundle/release/app-release.aab
```

### 2. No Google Play Console:

#### A. Criar Produto de Assinatura:
1. Vá para **Monetização** > **Produtos** > **Assinaturas**
2. Clique em **Criar assinatura**
3. Configure:
   - **ID do produto**: `premium_yearly` (DEVE ser exatamente este)
   - **Nome**: Premium Anual
   - **Descrição**: Acesso completo ao Sentiments por 1 ano
   - **Período de faturamento**: Anual
   - **Preço**: Configure o preço desejado

#### B. Configurar Teste:
1. Vá para **Configurações** > **Testadores internos**
2. Adicione emails dos testadores
3. Ative o teste de licença em **Configurações** > **Configuração de licença de teste**

#### C. Publicar App para Teste:
1. Faça upload do AAB em **Teste interno** ou **Teste fechado**
2. Aguarde revisão (pode levar algumas horas)
3. Compartilhe link de teste com testadores

## Importante para Testes

### Requisitos:
- ✅ App DEVE estar publicado (pelo menos em teste interno)
- ✅ Produto DEVE estar ativo no Console
- ✅ Testador DEVE estar na lista de testadores
- ✅ Testador DEVE aceitar convite de teste
- ✅ App DEVE ser instalado via Google Play (não APK direto)

### Como Testar:
1. Aceite o convite de teste no email
2. Instale o app pelo link do Google Play de teste
3. No app, vá para a tela de pagamento
4. O Google Play abrirá com preços de teste ($0.99)
5. Complete a compra (não será cobrado se for testador)

## Product IDs Configurados

- iOS: `com.mycompany.sentiments.premium_yearly`
- Android: `premium_yearly`

O código já detecta automaticamente a plataforma e usa o ID correto.

## Verificação de Problemas Comuns

### Se a compra não funcionar:

1. **"Produto não encontrado"**
   - Verifique se o Product ID está correto
   - Aguarde até 24h para propagação no Google Play
   - Certifique-se que o produto está ATIVO

2. **"Store não disponível"**
   - Verifique se o Google Play Services está atualizado
   - Verifique conexão com internet
   - App deve ser instalado via Google Play

3. **"Compra cancelada"**
   - Normal se usuário cancelar
   - Verifique se testador está configurado corretamente

## Logs para Debug

O app mostra logs detalhados:
- 🤖 [IAP] - Logs do Android
- 📦 [IAP] - Carregamento de produtos
- 💳 [IAP] - Processo de compra
- ✅ [IAP] - Sucesso
- ❌ [IAP] - Erros

Use `adb logcat | grep IAP` para ver logs em tempo real.