# Ubuntu Development Environment in Docker

A fully-featured Ubuntu 24.04 desktop environment running in a Docker container with remote access capabilities via SSH, NoMachine, and VS Code Server.

## Features

- **Ubuntu 24.04 Desktop**: Full GNOME desktop environment
- **Remote Access**: 
  - SSH server on port 2222
  - NoMachine remote desktop on port 4003
  - VS Code Server (web-based) on port 8585
- **Development Tools**:
  - Build essentials (gcc, make, etc.)
  - Git, Vim, Nano, tmux
  - Python 3 with pip and pipx
  - Node.js (LTS) via NVM
  - Poetry (Python package manager)
  - Claude Code CLI
  - Docker-in-Docker support
- **Browsers**: Google Chrome and Firefox pre-installed
- **VS Code**: Desktop version installed with optional web-based server
- **Persistent Storage**: Home directory persists between container restarts

## Quick Start

1. **Clone this repository**:
   ```bash
   git clone <repository-url>
   cd docker
   ```

2. **Set up environment variables**:
   ```bash
   cp .env.example .env
   ```

3. **Generate a secure password hash**:
   ```bash
   ./generate-password-hash.sh
   ```
   Copy the generated hash to your `.env` file.

4. **Build and run the container**:
   ```bash
   docker-compose up -d
   ```

## Configuration

### Environment Variables (.env)

| Variable | Default | Description |
|----------|---------|-------------|
| `USERNAME` | default-user | Container user name |
| `USER_UID` | 1000 | User ID (match your host user for file permissions) |
| `USER_GID` | 1000 | Group ID |
| `USER_PASSWORD_HASH` | - | Hashed password for the user (required) |
| `USER_PASSWORD` | - | Plain text password (less secure alternative) |

### VS Code Server Options

| Variable | Default | Description |
|----------|---------|-------------|
| `VSCODE_PORT` | 8585 | Port for VS Code Server |
| `VSCODE_HOST` | 0.0.0.0 | Binding host |
| `VSCODE_TOKEN` | - | Access token for security |
| `VSCODE_SERVER_BASE_PATH` | - | URL base path (e.g., /vscode) |

## Accessing the Environment

### SSH Access
```bash
ssh -p 2222 your-username@localhost
```

### NoMachine Remote Desktop
1. Install NoMachine client on your host machine
2. Connect to `localhost:4003`
3. Use your container credentials to log in

### VS Code Server (Web)
Navigate to `http://localhost:8585` in your browser (if enabled).

## Directory Structure

- `dockerfile`: Container image definition
- `docker-compose.yml`: Service configuration
- `.env.example`: Example environment variables
- `generate-password-hash.sh`: Utility to create secure password hashes
- `workspace/`: Mounted directory for your projects

## Volumes

- **dev-home**: Persistent home directory storage
- **./workspace**: Host directory mounted at `~/workspace` in container

## Security Notes

1. **Password Security**: Always use `USER_PASSWORD_HASH` instead of plain text passwords
2. **Privileged Container**: Runs with elevated privileges for systemd compatibility
3. **Port Exposure**: Only expose necessary ports in production environments

## Docker-in-Docker

The container includes Docker CLI and can optionally connect to the host's Docker daemon by uncommenting this line in `docker-compose.yml`:
```yaml
# - /var/run/docker.sock:/var/run/docker.sock
```

## Troubleshooting

### Container won't start
- Ensure all required ports are available
- Check Docker logs: `docker-compose logs`

### Can't connect via SSH/NoMachine
- Verify the password was set correctly in `.env`
- Check if services are running: `docker exec ubuntu-dev systemctl status ssh nxserver`

### Permission issues with mounted volumes
- Ensure `USER_UID` and `USER_GID` match your host user

## Requirements

- Docker Engine 20.10+
- Docker Compose 2.0+
- 8GB+ RAM recommended for desktop environment
- 20GB+ disk space

## License

[Your License Here]