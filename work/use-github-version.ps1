$ErrorActionPreference = 'Stop'
$repoPath = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
Push-Location -LiteralPath $repoPath
try {
  # Fetch must succeed before discarding the cancelled local implementation.
  git fetch origin main
  if ($LASTEXITCODE -ne 0) { throw 'GitHub could not be reached. No local changes were discarded.' }
  git reset --hard origin/main
  if ($LASTEXITCODE -ne 0) { throw 'Could not switch to the GitHub version.' }
  # Only remove files introduced by the cancelled Monster Motion work.
  # The benchmark ZIP and original existing project assets remain available.
  $cancelledPaths = @(
    'Images/Monster/Motion',
    'web/css/monster-motion.css',
    'web/img/monster-motion',
    'web/js/monster-motion.js',
    'work/create-monster-benchmark.cjs',
    'work/extract-monster-poses.ps1',
    'work/test-monster-motion.cjs'
  )
  git clean -fd -- @cancelledPaths
  if ($LASTEXITCODE -ne 0) { throw 'Could not clean cancelled motion files.' }
  $conflicts = git ls-files -u
  if ($conflicts) { throw 'Unresolved conflicts remain.' }
  Write-Host "GitHub version is ready in $repoPath"
  git log -1 --oneline
  Write-Host 'The benchmark backup remains in benchmarks.'
} finally { Pop-Location }
