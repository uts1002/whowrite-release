# 누가기록 Windows 설치 · 업데이트 (PowerShell 한 줄)
#
#   irm https://raw.githubusercontent.com/uts1002/whowrite-release/main/install-win.ps1 | iex
#
# - 최신 setup.exe 를 받아 조용히(/VERYSILENT) 설치한다. 관리자 권한 필요 없음 (installer.iss: PrivilegesRequired=lowest).
# - PowerShell 로 받은 파일에는 "인터넷에서 받은 파일" 표시가 붙지 않아 SmartScreen 경고가 뜨지 않는다.
# - 같은 명령을 다시 실행하면 최신 버전으로 업데이트된다. 사용자 데이터(~\.whowrite)는 건드리지 않는다.
# - raw.githubusercontent.com 은 charset=utf-8 로 내려주므로 irm 이 한글을 바르게 읽는다.
#   BOM 을 넣지 말 것 — irm 결과 맨 앞에 BOM 이 남아 첫 줄 주석이 명령으로 실행된다.
#   (Release 자산 URL 은 octet-stream 이라 한글 안내문이 깨질 수 있어 쓰지 않는다)
#
# 환경 변수
#   WHOWRITE_BASE_URL  setup.exe 를 받을 주소 (기본: whowrite-release 최신 Release)
#   WHOWRITE_DRYRUN=1  내려받기·설치 없이 할 일만 출력

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'   # PS 5.1 진행 막대가 다운로드를 크게 늦춘다
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$base = if ($env:WHOWRITE_BASE_URL) { $env:WHOWRITE_BASE_URL.TrimEnd('/') } else {
    'https://github.com/uts1002/whowrite-release/releases/latest/download'
}
$url = "$base/whowrite_setup_latest.exe"
$installDir = Join-Path $env:LOCALAPPDATA 'Programs\whowrite'
$tmp = Join-Path $env:TEMP 'whowrite_setup_latest.exe'
$dry = $env:WHOWRITE_DRYRUN -eq '1'

function Say($msg) { Write-Host "  $msg" }

Write-Host ''
Write-Host '  누가기록 설치' -ForegroundColor Cyan
Write-Host ''

if ($dry) {
    $head = Invoke-WebRequest $url -Method Head -UseBasicParsing
    Say "[확인만] 받을 파일: $url ($($head.Headers['Content-Length']) bytes)"
    Say "[확인만] 설치 위치: $installDir"
    Say '[확인만] 실행 인자: /VERYSILENT /SUPPRESSMSGBOXES /NORESTART /CURRENTUSER /SKIPSELFUPDATE'
    return
}

# 켜져 있으면 파일을 덮어쓸 수 없으니 먼저 닫는다.
$running = Get-Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Path -and $_.Path.StartsWith($installDir, [StringComparison]::OrdinalIgnoreCase) }
if ($running) {
    Say '켜져 있는 누가기록을 닫는 중... (기록은 이미 저장돼 있어요)'
    $running | ForEach-Object { $_.CloseMainWindow() | Out-Null }
    Start-Sleep -Seconds 2
    $running | Where-Object { -not $_.HasExited } | Stop-Process -Force
}

Say '최신 버전을 내려받는 중...'
try {
    Invoke-WebRequest $url -OutFile $tmp -UseBasicParsing
} catch {
    Write-Host ''
    Write-Host '  내려받지 못했어요. 인터넷 연결을 확인하고 다시 실행해 주세요.' -ForegroundColor Red
    Write-Host "  ($($_.Exception.Message))"
    return
}

Say '설치하는 중... (관리자 권한 필요 없음, 30초쯤 걸려요)'
$p = Start-Process $tmp -ArgumentList '/VERYSILENT', '/SUPPRESSMSGBOXES', '/NORESTART', '/CURRENTUSER', '/SKIPSELFUPDATE' -Wait -PassThru
Remove-Item $tmp -ErrorAction SilentlyContinue
if ($p.ExitCode -ne 0) {
    Write-Host ''
    Write-Host "  설치하지 못했어요 (코드 $($p.ExitCode)). 다시 실행해 보고, 계속 안 되면 setup.exe 로 설치해 주세요:" -ForegroundColor Red
    Write-Host "  $url"
    return
}

# 실행 파일 이름이 한글이라 스크립트에 직접 쓰지 않고 찾는다 (인코딩이 달라도 안전).
$exe = Get-ChildItem $installDir -Filter '*.exe' -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -notlike 'unins*' } | Select-Object -First 1
Write-Host ''
Write-Host '  설치 끝! 시작 메뉴와 바탕화면에 "누가기록"이 생겼어요.' -ForegroundColor Green
Say '나중에 같은 명령을 다시 붙여넣으면 최신 버전으로 업데이트돼요.'
Write-Host ''
if ($exe) { Start-Process $exe.FullName }
