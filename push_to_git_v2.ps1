// ===============================================
// CONFIGURAÇÕES GERAIS E VARIÁVEIS DO PROJETO
// ===============================================
const DRIVE_FOLDER_ID = '1dxlGc9W3zBCdLmLA5FUtW4SPt18ee8nf'; // Seu ID da pasta do Drive
const REPO_OWNER = 'waldeckgil'; // Proprietário do repositório
const REPO_NAME = 'FACANACAVEIRA'; // Nome do repositório
const BRANCH = 'main'; // Branch principal do repositório

// Caminhos no repositório GitHub
const GITHUB_PHOTO_PATH = 'GALERIA/';
const GITHUB_HTML_PATH = 'galeria.html';

// **************** CORRIGIDO ****************
const HTML_MARKER_START = ''; 
const HTML_MARKER_END = '';
// *******************************************


// ===============================================
// 1. FUNÇÕES DO FRONTEND (doGet)
// ===============================================

/**
 * Função para servir a interface web (frontend).
 * Retorna o Page.html.
 */
function doGet() {
  return HtmlService.createTemplateFromFile('Page')
      .evaluate()
      .setTitle('Atualizar Galeria - FACA NA CAVEIRA')
      .addMetaTag('viewport', 'width=device-width, initial-scale=1.0');
}


// ===============================================
// 2. FUNÇÃO PRINCIPAL DE SINCRONIZAÇÃO
// ===============================================

/**
 * Função principal que orquestra a sincronização.
 */
function syncGallery() {
  Logger.log('Iniciando sincronização da galeria...');
  
  try {
    const folder = DriveApp.getFolderById(DRIVE_FOLDER_ID);
    const files = folder.getFiles();
    const allPhotoRefs = [];
    let uploadCount = 0;
    
    // MIME Types de imagem mais comuns para filtro
    const validImageMimeTypes = [
      MimeType.JPEG, MimeType.PNG, MimeType.GIF, 'image/webp'
    ];
    
    // Busca lista do GitHub antes do loop para otimização e verificação SHA
    const githubContentList = githubApiFetch(GITHUB_PHOTO_PATH);
    if (githubContentList && githubContentList.error) {
        throw new Error(`ERRO FATAL: Falha ao listar conteúdo do GitHub: ${githubContentList.error}`);
    }

    // --- ETAPA 1: PROCESSAR ARQUIVOS DE FOTO ---
    while (files.hasNext()) {
      const file = files.next();
      const fileName = file.getName();
      const fileMimeType = file.getMimeType();

      // Filtro para imagens válidas e ignora arquivos ocultos
      if (!validImageMimeTypes.includes(fileMimeType) || fileName.startsWith('.')) {
        Logger.log(`Pulando arquivo não-imagem ou oculto: ${fileName}`);
        continue;
      }
      
      Logger.log(`Processando arquivo: ${fileName}`);
      
      // Obter Conteúdo em Base64 e calcular SHA-1 do Drive
      const blob = file.getBlob();
      const driveContent = blob.getBytes();
      const driveSha1 = Utilities.computeDigest(Utilities.DigestAlgorithm.SHA_1, driveContent).map(c => (c < 0 ? c + 256 : c).toString(16).padStart(2, '0')).join('');
      const fileContentBase64 = Utilities.base64Encode(driveContent);

      const githubPath = GITHUB_PHOTO_PATH + fileName;
      let existingFile = null;
      if (githubContentList) {
        existingFile = githubContentList.find(item => item.name === fileName);
      }
      
      let sha = null;
      
      // LÓGICA DE NÃO SOBRESCREVER (Verifica o SHA)
      if (existingFile && existingFile.sha) {
        if (existingFile.sha === driveSha1) {
            Logger.log(`Arquivo ${fileName} já existe. SHA idêntico. Pulando re-upload.`);
        } else {
            // SHA diferente: Atualiza o arquivo
            sha = existingFile.sha;
            Logger.log(`Arquivo ${fileName} já existe. SHA diferente. Será atualizado.`);
            const commitMsg = `[AppsScript] Update do Drive: ${fileName}`;
            const uploadResult = githubApiPut(githubPath, fileContentBase64, commitMsg, sha);
            if (uploadResult && uploadResult.commit) {
                Logger.log(`Upload/Update de ${fileName} concluído.`);
                uploadCount++;
            }
        }
      } else {
        // Arquivo não existe: Cria novo arquivo
        Logger.log(`Arquivo ${fileName} é novo e será criado.`);
        const commitMsg = `[AppsScript] Foto do Drive: ${fileName}`;
        const uploadResult = githubApiPut(githubPath, fileContentBase64, commitMsg, null);
        if (uploadResult && uploadResult.commit) {
            Logger.log(`Upload/Update de ${fileName} concluído.`);
            uploadCount++;
        }
      }
      
      // Constrói o snippet HTML para a lista final
      const photoSnippet = `<a href="${GITHUB_PHOTO_PATH}${fileName}" target="_blank"><img src="${GITHUB_PHOTO_PATH}${fileName}" alt="${fileName}" class="foto-galeria"></a>`;
      allPhotoRefs.push(photoSnippet);
    }
    
    // --- ETAPA 2: ATUALIZAR galeria.html ---
    if (allPhotoRefs.length > 0) { 
      return updateGalleryHtml(allPhotoRefs, uploadCount); 
    } else {
      return 'Nenhuma foto válida encontrada na pasta. galeria.html não atualizado.';
    }

  } catch (e) {
    Logger.log(`ERRO FATAL na sincronização: ${e.toString()}`);
    throw new Error(e.message || e.toString());
  }
}

/**
 * Função corrigida para atualizar o galeria.html no GitHub usando regex robusto.
 */
function updateGalleryHtml(allPhotoRefs, uploadCount) {
  // A. Busca o arquivo galeria.html para obter o SHA
  const htmlFilePath = GITHUB_HTML_PATH;
  const existingHtmlFile = githubApiFetch(htmlFilePath);
  
  if (!existingHtmlFile || !existingHtmlFile.sha || !existingHtmlFile.content) {
    Logger.log('ERRO: Falha ao buscar galeria.html. Verifique o caminho e permissões.');
    throw new Error('Falha ao buscar galeria.html. O arquivo existe?');
  }

  // B. Cria o novo conteúdo da galeria
  const newGalleryHtmlSnippet = allPhotoRefs.join('\n    '); // Junta com indentação
  
  // CORREÇÃO: Decodificação correta de base64 para string UTF-8 em Apps Script
  const bytes = Utilities.base64Decode(existingHtmlFile.content);
  
  // LINHA CORRIGIDA: Força a decodificação como UTF-8 para preservar acentos e caracteres especiais.
  const currentHtmlContent = Utilities.newBlob(bytes).getDataAsString('UTF-8'); // <-- CORRIGIDO AQUI
  
  // LOG: Tamanho do HTML antes da substituição
  Logger.log(`[FINAL DEBUG HTML] Tamanho do HTML ANTES da substituição: ${currentHtmlContent.length} caracteres.`);
  
  // LOG adicional para debug: imprime os primeiros 1000 caracteres para verificar
  Logger.log(`[DEBUG] Primeiros 1000 caracteres do HTML: ${currentHtmlContent.substring(0, 1000)}`);
  
  // --- BUSCA ROBUSTA COM REGEX PARA MARCADORES ---
  // Encontra o início após o comentário GALERIA_START (ignorando espaços/quebras de linha)
  const startMatch = currentHtmlContent.match(//i);
  const endMatch = currentHtmlContent.match(//i);

  if (!startMatch || !endMatch) {
    Logger.log(`[FINAL DEBUG] ERRO CRÍTICO: Marcadores não encontrados.`);
    Logger.log(`Marcador START procurado: `);
    Logger.log(`Marcador END procurado: `);
    // Log adicional para debug: busca por qualquer comentário com GALERIA
    const galeriaComments = currentHtmlContent.match(//gi);
    if (galeriaComments) {
      Logger.log(`Comentários com 'GALERIA' encontrados: ${galeriaComments.join('\n')}`);
    }
    throw new Error('Marcadores GALERIA_START/END não encontrados no HTML. Verifique o arquivo no GitHub.');
  }

  const startIndex = startMatch.index + startMatch[0].length;
  const endIndex = endMatch.index;

  if (startIndex > endIndex) {
    throw new Error('Marcadores START e END estão na ordem incorreta no HTML.');
  }


  // 3. Pega todo o HTML ANTES da área de substituição
  const contentBefore = currentHtmlContent.substring(0, startIndex); 
  
  // 4. Pega todo o HTML DEPOIS da área de substituição (a partir do END)
  const contentAfter = currentHtmlContent.substring(endIndex);
  
  // 5. Monta o novo conteúdo: Antes + Novo Snippet + Depois
  const newHtmlContent = contentBefore + '\n    ' + newGalleryHtmlSnippet + '\n    ' + contentAfter;
  
  // LINHA CORRIGIDA: Garante que o novo conteúdo seja codificado como UTF-8 antes de enviar ao GitHub.
  const newHtmlBase64 = Utilities.base64Encode(newHtmlContent, 'UTF-8'); // <-- CORRIGIDO AQUI

  // LOG: Tamanho do HTML depois da substituição
  Logger.log(`[FINAL DEBUG HTML] Tamanho do HTML DEPOIS da substituição: ${newHtmlContent.length} caracteres.`);

  // C. Commitar o novo HTML
  Logger.log('Commitando novo galeria.html...');
  const htmlCommitMsg = `[AppsScript] Atualização automática da galeria (${allPhotoRefs.length} fotos).`;
  const htmlResult = githubApiPut(htmlFilePath, newHtmlBase64, htmlCommitMsg, existingHtmlFile.sha);
  
  if (htmlResult && htmlResult.commit) {
    Logger.log('galeria.html atualizado com sucesso no GitHub. O Netlify foi acionado.');
    return `Sincronização concluída! ${uploadCount} fotos novas/atualizadas. ${allPhotoRefs.length} fotos no total no galeria.html.`;
  } else {
    Logger.log(`ERRO ao commitar galeria.html: ${JSON.stringify(htmlResult)}`);
    throw new Error('A sincronização de fotos ocorreu, mas a atualização do galeria.html falhou no GitHub.');
  }
}
// ===============================================
// 3. FUNÇÕES DE INTERAÇÃO COM O GITHUB (API)
// ===============================================

function getGithubToken() {
  const token = PropertiesService.getScriptProperties().getProperty('GITHUB_TOKEN');
  if (!token) {
    throw new Error("O GITHUB_TOKEN não foi configurado nas Propriedades do Script. Sincronização interrompida.");
  }
  return token;
}

function githubApiFetch(path) {
  const token = getGithubToken();
  const API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/`;
  const url = API_URL + path + `?ref=${BRANCH}`;
  
  const options = {
    method: 'GET',
    headers: {
      'Authorization': `token ${token}`,
      'Accept': 'application/vnd.github.com.v3.raw' 
    },
    muteHttpExceptions: true
  };
  
  try {
    const response = UrlFetchApp.fetch(url, options);
    if (response.getResponseCode() === 200) {
      const content = JSON.parse(response.getContentText());
      return content;
    }
    return null; 
  } catch (e) {
    Logger.log(`Erro ao buscar ${path}: ${e.message}`);
    return { error: e.message };
  }
} // <--- Fechamento da função githubApiFetch, corrigido o SyntaxError.

function githubApiPut(path, fileContent, message, sha) {
  const token = getGithubToken();
  const API_URL = `https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/contents/`;
  const url = API_URL + path;
  
  const payload = {
    message: message,
    content: fileContent, 
    branch: BRANCH
  };
  
  if (sha) {
    payload.sha = sha; 
  }

  const options = {
    method: 'PUT',
    headers: {
      'Authorization': `token ${token}`,
      'Accept': 'application/vnd.github.v3+json'
    },
    payload: JSON.stringify(payload),
    muteHttpExceptions: true
  };

  try {
    const response = UrlFetchApp.fetch(url, options);
    if (response.getResponseCode() === 201 || response.getResponseCode() === 200) {
      return JSON.parse(response.getContentText());
    } else {
      throw new Error(`Falha no commit: ${response.getContentText()}`);
    }
  } catch (e) {
    throw new Error(`ERRO FATAL na sincronização: ${e.message}`);
  }
}