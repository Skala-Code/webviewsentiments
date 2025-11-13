# 🍎 Backend Laravel - Endpoint de Verificação de IAP

## 📋 **ENDPOINT NECESSÁRIO**

O app Flutter agora envia automaticamente o receipt da Apple para o backend Laravel para ativar o `active_plan` na tabela `usuarios`.

### **URL do Endpoint**
```
POST https://sentiments-app-2025-main-0edfqj.laravel.cloud/api/ios-purchase-verify
```

### **Headers**
```
Content-Type: application/json
Accept: application/json
```

### **Body (JSON)**
```json
{
  "receipt_data": "base64_encoded_receipt_from_apple",
  "email": "user@example.com",
  "product_id": "com.mycompany.sentiments.premium_yearly",
  "platform": "ios",
  "is_jwt": true,
  "transaction_id": "1000000123456789",
  "purchase_token": null,
  "is_restore": false
}
```

## 🔧 **IMPLEMENTAÇÃO LARAVEL**

### **1. Route (routes/api.php)**
```php
Route::post('/ios-purchase-verify', [IAPController::class, 'verifyIOSPurchase']);
```

### **2. Controller (app/Http/Controllers/IAPController.php)**
```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class IAPController extends Controller
{
    public function verifyIOSPurchase(Request $request)
    {
        try {
            $receiptData = $request->input('receipt_data');
            $email = $request->input('email');
            $productId = $request->input('product_id');
            $transactionId = $request->input('transaction_id');
            $platform = $request->input('platform');
            $isRestore = $request->input('is_restore', false);
            
            Log::info('📤 Verificando receipt', [
                'email' => $email,
                'product_id' => $productId,
                'transaction_id' => $transactionId,
                'platform' => $platform,
                'is_restore' => $isRestore ? 'true' : 'false'
            ]);
            
            // Verificar receipt com Apple (Sandbox first, then Production)
            $appleResponse = $this->verifyWithApple($receiptData, true); // Sandbox
            
            if (!$appleResponse || $appleResponse['status'] !== 0) {
                // Try Production
                $appleResponse = $this->verifyWithApple($receiptData, false);
            }
            
            if (!$appleResponse || $appleResponse['status'] !== 0) {
                Log::error('❌ Receipt inválido', ['apple_response' => $appleResponse]);
                return response()->json(['error' => 'Receipt inválido'], 400);
            }
            
            // Extrair dados da resposta da Apple
            $receipt = $appleResponse['receipt'];
            $inAppPurchases = $receipt['in_app'] ?? [];
            
            // Verificar se há uma compra válida para o produto
            $validPurchase = null;
            foreach ($inAppPurchases as $purchase) {
                if ($purchase['product_id'] === $productId) {
                    $validPurchase = $purchase;
                    break;
                }
            }
            
            if (!$validPurchase) {
                Log::error('❌ Produto não encontrado no receipt', ['product_id' => $productId]);
                return response()->json(['error' => 'Produto não encontrado'], 400);
            }
            
            // Buscar ou criar usuário baseado no email
            $userId = $this->findOrCreateUser($email, $isRestore);
            
            if (!$userId) {
                Log::error('❌ Falha ao identificar/criar usuário', ['email' => $email]);
                return response()->json(['error' => 'Falha ao processar usuário'], 500);
            }
            
            Log::info('✅ Usuário identificado/criado', ['user_id' => $userId, 'email' => $email]);
            
            // Ativar plano do usuário
            DB::table('usuarios')
                ->where('id', $userId)
                ->update([
                    'active_plan' => true,
                    'plan_type' => 'premium_yearly',
                    'plan_start_date' => now(),
                    'plan_end_date' => now()->addYear(),
                    'apple_transaction_id' => $transactionId,
                    'updated_at' => now()
                ]);
            
            Log::info('✅ Plano ativado', [
                'user_id' => $userId,
                'product_id' => $productId,
                'transaction_id' => $transactionId
            ]);
            
            return response()->json([
                'success' => true,
                'active_plan' => true,
                'plan_type' => 'premium_yearly',
                'user_id' => $userId,
                'is_restore' => $isRestore,
                'message' => $isRestore ? 'Plano restaurado com sucesso' : 'Plano ativado com sucesso'
            ]);
            
        } catch (\Exception $e) {
            Log::error('❌ Erro na verificação IAP', ['error' => $e->getMessage()]);
            return response()->json(['error' => 'Erro interno'], 500);
        }
    }
    
    private function verifyWithApple($receiptData, $sandbox = true)
    {
        $url = $sandbox 
            ? 'https://sandbox.itunes.apple.com/verifyReceipt'
            : 'https://buy.itunes.apple.com/verifyReceipt';
            
        $response = Http::post($url, [
            'receipt-data' => $receiptData,
            'password' => env('APPLE_SHARED_SECRET'), // Add to .env
            'exclude-old-transactions' => true
        ]);
        
        return $response->json();
    }
    
    private function findOrCreateUser($email, $isRestore = false)
    {
        try {
            Log::info('🔍 Buscando usuário por email', ['email' => $email, 'is_restore' => $isRestore]);
            
            // Buscar usuário existente por email
            $user = DB::table('usuarios')->where('email', $email)->first();
            
            if ($user) {
                Log::info('✅ Usuário encontrado', ['user_id' => $user->id, 'email' => $email]);
                return $user->id;
            }
            
            // Criar novo usuário (especialmente importante para restaurações)
            Log::info('🆕 Criando novo usuário', ['email' => $email, 'is_restore' => $isRestore]);
            
            $userId = DB::table('usuarios')->insertGetId([
                'email' => $email,
                'name' => explode('@', $email)[0], // Use email prefix as name
                'firebase_uid' => null, // Será preenchido posteriormente
                'active_plan' => false, // Será ativado após verificação
                'created_at' => now(),
                'updated_at' => now()
            ]);
            
            Log::info('✅ Usuário criado com sucesso', ['user_id' => $userId, 'email' => $email]);
            return $userId;
            
        } catch (\Exception $e) {
            Log::error('❌ Erro ao buscar/criar usuário', ['email' => $email, 'error' => $e->getMessage()]);
            return null;
        }
    }
    
    private function getCurrentUserId($request)
    {
        // IMPLEMENT YOUR USER IDENTIFICATION LOGIC
        // Examples:
        
        // Option 1: From session/cookie
        if (session('user_id')) {
            return session('user_id');
        }
        
        // Option 2: From Authorization header
        $token = $request->bearerToken();
        if ($token) {
            // Validate token and return user_id
        }
        
        // Option 3: From request data (if sent from app)
        if ($request->has('user_id')) {
            return $request->input('user_id');
        }
        
        // Option 4: From email matching transaction
        // You could send user email from Flutter and match here
        
        return null;
    }
}
```

### **3. Environment Variables (.env)**
```env
# Apple Shared Secret for IAP verification
APPLE_SHARED_SECRET=your_app_store_connect_shared_secret_here
```

## 📊 **DATABASE UPDATES**

Ensure your `usuarios` table has these columns:
```sql
ALTER TABLE usuarios ADD COLUMN active_plan BOOLEAN DEFAULT FALSE;
ALTER TABLE usuarios ADD COLUMN plan_type VARCHAR(50) DEFAULT NULL;
ALTER TABLE usuarios ADD COLUMN plan_start_date TIMESTAMP NULL;
ALTER TABLE usuarios ADD COLUMN plan_end_date TIMESTAMP NULL;
ALTER TABLE usuarios ADD COLUMN apple_transaction_id VARCHAR(255) DEFAULT NULL;
```

## 🔑 **Apple Shared Secret**

1. Go to App Store Connect
2. My Apps > Your App > Features > In-App Purchases  
3. Click "App-Specific Shared Secret"
4. Generate or view the secret
5. Add to Laravel .env file

## 🔄 **MELHORIAS PARA RESTAURAÇÃO**

**Novo campo `is_restore`:**
- Flutter agora envia `is_restore: true` quando é uma restauração
- Backend trata restaurações igual a compras novas
- Usuários são criados automaticamente se não existirem

**Criação automática de usuários:**
- Função `findOrCreateUser()` busca por email
- Se não encontrar, cria usuário automaticamente
- Importante para usuários que restauram em novos dispositivos

**Navegação unificada:**
- Restaurações agora redirecionam para dashboard igual compras novas
- Resposta inclui `user_id` e `is_restore` para debug

## 🧪 **TESTING**

After implementing, test:
1. **Compra nova**: Make a purchase in the app
2. **Restauração existente**: Click "Restaurar Compras" with existing subscription
3. **Restauração novo usuário**: Use different email to test user creation
4. Check Laravel logs for verification process
5. Verify `usuarios.active_plan` is set to `true`
6. Confirm navigation to dashboard works for both scenarios
7. Test both Sandbox and Production receipts

**Logs para verificar:**
```bash
# Laravel logs (storage/logs/laravel.log)
grep "Verificando receipt" storage/logs/laravel.log
grep "is_restore" storage/logs/laravel.log
grep "Usuário criado" storage/logs/laravel.log
```

**Flutter logs para verificar:**
```
🔄 [MAIN] RESTORE SUCCESS EXECUTADO!!!
📤 [MAIN] _sendReceiptToBackend INICIADO
🎉 [MAIN] Premium confirmado pelo backend!
🚀 [MAIN] Navegando DIRETO para dashboard
```

---

💡 **Important**: Adjust `getCurrentUserId()` method based on your authentication system!