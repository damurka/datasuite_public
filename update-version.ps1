$ReleaseVersion = "1.0.0-beta6"
$BuildSourceVersion = "7832a8a4375372a5920cb54f8dff62588f386dcb"
$BaseUrl = "https://github.com/aphrcwaro/datasuite_public/releases/download/$ReleaseVersion"
$OutRoot = "versions/stable/win32/x64"

$SystemExe = Get-ChildItem ".build/win32-x64/system-setup/*.exe" | Select-Object -First 1
$UserExe   = Get-ChildItem ".build/win32-x64/user-setup/*.exe"   | Select-Object -First 1
$ZipFile   = Get-ChildItem "../*.zip" | Select-Object -First 1

function Get-Sha1Hex($path) {
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    $stream = [System.IO.File]::OpenRead($path)
    try {
        ($sha1.ComputeHash($stream) | ForEach-Object { $_.ToString("x2") }) -join ""
    } finally {
        $stream.Dispose()
        $sha1.Dispose()
    }
}

function Get-Sha256Hex($path) {
    return (Get-FileHash $path -Algorithm SHA256).Hash.ToLower()
}

function Transform-Version($version) {
    # Split into numeric core and optional suffix, e.g.
    # 1.2.0-beta3 -> base=1.2.0, suffix=-beta3
    # 1.2.0-insider -> base=1.2.0, suffix=-insider
    if ($version -match '^(?<base>\d+\.\d+\.\d+)(?<suffix>-[0-9A-Za-z.-]+)?$') {
        $base = $Matches.base
        $suffix = $Matches.suffix
    } else {
        throw "Unsupported version format: $version"
    }

    $parts = $base.Split('.')

    # normalize patch segment
    $parts[2] = ([int]$parts[2]).ToString()

    # VSCodium-style productVersion uses 4 numeric parts
    $productVersion = "$($parts[0]).$($parts[1]).$($parts[2]).0"

    # keep prerelease suffix if you want it in JSON
    if ($suffix) {
        $productVersion += $suffix
    }

    return $productVersion
}

function Write-LatestJson($filePath, $subPath) {
    $timestamp = [DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds()
    $fileName = Split-Path $filePath -Leaf

    $json = [ordered]@{
        url            = "$BaseUrl/$fileName"
        name           = $ReleaseVersion
        version        = $BuildSourceVersion
        productVersion = Transform-Version $ReleaseVersion
        hash           = Get-Sha1Hex $filePath
        timestamp      = $timestamp
        sha256hash     = Get-Sha256Hex $filePath
    }

    $targetDir = Join-Path $OutRoot $subPath
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    $json | ConvertTo-Json -Depth 3 | Set-Content -Encoding utf8 (Join-Path $targetDir "latest.json")
}

Write-LatestJson $SystemExe.FullName "system"
Write-LatestJson $UserExe.FullName   "user"
Write-LatestJson $ZipFile.FullName   "archive"