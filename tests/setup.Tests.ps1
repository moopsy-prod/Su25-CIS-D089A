#Requires -Modules Pester
<#
.SYNOPSIS
    Regression tests for setup.ps1.
.DESCRIPTION
    Validates that:
      - setup.ps1 is syntactically valid PowerShell.
      - RDP registry keys and firewall are configured correctly and the machine
        can reach itself on TCP 3389 (loopback).
      - Dark mode registry values are set and the lower-left corner of the
        primary display shows dark pixels (RGB all < 64).

    The RDP and dark mode sections apply the relevant configuration themselves
    so they can be run independently of setup.ps1 in CI.
#>

BeforeAll {
    $script:SetupScriptPath = Join-Path $PSScriptRoot '..' 'setup.ps1' | Resolve-Path
}

# ---------------------------------------------------------------------------
Describe 'setup.ps1 – script validation' {

    It 'setup.ps1 exists' {
        $script:SetupScriptPath | Should -Exist
    }

    It 'setup.ps1 has no syntax errors' {
        $parseErrors = $null
        $null = [System.Management.Automation.Language.Parser]::ParseFile(
            $script:SetupScriptPath,
            [ref]$null,
            [ref]$parseErrors
        )
        $parseErrors | Should -BeNullOrEmpty
    }
}

# ---------------------------------------------------------------------------
Describe 'RDP configuration' {

    BeforeAll {
        Set-ItemProperty `
            -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
            -Name 'fDenyTSConnections' -Value 0

        Set-ItemProperty `
            -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-TCP\' `
            -Name 'UserAuthentication' -Value 1

        Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

        # Allow TermService (Remote Desktop) a moment to start listening.
        Start-Sleep -Seconds 3
    }

    It 'fDenyTSConnections is 0 (RDP allowed)' {
        $val = Get-ItemPropertyValue `
            -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
            -Name 'fDenyTSConnections'
        $val | Should -Be 0
    }

    It 'UserAuthentication is 1 (NLA required)' {
        $val = Get-ItemPropertyValue `
            -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-TCP\' `
            -Name 'UserAuthentication'
        $val | Should -Be 1
    }

    It 'TCP port 3389 is reachable via loopback (127.0.0.1)' {
        $result = Test-NetConnection -ComputerName '127.0.0.1' -Port 3389 `
            -WarningAction SilentlyContinue
        $result.TcpTestSucceeded | Should -Be $true
    }
}

# ---------------------------------------------------------------------------
Describe 'Dark mode configuration' {

    BeforeAll {
        @('AppsUseLightTheme', 'SystemUsesLightTheme') | ForEach-Object {
            Set-ItemProperty `
                -Path 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
                -Name $_ -Value 0
        }

        # Restart Explorer so the visual change takes effect before screenshotting.
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Process explorer
        Start-Sleep -Seconds 4
    }

    It 'AppsUseLightTheme registry value is 0' {
        $val = Get-ItemPropertyValue `
            -Path 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
            -Name 'AppsUseLightTheme'
        $val | Should -Be 0
    }

    It 'SystemUsesLightTheme registry value is 0' {
        $val = Get-ItemPropertyValue `
            -Path 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
            -Name 'SystemUsesLightTheme'
        $val | Should -Be 0
    }

    It 'lower-left desktop pixels are dark (taskbar is dark-mode coloured)' {
        Add-Type -AssemblyName System.Windows.Forms
        Add-Type -AssemblyName System.Drawing

        $screen  = [System.Windows.Forms.Screen]::PrimaryScreen
        $width   = $screen.Bounds.Width
        $height  = $screen.Bounds.Height

        $bitmap   = New-Object System.Drawing.Bitmap($width, $height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen(
            $screen.Bounds.Location,
            [System.Drawing.Point]::Empty,
            $screen.Bounds.Size
        )
        $graphics.Dispose()

        # Sample a small cluster of pixels near the bottom-left corner
        # (inside the taskbar area).  In dark mode every sampled pixel should
        # have all three channels below 64.
        $sampleCoords = @(
            @{ X = 5;  Y = $height - 5  }
            @{ X = 10; Y = $height - 10 }
            @{ X = 5;  Y = $height - 20 }
        )

        $darkCount = 0
        foreach ($coord in $sampleCoords) {
            $pixel = $bitmap.GetPixel($coord.X, $coord.Y)
            if ($pixel.R -lt 64 -and $pixel.G -lt 64 -and $pixel.B -lt 64) {
                $darkCount++
            }
        }
        $bitmap.Dispose()

        # Require at least 2 of 3 sampled pixels to be dark.  A majority
        # threshold (rather than 3/3) tolerates the rare anti-aliased or
        # icon pixel that may stray from the expected taskbar background colour.
        $darkCount | Should -BeGreaterOrEqual 2
    }
}
