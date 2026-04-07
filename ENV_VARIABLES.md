# Environment Variables Reference

Quick reference for all environment variables used in the Stock Screener application.

## Backend Variables (`.env`)

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `BACKEND_HOST` | `0.0.0.0` | Host address to bind the server. Use `0.0.0.0` for all interfaces or `127.0.0.1` for localhost only. |
| `BACKEND_PORT` | `8000` | Port number for the backend API server. |
| `FRONTEND_URL` | `http://localhost:5173` | URL of the frontend application (for reference). |
| `CORS_ORIGINS` | `http://localhost:5173,http://localhost:3000` | Comma-separated list of allowed frontend URLs for CORS. |
| `ENVIRONMENT` | `development` | Application environment mode: `development` or `production`. |

## Frontend Variables (`frontend/.env`)

| Variable | Default Value | Description |
|----------|---------------|-------------|
| `VITE_API_URL` | `http://localhost:8000` | URL of the backend API server. Must match your backend configuration. |

## Usage Examples

### Development (Default)

**Backend (`.env`)**:
```env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
ENVIRONMENT=development
```

**Frontend (`frontend/.env`)**:
```env
VITE_API_URL=http://localhost:8000
```

### Custom Port

If port 8000 is in use, change to 8080:

**Backend (`.env`)**:
```env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8080
CORS_ORIGINS=http://localhost:5173,http://localhost:3000
ENVIRONMENT=development
```

**Frontend (`frontend/.env`)**:
```env
VITE_API_URL=http://localhost:8080
```

### Network Access (LAN)

To access from other devices on your local network:

**Backend (`.env`)**:
```env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
CORS_ORIGINS=http://localhost:5173,http://192.168.1.100:5173
ENVIRONMENT=development
```

**Frontend (`frontend/.env`)**:
```env
VITE_API_URL=http://192.168.1.100:8000
```

Replace `192.168.1.100` with your actual local IP address.

### Production Deployment

**Backend (`.env`)**:
```env
BACKEND_HOST=0.0.0.0
BACKEND_PORT=8000
CORS_ORIGINS=https://your-domain.com
ENVIRONMENT=production
```

**Frontend (`frontend/.env`)**:
```env
VITE_API_URL=https://api.your-domain.com
```

## Notes

### Backend Variables

- **BACKEND_HOST**:
  - `0.0.0.0` allows access from any network interface (recommended for development and production)
  - `127.0.0.1` restricts access to localhost only (more secure, but limits functionality)

- **CORS_ORIGINS**:
  - Must include all URLs that will access your API
  - Use commas to separate multiple origins, no spaces
  - Include protocol (`http://` or `https://`)
  - In production, only include your actual domain

- **ENVIRONMENT**:
  - `development`: More verbose logging, debug mode
  - `production`: Optimized for performance, less logging

### Frontend Variables

- **VITE_API_URL**:
  - Must start with `VITE_` to be accessible in the frontend
  - Must match the backend server's actual URL and port
  - Include protocol but no trailing slash
  - Changes require frontend restart

## Validation Checklist

Before starting the application, verify:

- [ ] `.env` file exists in root directory
- [ ] `frontend/.env` file exists in frontend directory
- [ ] `BACKEND_PORT` in `.env` matches port in `VITE_API_URL`
- [ ] `CORS_ORIGINS` includes your frontend URL
- [ ] No syntax errors (no spaces around `=`)
- [ ] All required variables are set

## Common Issues

### Frontend can't connect to backend
- Check `VITE_API_URL` matches backend URL
- Verify backend is running
- Check `CORS_ORIGINS` includes frontend URL

### Port already in use
- Change `BACKEND_PORT` to a different port
- Update `VITE_API_URL` to match new port

### Environment changes not taking effect
- Restart backend server after changing `.env`
- Restart frontend dev server after changing `frontend/.env`
- Clear browser cache if needed
