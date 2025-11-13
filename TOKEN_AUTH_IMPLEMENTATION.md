# Implementação de Autenticação por Token - Sentiments App

## Visão Geral
Sistema de autenticação baseado em tokens persistentes para resolver problemas de perda de sessão quando o app é fechado/reaberto.

## Arquivos Modificados

### 1. `/lib/services/auth_service.dart` (NOVO)
Serviço centralizado de autenticação que gerencia:
- Armazenamento seguro de tokens usando `flutter_secure_storage`
- Comunicação com endpoints Laravel para login/registro/validação
- Sincronização de dados do usuário
- Logout e limpeza de dados

### 2. `/lib/main.dart`
Atualizações no WebViewScreen:
- Validação de token ao iniciar o app
- Interceptação de navegações para adicionar token nas URLs
- Sincronização de token com localStorage do JavaScript
- Handlers JavaScript para login/logout/registro

## Fluxo de Autenticação

### 1. Ao Abrir o App
```dart
// Em initState() do WebViewScreen
_validateTokenOnStartup() {
  // Valida token com backend
  // Redireciona baseado em perguntas_completas
  // Sincroniza com WebView localStorage
}
```

### 2. Durante Navegação
```dart
// Em shouldOverrideUrlLoading
if (url.contains('sentiments.skalacode.com') && !url.contains('token=')) {
  // Adiciona token automaticamente
  final urlWithToken = await AuthService.getUrlWithToken(url);
  controller.loadUrl(urlWithToken);
}
```

### 3. Sincronização JavaScript
```dart
// Em onLoadStop
if (token != null) {
  await controller.evaluateJavascript(source: '''
    localStorage.setItem('auth_token', '$token');
    localStorage.setItem('user_id', '${userData['id']}');
  ''');
}
```

## Endpoints Laravel

### Endpoints Implementados
- `POST /api/auth/login` - Login com email/senha
- `POST /api/auth/register` - Registro de novo usuário
- `POST /api/auth/validate` - Validação de token
- `POST /api/auth/logout` - Invalidação de token
- `POST /api/auth/auto-register` - Auto-registro para usuários gratuitos
- `GET /api/auth/check-session` - Verificação de status da sessão

## Handlers JavaScript

### Handlers Disponíveis no WebView
```javascript
// Salvar dados de autenticação
flutter_inappwebview.callHandler('saveAuthData', {
  token: 'token-aqui',
  user: { id: 123, email: 'user@example.com' }
});

// Recuperar dados salvos
flutter_inappwebview.callHandler('getAuthData');

// Fazer logout
flutter_inappwebview.callHandler('userLogout');

// Auto-registro (usuários gratuitos)
flutter_inappwebview.callHandler('createUserWithSchedules', 
  'Nome Usuario', 
  ['10:00', '14:00', '20:00']
);
```

## Storage de Dados

### Token (Seguro)
- Armazenado em `FlutterSecureStorage`
- Chave: `auth_token`

### Dados do Usuário (SharedPreferences)
- `user_id`: ID do usuário
- `user_email`: Email do usuário
- `user_name`: Nome do usuário
- `perguntas_completas`: Status das perguntas iniciais
- `plano_id`: ID do plano atual
- `tema_id`: ID do tema selecionado

## Logs de Debug

O sistema inclui logs detalhados para troubleshooting:
```
[AUTH] Token recuperado: abc123def4...
[AUTH] Validando token ao abrir app...
[AUTH] Token válido, perguntas completas: true
[AUTH] URL inicial atualizada para: https://sentiments.skalacode.com/dashboard?token=...
[AUTH] Adicionando token à navegação: /profile
[AUTH] Token sincronizado com localStorage
```

## Cenários de Teste

### 1. Primeira Instalação
- App limpa dados antigos
- Usuário faz onboarding
- Token é gerado e salvo
- Próxima abertura mantém sessão

### 2. Usuário Retornando
- App valida token ao abrir
- Se válido: redireciona para dashboard/perguntas
- Se inválido: limpa dados e vai para login

### 3. Logout
- Token invalidado no backend
- Storage local limpo
- Cookies e cache limpos
- Redirecionamento para login

### 4. Navegação Interna
- Todas URLs automaticamente incluem token
- JavaScript pode acessar token via localStorage
- Sincronização bidirecional Flutter ↔ WebView

## Problemas Resolvidos

✅ Perda de sessão ao fechar/reabrir app
✅ Usuários voltando para telas erradas
✅ Inconsistência entre Flutter e WebView
✅ Falta de persistência em cookies/sessões Laravel

## Próximos Passos

1. Testar em dispositivos reais (iOS e Android)
2. Implementar refresh token para sessões longas
3. Adicionar analytics de falhas de autenticação
4. Considerar migração para OAuth2 no futuro