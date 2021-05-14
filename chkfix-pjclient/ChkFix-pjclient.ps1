<# #####################################
Disclaimer: This Sample Code is provided for the purpose of illustration only and is not intended to be used in a production environment.  THIS SAMPLE CODE AND ANY RELATED INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A PARTICULAR PURPOSE.  We grant You a nonexclusive, royalty-free right to use and modify the Sample Code and to reproduce and distribute the object code form of the Sample Code, provided that You agree: (i) to not use Our name, logo, or trademarks to market Your software product in which the Sample Code is embedded; (ii) to includea valid copyright notice on Your software product in which the Sample Code is embedded; and (iii) to indemnify, hold harmless, and defend Us and Our suppliers from and against any claims or lawsuits, including attorneys’ fees, that arise or result from the use or distribution of the Sample Code.
Please note: None of the conditions outlined in the disclaimer above will supersede the terms and conditions contained within the Premier Customer Services Description.
#####################################>

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
$Inactives = Get-Content $scriptPath\Inactives.txt
$RunDate = get-date -f "yyyyMMdd_HHmmss"
If (!(Test-Path -Path "$ScriptPath\Logs")) {New-Item -Name "Logs" -Path $ScriptPath -ItemType Directory}
If (!(Test-Path -Path "$ScriptPath\Logs\$RunDate")) {New-Item -Name "$RunDate" -Path "$ScriptPath\Logs" -ItemType Directory}
 
$scriptblock = {
    Param (
        [string]$ClientName,
        [string]$ScriptPath,
        [string]$RunDate
    )
 
    function convert-BytesUnits {
        Param (
            [Int64]$Bytes
        )
    
        $Unit = $Bytes / 1TB
        If ($Unit -ge 1) {
            Return "$("{0:N2}" -f $Unit) TBytes"
        }
        Else {
            $Unit = $Bytes / 1GB
            If ($Unit -ge 1) {
                Return "$("{0:N2}" -f $Unit) GBytes"
            }
            Else {
                $Unit = $Bytes / 1MB
                If ($Unit -ge 1) {
                    Return "$("{0:N2}" -f $Unit) MBytes"
                }
                Else {
                    $Unit = $Bytes / 1KB
                    If ($Unit -ge 1) {
                        Return "$("{0:N2}" -f $Unit) KBytes"
                    }
                    Else {
                        Return "$Bytes Bytes"
                    }
                }
            }
        }
    }

    function Save-Log {
        param (
            [string]$FilePath,
            [array]$LogMess,
            [switch]$Obj
        )
        
        If($Obj) {
           Add-Content -Value "$(Get-date -f "yyyy/MM/dd HH:mm:ss.fff")" -Path $FilePath
           $LogMess | Out-File -FilePath $FilePath -Append
        } else {
           "$(Get-date -f "yyyy/MM/dd HH:mm:ss.fff"): $LogMess" | Out-File $FilePath -Append
        }
    }

    <#
    A nova estrutura terá a seguinte configuração com as seguintes pastas:
     
        0.Process - Uma pasta que mostra os clientes que o Script está rodando
        1.DNSFail - Máquinas que não resolveram nome
        2.DNSTOut - Clientes que tem um endereço IP mas estão desligadas ou não são alcançadas
        3.DNSOthr - Clientes que retornaram código de DNS diferente de timeout. Consultar <https://docs.microsoft.com/en-us/previous-versions/windows/desktop/wmipicmp/win32-pingstatus>
        4.ClPngOK - Clientes recebem resposta do Ping, mas não conectam no Admin$
        5.ClAccOK - Clientes que tem acesso e executaram o diagnóstico / fix

    #>

    $StartTime = Get-Date
    $DirWork = "$ScriptPath\Logs\$RunDate"
    $Stage = "0.Process"
    If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
    $FileLogPath = "$DirWork\$Stage\$clientName.log"
    
    # Salva no log data e hora do início do Script
    Save-Log -FilePath $FileLogPath -LogMess "Início Script"
    

    $Ping = Get-WmiObject -Query "Select * from win32_PingStatus where Address='$ClientName'" | Select-Object PrimaryAddressResolutionStatus, StatusCode, IPV4Address
   
    Switch ($Ping.StatusCode) {
        $null   {
            
            Save-Log -FilePath $FileLogPath -LogMess "O DNS não resolveu o nome para o cliente $clientName"
            Save-Log -FilePath $FileLogPath -LogMess "O PrimaryAddressResolutionStatus é: $($Ping.PrimaryAddressResolutionStatus)"
            
            # Registrar data e hora do fim do script
            $EndTime = Get-Date
            $TotalTime = $EndTime - $StartTime
            Save-Log -FilePath $FileLogPath -LogMess ("Tempo total de execução: {0:d2}h {1:d2}m {2:d2}s" -f ($TotalTime.Hours), ($TotalTime.Minutes), ($TotalTime.Seconds) )
            Save-Log -FilePath $FileLogPath -LogMess "Fim Script"
            
            # Mover para o diretório '1.DNSFail'
            $Stage = "1.DNSFail"
            If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
            $NewFileLogPath = "$DirWork\$Stage\$clientName.log"
            Move-Item -Path $FileLogPath -Destination $NewFileLogPath -Force
            Break
        }
       
        0   {
            # Cliente está respondendo a Ping
            Save-Log -FilePath $FileLogPath -LogMess "O cliente $clientName estah pingando"
            Save-Log -FilePath $FileLogPath -LogMess "Endereço IP é: $($Ping.IPV4Address.IPAddressToString)"

            if (test-path \\$ClientName\admin$) {
                Save-Log -FilePath $FileLogPath -LogMess "$("#" * 10) Informações Gerais $("#" * 10)"

                Save-Log -FilePath $FileLogPath -LogMess "O cliente consegue conectar no admin$"
                
                # Pega a quantidade de espaço em disco no cliente
                Save-Log -FilePath $FileLogPath -LogMess "Espaço livre nos discos:"
                $Disks = Get-WmiObject -Class win32_logicaldisk -filter "DriveType = 3" -ComputerName $ClientName
                foreach ($Disk in $Disks) {
                    Save-Log -FilePath $FileLogPath -LogMess "   $($Disk.DeviceID) $(convert-BytesUnits -Bytes $Disk.freespace)"
                }
                
                # Pega informacoes de S.O.
                $WMIOS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ClientName
                $LocalDateTime = [Management.ManagementDateTimeConverter]::ToDateTime($WMIOS.LocalDateTime)
                $LastBootUpTime = [Management.ManagementDateTimeConverter]::ToDateTime($WMIOS.LastBootUpTime)
                $Uptime = $LocalDateTime - $LastBootUpTime
                $UptimeStr = "{0}d {1:d2}h {2:d2}m {3:d2}s" -f ($Uptime.Days),($Uptime.Hours),($Uptime.Minutes),($Uptime.Seconds)
                Save-Log -FilePath $FileLogPath -LogMess $UptimeStr

                # Traz informacoes sobre alguns servicos
                Save-Log -FilePath $FileLogPath -LogMess "Servicos:"
                $Services = Get-Service -ComputerName $ClientName -Name CcmExec, BITS, Winmgmt, winrm
                Save-Log -FilePath $FileLogPath -LogMess $Services -Obj

                Save-Log -FilePath $FileLogPath -LogMess "$("#" * 10)"
                
                #############
                #Stop CCM Service
                Save-Log -FilePath $FileLogPath -LogMess "Parando o servico ccmexec"
                $CCMService = Get-WmiObject -Class Win32_Service -ComputerName $ClientName -Filter "name = 'ccmexec'"
                $CCMService.StopService()
                $Count = 0
                            
                #Check if ccmservice Stopped
                Do {
                    Save-Log -FilePath $FileLogPath -LogMess "Parando o servico.."
                    Start-Sleep 2
                    $CCMService = Get-WmiObject -Class Win32_Service -ComputerName $ClientName -Filter "name = 'ccmexec'"
                    $count ++
                } Until ($CCMService.State -eq "Stopped" -or $count -gt 5)
                
                #Terminate Process if running
                If ($CCMService.State -ne "Stopped") {
                    Save-Log -FilePath $FileLogPath -LogMess "Servico nao parou no tempo esperado, forcando parada"
                    $CCMProcess = Get-WmiObject -Class win32_process -ComputerName $ClientName -Filter "Name = 'ccmexec.exe'"
                    $CCMProcess.Terminate()                   
                }
                
                # Remove o arquivo registry.pol
                Save-Log -FilePath $FileLogPath -LogMess "Exclui o arquivo Registry.pol para politicas de computador"
                Remove-Item -path "\\$clientName\admin$\system32\groupPolicy\Machine\Registry.pol" -Force

                # Se WINRM parado
                if((Get-Service -ComputerName $ClientName -Name "winrm").status -ne "Running"){
                    Save-Log -FilePath $FileLogPath -LogMess "Iniciando WINRM"
                    Get-Service -ComputerName $ClientName -Name WinRM | Start-Service 
                }

                Save-Log -FilePath $FileLogPath -LogMess "Conta BITS e DataTransferServices - Antes"
                # Conta a quantidade de itens na fila de BITS
                $BITSQueue = Invoke-Command -ComputerName $ClientName -ScriptBlock {
                    "Fila de BITS - $((Get-BitsTransfer -AllUsers | Measure-Object).count)" 
                }
                Save-Log -FilePath $FileLogPath -LogMess $BITSQueue
                
                # Conta a quantidade de itens na fila do DataTransferService
                $NS = "root\ccm\DataTransferService"
                $ClassDts = @("CCM_DTS_JobEx", "CCM_DTS_JobItemEx")
                
                foreach ($item in $ClassDts) {
                    [int]$wmiCount = (Get-WmiObject -ComputerName $clientName -Namespace $NS -Class $item | Measure-Object).count
                    Save-Log -FilePath $FileLogPath -LogMess ("Fila DataTransferService $item - $($wmiCount.ToString())")
                }

                # Create Task Schedule 
                Save-Log -FilePath $FileLogPath -LogMess "Criando Task para limpeza de BITS e Data Transfer"
                                    
                $ClientSession = New-CimSession -ComputerName $ClientName
                                                
                $cmd = "Get-BitsTransfer -AllUsers | Remove-BitsTransfer; Get-WmiObject -Namespace root\ccm\datatransferservice -Class ccm_dts_jobex `
                    | Remove-WmiObject; Get-WmiObject -Namespace root\ccm\datatransferservice -Class ccm_dts_jobitemEx `
                    | Remove-WmiObject; new-item -path c:\temp -name RunTask -itemtype file"
                $cmdOpen = "-noprofile -nonInteractive -ExecutionPolicy Bypass -Command `""
                $cmdClose = "`""
                $Description = "Reset BITS SCCM"
                $Trigger = New-ScheduledTaskTrigger -At $((get-date).AddSeconds(15)) -Once 
                $Action = New-ScheduledTaskAction -Execute "C:\Windows\system32\WindowsPowershell\v1.0\powershell.exe" -Argument "$cmdOpen$cmd$cmdClose"
                $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries
                $Principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -RunLevel Highest -LogonType ServiceAccount
                $TaskName = "Reset BITS SCCM"
                Register-ScheduledTask -CimSession $ClientSession -TaskName $TaskName -Force -TaskPath \SCCM\ -Principal $Principal -Settings $Settings `
                    -Description $Description -Trigger $Trigger -Action $Action 
                $TargetTask = Get-ScheduledTask -TaskName $TaskName -CimSession $ClientSession
                #$TargetTask.Triggers[0].StartBoundary = [DateTime]::Now.ToString("yyyy-MM-dd'T'HH:mm:ss")
                $TargetTask.Triggers[0].EndBoundary = [DateTime]::Now.AddSeconds(90).ToString("yyyy-MM-dd'T'HH:mm:ss")
                $TargetTask.Settings.DeleteExpiredTaskAfter = 'PT0S'
                $TargetTask | Set-ScheduledTask -CimSession $ClientSession
                                       
                # Conta a quantidade de itens na fila de BITS
                Start-Sleep -Seconds 20
                Save-Log -FilePath $FileLogPath -LogMess "Conta BITS e DataTransferServices - Depois"
                
                # Conta a quantidade de itens na fila de BITS
                $BITSQueue = Invoke-Command -ComputerName $ClientName -ScriptBlock {
                    "Fila de BITS - $((Get-BitsTransfer -AllUsers | Measure-Object).count)" 
                }
                Save-Log -FilePath $FileLogPath -LogMess $BITSQueue

                # Conta a quantidade de itens na fila do DataTransferService
                $NS = "root\ccm\DataTransferService"
                $ClassDts = @("CCM_DTS_JobEx", "CCM_DTS_JobItemEx")
                
                foreach ($item in $ClassDts) {
                    [int]$wmiCount = (Get-WmiObject -ComputerName $clientName -Namespace $NS -Class $item | Measure-Object).count
                    Save-Log -FilePath $FileLogPath -LogMess ("Fila DataTransferService $item - $($wmiCount.ToString())")
                }
                                                    
                #$CCMProcess = Get-WmiObject -Class win32_process -ComputerName $ClientName 
                $CCMProcess = $([wmiclass]"\\$ClientName\root\cimv2:win32_process")
                Save-Log -FilePath $FileLogPath -LogMess "Executando CCMEval"
                $CCMProcess.Create("c:\windows\ccm\ccmeval.exe")
                
                Start-Sleep -Seconds 2
                # Reset Policy   
                Save-Log -FilePath $FileLogPath -LogMess "Executando Reset Policy"                
                $Class = $([WMIClass]"\\$ClientName\root\ccm:SMS_Client")
                $Class.ResetPolicy(1)
                start-sleep 5
                $Class.TriggerSchedule("{00000000-0000-0000-0000-000000000021}")
                $Class.TriggerSchedule("{00000000-0000-0000-0000-000000000022}")

                # Registrar a data e hora do fim do script
                $EndTime = Get-Date
                $TotalTime = $EndTime - $StartTime
                Save-Log -FilePath $FileLogPath -LogMess ("Tempo total de execução: {0:d2}h {1:d2}m {2:d2}s" -f ($TotalTime.Hours), ($TotalTime.Minutes), ($TotalTime.Seconds) )
                Save-Log -FilePath $FileLogPath -LogMess "Fim Script"

                # Mover o arquivo para a pasta '5.ClAccOK'
                $Stage = "5.ClAccOK"
                If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
                $NewFileLogPath = "$DirWork\$Stage\$clientName.log"
                Move-Item -Path $FileLogPath -Destination $NewFileLogPath -Force

            } else {
                # "Servidor não acessa o admin$ do cliente"
                Save-Log -FilePath $FileLogPath -LogMess "Servidor não acessa o admin$ do cliente"

                # Registrar data e hora do fim do script
                $EndTime = Get-Date
                $TotalTime = $EndTime - $StartTime
                Save-Log -FilePath $FileLogPath -LogMess ("Tempo total de execução: {0:d2}h {1:d2}m {2:d2}s" -f ($TotalTime.Hours), ($TotalTime.Minutes), ($TotalTime.Seconds) )
                Save-Log -FilePath $FileLogPath -LogMess "Fim Script"

                #Mover o arquivo para a pasta '4.ClPngOK'
                $Stage = "4.ClPngOK"
                If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
                $NewFileLogPath = "$DirWork\$Stage\$clientName.log"
                Move-Item -Path $FileLogPath -Destination $NewFileLogPath -Force
    
            }
            Break
       }
       
        11010 {
            
            #If (!(Test-Path -Path "$DirWork\TimeOut")) {New-Item -Name "TimeOut" -Path $DirWork -ItemType Directory}
            Save-Log -FilePath $FileLogPath -LogMess "O cliente $clientName não reponde ao ping"
            Save-Log -FilePath $FileLogPath -LogMess "Endereço IP é: $($Ping.IPV4Address.IPAddressToString)"

            # Registrar data e hora do fim do script
            $EndTime = Get-Date
            $TotalTime = $EndTime - $StartTime
            Save-Log -FilePath $FileLogPath -LogMess ("Tempo total de execução: {0:d2}h {1:d2}m {2:d2}s" -f ($TotalTime.Hours), ($TotalTime.Minutes), ($TotalTime.Seconds) )
            Save-Log -FilePath $FileLogPath -LogMess "Fim Script"

            #Mover o arquivo para a pasta '4.ClPngOK'
            $Stage = "2.DNSTOut"
            If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
            $NewFileLogPath = "$DirWork\$Stage\$clientName.log"
            Move-Item -Path $FileLogPath -Destination $NewFileLogPath -Force
            Break
        }
       
        default {
            #If (!(Test-Path -Path "$DirWork\Other")) {New-Item -Name "Other" -Path $DirWork -ItemType Directory}
            Save-Log -FilePath $FileLogPath -LogMess "O cliente $clientName apresentou STATUS diferente dos previstos"
            Save-Log -FilePath $FileLogPath -LogMess "O STATUS foi: $($Ping.StatusCode)"
            Save-Log -FilePath $FileLogPath -LogMess "O PrimaryAddressResolutionStatus é: $($Ping.PrimaryAddressResolutionStatus)"
            Save-Log -FilePath $FileLogPath -LogMess "Endereço IP é: $($Ping.IPV4Address.IPAddressToString)"

            # Registrar data e hora do fim do script
            $EndTime = Get-Date
            $TotalTime = $EndTime - $StartTime
            Save-Log -FilePath $FileLogPath -LogMess ("Tempo total de execução: {0:d2}h {1:d2}m {2:d2}s" -f ($TotalTime.Hours), ($TotalTime.Minutes), ($TotalTime.Seconds) )
            Save-Log -FilePath $FileLogPath -LogMess "Fim Script"

            #Mover o arquivo para a pasta '4.ClPngOK'
            $Stage = "3.DNSOthr"
            If (!(Test-Path -Path "$DirWork\$Stage")) {New-Item -Name $Stage -Path $DirWork -ItemType Directory}
            $NewFileLogPath = "$DirWork\$Stage\$clientName.log"
            Move-Item -Path $FileLogPath -Destination $NewFileLogPath -Force
        }
    }
}
 
#Create session state
$myString = "This is session state!"
$SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()
$SessionState.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList "MyString", $myString, "Exemple String"))
 
#Create runspace pool
$RunspacePool = [RunspaceFactory]::CreateRunspacePool(1, 20, $SessionState, $Host)
$RunspacePool.Open()
 
foreach ($Inactive in $Inactives) {
    $Job = [powershell]::Create().AddScript($scriptblock).AddParameter("ClientName", $Inactive).AddParameter("ScriptPath", $ScriptPath).AddParameter("RunDate", $RunDate)
    $Job.RunspacePool = $RunspacePool
    [PSObject[]]$Jobs += New-Object PSObject -Property @{
        RunClient = $Inactive
        Job = $Job
        ScriptPath = $ScriptPath
        Result = $Job.BeginInvoke()
    }
}
 
#Write-Host "Running." -NoNewline
Do {
    $Cnt = ($Jobs | Where-Object {$_.Result.IsCompleted -ne $true}).Count
    "Scripts running: $($cnt)"
    Start-Sleep -Seconds 1
} while ( $Jobs.Result.IsCompleted -contains $false)
 
# Backup da lista no diretório de trabalho.
$Inactives | Out-File "$ScriptPath\Logs\$RunDate\Inactives.txt" -Append
 
#Remove as variáveis
Remove-Variable ScriptPath, Inactive, RunDate, scriptblock, Job, Jobs, myString, SessionState, RunspacePool, Inactives, Cnt