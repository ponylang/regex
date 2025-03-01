Param(
  [Parameter(Position=0, HelpMessage="The action to take (build, test, install, package, clean).")]
  [string]
  $Command = 'build',

  [Parameter(HelpMessage="The build configuration (Release, Debug).")]
  [string]
  $Config = "Release",

  [Parameter(HelpMessage="The version number to set.")]
  [string]
  $Version = "",

  [Parameter(HelpMessage="Architecture (native, x64).")]
  [string]
  $Arch = "x86-64",

  [Parameter(HelpMessage="Directory to install to.")]
  [string]
  $Destdir = "build/install"
)

$ErrorActionPreference = "Stop"

$target = "regex" # The name of the source package, and the base name of the .exe file that is built if this is a program, not a library.
$testPath = "." # The path of the tests package relative to the $target directory.
$isLibrary = $true

$rootDir = Split-Path $script:MyInvocation.MyCommand.Path
$srcDir = Join-Path -Path $rootDir -ChildPath $target

if ($Config -ieq "Release")
{
  $configFlag = ""
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/release"
}
elseif ($Config -ieq "Debug")
{
  $configFlag = "--debug"
  $buildDir = Join-Path -Path $rootDir -ChildPath "build/debug"
}
else
{
  throw "Invalid -Config path '$Config'; must be one of (Debug, Release)."
}

$libsDir = Join-Path -Path $rootDir -ChildPath "build/libs"

if (($Version -eq "") -and (Test-Path -Path "$rootDir\VERSION"))
{
  $Version = (Get-Content "$rootDir\VERSION") + "-" + (& git 'rev-parse' '--short' '--verify' 'HEAD^')
}

$ponyArgs = "--define openssl_0.9.0 --path $rootDir"

Write-Host "Configuration:    $Config"
Write-Host "Version:          $Version"
Write-Host "Root directory:   $rootDir"
Write-Host "Source directory: $srcDir"
Write-Host "Build directory:  $buildDir"

# generate pony templated files if necessary
if (($Command -ne "clean") -and (Test-Path -Path "$rootDir\VERSION"))
{
  $versionTimestamp = (Get-ChildItem -Path "$rootDir\VERSION").LastWriteTimeUtc
  Get-ChildItem -Path $srcDir -Include "*.pony.in" -Recurse | ForEach-Object {
    $templateFile = $_.FullName
    $ponyFile = $templateFile.Substring(0, $templateFile.Length - 3)
    $ponyFileTimestamp = [DateTime]::MinValue
    if (Test-Path $ponyFile)
    {
      $ponyFileTimestamp = (Get-ChildItem -Path $ponyFile).LastWriteTimeUtc
    }
    if (($ponyFileTimestamp -lt $versionTimestamp) -or ($ponyFileTimestamp -lt $_.LastWriteTimeUtc))
    {
      Write-Host "$templateFile -> $ponyFile"
      ((Get-Content -Path $templateFile) -replace '%%VERSION%%', $Version) | Set-Content -Path $ponyFile
    }
  }
}

function BuildTarget
{
  $binaryFile = Join-Path -Path $buildDir -ChildPath "$target.exe"
  $binaryTimestamp = [DateTime]::MinValue
  if (Test-Path $binaryFile)
  {
    $binaryTimestamp = (Get-ChildItem -Path $binaryFile).LastWriteTimeUtc
  }

  :buildFiles foreach ($file in (Get-ChildItem -Path $srcDir -Include "*.pony" -Recurse))
  {
    if ($binaryTimestamp -lt $file.LastWriteTimeUtc)
    {
      Write-Host "corral fetch"
      $output = (corral fetch)
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }

      Write-Host "corral run -- ponyc $configFlag $ponyArgs --cpu `"$Arch`" --output `"$buildDir`" `"$srcDir`""
      $output = (corral run -- ponyc $configFlag $ponyArgs --cpu "$Arch" --output "$buildDir" "$srcDir")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }
      break buildFiles
    }
  }
}

function BuildTest
{
  $testTarget = "test.exe"
  if ($testPath -eq ".")
  {
    $testTarget = "$target.exe"
  }

  $testFile = Join-Path -Path $buildDir -ChildPath $testTarget
  $testTimestamp = [DateTime]::MinValue
  if (Test-Path $testFile)
  {
    $testTimestamp = (Get-ChildItem -Path $testFile).LastWriteTimeUtc
  }

  :testFiles foreach ($file in (Get-ChildItem -Path $srcDir -Include "*.pony" -Recurse))
  {
    if ($testTimestamp -lt $file.LastWriteTimeUtc)
    {
      Write-Host "corral fetch"
      $output = (corral fetch)
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }

      $testDir = Join-Path -Path $srcDir -ChildPath $testPath
      Write-Host "corral run -- ponyc $configFlag $ponyArgs --cpu `"$Arch`" --output `"$buildDir`" `"$testDir`""
      $output = (corral run -- ponyc $configFlag $ponyArgs --cpu "$Arch" --output "$buildDir" "$testDir")
      $output | ForEach-Object { Write-Host $_ }
      if ($LastExitCode -ne 0) { throw "Error" }
      break testFiles
    }
  }

  Write-Output "$testTarget.exe is built" # force function to return a list of outputs
  return $testFile
}

function BuildLibs
{
  $pcre2 = "pcre2-10.35"
  $pcre2LibTgt = Join-Path -Path $rootDir -ChildPath "pcre2-8.lib"

  if (-not (Test-Path $pcre2LibTgt))
  {
    $pcre2Src = Join-Path -Path $libsDir -ChildPath $pcre2

    if (-not (Test-Path $pcre2Src))
    {
      $pcre2Zip = "$pcre2.zip"
      $pcre2ZipTgt = Join-Path -Path $libsDir -ChildPath $pcre2Zip
      if (-not (Test-Path $pcre2ZipTgt)) { Invoke-WebRequest -TimeoutSec 300 -Uri "https://github.com/PhilipHazel/pcre2/releases/download/$pcre2/$pcre2Zip" -OutFile $pcre2ZipTgt }
      Write-Output "Expand-Archive -Force -LiteralPath `"$pcre2ZipTgt`" -DestinationPath `"$libsDir`""
      Expand-Archive -Force -LiteralPath "$pcre2ZipTgt" -DestinationPath "$libsDir"
    }

    # Write-Output "Building $pcre2"
    $pcre2Lib = Join-Path -Path $libsDir -ChildPath "lib/pcre2-8.lib"

    if (-not (Test-Path $pcre2Lib))
    {
      Push-Location $pcre2Src
      cmake.exe $pcre2Src -Thost=x64 -A x64 -DCMAKE_INSTALL_PREFIX="$libsDir" -DCMAKE_BUILD_TYPE="Release"
      if ($LastExitCode -ne 0) { Pop-Location; throw "Error configuring $pcre2" }
      cmake.exe --build . --target install --config Release
      if ($LastExitCode -ne 0) { Pop-Location; throw "Error building $pcre2" }
      Pop-Location
    }

    # copy to the root dir (i.e. PONYPATH) for linking
    Copy-Item -Force -Path $pcre2Lib -Destination $pcre2LibTgt
  }
}

switch ($Command.ToLower())
{
  "libs"
  {
    if (-not (Test-Path $libsDir))
    {
      mkdir "$libsDir"
    }

    BuildLibs
  }

  "build"
  {
    if (-not $isLibrary)
    {
      BuildTarget
    }
    else
    {
      Write-Host "$target is a library; nothing to build."
    }
    break
  }

  "test"
  {
    if (-not $isLibrary)
    {
      BuildTarget
    }

    $testFile = (BuildTest)[-1]
    Write-Host "$testFile"
    & "$testFile"
    if ($LastExitCode -ne 0) { throw "Error" }
    break
  }

  "clean"
  {
    if (Test-Path "$buildDir")
    {
      Write-Host "Remove-Item -Path `"$buildDir`" -Recurse -Force"
      Remove-Item -Path "$buildDir" -Recurse -Force
    }
    break
  }

  "distclean"
  {
    $distDir = Join-Path -Path $rootDir -ChildPath "build"
    if (Test-Path $distDir)
    {
      Remove-Item -Path $distDir -Recurse -Force
    }
    Remove-Item -Path "*.lib" -Force
  }

  "install"
  {
    if (-not $isLibrary)
    {
      $binDir = Join-Path -Path $Destdir -ChildPath "bin"

      if (-not (Test-Path $binDir))
      {
        mkdir "$binDir"
      }

      $binFile = Join-Path -Path $buildDir -ChildPath "$target.exe"
      Copy-Item -Path $binFile -Destination $binDir -Force
    }
    else
    {
      Write-Host "$target is a library; nothing to install."
    }
    break
  }

  "package"
  {
    if (-not $isLibrary)
    {
      $binDir = Join-Path -Path $Destdir -ChildPath "bin"
      $package = "$target-x86-64-pc-windows-msvc.zip"
      Write-Host "Creating $package..."

      Compress-Archive -Path $binDir -DestinationPath "$buildDir\..\$package" -Force
    }
    else
    {
      Write-Host "$target is a library; nothing to package."
    }
    break
  }

  default
  {
    throw "Unknown command '$Command'; must be one of (libs, build, test, install, package, clean, distclean)."
  }
}
