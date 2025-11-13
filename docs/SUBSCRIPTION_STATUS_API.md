# API de Verificação de Status de Assinatura

## Implementação para Backend Laravel

### 1. Rota da API
Adicione no `routes/api.php`:

```php
Route::middleware('auth:sanctum')->group(function () {
    Route::post('/user/subscription-status', [SubscriptionController::class, 'updateStatus']);
});
```

### 2. Controller
Crie ou atualize `SubscriptionController.php`:

```php
<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use App\Models\User;
use Carbon\Carbon;

class SubscriptionController extends Controller
{
    public function updateStatus(Request $request)
    {
        $validated = $request->validate([
            'is_active' => 'required|boolean',
            'checked_at' => 'required|date',
            'purchases' => 'nullable|array'
        ]);
        
        $user = auth()->user();
        
        // Atualizar status da assinatura
        $user->update([
            'is_premium' => $validated['is_active'],
            'subscription_checked_at' => $validated['checked_at'],
            'subscription_status' => $validated['is_active'] ? 'active' : 'expired'
        ]);
        
        // Se assinatura expirou, reverter para plano básico
        if (!$validated['is_active']) {
            // Reverter funcionalidades premium
            $user->update([
                'plan_type' => 'basic',
                'premium_features' => null,
                'subscription_expires_at' => null
            ]);
            
            // Log da mudança
            activity()
                ->performedOn($user)
                ->log('Assinatura expirada - revertido para plano básico');
        } else {
            // Assinatura ativa - garantir acesso premium
            $user->update([
                'plan_type' => 'premium',
                'premium_features' => json_encode(['all_features'])
            ]);
            
            // Se houver informações de compra, processar
            if (!empty($validated['purchases'])) {
                foreach ($validated['purchases'] as $purchase) {
                    // Salvar ou atualizar informações da compra
                    $user->purchases()->updateOrCreate(
                        ['transaction_id' => $purchase['transactionId'] ?? null],
                        [
                            'product_id' => $purchase['productId'] ?? null,
                            'status' => 'active',
                            'platform' => $purchase['platform'] ?? null,
                            'verified_at' => now()
                        ]
                    );
                }
            }
        }
        
        return response()->json([
            'success' => true,
            'user_status' => [
                'is_premium' => $user->is_premium,
                'plan_type' => $user->plan_type
            ]
        ]);
    }
}
```

### 3. Funções JavaScript no Frontend

Adicione estas funções no JavaScript do Laravel:

```javascript
// Função chamada quando o Flutter verifica o status da assinatura
window.onSubscriptionStatusChecked = function(data) {
    console.log('Status da assinatura verificado:', data);
    
    if (data.isActive) {
        // Usuário tem assinatura ativa
        showPremiumFeatures();
        hidePurchaseButtons();
    } else {
        // Assinatura expirada ou cancelada
        hidePremiumFeatures();
        showUpgradePrompt();
    }
};

// Atualizar status premium do usuário
window.updateUserPremiumStatus = function(isPremium) {
    if (isPremium) {
        document.body.classList.add('premium-user');
        document.body.classList.remove('basic-user');
    } else {
        document.body.classList.add('basic-user');
        document.body.classList.remove('premium-user');
    }
};

// Reverter para plano básico
window.revertToBasicPlan = function() {
    console.log('Revertendo para plano básico...');
    
    // Esconder recursos premium
    document.querySelectorAll('.premium-only').forEach(el => {
        el.style.display = 'none';
    });
    
    // Mostrar botões de upgrade
    document.querySelectorAll('.upgrade-button').forEach(el => {
        el.style.display = 'block';
    });
    
    // Atualizar interface
    updateUserInterface('basic');
    
    // Opcional: mostrar modal informativo
    showModal({
        title: 'Assinatura Expirada',
        message: 'Sua assinatura premium expirou. Renove para continuar aproveitando todos os recursos.',
        buttons: [
            { text: 'Renovar Agora', action: 'showPurchaseOptions' },
            { text: 'Mais Tarde', action: 'close' }
        ]
    });
};
```

### 4. Migration para o Banco de Dados

Se necessário, crie uma migration para adicionar campos:

```php
Schema::table('users', function (Blueprint $table) {
    $table->boolean('is_premium')->default(false);
    $table->string('plan_type')->default('basic');
    $table->json('premium_features')->nullable();
    $table->timestamp('subscription_checked_at')->nullable();
    $table->timestamp('subscription_expires_at')->nullable();
    $table->string('subscription_status')->default('inactive');
});
```

### 5. Modelo de Compras (opcional)

Se quiser salvar histórico de compras:

```php
Schema::create('purchases', function (Blueprint $table) {
    $table->id();
    $table->foreignId('user_id')->constrained();
    $table->string('transaction_id')->unique()->nullable();
    $table->string('product_id');
    $table->string('platform'); // ios ou android
    $table->string('status');
    $table->json('receipt_data')->nullable();
    $table->timestamp('verified_at')->nullable();
    $table->timestamps();
});
```

## Como Funciona

1. **Ao abrir o app**: Flutter verifica automaticamente se há assinatura ativa
2. **Se ativa**: Mantém usuário como premium
3. **Se expirada/cancelada**: 
   - Reverte para plano básico
   - Atualiza banco de dados
   - Ajusta interface removendo recursos premium
   - Mostra opção de renovar

## Webhook para Notificações em Tempo Real

Para receber notificações em tempo real da Apple/Google sobre cancelamentos:

### Apple (App Store Server Notifications)
1. Configure no App Store Connect
2. URL: `https://seusite.com/api/webhooks/apple`
3. Processar eventos: `DID_CHANGE_RENEWAL_STATUS`, `CANCEL`, `EXPIRED`

### Google (Real-time Developer Notifications)
1. Configure no Google Play Console
2. Use Google Cloud Pub/Sub
3. Processar eventos de cancelamento e expiração

## Testando

1. **Simular expiração**: No sandbox da Apple, assinaturas expiram rapidamente
2. **Cancelamento**: Cancele a assinatura nas configurações do dispositivo
3. **Verificação**: Abra o app e veja se reverte ao plano básico
