$ErrorActionPreference = "Stop"

$projectRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$scriptPath = Join-Path $projectRoot "excrementus.nvgt"
$outputDir = Join-Path $projectRoot "builds"
$platforms = @("windows", "linux", "mac", "android")

if (!(Test-Path $scriptPath)) {
	throw "Missing script file: $scriptPath"
}

New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

function Get-CandidatesForPlatform([string]$platform) {
	switch ($platform) {
		"windows" { return @("excrementus.zip") }
		"linux" { return @("excrementus.zip") }
		"mac" { return @("excrementus.app.zip", "excrementus.zip") }
		"android" { return @("excrementus.apk", "excrementus.aab", "excrementus.zip") }
		default { return @("excrementus.zip") }
	}
}

foreach ($platform in $platforms) {
	$candidates = Get-CandidatesForPlatform $platform
	foreach ($candidate in $candidates) {
		$candidatePath = Join-Path $projectRoot $candidate
		if (Test-Path $candidatePath) {
			Remove-Item -Force $candidatePath
		}
	}

	Write-Host "Building $platform..."
	& nvgt -C -p $platform $scriptPath -Q
	if ($LASTEXITCODE -ne 0) {
		throw "Build failed for platform: $platform"
	}

	$bundlePath = $null
	foreach ($candidate in $candidates) {
		$candidatePath = Join-Path $projectRoot $candidate
		if (Test-Path $candidatePath) {
			$bundlePath = $candidatePath
			break
		}
	}
	if ($bundlePath -eq $null) {
		throw "Expected bundle not found after $platform build"
	}

	$targetPath = Join-Path $outputDir ("excrementus-" + $platform + [System.IO.Path]::GetExtension($bundlePath))
	Move-Item -Force $bundlePath $targetPath
}

Write-Host "Done. Bundles saved to $outputDir"
