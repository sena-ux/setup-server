# =====================================================
# SCRIPT ROLLBACK MITIGASI CVE-2020-0796 (SMBGhost)
# =====================================================
# Jalankan sebagai Administrator
# =====================================================

$logFile = "C:\Rollback_SMBGhost_Log.txt"

function Write-Log {
    param ([string]$message)
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$time - $message" | Tee-Object -Append -FilePath $logFile
}

Write-Log "=== MULAI ROLLBACK MITIGASI CVE-2020-0796 ==="

# -----------------------------------------------------
# 1. AKTIFKAN KEMBALI SMBv3 COMPRESSION
# -----------------------------------------------------
Write-Log "Mengaktifkan kembali SMBv3 Compression"

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\LanmanServer\Parameters"

if (Get-ItemProperty -Path $regPath -Name "DisableCompression" -ErrorAction SilentlyContinue) {
    Remove-ItemProperty -Path $regPath -Name "DisableCompression"
    Write-Log "Registry DisableCompression dihapus (Compression AKTIF)"
} else {
    Write-Log "Registry DisableCompression tidak ditemukan"
}

# -----------------------------------------------------
# 2. HAPUS FIREWALL RULE BLOKIR SMB
# -----------------------------------------------------
Write-Log "Menghapus Firewall Rules pemblokiran SMB"

$rules = @(
    "Block SMB TCP 445",
    "Block SMB TCP 139",
    "Block SMB UDP 137",
    "Block SMB UDP 138"
)

foreach ($rule in $rules) {
    $fwRule = Get-NetFirewallRule -DisplayName $rule -ErrorAction SilentlyContinue
    if ($fwRule) {
        Remove-NetFirewallRule -DisplayName $rule
        Write-Log "Firewall rule dihapus: $rule"
    } else {
        Write-Log "Firewall rule tidak ditemukan: $rule"
    }
}

# -----------------------------------------------------
# 3. STATUS SMB v1 (TIDAK DIAKTIFKAN SECARA DEFAULT)
# -----------------------------------------------------
Write-Log "SMB v1 tetap NONAKTIF (direkomendasikan)"

$smbConfig = Get-SmbServerConfiguration
Write-Log "SMB1 Enabled : $($smbConfig.EnableSMB1Protocol)"
Write-Log "SMB2 Enabled : $($smbConfig.EnableSMB2Protocol)"

# -----------------------------------------------------
# 4. VERIFIKASI FIREWALL
# -----------------------------------------------------
Write-Log "Status Firewall"
Get-NetFirewallProfile | ForEach-Object {
    Write-Log "$($_.Name) Firewall Enabled: $($_.Enabled)"
}

# -----------------------------------------------------
# 5. SELESAI
# -----------------------------------------------------
Write-Log "=== ROLLBACK SELESAI - RESTART DISARANKAN ==="

Write-Host ""
Write-Host "========================================"
Write-Host " ROLLBACK SMBGHOST SELESAI"
Write-Host " Restart sistem untuk finalisasi"
Write-Host " Log tersimpan di: $logFile"
Write-Host "========================================"
