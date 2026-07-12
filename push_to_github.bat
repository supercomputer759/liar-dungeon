@echo off
chcp 65001 >nul
setlocal

set "REMOTE_URL=https://github.com/supercomputer759/liar-dungeon.git"
set "BRANCH_NAME=main"

cd /d "%~dp0"

if /i "%~1"=="--check" (
    echo 배치 파일 확인 모드입니다.
    if not exist "project.godot" (
        echo 오류: project.godot을 찾지 못했습니다.
        exit /b 1
    )
    where git >nul 2>nul
    if errorlevel 1 (
        echo 오류: Git이 설치되어 있지 않거나 PATH에 등록되어 있지 않습니다.
        exit /b 1
    )
    echo 확인 완료: 기본 실행 조건이 정상입니다.
    exit /b 0
)

echo.
echo [거짓말 던전] GitHub 업로드 스크립트
echo 저장소: %REMOTE_URL%
echo.

where git >nul 2>nul
if errorlevel 1 (
    echo 오류: Git이 설치되어 있지 않거나 PATH에 등록되어 있지 않습니다.
    echo Git for Windows 설치 후 다시 실행하세요.
    pause
    exit /b 1
)

if not exist "project.godot" (
    echo 오류: project.godot을 찾지 못했습니다.
    echo 이 .bat 파일을 Godot 프로젝트 루트 폴더에서 실행하세요.
    pause
    exit /b 1
)

if not exist ".gitignore" (
    echo # Godot 4+ specific ignores> ".gitignore"
    echo .godot/>> ".gitignore"
    echo /android/>> ".gitignore"
)

findstr /c:".godot/" ".gitignore" >nul 2>nul
if errorlevel 1 (
    echo .godot/>> ".gitignore"
)

echo Git 저장소를 준비합니다...
git init
if errorlevel 1 goto fail

git remote get-url origin >nul 2>nul
if errorlevel 1 (
    git remote add origin "%REMOTE_URL%"
) else (
    git remote set-url origin "%REMOTE_URL%"
)
if errorlevel 1 goto fail

echo.
echo 커밋할 파일을 추가합니다...
git add .
if errorlevel 1 goto fail

echo.
echo 현재 변경 사항:
git status --short

echo.
set "COMMIT_MESSAGE=첫 번째 거짓말 던전 프로토타입"
set /p "USER_COMMIT_MESSAGE=커밋 메시지 입력, Enter는 기본값 사용: "
if not "%USER_COMMIT_MESSAGE%"=="" set "COMMIT_MESSAGE=%USER_COMMIT_MESSAGE%"

git diff --cached --quiet
if errorlevel 1 (
    git commit -m "%COMMIT_MESSAGE%"
    if errorlevel 1 goto fail
) else (
    echo 커밋할 변경 사항이 없습니다. 푸시만 시도합니다.
)

git branch -M "%BRANCH_NAME%"
if errorlevel 1 goto fail

echo.
echo GitHub로 푸시합니다...
echo 인증 창이 뜨면 GitHub 로그인을 진행하세요.
git push -u origin "%BRANCH_NAME%"
if errorlevel 1 goto fail

echo.
echo 완료: GitHub 저장소에 업로드했습니다.
pause
exit /b 0

:fail
echo.
echo 실패: 위의 Git 오류 메시지를 확인하세요.
echo GitHub 저장소 권한, 로그인 상태, 원격 주소를 확인해야 할 수 있습니다.
pause
exit /b 1
