# Debug In-App Purchase Android

## Checklist de Verificação

### 1. ✅ Package Name
- App: `com.mycompany.sentiments`
- Correto no build.gradle

### 2. ✅ Product ID no Console
- ID criado: `com.mycompany.sentiments.premium_yearly`
- Status: Ativo
- Plano: yearly (anual)

### 3. Possíveis Problemas:

#### A. **Tempo de Propagação**
- Produtos novos podem levar 1-24 horas para propagar
- Solução: Aguardar mais tempo

#### B. **App não está "publicado" suficiente**
- O app precisa estar pelo menos em "Teste Interno" com status "Disponível"
- Não funciona em "Rascunho" ou "Em revisão"

#### C. **Conta de teste**
- Você está testando com uma conta Google diferente da conta de desenvolvedor?
- A conta precisa estar na lista de testadores E ter aceitado o convite

#### D. **Cache do Google Play**
- Limpe o cache do Google Play Store no dispositivo
- Settings > Apps > Google Play Store > Storage > Clear Cache

#### E. **Instalação**
- O app DEVE ser instalado via Google Play (link de teste)
- NÃO funciona com APK instalado diretamente

## Teste com IDs alternativos

O código agora tenta múltiplas variações:
1. `com.mycompany.sentiments.premium_yearly` (ID completo)
2. `premium_yearly` (ID simples)
3. `yearly` (nome do plano básico)
4. `com.mycompany.sentiments.premium_yearly:yearly` (ID com sufixo)

## Como verificar no dispositivo:

```bash
# Ver logs em tempo real
adb logcat | grep IAP

# Limpar dados do Google Play
adb shell pm clear com.android.vending
```

## Se nada funcionar:

### Opção 1: Criar produto com ID simples
No Google Play Console, crie NOVO produto:
- ID: `premium_yearly` (sem prefixo)
- Deixe o antigo ativo também

### Opção 2: Verificar com suporte Google
- Play Console > Ajuda > Contatar suporte
- Pergunte sobre "Product not found in billing library"

## Logs esperados quando funcionar:
```
✅ [IAP] 1 produtos carregados com sucesso!
✅ [IAP] IDs encontrados:
   📋 com.mycompany.sentiments.premium_yearly: Premium Anual - R$ 199,90
```