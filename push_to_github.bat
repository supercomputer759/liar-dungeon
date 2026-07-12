@echo off
chcp 65001 >nul
setlocal

set "REMOTE_URL=https://github.com/supercomputer759/liar-dungeon.git"
set "BRANCH_NAME=main"

cd /d "%~dp0"

if /i "%~1"=="--check" (
    if not exist "project.godot" exit /b 1
    where git >nul 2>nul
    if errorlevel 1 exit /b 1
    echo 확인 완료
    exit /b 0
)

where git >nul 2>nul
if errorlevel 1 (
    echo 오류: Git for Windows가 필요합니다.
    pause
    exit /b 1
)

if not exist "project.godot" (
    echo 오류: project.godot을 찾지 못했습니다.
    pause
    exit /b 1
)

git init
if errorlevel 1 goto fail

git remote get-url origin >nul 2>nul
if errorlevel 1 (
    git remote add origin "%REMOTE_URL%"
) else (
    git remote set-url origin "%REMOTE_URL%"
)
if errorlevel 1 goto fail

git add .
if errorlevel 1 goto fail

set "COMMIT_MESSAGE=거짓말 던전 업데이트"
set /p "USER_COMMIT_MESSAGE=커밋 메시지 입력, Enter는 기본값 사용: "
if not "%USER_COMMIT_MESSAGE%"=="" set "COMMIT_MESSAGE=%USER_COMMIT_MESSAGE%"

git diff --cached --quiet
if errorlevel 1 (
    git commit -m "%COMMIT_MESSAGE%"
    if errorlevel 1 goto fail
)

git pull --rebase origin "%BRANCH_NAME%"
if errorlevel 1 goto fail

git push -u origin "%BRANCH_NAME%"
if errorlevel 1 goto fail

echo 완료: GitHub에 업로드했습니다.
pause
exit /b 0

:fail
echo 실패: 위 Git 오류 메시지를 확인하세요.
pause
exit /b 1
