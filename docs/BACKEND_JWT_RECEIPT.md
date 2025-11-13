# 🍎 Backend Laravel - Processar JWT Receipt (StoreKit 2)

## ⚠️ **IMPORTANTE: iOS agora usa JWT ao invés de Base64**

A Apple migrou para StoreKit 2 que usa **JWT (JSON Web Token)** ao invés do formato Base64 tradicional.

## 📋 **Dados recebidos do Flutter:**

```json
{
  "receipt_data": "eyJhbGciOiJFUzI1NiIsIng1YyI6WyJNSUlFTURDQ...", // JWT format
  "email": "user@example.com",
  "product_id": "com.mycompany.sentiments.premium_yearly",
  "is_jwt": true,
  "transaction_id": "2000000989391771"
}
```

## 🔧 **SOLUÇÃO PARA O BACKEND:**

### **Opção 1: Decodificar JWT Localmente (Recomendado)**

```php
use Firebase\JWT\JWT;
use Firebase\JWT\Key;

public function verifyIOSPurchase(Request $request)
{
    $jwtReceipt = $request->input('receipt_data');
    $isJWT = $request->input('is_jwt', false);
    
    if ($isJWT) {
        // Decodificar JWT sem verificar assinatura (para desenvolvimento)
        $parts = explode('.', $jwtReceipt);
        if (count($parts) === 3) {
            $payload = json_decode(base64_decode($parts[1]), true);
            
            // Extrair informações
            $transactionId = $payload['transactionId'];
            $productId = $payload['productId'];
            $environment = $payload['environment']; // "Sandbox" ou "Production"
            $expiresDate = $payload['expiresDate'] / 1000; // Convert from ms to seconds
            
            // Verificar se é Sandbox
            if ($environment === 'Sandbox') {
                // Aceitar para desenvolvimento
                Log::info('✅ Sandbox receipt válido', [
                    'transaction_id' => $transactionId,
                    'product_id' => $productId,
                    'expires' => date('Y-m-d H:i:s', $expiresDate)
                ]);
                
                // Ativar plano
                $this->activateUserPlan($request->input('email'));
                
                return response()->json([
                    'success' => true,
                    'active_plan' => true,
                    'message' => 'Plano ativado (Sandbox)'
                ]);
            }
        }
    }
    
    // Fallback para formato antigo Base64...
}

private function activateUserPlan($email)
{
    DB::table('usuarios')
        ->where('email', $email)
        ->update([
            'active_plan' => true,
            'plan_type' => 'premium_yearly',
            'plan_start_date' => now(),
            'plan_end_date' => now()->addYear(),
            'updated_at' => now()
        ]);
}
```

### **Opção 2: Usar App Store Server API (Produção)**

Para produção, use a nova [App Store Server API](https://developer.apple.com/documentation/appstoreserverapi):

```php
// Verificar transação via API
$response = Http::withHeaders([
    'Authorization' => 'Bearer ' . $this->generateJWT(),
])->get("https://api.storekit-sandbox.itunes.apple.com/inApps/v1/transactions/{$transactionId}");
```

## 🔍 **Estrutura do JWT Decodificado:**

```json
{
  "transactionId": "2000000989391771",
  "originalTransactionId": "2000000989390719",
  "bundleId": "com.mycompany.sentiments",
  "productId": "com.mycompany.sentiments.premium_yearly",
  "purchaseDate": 1755794777000,
  "expiresDate": 1755798377000,
  "environment": "Sandbox",
  "transactionReason": "RENEWAL",
  "price": 69900,
  "currency": "BRL"
}
```

## ✅ **Implementação Simplificada para Desenvolvimento:**

```php
public function verifyIOSPurchase(Request $request)
{
    try {
        // Para desenvolvimento, aceitar qualquer JWT válido
        $email = $request->input('email');
        
        // Ativar plano diretamente
        DB::table('usuarios')
            ->where('email', $email)
            ->update([
                'active_plan' => true,
                'plan_type' => 'premium_yearly',
                'plan_start_date' => now(),
                'plan_end_date' => now()->addYear()
            ]);
        
        return response()->json([
            'success' => true,
            'active_plan' => true,
            'message' => 'Plano ativado com sucesso'
        ]);
        
    } catch (\Exception $e) {
        return response()->json([
            'success' => false,
            'message' => $e->getMessage()
        ], 400);
    }
}
```

## 📱 **Para Produção:**

1. Validar assinatura JWT com certificados da Apple
2. Verificar `environment` !== "Sandbox"
3. Usar App Store Server API para verificação completa
4. Implementar webhook para renovações automáticas

---

**NOTA:** O erro `apple_status: 21002` ocorre porque você está enviando JWT para o endpoint legacy que espera Base64. Use a implementação acima!