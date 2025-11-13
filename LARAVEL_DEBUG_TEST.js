// TESTE PARA LARAVEL - Execute no Console do Navegador

// 1. TESTE BÁSICO - Verificar se Flutter está escutando
console.log('🧪 [TESTE 1] Testando comunicação Flutter...');
localStorage.setItem('test_communication', 'flutter_test');

// Aguardar 3 segundos e verificar se Flutter removeu o item
setTimeout(() => {
    const check = localStorage.getItem('test_communication');
    if (!check) {
        console.log('✅ [TESTE 1] Flutter está escutando localStorage!');
    } else {
        console.log('❌ [TESTE 1] Flutter NÃO está escutando localStorage');
    }
}, 3000);

// 2. TESTE WhatsApp - COM imagem (deve abrir menu compartilhamento)
function testWhatsAppComImagem() {
    console.log('🧪 [TESTE 2] Enviando dados COM imagem para WhatsApp...');
    
    localStorage.setItem('affirmation_to_share', JSON.stringify({
        blobUrl: 'https://via.placeholder.com/400x400/FF6B6B/FFFFFF?text=TESTE',
        text: '🧪 TESTE: Esta mensagem deve abrir o menu de compartilhamento com imagem anexada!'
    }));
    
    console.log('✅ [TESTE 2] Dados enviados. Aguarde 3 segundos...');
}

// 3. TESTE WhatsApp - SEM imagem (deve apenas compartilhar texto)
function testWhatsAppSemImagem() {
    console.log('🧪 [TESTE 3] Enviando dados SEM imagem...');
    
    localStorage.setItem('affirmation_to_share', JSON.stringify({
        text: '🧪 TESTE: Esta mensagem deve abrir compartilhamento apenas com texto (sem imagem)'
    }));
    
    console.log('✅ [TESTE 3] Dados enviados. Aguarde 3 segundos...');
}

// 4. TESTE Específico WhatsApp (usando nova chave)
function testWhatsAppEspecifico() {
    console.log('🧪 [TESTE 4] Enviando diretamente para WhatsApp...');
    
    localStorage.setItem('whatsapp_share', JSON.stringify({
        imageUrl: 'https://via.placeholder.com/400x400/28A745/FFFFFF?text=WHATSAPP',
        texto: '🧪 TESTE WHATSAPP: Esta mensagem deve abrir diretamente no WhatsApp!',
        fileName: 'teste_whatsapp.png'
    }));
    
    console.log('✅ [TESTE 4] Dados enviados. Aguarde 3 segundos...');
}

// 5. VERIFICAR dados atuais no localStorage
function verificarDadosAtuais() {
    console.log('🔍 [VERIFICAÇÃO] Dados atuais no localStorage:');
    
    const affirmation = localStorage.getItem('affirmation_to_share');
    const whatsapp = localStorage.getItem('whatsapp_share');
    const pending = localStorage.getItem('pending_image_save');
    
    console.log('affirmation_to_share:', affirmation);
    console.log('whatsapp_share:', whatsapp);
    console.log('pending_image_save:', pending);
}

// EXECUTAR TESTES
console.log('🚀 INICIANDO TESTES LARAVEL → FLUTTER');
console.log('');
console.log('Execute os comandos abaixo para testar:');
console.log('1. testWhatsAppComImagem()     - Teste com imagem');
console.log('2. testWhatsAppSemImagem()     - Teste sem imagem');  
console.log('3. testWhatsAppEspecifico()    - Teste chave específica');
console.log('4. verificarDadosAtuais()     - Ver dados atuais');
console.log('');
console.log('IMPORTANTE: Aguarde 3 segundos entre cada teste!');

// AUTO-EXECUTAR teste básico
// Descomente a linha abaixo para executar automaticamente:
// testWhatsAppComImagem();