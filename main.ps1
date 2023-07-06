$host.ui.rawui.BackgroundColor = "Black"
$host.ui.rawui.ForegroundColor = "White"
Clear-Host

$tmpDirectory = "$Env:TEMP\tmp"
Remove-Item -Path "$tmpDirectory\*" -Recurse -Force -ErrorAction SilentlyContinue | Out-Null
New-Item -Path $tmpDirectory -Force -ItemType Directory | Out-Null

$adbDirectory = Join-Path -Path $env:LOCALAPPDATA -ChildPath "scapps"

function FetchLatestRelease {
  $latestUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
  try {
    $response = Invoke-WebRequest -Uri $latestUrl -MaximumRedirection 0 -ErrorAction SilentlyContinue -UseBasicParsing -TimeoutSec 5
    $latestVersion = [regex]::Matches(($response.Headers.Location | Split-Path -Leaf), '(\d+(\.\d+){2})').Value
    $latestVersion = [version]$latestVersion
    return $latestVersion
  } catch {
    Write-Host "An error occurred: $_"
    throw
  }
}

function GetInstalledADBVersion {
  $versionLine = adb version
  $installedVersion = [regex]::Matches($versionLine[1], '(\d+(\.\d+){2})').Value
  $installedVersion = [version]$installedVersion
  if ([string]::IsNullOrEmpty($installedVersion)) {
    Write-Output "Error retrieving ADB version."
    throw
  }
  return $installedVersion
}

function InstallADB {
  $adbUrl = "https://dl.google.com/android/repository/platform-tools-latest-windows.zip"
  $destination = Join-Path -Path $tmpDirectory -ChildPath "pf.zip"
  Start-BitsTransfer -Source $adbUrl -Destination $destination
  Expand-Archive -Path $destination -DestinationPath $tmpDirectory -Force
  Copy-Item -Path "$tmpDirectory\platform-tools\" -Recurse -Destination $adbDirectory -Force
}

function SetToPath {
  $currentPath = [Environment]::GetEnvironmentVariable("Path", "User") -replace ";;+", ";"
  $currentPath = $currentPath.TrimEnd(';')
  $newPath = "$adbDirectory\platform-tools" | Convert-Path

  if ($currentPath.Split(';') -contains $newPath) {
    Write-Host "The path '$newPath' is already in the user path variable"
  } else {
    $newUserPath = "$currentPath;$newPath;"
    [Environment]::SetEnvironmentVariable("PATH", $newUserPath, "User")
    $env:Path = "$newPath;$env:Path"
    Write-Host "The path '$newPath' has been added to the user path variable."
  }
}

function UpdateADB {
  $installedVersion = GetInstalledADBVersion
  $latestVersion = FetchLatestRelease
  if ($latestVersion -gt $installedVersion) {
    Write-Output "Update available. Latest Version: $latestVersion. Installed Version: $installedVersion"
    $adbDirectory = (Get-Command -Name adb.exe).Source | Split-Path -Parent | Split-Path -Parent
    InstallADB
  } elseif ($latestVersion -eq $installedVersion) {
    Write-Output "Latest Version: $latestVersion installed"
  } else {
    Write-Output "Error retrieving ADB version."
  }
}

function Main {
  $isinstalled = Get-Command -Name "adb.exe" -ErrorAction SilentlyContinue
  
  if (!($isinstalled)) {
    Write-Host "Installing Platform Tools..."
    New-Item $adbDirectory -ItemType Directory -ErrorAction SilentlyContinue
    InstallADB
    SetToPath
  } elseif ($isinstalled) {
    Write-Host "Platform Tools are installed. Checking for updates."
    UpdateADB
  }
}

function RemoveADB {
  $adbExecutable = "adb.exe"
  $isInstalled = Get-Command -Name $adbExecutable -ErrorAction SilentlyContinue

  if ($isInstalled) {
    Write-Host "Removing ADB..."

    $adbDirectory = (Get-Command adb.exe).Source | Split-Path -Parent
    $currentPath = [Environment]::GetEnvironmentVariable("Path", "User") -replace ";;+", ";"
    $currentPath = $currentPath.TrimEnd(';')

    adb kill-server 2>&1 | Out-Null
    Remove-Item -Path $adbDirectory -Recurse -Force
	
    if ($currentPath.Split(';') -contains $adbDirectory) {
      $newPath = $currentPath.Replace($adbDirectory, "")
      [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    }

    Write-Host "ADB removed successfully.Verify Yourself"
    Pause
    rundll32 sysdm.cpl, EditEnvironmentVariables
    explorer.exe ($adbDirectory | Split-Path -Parent)
  } else {
    Write-Host "ADB not found."
    return
  }
}

# Main menu loop
do {
  Clear-Host
  Write-Output "Select an option:"
  Write-Output "1. Install/Update Platform Tools"
  Write-Output "2. Remove Platform Tools"
  Write-Output "3. Check Path Variables"
  Write-Output "4. Exit"
  $choice = Read-Host "Enter your choice (1-4)"

  switch ($choice) {
    1 {
      try {
        Main
      } catch {
        Write-Host "An error occurred: $_"
      }
      Read-Host "Press Enter to continue"
    }
    2 { RemoveADB }
    3 { rundll32 sysdm.cpl, EditEnvironmentVariables }
    4 { Remove-Item -Recurse -Force $tmpDirectory;break }
    default {
      Write-Output "Invalid choice. Please try again."
      Read-Host "Press Enter to continue"
    }
  }
} while ($choice -ne '4')
