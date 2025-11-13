# 🍎 Configuração Xcode para In-App Purchase

## 📋 CONFIGURAÇÕES OBRIGATÓRIAS

### 1. **Capabilities - In-App Purchase**

No Xcode:
1. Abra `ios/Runner.xcworkspace`
2. Selecione **Runner** (projeto azul)
3. Aba **"Signing & Capabilities"**
4. Clique **"+ Capability"**
5. Adicione **"In-App Purchase"**
6. ✅ Deve aparecer checkmark verde

### 2. **Bundle ID Correto**

- **Bundle Identifier**: `com.mycompany.sentiments`
- ⚠️ DEVE ser EXATAMENTE igual ao App Store Connect
- ⚠️ DEVE ser igual ao Product ID prefix

### 3. **Team e Signing**

- **Team**: Sua conta Apple Developer
- **Automatically manage signing**: ✅ Habilitado
- **Provisioning Profile**: Automatic

## 🔧 VERIFICAÇÕES IMPORTANTES

### Info.plist (já configurado):
```xml
<key>NSAllowsArbitraryLoads</key>
<true/>
```

### Product ID no código:
```dart
// em iap_service.dart
static const String PREMIUM_YEARLY = 'com.mycompany.sentiments.premium_yearly';
```

## 🚀 TESTAR CONFIGURAÇÃO

### 1. **Build no device físico:**
```bash
flutter run --release
```

### 2. **Verificar logs esperados:**
```
🚀 [IAP] Inicializando In-App Purchase Service...
✅ [IAP] App Store disponível
✅ [IAP] Serviço inicializado com sucesso
🎯 [MAIN] Configurando IAP JavaScript Handlers...
✅ [MAIN] IAP handlers configurados
```

### 3. **Se der erro "App Store não disponível":**
- Verifique Bundle ID
- Confirme que Capabilities está ativado
- Teste em device físico (não simulator)
- Aguarde propagação do App Store Connect (até 24h)

## ⚠️ TROUBLESHOOTING

### **Erro: "No matching provisioning profile"**
```
1. Xcode > Preferences > Accounts
2. Download Manual Profiles
3. Runner > Signing > Team > Reselecionar sua conta
```

### **Erro: "App Store Connect operation failed"**
```
- Produto ainda em "Ready to Submit"?
- Aguardar aprovação da Apple
- Testar com conta Sandbox
```

### **Erro: "StoreKit não disponível"**
```
- Só funciona em device físico
- Simulator não suporta IAP real
- Verificar conta Sandbox configurada
```

## 📱 FLUXO DE TESTE

### **No device físico:**
1. App abre WebView: `/perguntas`
2. Preenche formulário
3. Clica "Começar teste grátis"
4. JavaScript chama: `purchaseProduct('com.mycompany.sentiments.premium_yearly')`
5. **Apple Store abre automaticamente**
6. Usuário confirma com Face ID/Touch ID
7. **Pagamento é processado** (real ou sandbox)
8. Callback `onPurchaseSuccess` é chamado
9. WebView recebe confirmação

## 🎯 PRÓXIMOS PASSOS

Após Xcode configurado:
1. ✅ Build no device
2. ✅ Testar fluxo completo
3. ✅ Verificar logs de debug
4. ✅ Confirmar pagamento processado
5. ✅ Validar callbacks JavaScript

---

💡 **Dica**: Sempre teste em device físico. Simulator não suporta In-App Purchase!