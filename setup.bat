@echo off
echo ========================================
echo Stock Screener - Setup Script
echo ========================================
echo.

REM Check if .env exists
if exist .env (
    echo [INFO] .env file already exists.
    set /p overwrite="Do you want to overwrite it? (y/n): "
    if /i not "%overwrite%"=="y" (
        echo [INFO] Keeping existing .env file.
        goto :frontend_env
    )
)

echo [1/5] Creating backend .env file...
copy .env.example .env >nul
echo [SUCCESS] Backend .env file created.
echo.

:frontend_env
REM Check if frontend .env exists
if exist frontend\.env (
    echo [INFO] Frontend .env file already exists.
    set /p overwrite_frontend="Do you want to overwrite it? (y/n): "
    if /i not "%overwrite_frontend%"=="y" (
        echo [INFO] Keeping existing frontend .env file.
        goto :venv_check
    )
)

echo [2/5] Creating frontend .env file...
copy frontend\.env.example frontend\.env >nul
echo [SUCCESS] Frontend .env file created.
echo.

:venv_check
echo [3/5] Checking Python virtual environment...
if exist venv\ (
    echo [INFO] Virtual environment already exists.
) else (
    echo [INFO] Creating virtual environment...
    python -m venv venv
    echo [SUCCESS] Virtual environment created.
)
echo.

echo [4/5] Installing Python dependencies...
call venv\Scripts\activate.bat
pip install -r requirements.txt
echo [SUCCESS] Python dependencies installed.
echo.

echo [5/5] Installing frontend dependencies...
cd frontend
call npm install
cd ..
echo [SUCCESS] Frontend dependencies installed.
echo.

echo ========================================
echo Setup Complete!
echo ========================================
echo.
echo Your .env files have been configured with default values.
echo.
echo To customize the configuration, edit:
echo   - .env (backend configuration)
echo   - frontend\.env (frontend configuration)
echo.
echo To start the application:
echo   1. Run: start-backend.bat
echo   2. Run: start-frontend.bat
echo.
echo The app will be available at: http://localhost:5173
echo The API will be available at: http://localhost:8000
echo.
pause
