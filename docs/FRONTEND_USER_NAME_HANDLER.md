# 👤 Frontend Laravel - Handler para Capturar Nome do Usuário

## 🎯 **PROBLEMA RESOLVIDO**

O email estava hardcoded como `lois@lois.com`. Agora o Flutter tem um handler para capturar dinamicamente o nome digitado pelo usuário e gerar um email único.

## 📱 **HANDLER FLUTTER IMPLEMENTADO**

```javascript
// Handler disponível: setUserName
flutter_inappwebview.callHandler('setUserName', 'NomeDoUsuario')
```

## 🔧 **COMO USAR NO FRONTEND LARAVEL**

### **1. Quando o usuário digitar o nome no formulário:**

```javascript
// Exemplo: usuário digita "L" no campo nome
const userName = document.getElementById('nome').value; // "L"

// Chamar handler Flutter
if (window.flutter_inappwebview) {
    flutter_inappwebview.callHandler('setUserName', userName)
    .then(function(result) {
        if (result.success) {
            console.log('✅ Email gerado:', result.email);
            // Email será algo como: L_1755799000000@sentiments.app
            
            // Salvar email no localStorage para uso posterior
            localStorage.setItem('user_email', result.email);
        } else {
            console.error('❌ Erro:', result.error);
        }
    })
    .catch(function(error) {
        console.error('❌ Erro ao chamar handler:', error);
    });
}
```

### **2. Formato do email gerado:**
```
{nome}_{timestamp}@sentiments.app

Exemplos:
- L_1755799000000@sentiments.app
- João_1755799000001@sentiments.app  
- Maria_1755799000002@sentiments.app
```

### **3. Fluxo completo:**
```javascript
// 1. Usuário digita nome
const userName = "L";

// 2. Chamar Flutter
flutter_inappwebview.callHandler('setUserName', userName);

// 3. Flutter:
//    - Gera email único: L_1755799000000@sentiments.app
//    - Salva no localStorage
//    - Autentica no Firebase
//    - Cria usuário no backend se não existir

// 4. Quando fizer IAP:
//    - Flutter usa o email gerado automaticamente
//    - Backend recebe L_1755799000000@sentiments.app
//    - Ativa active_plan = true para este email
```

## ⚡ **IMPLEMENTAÇÃO IMEDIATA**

### **No formulário de cadastro/login:**
```html
<input type="text" id="nome" placeholder="Digite seu nome">
<button onclick="setUserName()">Continuar</button>

<script>
function setUserName() {
    const userName = document.getElementById('nome').value.trim();
    
    if (!userName) {
        alert('Digite seu nome');
        return;
    }
    
    // Chamar Flutter
    flutter_inappwebview.callHandler('setUserName', userName)
    .then(function(result) {
        if (result.success) {
            console.log('✅ Usuário configurado:', result.email);
            // Redirecionar para próxima página
            window.location.href = '/perguntas';
        }
    });
}
</script>
```

## 🔍 **LOGS ESPERADOS**
Quando o usuário digitar "L":
```
👤 [HANDLER] Nome capturado: L
📧 [HANDLER] Email gerado: L_1755799000000@sentiments.app
```

## ✅ **BENEFÍCIOS:**
1. **Email único** para cada usuário
2. **Sem hardcode** - dinâmico baseado no nome
3. **Timestamp único** evita duplicatas  
4. **Integração automática** com IAP
5. **Criação automática** de usuário no backend

---

**🚀 PRÓXIMO PASSO:** Implementar a chamada `setUserName()` no formulário onde o usuário digita o nome!