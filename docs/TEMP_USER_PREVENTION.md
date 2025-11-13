# Solução para Prevenir temp_users Após Reinstalação

## Problema Identificado

Quando o usuário desinstala e reinstala o app, está sendo criado automaticamente um `temp_user_timestamp@sentiments.app` em vez de mostrar o onboarding. Isso acontece porque dados podem persistir no Keychain (iOS) ou Keystore (Android).

## Soluções Implementadas

### 1. Melhorias no Flutter

#### A) FirstRunManager Aprimorado
- ✅ **Detecção mais robusta**: Combina SharedPreferences + SecureStorage
- ✅ **Limpeza completa**: Remove localStorage, cookies, IndexedDB, cache
- ✅ **Prevenção específica**: Remove dados que contenham "temp_", "user", "auth"

#### B) Nova dependência adicionada:
```yaml
flutter_secure_storage: ^9.2.2
```

### 2. Solução Dupla Recomendada (Flutter + Laravel)

#### A) No Laravel - Bloquear temp_users

```php
// AuthController.php ou similar
public function preventTempUsers(Request $request)
{
    $email = $request->input('email');
    
    // Bloquear criação de temp_users
    if (str_contains($email, 'temp_user_') || str_ends_with($email, '@sentiments.app')) {
        return response()->json([
            'error' => 'temp_user_blocked',
            'message' => 'Usuários temporários não são permitidos',
            'action' => 'redirect_onboarding'
        ], 400);
    }
    
    // Continuar processo normal...
}

// Middleware para verificar em todas as rotas de auth
public function handle($request, Closure $next)
{
    $email = $request->input('email') ?? $request->user()?->email;
    
    if ($email && (str_contains($email, 'temp_user_') || str_ends_with($email, '@sentiments.app'))) {
        // Forçar logout e limpar sessão
        Auth::logout();
        return response()->json([
            'error' => 'temp_user_detected',
            'action' => 'force_onboarding'
        ], 401);
    }
    
    return $next($request);
}
```

#### B) JavaScript no Frontend Laravel

```javascript
// Interceptar tentativas de login/registro de temp_users
function checkTempUser(email) {
    if (email && (email.includes('temp_user_') || email.endsWith('@sentiments.app'))) {
        console.warn('🚫 Temp user detectado, redirecionando para onboarding');
        
        // Limpar todos os dados locais
        localStorage.clear();
        sessionStorage.clear();
        
        // Redirecionar para onboarding
        window.location.href = '/onboarding';
        return false;
    }
    return true;
}

// Usar em formulários de login/registro
document.addEventListener('DOMContentLoaded', function() {
    const loginForms = document.querySelectorAll('form[action*="login"], form[action*="register"]');
    
    loginForms.forEach(form => {
        form.addEventListener('submit', function(e) {
            const emailInput = form.querySelector('input[type="email"], input[name="email"]');
            if (emailInput && !checkTempUser(emailInput.value)) {
                e.preventDefault();
                return false;
            }
        });
    });
});
```

## Como Testar

1. **Instalar app** → Fazer onboarding → Usar normalmente
2. **Desinstalar app** → Reinstalar
3. **Resultado esperado**: Mostrar onboarding novamente, não temp_user

## Logs para Debug

Procurar nos logs do Flutter:
- `🆕 [FIRST_RUN] Nova instalação detectada`
- `🔄 [FIRST_RUN] App reinstalado` 
- `🧹 [FIRST_RUN] Limpeza completa realizada`

Procurar nos logs do Laravel:
- `temp_user_blocked` ou `temp_user_detected`

## Próximos Passos

1. ✅ Flutter: Implementado FirstRunManager melhorado
2. ⏳ Laravel: Implementar bloqueio de temp_users
3. ⏳ Testar: Desinstalar/reinstalar e verificar comportamento

## Arquivos Modificados

- `lib/services/first_run_manager.dart` - Detecção melhorada
- `pubspec.yaml` - Nova dependência
- `docs/TEMP_USER_PREVENTION.md` - Este documento