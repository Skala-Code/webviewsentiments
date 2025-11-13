# 📸 Screenshots para In-App Purchases - Guia Completo

## 📋 REQUISITOS DA APPLE

### Tamanho obrigatório:
- **Mínimo**: 640x920 pixels
- **Formato**: PNG ou JPG
- **Orientação**: Portrait (vertical)
- **Qualidade**: Alta resolução, sem blur

## 🎯 O QUE MOSTRAR

### Screenshot deve conter:
1. **Tela de compra do app** mostrando:
   - Nome do produto
   - Preço em R$
   - Descrição do que o usuário recebe
   - Botão "Assinar" ou "Comprar"

2. **Interface do produto premium** (opcional mas recomendado):
   - Funcionalidades desbloqueadas
   - Telas exclusivas do premium
   - Benefícios visíveis

## 📱 COMO CRIAR NO SIMULADOR iOS

### 1. Abrir simulador:
```bash
# No terminal, rode:
open -a Simulator

# Ou pelo Xcode:
# Xcode > Open Developer Tool > Simulator
```

### 2. Configurar device:
- Escolha iPhone 15 Pro (recomendado)
- iOS 17.x ou mais recente
- Configurações > Display & Brightness > Light mode

### 3. Criar tela de compra mock:
- Abra Safari no simulador
- Vá para seu site localhost ou crie HTML temporário
- Mostre interface de assinatura

## 🎨 TEMPLATE HTML PARA SCREENSHOT

Crie um arquivo test_purchase.html:

```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sentiments Premium</title>
    <style>
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            margin: 0;
            padding: 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            min-height: 100vh;
        }
        .container {
            max-width: 350px;
            margin: 0 auto;
            text-align: center;
            padding-top: 60px;
        }
        .logo {
            font-size: 28px;
            font-weight: bold;
            margin-bottom: 10px;
        }
        .subtitle {
            font-size: 16px;
            opacity: 0.9;
            margin-bottom: 40px;
        }
        .plan {
            background: rgba(255,255,255,0.15);
            border-radius: 16px;
            padding: 24px;
            margin: 16px 0;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255,255,255,0.2);
        }
        .plan-name {
            font-size: 20px;
            font-weight: 600;
            margin-bottom: 8px;
        }
        .price {
            font-size: 32px;
            font-weight: bold;
            color: #FFD700;
            margin: 12px 0;
        }
        .price-period {
            font-size: 14px;
            opacity: 0.8;
        }
        .features {
            text-align: left;
            margin: 20px 0;
        }
        .feature {
            display: flex;
            align-items: center;
            margin: 8px 0;
            font-size: 14px;
        }
        .feature::before {
            content: "✓";
            color: #4CAF50;
            font-weight: bold;
            margin-right: 8px;
        }
        .subscribe-btn {
            background: #4CAF50;
            color: white;
            border: none;
            padding: 16px 32px;
            border-radius: 25px;
            font-size: 16px;
            font-weight: 600;
            width: 100%;
            margin-top: 16px;
            box-shadow: 0 4px 15px rgba(76, 175, 80, 0.3);
        }
        .terms {
            font-size: 12px;
            opacity: 0.7;
            margin-top: 20px;
            line-height: 1.4;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="logo">✨ Sentiments</div>
        <div class="subtitle">Desbloqueie todo o potencial</div>
        
        <div class="plan">
            <div class="plan-name">Premium Mensal</div>
            <div class="price">
                R$ 19,90
                <div class="price-period">por mês</div>
            </div>
            
            <div class="features">
                <div class="feature">Acesso ilimitado a todas as frases</div>
                <div class="feature">Salvamento em alta qualidade</div>
                <div class="feature">Compartilhamento sem marca d'água</div>
                <div class="feature">Novos temas exclusivos</div>
                <div class="feature">Suporte prioritário</div>
            </div>
            
            <button class="subscribe-btn">Assinar Agora</button>
        </div>
        
        <div class="terms">
            Renovação automática. Cancele a qualquer momento.<br>
            Termos de uso e política de privacidade se aplicam.
        </div>
    </div>
</body>
</html>
```

### 4. Tirar screenshot:
- **Cmd + S** no simulador
- Salva automaticamente na área de trabalho
- Renomeie para: `sentiments_premium_screenshot.png`

## ✅ CHECKLIST FINAL

- [ ] Resolução mínima 640x920px
- [ ] Mostra claramente o produto e preço
- [ ] Interface limpa e profissional
- [ ] Texto legível e bem contrastado
- [ ] Botão de compra visível
- [ ] Logo/nome do app presente
- [ ] Formato PNG ou JPG
- [ ] Sem elementos cortados nas bordas

## 🎯 DICAS PARA APROVAÇÃO

1. **Seja honesto**: Mostre exatamente o que o usuário vai receber
2. **Visual limpo**: Evite poluição visual
3. **Preço claro**: Sempre em reais (R$)
4. **Call-to-action**: Botão de compra bem visível
5. **Benefícios óbvios**: Liste o que desbloqueia

## 📤 ONDE USAR

Quando criar o produto no App Store Connect:
1. Vá em "Review Information"
2. Upload o screenshot em "Screenshot for Review"
3. Este screenshot é só para análise da Apple, não aparece na App Store

---

💡 **Lembre-se**: Este screenshot é OBRIGATÓRIO para aprovação, mas não aparece para os usuários. É só para a Apple entender o que você está vendendo.