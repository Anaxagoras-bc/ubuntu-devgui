#!/bin/bash

echo "Password Hash Generator for Docker Dev Environment"
echo "================================================="
echo

# Get username from .env or use default
if [ -f .env ]; then
    USERNAME=$(grep "^USERNAME=" .env | cut -d'=' -f2 || echo "default-user")
else
    USERNAME="default-user"
fi

# Check if we're using bash
if [ -z "$BASH_VERSION" ]; then
    echo "Warning: This script works best with bash. Run with: bash ./generate-password-hash.sh"
    echo
fi

# Function to read password portably
read_password() {
    if [ -t 0 ]; then
        # Try to turn off echo
        stty -echo 2>/dev/null
        read password
        stty echo 2>/dev/null
        echo
    else
        read password
    fi
}

# Prompt for password
printf "Enter password for user '$USERNAME': "
read_password
password1="$password"

printf "Confirm password: "
read_password
password2="$password"

echo

# Check if passwords match
if [ "$password1" != "$password2" ]; then
    echo "Passwords do not match!"
    exit 1
fi

# Generate SHA-512 hash (most secure option supported by Linux)
echo "Generating SHA-512 password hash..."
hash=$(printf "%s" "$password1" | openssl passwd -6 -stdin)

echo
echo "Add this to your .env file:"
echo "USER_PASSWORD_HASH='$hash'"
echo
echo "Security note: This hash is safe to commit to version control,"
echo "but .env files should still be in .gitignore as a best practice."