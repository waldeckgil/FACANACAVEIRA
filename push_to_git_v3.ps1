# =================================================================
# SCRIPT: push_to_git_v3.ps1
# OBJETIVO: Automação Git com Compactação/Descompactação Local
# =================================================================

# 1. DEFINIÇÕES DE CAMINHOS (Baseado na tua estrutura)
$gitExe = "C:\Program Files\Git\bin\git.exe"
$caminhoProjeto = "C:\WALDECK_IA\FACA_NACAVEIRA"
$arquivoZip = "C:\WALDECK_IA\FACA_NACAVEIRA.zip"

# --- 
# 2. PASSO: VERIFICAÇÃO E DESCOMPACTAÇÃO
# ---
if (Test-Path $arquivoZip) {
    Write-Host "---"
    Write-Host "O projeto está COMPACTADO em: $arquivoZip"
    $respUnzip = Read-Host "Deseja DESCOMPACTAR para trabalhar no Git? (S/N)"
    
    if ($respUnzip.ToUpper() -eq "S") {
        Write-Host "A extrair ficheiros..."
        Expand-Archive -Path $arquivoZip -DestinationPath "C:\WALDECK_IA\" -Force
        
        # Pausa de segurança para o Windows libertar os ficheiros
        Write-Host "A aguardar sincronização do sistema..."
        Start-Sleep -Seconds 3
        Write-Host "Projeto descompactado com sucesso!"
    }
}

# Entra na pasta do projeto para executar comandos Git
if (Test-Path $caminhoProjeto) {
    Set-Location -Path $caminhoProjeto
} else {
    Write-Host "ERRO: Pasta do projeto não encontrada em $caminhoProjeto"
    exit
}

# ---
# 3. PASSO: LÓGICA DO GIT (Fiel ao teu script V2)
# ---
Write-Host "---"
$isFirstPush = Read-Host "Este é o primeiro envio deste projeto para o GitHub? (S/N)"

if ($isFirstPush.ToUpper() -eq "S") {
    Write-Host "Configuração inicial para o primeiro envio."
    $repoName = Read-Host "Digite o nome do repositório a ser criado no GitHub"
    $githubUser = "Waldeckgil"
    
    & $gitExe init
    $remoteUrl = "https://github.com/$githubUser/$repoName.git"
    & $gitExe remote add origin $remoteUrl
} else {
    Write-Host "A sincronizar com o GitHub (Git Pull)..."
    & $gitExe pull origin main
}

& $gitExe branch -M main
Write-Host "A remover .env do cache..."
& $gitExe rm --cached .env 2>$null 
& $gitExe add .

$commitMessage = Read-Host "Digite a mensagem do commit"
if ([string]::IsNullOrEmpty($commitMessage)) {
    Write-Host "ERRO: Mensagem obrigatória. Processo abortado."
    exit
}

& $gitExe commit -m "$commitMessage"
Write-Host "A enviar para o GitHub..."
& $gitExe push -u origin main

# ---
# 4. PASSO: COMPACTAÇÃO FINAL E LIMPEZA
# ---
Write-Host "---"
Write-Host "Push concluído com sucesso!"
$respZip = Read-Host "Deseja COMPACTAR a pasta agora para poupar espaço? (S/N)"

if ($respZip.ToUpper() -eq "S") {
    Write-Host "A iniciar compactação..."
    
    # IMPORTANTE: Sai da pasta para o Windows permitir a compressão/eliminação
    Set-Location .. 
    
    Compress-Archive -Path $caminhoProjeto -DestinationPath $arquivoZip -Force
    
    Write-Host "A finalizar escrita do ficheiro ZIP, aguarde..."
    Start-Sleep -Seconds 5
    
    if (Test-Path $arquivoZip) {
        $respRemove = Read-Host "Pasta zipada com sucesso! Deseja APAGAR a pasta original aberta? (S/N)"
        if ($respRemove.ToUpper() -eq "S") {
            Remove-Item -Recurse -Force $caminhoProjeto
            Write-Host "Limpeza concluída. Apenas o ZIP foi mantido."
        }
    }
}

Write-Host "---"
Write-Host "Script V3 finalizado!"