using namespace System.Management.Automation

function Get-Hosts($configFile) {
    Get-Content $configFile `
    | Select-String -Pattern "^Host " `
    | ForEach-Object { $_ -replace "host ", "" } `
    | Sort-Object -Unique
}

Register-ArgumentCompleter -CommandName ssh, scp, sftp -Native -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)

    $sshDir = "${Env:HOMEPATH}\.ssh"

    $hosts = Get-Content "$sshDir\config" `
    | Select-String -Pattern "^Include " `
    | ForEach-Object { $_ -replace "include ", "" } `
    | ForEach-Object { Get-Hosts "$_" }

    $hosts += Get-Hosts "$sshDir\config"
    $hosts = $hosts | Sort-Object -Unique

    # For now just assume it's a hostname.
    $textToComplete = $wordToComplete
    $generateCompletionText = {
        param($x)
        $x
    }
    if ($wordToComplete -match "^(?<user>[-\w/\\]+)@(?<host>[-.\w]+)$") {
        $textToComplete = $Matches["host"]
        $generateCompletionText = {
            param($hostname)
            $Matches["user"] + "@" + $hostname
        }
    }

    $hosts `
    | Where-Object { $_ -like "${textToComplete}*" } `
    | ForEach-Object { [CompletionResult]::new((&$generateCompletionText($_)), $_, [CompletionResultType]::ParameterValue, $_) }
}

oh-my-posh init pwsh --config "${Env:HOMEPATH}\AppData\Local\Programs\oh-my-posh\themes\amro.omp.json" | Invoke-Expression


# Find out if the current user identity is elevated (has admin rights)
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

# We don't need these any more; they were just temporary variables to get to $isAdmin.
# Delete them to prevent cluttering up the user profile.
Remove-Variable identity
Remove-Variable principal


# Simple function to start a new elevated process. If arguments are supplied then
# a single command is started with admin rights; if not then a new admin instance
# of PowerShell is started.
function admin
{
    if ($args.Count -gt 0)
    {
       $argList = "& '" + $args + "'"
       Start-Process "$psHome\powershell.exe" -Verb runAs -ArgumentList $argList
    }
    else
    {
       Start-Process "$psHome\powershell.exe" -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command
# with elevated rights.
Set-Alias -Name su -Value admin
Set-Alias -Name sudo -Value admin

# Make ll great again
Set-Alias -Name ll -Value Get-ChildItem


# Shows navigable menu of all options when hitting Tab
Set-PSReadlineKeyHandler -Key Tab -Function MenuComplete

# Autocompletion for arrow keys
Set-PSReadlineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadlineKeyHandler -Key DownArrow -Function HistorySearchForward
