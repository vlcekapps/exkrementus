param(
	[ValidateSet("patch", "minor", "major")]
	[string]$Bump = "patch",
	[string]$Version = "",
	[switch]$SkipBuild,
	[switch]$SkipPush,
	[switch]$SkipRelease,
	[switch]$Draft,
	[switch]$Prerelease
)

$ErrorActionPreference = "Stop"

function Require-Command {
	param([string]$Name)
	$cmd = Get-Command $Name -ErrorAction SilentlyContinue
	if ($null -eq $cmd) {
		throw "Required command '$Name' is not available in PATH."
	}
}

function Invoke-Git {
	param([string[]]$GitArgs)
	if (-not $GitArgs -or $GitArgs.Count -eq 0) {
		throw "Invoke-Git requires at least one git argument."
	}
	& git @GitArgs
	if ($LASTEXITCODE -ne 0) {
		throw "git command failed: git $($GitArgs -join ' ')"
	}
}

function Read-VersionFile {
	param([string]$Path)
	if (!(Test-Path $Path)) {
		throw "VERSION file not found: $Path"
	}
	$raw = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false)).Trim()
	if ($raw -notmatch '^\d+\.\d+\.\d+$') {
		throw "VERSION must use SemVer MAJOR.MINOR.PATCH. Found: '$raw'"
	}
	return $raw
}

function Parse-SemVer {
	param([string]$Value)
	$parts = $Value.Split('.')
	return @([int]$parts[0], [int]$parts[1], [int]$parts[2])
}

function Compare-SemVer {
	param(
		[string]$Left,
		[string]$Right
	)
	$l = Parse-SemVer -Value $Left
	$r = Parse-SemVer -Value $Right
	for ($i = 0; $i -lt 3; $i++) {
		if ($l[$i] -lt $r[$i]) { return -1 }
		if ($l[$i] -gt $r[$i]) { return 1 }
	}
	return 0
}

function Get-BumpedVersion {
	param(
		[string]$Current,
		[string]$Kind
	)
	$parts = Parse-SemVer -Value $Current
	$major = $parts[0]
	$minor = $parts[1]
	$patch = $parts[2]

	switch ($Kind) {
		"major" {
			$major += 1
			$minor = 0
			$patch = 0
		}
		"minor" {
			$minor += 1
			$patch = 0
		}
		default {
			$patch += 1
		}
	}

	return "$major.$minor.$patch"
}

function Assert-CleanWorkingTree {
	$status = (& git status --porcelain)
	if ($LASTEXITCODE -ne 0) {
		throw "Cannot read git status."
	}
	if ($status -and $status.Count -gt 0) {
		throw "Working tree is not clean. Commit or stash changes before running release.ps1."
	}
}

function Assert-RemoteTagDoesNotExist {
	param([string]$TagName)
	$remote = (& git ls-remote --tags origin "refs/tags/$TagName")
	if ($LASTEXITCODE -ne 0) {
		throw "Failed to query remote tags from origin."
	}
	if ($remote) {
		throw "Tag $TagName already exists on origin."
	}
}

function Resolve-ReleaseAssets {
	param([string]$ProjectRoot)

	$buildsDir = Join-Path $ProjectRoot "builds"
	$assetDefinitions = @(
		@{ Label = "windows"; Candidates = @("exkrementus-windows.zip") },
		@{ Label = "linux"; Candidates = @("exkrementus-linux.zip") },
		@{ Label = "mac"; Candidates = @("exkrementus-mac.zip") },
		@{ Label = "android"; Candidates = @("exkrementus-android.apk", "exkrementus-android.aab", "exkrementus-android.zip") }
	)

	$assets = @()
	foreach ($definition in $assetDefinitions) {
		$found = $null
		foreach ($candidate in $definition.Candidates) {
			$candidatePath = Join-Path $buildsDir $candidate
			if (Test-Path $candidatePath) {
				$found = (Resolve-Path $candidatePath).Path
				break
			}
		}

		if ($null -eq $found) {
			throw "Missing release asset for $($definition.Label) in $buildsDir"
		}
		$assets += $found
	}

	return $assets
}

function Write-ReleaseNotes {
	param(
		[string]$Path,
		[string]$Version,
		[string[]]$Assets
	)

	$releaseDate = (Get-Date).ToString("yyyy-MM-dd")
	$lines = @(
		"# Exkrementus $Version",
		"",
		"Release date: $releaseDate",
		"",
		"Assets:"
	)

	foreach ($asset in $Assets) {
		$lines += "- " + [System.IO.Path]::GetFileName($asset)
	}

	$lines += ""
	[System.IO.File]::WriteAllText($Path, ($lines -join "`n"), [System.Text.UTF8Encoding]::new($false))
}

$projectRoot = (Resolve-Path $PSScriptRoot).Path
$versionPath = Join-Path $projectRoot "VERSION"
$buildScript = Join-Path $projectRoot "build-all.ps1"
$buildsDir = Join-Path $projectRoot "builds"

Require-Command -Name git
Assert-CleanWorkingTree

$currentBranch = (& git branch --show-current).Trim()
if ([string]::IsNullOrWhiteSpace($currentBranch)) {
	throw "Unable to determine current branch."
}
if ($currentBranch -ne "main") {
	throw "Release must run from branch 'main'. Current branch: $currentBranch"
}

$currentVersion = Read-VersionFile -Path $versionPath
$newVersion = if ($Version -and $Version.Trim() -ne "") { $Version.Trim() } else { Get-BumpedVersion -Current $currentVersion -Kind $Bump }

if ($newVersion -notmatch '^\d+\.\d+\.\d+$') {
	throw "Target version '$newVersion' is invalid. Use MAJOR.MINOR.PATCH."
}
if ((Compare-SemVer -Left $newVersion -Right $currentVersion) -le 0) {
	throw "Target version '$newVersion' must be higher than current version '$currentVersion'."
}

$tagName = "v$newVersion"
if ((& git tag --list $tagName) -contains $tagName) {
	throw "Tag $tagName already exists locally."
}
Assert-RemoteTagDoesNotExist -TagName $tagName

if (-not $SkipBuild) {
	if (!(Test-Path $buildScript)) {
		throw "Build script not found: $buildScript"
	}
	& $buildScript
	if ($LASTEXITCODE -ne 0) {
		throw "Build failed."
	}
}

$assets = Resolve-ReleaseAssets -ProjectRoot $projectRoot
if (!(Test-Path $buildsDir)) {
	New-Item -ItemType Directory -Path $buildsDir -Force | Out-Null
}
$releaseNotesPath = Join-Path $buildsDir ("RELEASE_" + $newVersion + ".md")
Write-ReleaseNotes -Path $releaseNotesPath -Version $newVersion -Assets $assets

[System.IO.File]::WriteAllText($versionPath, "$newVersion`n", [System.Text.UTF8Encoding]::new($false))

Invoke-Git -GitArgs @("add", "VERSION")
Invoke-Git -GitArgs @("commit", "-m", "chore(release): prepare $newVersion")

if (-not $SkipPush) {
	Invoke-Git -GitArgs @("push", "origin", "main")
}

Invoke-Git -GitArgs @("tag", "-a", $tagName, "-m", "Release $newVersion")
if (-not $SkipPush) {
	Invoke-Git -GitArgs @("push", "origin", $tagName)
}

if (-not $SkipRelease) {
	if ($SkipPush) {
		throw "Cannot create remote release with -SkipPush. Push commit/tag first or run without -SkipPush."
	}

	Require-Command -Name gh
	$releaseTitle = "Exkrementus $newVersion"
	$releaseExists = $false
	$previousErrorActionPreference = $ErrorActionPreference
	try {
		$ErrorActionPreference = "Continue"
		& gh release view $tagName *> $null
		$releaseExists = ($LASTEXITCODE -eq 0)
	} finally {
		$ErrorActionPreference = $previousErrorActionPreference
	}

	if ($releaseExists) {
		$editArgs = @("release", "edit", $tagName, "--title", $releaseTitle, "--notes-file", $releaseNotesPath, "--verify-tag")
		if ($Draft) { $editArgs += "--draft" }
		if ($Prerelease) { $editArgs += "--prerelease" }
		& gh @editArgs
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to edit existing GitHub release $tagName."
		}

		$uploadArgs = @("release", "upload", $tagName) + $assets + @("--clobber")
		& gh @uploadArgs
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to upload assets to existing GitHub release $tagName."
		}
	} else {
		$createArgs = @("release", "create", $tagName) + $assets + @("--target", "main", "--title", $releaseTitle, "--notes-file", $releaseNotesPath, "--verify-tag")
		if ($Draft) { $createArgs += "--draft" }
		if ($Prerelease) { $createArgs += "--prerelease" }
		& gh @createArgs
		if ($LASTEXITCODE -ne 0) {
			throw "Failed to create GitHub release $tagName."
		}
	}
}

Write-Host "Release workflow finished successfully."
Write-Host "Current version: $currentVersion"
Write-Host "New version: $newVersion"
Write-Host "Tag: $tagName"
if (-not $SkipRelease) {
	Write-Host "Release notes: $releaseNotesPath"
}
