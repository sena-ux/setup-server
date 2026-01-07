# =====================================================
# SCRIPT MITIGASI CVE-2020-0796 (SMBGhost)
# =====================================================
# Jalankan sebagai Administrator
# =====================================================

$logFile = "C:\Mitigasi_SMBGhost_Log.txt"

function Write-Log {
    param ([string]$message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $message" | Tee-Object -Append -FilePath $logFile
}

Write-Log "=== MULAI MITIGASI CVE-2020-0796 ==="

# -----------------------------------------------------
# 1. INVENTARISASI SISTEM
# -----------------------------------------------------
Write-Log "Inventarisasi Sistem Operasi"
$os = Get-CimInstance Win32_OperatingSystem
Write-Log "OS Name    : $($os.Caption)"
Write-Log "OS Version : $($os.Version)"
Write-Log "Build No   : $($os.BuildNumber)"

# -----------------------------------------------------
# 2. NONAKTIFKAN SMB v1
# -----------------------------------------------------
Write-Log "Menonaktifkan SMB v1"
Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -ErrorAction SilentlyContinue
Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force
Write-Log "SMB v1 dinonaktifkan"

# -----------------------------------------------------
# 3. PASTIKAN SMB v2 / v3 AKTIF
# -----------------------------------------------------
Write-Log "Mengaktifkan SMB v2/v3"
Set-SmbServerConfiguration -EnableSMB2Protocol $true -Force
Write-Log "SMB v2/v3 aktif"

# -----------------------------------------------------
# 4. NONAKTIFKAN SMBv3 COMPRESSION
# -----------------------------------------------------
Write-Log "Menonaktifkan SMBv3 Compression (Mitigasi Sementara)"
$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"
New-ItemProperty -Path $regPath -Name "DisableCompression" -PropertyType DWORD -Value 1 -Force | Out-Null
Write-Log "SMBv3 Compression dinonaktifkan"

# -----------------------------------------------------
# 5. BLOKIR PORT SMB
# -----------------------------------------------------
Write-Log "Mengonfigurasi Firewall - Pemblokiran Port SMB"

$rules = @(
    @{Name="Block SMB TCP 445"; Protocol="TCP"; Port="445"},
    @{Name="Block SMB TCP 139"; Protocol="TCP"; Port="139"},
    @{Name="Block SMB UDP 137"; Protocol="UDP"; Port="137"},
    @{Name="Block SMB UDP 138"; Protocol="UDP"; Port="138"}
)

foreach ($rule in $rules) {
    if (-not (Get-NetFirewallRule -DisplayName $rule.Name -ErrorAction SilentlyContinue)) {
        New-NetFirewallRule `
            -DisplayName $rule.Name `
            -Direction Inbound `
            -Protocol $rule.Protocol `
            -LocalPort $rule.Port `
            -Action Block
        Write-Log "Firewall rule dibuat: $($rule.Name)"
    } else {
        Write-Log "Firewall rule sudah ada: $($rule.Name)"
    }
}

# -----------------------------------------------------
# 6. VERIFIKASI STATUS
# -----------------------------------------------------
Write-Log "Verifikasi Konfigurasi SMB"
$smbConfig = Get-SmbServerConfiguration
Write-Log "SMB1 Enabled : $($smbConfig.EnableSMB1Protocol)"
Write-Log "SMB2 Enabled : $($smbConfig.EnableSMB2Protocol)"

Write-Log "Firewall Status"
Get-NetFirewallProfile | ForEach-Object {
    Write-Log "$($_.Name) Firewall Enabled: $($_.Enabled)"
}

# -----------------------------------------------------
# 7. SELESAI
# -----------------------------------------------------
Write-Log "=== MITIGASI SELESAI - RESTART SERVER DISARANKAN ==="

Write-Host ""
Write-Host "========================================"
Write-Host " MITIGASI CVE-2020-0796 SELESAI"
Write-Host " Silakan RESTART server untuk finalisasi"
Write-Host " Log tersimpan di: $logFile"
Write-Host "========================================"
