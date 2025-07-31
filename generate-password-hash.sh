#!/bin/bash

echo "Yescrypt Password Hash Generator"
echo "================================"
echo

# Get username from .env or use default
if [ -f .env ]; then
    USERNAME=$(grep "^USERNAME=" .env | cut -d'=' -f2 || echo "default-user")
else
    USERNAME="default-user"
fi

# Function to read password portably
read_password() {
    if [ -t 0 ]; then
        stty -echo 2>/dev/null
        read password
        stty echo 2>/dev/null
        echo
    else
        read password
    fi
}

# Method 1: Try mkpasswd
if command -v mkpasswd >/dev/null 2>&1; then
    if mkpasswd -m help 2>&1 | grep -q yescrypt; then
        echo "Found mkpasswd with yescrypt support!"
        printf "Enter password for user '$USERNAME': "
        read_password
        password1="$password"
        
        printf "Confirm password: "
        read_password
        password2="$password"
        
        if [ "$password1" != "$password2" ]; then
            echo "Passwords do not match!"
            exit 1
        fi
        
        echo "Generating yescrypt hash..."
        hash=$(printf "%s" "$password1" | mkpasswd -m yescrypt -s)
        echo
        echo "Add this to your .env file:"
        echo "USER_PASSWORD_HASH='$hash'"
        exit 0
    fi
fi

# Method 2: Try Python
if command -v python3 >/dev/null 2>&1; then
    python_version=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')
    if [ "$(echo "$python_version >= 3.10" | bc)" -eq 1 ]; then
        echo "Found Python $python_version with yescrypt support!"
        printf "Enter password for user '$USERNAME': "
        read_password
        password1="$password"
        
        printf "Confirm password: "
        read_password
        password2="$password"
        
        if [ "$password1" != "$password2" ]; then
            echo "Passwords do not match!"
            exit 1
        fi
        
        echo "Generating yescrypt hash..."
        hash=$(python3 -c "import crypt; print(crypt.crypt('$password1', crypt.mksalt(crypt.METHOD_YESCRYPT)))")
        echo
        echo "Add this to your .env file:"
        echo "USER_PASSWORD_HASH='$hash'"
        exit 0
    fi
fi

# Fallback
echo "Cannot generate yescrypt hash. Options:"
echo
echo "1. Install mkpasswd:"
echo "   Ubuntu/Debian: sudo apt-get install whois"
echo "   macOS: brew install mkpasswd"
echo
echo "2. Use Python 3.10+:"
echo "   python3 -c \"import crypt; print(crypt.crypt('yourpass', crypt.mksalt(crypt.METHOD_YESCRYPT)))\""
echo
echo "3. Use plaintext password in .env (recommended):"
echo "   USER_PASSWORD=yourpassword"
echo
echo "The container will hash it correctly."