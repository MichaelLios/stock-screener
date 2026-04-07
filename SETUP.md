# Stock Screener - Setup Guide

This guide will help you set up and configure the Stock Screener application.

## Quick Start

### Automated Setup

The easiest way to get started is to run the setup script:

```bash
setup.bat
```

This automated script will:
1. Create `.env` configuration files from templates
2. Set up Python virtual environment (if not exists)
3. Install all Python dependencies
4. Install all Node.js dependencies

After running the setup script, you're ready to start the application!

## Environment Configuration

The application uses environment variables for configuration. Two `.env` files are used:

### Backend Configuration (`.env`)

Located in the root directory. Controls backend server settings.

```env
# Backend Configuration
BACKEND_HOST=0.0.0.0          # Host to bind the server to
BACKEND_PORT=8000             # Port for the backend API

# Frontend Configuration
FRONTEND_URL=http://localhost:5173

# CORS Origins (comma-separated)
CORS_ORIGINS=http://localhost:5173,http://localhost:3000

# Environment
ENVIRONMENT=development       # development or production
```

**Configuration Options:**

- `BACKEND_HOST`: The network interface to bind to
  - `0.0.0.0` = All interfaces (accessible from network)
  - `127.0.0.1` = Localhost only (more secure)

- `BACKEND_PORT`: The port number for the API server
  - Default: `8000`
  - Change if port 8000 is already in use

- `CORS_ORIGINS`: Comma-separated list of allowed frontend URLs
  - Add your production frontend URL here when deploying

- `ENVIRONMENT`: Application environment mode
  - `development` = Development mode with debug info
  - `production` = Production mode

### Frontend Configuration (`frontend/.env`)

Located in the `frontend/` directory. Controls frontend API connection.

```env
# API Configuration
VITE_API_URL=http://localhost:8000
```

**Configuration Options:**

- `VITE_API_URL`: The URL where the backend API is running
  - Default: `http://localhost:8000`
  - Change if you modified `BACKEND_PORT` or hosting remotely
  - Must match your backend server URL

## Manual Setup

If you prefer to set up manually or need to troubleshoot:

### Step 1: Create Environment Files

```bash
# Copy the example files
copy .env.example .env
copy frontend\.env.example frontend\.env
```

### Step 2: Set Up Python Environment

```bash
# Create virtual environment
python -m venv venv

# Activate virtual environment
venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

### Step 3: Set Up Frontend

```bash
# Navigate to frontend
cd frontend

# Install dependencies
npm install

# Return to root
cd ..
```

### Step 4: Verify Setup

Check that all files are in place:
- ✓ `.env` exists in root directory
- ✓ `frontend/.env` exists in frontend directory
- ✓ `venv/` folder exists
- ✓ `frontend/node_modules/` folder exists

## Starting the Application

After setup is complete:

### Option 1: Using Batch Scripts (Recommended)

1. **Start Backend**:
   ```bash
   start-backend.bat
   ```
   Keep this window open.

2. **Start Frontend**:
   ```bash
   start-frontend.bat
   ```
   Keep this window open.

### Option 2: Manual Start

**Backend**:
```bash
cd backend
..\venv\Scripts\python.exe main.py
```

**Frontend** (in a new terminal):
```bash
cd frontend
npm run dev
```

## Customizing Configuration

### Changing the Backend Port

If port 8000 is already in use:

1. Edit `.env`:
   ```env
   BACKEND_PORT=8080  # Use your desired port
   ```

2. Edit `frontend/.env`:
   ```env
   VITE_API_URL=http://localhost:8080  # Match the backend port
   ```

3. Restart both servers

### Adding CORS Origins

To allow additional frontend URLs (e.g., for deployment):

1. Edit `.env`:
   ```env
   CORS_ORIGINS=http://localhost:5173,http://localhost:3000,https://your-domain.com
   ```

2. Restart the backend server

### Network Access

To allow access from other devices on your network:

1. Keep `BACKEND_HOST=0.0.0.0` in `.env`

2. Find your local IP address:
   ```bash
   ipconfig
   ```

3. Update `frontend/.env` with your IP:
   ```env
   VITE_API_URL=http://192.168.1.100:8000  # Use your actual IP
   ```

4. Access from other devices at: `http://192.168.1.100:5173`

## Troubleshooting

### "Module not found" errors

```bash
# Reactivate virtual environment and reinstall
venv\Scripts\activate
pip install -r requirements.txt
```

### Frontend can't connect to backend

1. Verify backend is running (check terminal window)
2. Check `frontend/.env` has correct `VITE_API_URL`
3. Check browser console for CORS errors
4. Ensure `CORS_ORIGINS` in `.env` includes your frontend URL

### Port already in use

```bash
# Windows: Find and kill the process
netstat -ano | findstr :8000
taskkill /PID <process_id> /F
```

Then change the port in your `.env` files.

### Environment variables not loading

1. Ensure `.env` files have no spaces around `=`:
   ```env
   # Correct
   BACKEND_PORT=8000

   # Wrong
   BACKEND_PORT = 8000
   ```

2. Restart both servers after changing `.env` files

3. For frontend changes, you may need to clear Vite cache:
   ```bash
   cd frontend
   rm -rf node_modules/.vite
   npm run dev
   ```

## Security Notes

### Important for Production

1. **Never commit `.env` files to version control**
   - They're already in `.gitignore`
   - Only commit `.env.example` files

2. **Use strong, unique values in production**:
   - Add API keys only to `.env`, never to code
   - Use environment-specific values

3. **Restrict CORS origins in production**:
   ```env
   CORS_ORIGINS=https://your-production-domain.com
   ```

4. **Use HTTPS in production**:
   ```env
   VITE_API_URL=https://api.your-domain.com
   ```

## Adding New Environment Variables

### Backend

1. Add to `.env.example`:
   ```env
   MY_NEW_VARIABLE=default_value
   ```

2. Add to your `.env` file with actual value

3. Load in `backend/main.py`:
   ```python
   MY_NEW_VARIABLE = os.getenv("MY_NEW_VARIABLE", "default_value")
   ```

### Frontend

1. Add to `frontend/.env.example` (must start with `VITE_`):
   ```env
   VITE_MY_NEW_VARIABLE=default_value
   ```

2. Add to your `frontend/.env` file with actual value

3. Use in components:
   ```typescript
   const myVar = import.meta.env.VITE_MY_NEW_VARIABLE
   ```

## Getting Help

If you encounter issues:

1. Check this guide's Troubleshooting section
2. Review the main [README.md](README.md)
3. Ensure all environment files are properly configured
4. Check terminal/console for error messages

## Summary

✓ Run `setup.bat` for automated configuration
✓ Edit `.env` files to customize settings
✓ Use `start-backend.bat` and `start-frontend.bat` to run
✓ Never commit `.env` files to version control
✓ Restart servers after changing configuration
