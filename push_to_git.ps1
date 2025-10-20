# Script para automatizar o processo de commit e push para o GitHub

# Remove o arquivo .env do cache do Git para que ele não seja rastreado
Write-Host "Executando: git rm --cached .env"
git rm --cached .env

# Adiciona todos os arquivos alterados ao stage
Write-Host "Executando: git add ."
git add .

# Solicita a mensagem do commit
Write-Host "Digite a mensagem do commit:"
$commitMessage = Read-Host

# Verifica se a mensagem de commit não está vazia
if ([string]::IsNullOrEmpty($commitMessage)) {
    Write-Host "Mensagem de commit não pode ser vazia. O script foi abortado."
    exit
}

# Realiza o commit com a mensagem fornecida
Write-Host "Executando: git commit -m `"$commitMessage`""
git commit -m "$commitMessage"

# Envia as alterações para o repositório remoto na branch 'master'
Write-Host "Executando: git push origin master"
git push origin master

Write-Host "---"
Write-Host "Processo de envio para o GitHub concluído com sucesso!"
Write-Host "Comandos executados:"
Write-Host "- git rm --cached .env"
Write-Host "- git add ."
Write-Host "- git commit -m ""$commitMessage"""
Write-Host "- git push origin master"