# push_to_git_v2.ps1
# Lembre-se: Salve este script com a codificação UTF-8 para evitar problemas com acentuação.

# Define o caminho absoluto para o executável do Git.
# Isso resolve o problema da tela "Selecionar um aplicativo para abrir 'git'".
$gitExe = "C:\Program Files\Git\bin\git.exe"

# ---
# PERGUNTA AO USUÁRIO
# ---
Write-Host "Este é o primeiro envio deste projeto para o GitHub? (S/N)"
$isFirstPush = Read-Host

# ---
# LÓGICA DO SCRIPT
# ---
if ($isFirstPush.ToUpper() -eq "S") {
    # ---
    # BLOCO DE COMANDOS PARA O PRIMEIRO ENVIO
    # ---
    Write-Host "---"
    Write-Host "Configuração inicial para o primeiro envio ao GitHub."
    Write-Host " "
    Write-Host "Lembrete Importante: Por favor, crie primeiro o repositório vazio no GitHub."
    Write-Host "O script só consegue enviar arquivos para um repositório que já existe."
    Write-Host " "

    # Solicita o nome do repositório
    Write-Host "Por favor, digite o nome do repositório a ser criado no GitHub:"
    $repoName = Read-Host

    # Informa o nome de usuário do GitHub
    $githubUser = "Waldeckgil"
    Write-Host "O seu usuário do GitHub é: $githubUser"

    # Inicializa o repositório Git localmente
    Write-Host "Executando: $gitExe init"
    & $gitExe init

    # Conecta o repositório local ao repositório remoto no GitHub
    $remoteUrl = "https://github.com/$githubUser/$repoName.git"
    Write-Host "Executando: $gitExe remote add origin $remoteUrl"
    & $gitExe remote add origin $remoteUrl

    Write-Host "Configuração inicial concluída."
    Write-Host "---"

} else {
    # ---
    # BLOCO DE COMANDOS PARA ENVIOS SUBSEQUENTES
    # ---
    Write-Host "---"
    Write-Host "Iniciando processo de commit e push para o repositório existente."
}

# ---
# BLOCO DE COMANDOS PARA COMIT E PUSH (COMUM AOS DOIS CENÁRIOS)
# ---

# *** COMANDO ADICIONADO PARA GARANTIR O NOME DO BRANCH ***
Write-Host "Executando: $gitExe branch -M main (garantindo o nome correto do branch: master -> main)"
& $gitExe branch -M main

# Comando para remover .env do cache. Adicionar ao .gitignore é a melhor prática.
# Foi envolvido em um bloco 'try' para ignorar o erro fatal se o arquivo não estiver rastreado.
try {
    Write-Host "Executando: $gitExe rm --cached .env (Ignorando se o arquivo não estiver rastreado)"
    & $gitExe rm --cached .env | Out-Null
} catch {
    Write-Host "Aviso: O arquivo .env não estava rastreado. Continuar..."
}

# Adiciona todos os arquivos alterados ao stage
Write-Host "Executando: $gitExe add ."
& $gitExe add .

# Solicita a mensagem do commit
Write-Host "Digite a mensagem do commit:"
$commitMessage = Read-Host

# Verifica se a mensagem de commit não está vazia
if ([string]::IsNullOrEmpty($commitMessage)) {
    Write-Host "Mensagem de commit não pode ser vazia. O script foi abortado."
    exit
}

# Realiza o commit com a mensagem fornecida
Write-Host "Executando: $gitExe commit -m `"$commitMessage`""
& $gitExe commit -m "$commitMessage"

# *** NOVO COMANDO: