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

    # Remove o arquivo .env do cache do Git para que ele não seja rastreado (Opcional, mas seguro)
    Write-Host "Executando: $gitExe rm --cached .env"
    & $gitExe rm --cached .env

    # Adiciona todos os arquivos alterados ao stage (necessário para criar o commit)
    Write-Host "Executando: $gitExe add ."
    & $gitExe add .
    
    # Realiza o commit inicial (temporário - cria o branch 'master' local)
    Write-Host "Executando: $gitExe commit -m \"Primeiro commit inicial\""
    & $gitExe commit -m "Primeiro commit inicial"

    # Conecta o repositório local ao repositório remoto no GitHub
    $remoteUrl = "https://github.com/$githubUser/$repoName"
    Write-Host "Executando: $gitExe remote add origin $remoteUrl"
    & $gitExe remote add origin $remoteUrl
    
    # *** COMANDO ADICIONADO AQUI: DEFINE O NOME DO BRANCH CORRETO ***
    Write-Host "Executando: $gitExe branch -M main (renomeando o branch para 'main')"
    & $gitExe branch -M main
    
    # Realiza o push
    Write-Host "Executando: $gitExe push -u origin main (enviando o branch 'main' e configurando o upstream)"
    & $gitExe push -u origin main
    
    Write-Host "---"
    Write-Host "Primeiro envio concluído com sucesso!"
    
} else {
    # ---
    # BLOCO DE COMANDOS PARA ENVIOS SUBSEQUENTES
    # ---
    Write-Host "---"
    Write-Host "Executando commit e push para o repositório existente."
    
    # *** IMPORTANTE: SINCRONIZAR COM O REMOTO ***
    # Isso resolve o erro de [rejected] se o remoto tiver alterações (ex: README.md)
    Write-Host "Executando: $gitExe pull origin main (Sincronizando com o remoto)"
    & $gitExe pull origin main
    
    # Remove o arquivo .env do cache do Git para que ele não seja rastreado
    Write-Host "Executando: $gitExe rm --cached .env"
    & $gitExe rm --cached .env

    # Adiciona todos os arquivos alterados ao stage
    Write-Host "Executando: $gitExe add . (Adicionando todas as alteracoes)"
    & $gitExe add .

    # Solicita a mensagem do commit
    Write-Host "Digite a mensagem do commit (Ex: Correcao CSS e galeria):"
    $commitMessage = Read-Host

    # Verifica se a mensagem de commit não está vazia
    if ([string]::IsNullOrEmpty($commitMessage)) {
        Write-Host "Mensagem de commit não pode ser vazia. O script foi abortado."
        exit
    }

    # Realiza o commit com a mensagem fornecida
    Write-Host "Executando: $gitExe commit -m \"$commitMessage\""
    & $gitExe commit -m "$commitMessage"

    # Realiza o push
    Write-Host "Executando: $gitExe push (Enviando alteracoes)"
    & $gitExe push
    
    Write-Host "---"
    Write-Host "Push concluído com sucesso!"
}

# Aguarda para que a janela não feche imediatamente após a execução
Write-Host "Pressione qualquer tecla para sair..."
$host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown") | Out-Null