# 🤖 Android In-App Purchase - Google Play Console Setup

## ✅ **Flutter Configurado**
- ✅ Permission `com.android.vending.BILLING` adicionada
- ✅ IAP Service atualizado para Android
- ✅ Dados de compra compatíveis com Google Play

## 🚀 **Próximos Passos: Google Play Console**

### **1. Criar App no Google Play Console**
1. Acesse [Google Play Console](https://play.google.com/console)
2. **Create Application** → "Sentiments"
3. Package Name: `com.mycompany.sentiments`

### **2. Configurar In-App Products**
1. **Monetization** → **Products** → **In-app products**
2. **Create product**:
   - **Product ID:** `com.mycompany.sentiments.premium_yearly`
   - **Name:** "Sentiments Premium"
   - **Description:** "Plano premium anual do Sentiments"
   - **Price:** R$ 69,90 (mesmo valor do iOS)

### **3. Configurar Testing**
1. **Testing** → **License testing**
2. Adicionar emails de teste:
   ```
   seu-email@gmail.com
   ```
3. **Response:** "RESPOND_NORMALLY"

### **4. Upload APK/AAB**
```bash
# Gerar APK de debug para teste
flutter build apk --debug

# Ou AAB para produção
flutter build appbundle --release
```

### **5. Configurar Service Account (Para Backend)**
1. **Google Cloud Console** → **IAM & Admin** → **Service Accounts**
2. Criar Service Account para Google Play Developer API
3. Download JSON key
4. Habilitar **Google Play Developer API**

## 📱 **Teste Local (Sem Upload)**

### **Método 1: Debug com conta de teste**
```bash
flutter run --debug
```
- Use conta Google configurada como testador
- Produtos aparecerão como "Test"

### **Método 2: Release com keystore**
1. Gerar keystore (se não tiver):
```bash
keytool -genkey -v -keystore ~/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

2. Configurar `android/key.properties`:
```properties
storePassword=your_password
keyPassword=your_password  
keyAlias=upload
storeFile=/Users/seu-user/upload-keystore.jks
```

3. Build release:
```bash
flutter build apk --release
```

## 🔧 **Endpoint Backend para Android**

O endpoint Laravel já está configurado, mas precisa processar Android:

```php
public function verifyAndroidPurchase(Request $request)
{
    $platform = $request->input('platform'); // 'android'
    $purchaseToken = $request->input('purchase_token');
    $productId = $request->input('product_id');
    
    if ($platform === 'android') {
        // Validar com Google Play Developer API
        // Por enquanto, aceitar todas as compras de teste
        return response()->json([
            'success' => true,
            'active_plan' => true,
            'message' => 'Plano Android ativado com sucesso'
        ]);
    }
}
```

## 📋 **Dados Enviados (Android vs iOS)**

### **iOS (atual):**
```json
{
  "platform": "ios",
  "is_jwt": true,
  "receipt_data": "eyJhbGciOiJFUzI1NiI...",
  "transaction_id": "2000000989437563"
}
```

### **Android (novo):**
```json
{
  "platform": "android", 
  "is_jwt": false,
  "purchase_token": "abc123token...",
  "transaction_id": "GPA.1234-5678-9012",
  "order_id": "GPA.1234-5678-9012-34567"
}
```

## 🎯 **Fluxo de Teste**

1. **Configurar produto** no Google Play Console
2. **Adicionar email como testador**
3. **Build APK debug:** `flutter build apk --debug`
4. **Instalar:** `flutter install`
5. **Testar compra** - aparecerá como "Test (free)"
6. **Verificar logs** no Flutter

## ⚠️ **Importante**

- **Sandbox Android:** Compras aparecem como "Test (free)"
- **Verificação real:** Só funciona com app publicado
- **Desenvolvimento:** Backend deve aceitar compras de teste
- **Produção:** Implementar Google Play Developer API

---

**🚀 PRÓXIMO PASSO:** Configurar produto no Google Play Console!