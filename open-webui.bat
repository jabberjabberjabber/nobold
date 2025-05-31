@echo off


set "VENV_NAME=nobold_env"

set "PYTHON_PATH=python"

%PYTHON_PATH% --version >nul 2>&1
if errorlevel 1 (
    echo Python is not found. Please ensure Python is installed and added to your PATH.
    pause
    exit /b 1
)


if not exist "%VENV_NAME%\Scripts\activate.bat" (
    echo Creating new virtual environment: %VENV_NAME%
    %PYTHON_PATH% -m venv %VENV_NAME%
    if errorlevel 1 (
        echo Failed to create virtual environment. Please check your Python installation.
        pause
        exit /b 1
    )
else (
    echo Virtual environment %VENV_NAME% already exists.
)

call "%VENV_NAME%\Scripts\activate.bat"

open-webui serve

deactivate
exit /b 1