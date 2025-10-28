import os
import requests
import base64
import re # Para manipulação de texto (HTML)
from urllib.parse import urlparse, parse_qs

# ===============================================
# CONFIGURAÇÕES GERAIS (PREENCHA ESTAS VARIÁVEIS!)
# ===============================================
# Token de Acesso Pessoal (PAT) do GitHub
# (Será injetado como variável de ambiente no Render)
GITHUB_TOKEN = os.environ.get('GITHUB_TOKEN', 'SEU_PAT_AQUI') 

# Repositório no GitHub
REPO_OWNER = 'waldeckgil'
REPO_NAME = 'FACANACAVEIRA'
BRANCH = 'main'
# Caminho da pasta de fotos no GitHub
GITHUB_PHOTO_PATH = 'GALERIA/'
# Caminho do arquivo HTML da galeria
GITHUB_HTML_PATH = 'galeria.html' 
# URL base da API do GitHub
API_URL = f'https://api.github.com/repos/{REPO_OWNER}/{REPO_NAME}/contents/'

# ID da pasta do Google Drive: 1dxlGc9W3zBCdLmLA5FUtW4SPt18ee8nf
DRIVE_FOLDER_ID = '1dxlGc9W3zBCdLmLA5FUtW4SPt18ee8nf'
# Diretório temporário
DOWNLOAD_DIR = 'temp_photos'

# ===============================================
# 1. FUNÇÕES DO GOOGLE DRIVE (SIMPLIFICADAS)
# ===============================================

def get_drive_file_list(folder_id):
    """Obtém a lista de arquivos da pasta pública do Drive."""
    # API pública do Google Drive para listar arquivos
    url = f"https://www.googleapis.com/drive/v3/files?q='{folder_id}'+in+parents&fields=files(id,name)&key=SUA_CHAVE_API_AQUI"
    # NOTA: O Google Drive pode limitar a requisição sem uma 'API Key'. 
    # Usaremos uma alternativa mais robusta no download abaixo.

    # Usando uma abordagem mais simples e robusta: a API de listagem do Google Drive,
    # que é a mais simples para pastas públicas. A chave API é opcional para listagem pública.
    
    # URL da API para listar arquivos (Files API)
    list_url = f'https://www.googleapis.com/drive/v3/files?q="{folder_id}"+in+parents+and+mimeType!="application/vnd.google-apps.folder"&fields=files(id,name)&key='
    
    response = requests.get(list_url)
    if response.status_code == 200:
        return response.json().get('files', [])
    else:
        print(f"❌ Erro ao listar arquivos do Drive. Status: {response.status_code}")
        print("Certifique-se de que a pasta está pública e tente novamente mais tarde.")
        return []


def download_file(file_id, file_name):
    """Faz o download de um arquivo individual do Drive."""
    # URL de download direto (pode ser usado para arquivos públicos)
    download_url = f'https://drive.google.com/uc?export=download&id={file_id}'
    
    local_path = os.path.join(DOWNLOAD_DIR, file_name)

    try:
        response = requests.get(download_url, stream=True)
        response.raise_for_status() # Lança erro para 4xx/5xx status
        
        # O Google Drive às vezes redireciona para um link 'confirm'
        if 'confirm' in response.url:
            match = re.search(r'confirm=([0-9A-Za-z]+)', response.url)
            if match:
                confirm_token = match.group(1)
                download_url = f'{download_url}&confirm={confirm_token}'
                response = requests.get(download_url, stream=True)
                response.raise_for_status()

        with open(local_path, 'wb') as f:
            for chunk in response.iter_content(chunk_size=8192):
                f.write(chunk)
        return True
    except requests.exceptions.RequestException as e:
        print(f"❌ Erro ao baixar '{file_name}': {e}")
        return False

# ===============================================
# 2. FUNÇÕES DO GITHUB
# ===============================================

def get_github_file(path):
    """Busca um arquivo (e seu SHA) do GitHub."""
    headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    url = API_URL + path
    response = requests.get(url, headers=headers)
    
    if response.status_code == 200:
        data = response.json()
        # Retorna o conteúdo decodificado e o SHA (necessário para atualizar)
        content = base64.b64decode(data['content']).decode('utf-8')
        return content, data['sha']
    else:
        # Se não encontrar (404), o SHA é None, e o upload será uma criação (POST)
        return None, None


def upload_or_update_file(path, content_bytes, commit_message, sha=None):
    """Faz o upload ou a atualização de um arquivo no GitHub."""
    if not GITHUB_TOKEN:
        print("❌ ERRO: GITHUB_TOKEN não configurado.")
        return False
        
    encoded_content = base64.b64encode(content_bytes).decode('utf-8')

    payload = {
        "message": commit_message,
        "content": encoded_content,
        "branch": BRANCH
    }
    if sha:
        payload["sha"] = sha # Adiciona SHA para atualização

    headers = {"Authorization": f"token {GITHUB_TOKEN}", "Accept": "application/vnd.github.v3+json"}
    url = API_URL + path
    
    response = requests.put(url, json=payload, headers=headers)

    if response.status_code in [200, 201]: # 200=Update, 201=Create
        action = "Atualizado" if sha else "Criado"
        print(f"✅ Sucesso: Arquivo '{path}' {action}.")
        return True
    else:
        print(f"❌ Erro no upload/update de {path}. Status: {response.status_code}")
        print(f"Resposta: {response.json()}")
        return False

def update_html(new_photos):
    """Lê, insere as novas fotos no HTML e atualiza o arquivo no GitHub."""
    
    # 1. Obter o HTML atual e o SHA
    html_content, sha = get_github_file(GITHUB_HTML_PATH)
    if not html_content:
        print(f"❌ Não foi possível obter {GITHUB_HTML_PATH}. Saindo.")
        return False

    # 2. Definir o ponto de inserção no HTML (antes do </section>)
    # O HTML da sua galeria termina a seção com: </section>\n\n    </main>
    INSERT_MARKER = '</section>'
    
    if INSERT_MARKER not in html_content:
        print("❌ Marcador de inserção não encontrado no HTML.")
        return False

    # 3. Gerar o novo código HTML para as fotos
    new_html_entries = ""
    for name in new_photos:
        # Cria a tag <a> completa, usando o caminho da pasta GALERIA/
        entry = f'    <a href="{GITHUB_PHOTO_PATH}{name}" target="_blank"><img src="{GITHUB_PHOTO_PATH}{name}" alt="Nova Foto da Galeria" class="foto-galeria"></a>\n'
        new_html_entries += entry

    # 4. Inserir as novas entradas ANTES do marcador </section>
    new_html_content = html_content.replace(INSERT_MARKER, new_html_entries + INSERT_MARKER)

    # 5. Fazer o commit do HTML atualizado
    commit_msg = f"Automatic Sync: Adicionadas {len(new_photos)} novas fotos à galeria."
    return upload_or_update_file(
        GITHUB_HTML_PATH, 
        new_html_content.encode('utf-8'), # Conteúdo tem que ser em bytes
        commit_msg, 
        sha # Passa o SHA para garantir que a atualização funcione
    )


# ===============================================
# 3. LÓGICA PRINCIPAL
# ===============================================

def main_sync():
    if not GITHUB_TOKEN:
        print("Falha na execução: Variável de ambiente GITHUB_TOKEN não configurada.")
        return

    if not os.path.exists(DOWNLOAD_DIR):
        os.makedirs(DOWNLOAD_DIR)

    # 1. Obter lista de arquivos no Drive
    drive_files = get_drive_file_list(DRIVE_FOLDER_ID)
    if not drive_files:
        print("Não há arquivos para processar no Google Drive ou houve um erro de acesso.")
        return
        
    print(f"Iniciando sincronização. Encontrados {len(drive_files)} itens no Drive.")
    
    new_photos_to_commit = []

    # 2. Processar cada arquivo do Drive
    for file in drive_files:
        file_id = file['id']
        file_name = file['name']
        local_path = os.path.join(DOWNLOAD_DIR, file_name)
        
        # 2a. Verifica se o arquivo já foi commitado no GitHub (assumindo que o nome é único)
        # Uma verificação mais robusta:
        # Você pode manter uma lista de nomes de arquivos já processados em um arquivo TXT
        # dentro do repositório, como você tem um 'automação_fotos.txt'.
        
        # PULAR VERIFICAÇÃO SIMPLES: Se você assumir que só arquivos novos serão colocados no Drive
        # e que a pasta de download temporária será esvaziada entre execuções do Cron Job.
        
        # PARA ESTE ROTEIRO, VAMOS ASSUMIR QUE SE O ARQUIVO ESTIVER NO DRIVE, ELE DEVE SER PROCESSADO.
        # A API do GitHub cuidará de não duplicar arquivos se tentarmos subir o mesmo nome.

        # 2b. Baixar o arquivo (se necessário)
        if download_file(file_id, file_name):
            
            # 2c. Fazer o upload para o GitHub
            commit_msg = f"Foto do Drive: {file_name}"
            
            with open(local_path, 'rb') as f:
                content_bytes = f.read()

            if upload_or_update_file(GITHUB_PHOTO_PATH + file_name, content_bytes, commit_msg):
                new_photos_to_commit.append(file_name)
            
            # Limpeza: Deleta o arquivo temporário após o upload para economizar espaço no Render
            os.remove(local_path)
            
    # 3. Atualizar o HTML se novas fotos foram commitadas
    if new_photos_to_commit:
        print(f"\n>>>> Total de {len(new_photos_to_commit)} novas fotos commitadas. Atualizando galeria.html...")
        update_html(new_photos_to_commit)
    else:
        print("\nNenhuma nova foto encontrada ou commitada. galeria.html não foi alterado.")

    print("\nSincronização concluída.")
    
if __name__ == '__main__':
    main_sync()