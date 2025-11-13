# 🔍 Análise do Problema: Usuários "tempuser_" sendo criados automaticamente

## ❌ PROBLEMA PRINCIPAL IDENTIFICADO

### O que está acontecendo:
1. **NÃO há criação automática de usuário ao abrir o app** ✅ (isso está correto)
2. **O problema está no fluxo de compras/IAP** ❌

## 📍 Onde está o problema:

### Arquivo: `/lib/main.dart` - Linha 647-657

```dart
// Função: _sendReceiptToBackend
if (_userEmail == null || _userEmail == 'lois@lois.com') {
  print('⚠️ [MAIN] Email inválido ou null, gerando email temporário...');
  String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
  _userEmail = 'temp_user_$timestamp@sentiments.app';  // ⚠️ PROBLEMA AQUI!
  print('📧 [MAIN] Email temporário gerado: $_userEmail');
  
  // Salvar no localStorage também
  await _webViewController.evaluateJavascript(
    source: "localStorage.setItem('user_email', '$_userEmail')"
  );
}
```

### O problema ocorre quando:
1. Usuário tenta fazer uma compra premium
2. Sistema não tem email salvo (`_userEmail == null`)
3. Código cria automaticamente um `temp_user_` para processar a compra
4. Este email temporário é salvo no localStorage
5. Quando app reabre, encontra este email temporário e mantém

## 🔄 Fluxo atual (INCORRETO):

```
1. App abre → Valida token (✅ correto)
2. Usuário navega no app
3. Usuário tenta comprar premium
4. Sistema verifica _userEmail
5. Se null → CRIA temp_user_ (❌ ERRO!)
6. Salva temp_user_ no localStorage
7. Próxima abertura → temp_user_ persiste
```

## ✅ Como deveria ser:

```
1. App abre → Valida token
2. Usuário navega no app
3. Usuário tenta comprar premium
4. Sistema verifica se tem usuário autenticado
5. Se não tem → EXIGIR login/cadastro primeiro
6. Só processar compra com usuário real
```

## 🔍 Outros pontos verificados:

### 1. **createUserWithSchedules** (linha 2649-2747)
- ✅ Só cria usuário quando explicitamente chamado pelo JavaScript
- ✅ Não é chamado automaticamente

### 2. **_handleFirebaseAuth** (linha 1973-2051)
- ✅ Só é chamado quando já tem email
- ✅ Ignora emails temporários
- ✅ Não cria usuários automaticamente

### 3. **_checkLocalStorage** (linha 1829-1971)
- ✅ Apenas monitora mudanças
- ✅ Não cria usuários
- ✅ Só reage a mudanças vindas do WebView

## 🛠 SOLUÇÃO PROPOSTA:

### 1. Corrigir `_sendReceiptToBackend`:

```dart
Future<Map<String, dynamic>?> _sendReceiptToBackend(Map<String, dynamic> purchaseData) async {
  // ... código anterior ...
  
  if (_userEmail == null || _userEmail == 'lois@lois.com') {
    print('❌ [MAIN] Compra bloqueada - usuário não autenticado');
    
    // Notificar JavaScript que precisa fazer login
    await _webViewController.evaluateJavascript(source: '''
      console.error('Usuário não autenticado - redirecionando para login');
      if (window.onPurchaseRequiresAuth) {
        window.onPurchaseRequiresAuth();
      } else {
        window.location.href = '/premium-login';
      }
    ''');
    
    return {
      'success': false,
      'error': 'Usuario não autenticado',
      'requiresAuth': true
    };
  }
  
  // Continuar com o processamento normal...
}
```

### 2. Adicionar validação no AuthService:

```dart
// No validateTokenOnStartup
if (token != null) {
  // Verificar se é um token de temp_user
  final userData = await getUserData();
  if (userData?['email']?.contains('temp_user_') == true) {
    // Limpar dados temporários
    await clearAuth();
    debugPrint('[AUTH] Removendo usuário temporário inválido');
    return;
  }
}
```

## 📊 Impacto da correção:

### Antes:
- Usuários temporários criados automaticamente
- Nome "tempuser_" persistindo
- Múltiplos usuários sendo criados
- Confusão de identidade

### Depois:
- Só cria usuário quando explicitamente solicitado
- Compras exigem autenticação real
- Dados persistem corretamente
- Uma conta por usuário

## 🎯 Ações necessárias:

1. **URGENTE**: Remover criação de `temp_user_` em `_sendReceiptToBackend`
2. **IMPORTANTE**: Adicionar validação de autenticação antes de compras
3. **RECOMENDADO**: Limpar usuários temporários existentes no banco
4. **FUTURO**: Implementar fluxo de onboarding mais claro

## 🐛 Bug relacionados resolvidos:

- #182 - Maria Rita: nome volta para tempuser_ ao reabrir
- #124 - Problema similar de persistência
- Múltiplos usuários sendo criados para mesma pessoa

## 📝 Notas adicionais:

- O código de autenticação por tokens está correto
- O problema NÃO está na abertura do app
- O problema é específico do fluxo de compras (IAP)
- Emails temporários nunca deveriam ser criados automaticamente