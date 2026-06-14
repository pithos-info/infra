#!/usr/bin/env bash
set -euo pipefail

PACKAGES=(
    "postgresql@17"
    "redis"
    "minio"
    "liquibase"
    "maven"
)

if ! command -v brew &>/dev/null; then
    echo "Homebrew is required. Install it from https://brew.sh" >&2
    exit 1
fi

for pkg in "${PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        echo "  already installed: $pkg"
    else
        echo "  installing: $pkg"
        brew install "$pkg"
    fi
done

# vault is distributed via the official HashiCorp tap
if brew list hashicorp/tap/vault &>/dev/null; then
    echo "  already installed: vault"
else
    echo "  adding hashicorp tap..."
    brew tap hashicorp/tap
    echo "  installing: vault"
    brew install hashicorp/tap/vault
fi

echo ""
echo "Versions:"
"$(brew --prefix)/opt/postgresql@17/bin/postgres" --version
redis-server --version | head -1
minio --version
vault version
liquibase --version 2>/dev/null | head -1
mvn -version | head -1
