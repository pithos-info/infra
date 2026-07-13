#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DATA_DIR="$LOCAL_DIR/data"
CASSANDRA_DATA_DIR="$LOCAL_DIR/apache/data/cassandra"

# ── Directory structure ───────────────────────────────────────────────────────

DIRS=(
    "$DATA_DIR/postgres"
    "$DATA_DIR/minio"
    "$DATA_DIR/redis"
    "$LOCAL_DIR/logs/archive"
    "$LOCAL_DIR/pids"
    "$LOCAL_DIR/metrics"
    "$CASSANDRA_DATA_DIR/data"
    "$CASSANDRA_DATA_DIR/commitlog"
    "$CASSANDRA_DATA_DIR/hints"
    "$CASSANDRA_DATA_DIR/saved_caches"
)

echo "Creating local infra directory structure under $LOCAL_DIR..."
for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
    echo "  $dir"
done

# ── Cassandra yaml ────────────────────────────────────────────────────────────

CASSANDRA_YAML="$LOCAL_DIR/apache/cassandra/conf/cassandra.yaml"
if [[ -f "$CASSANDRA_YAML" ]]; then
    echo "Patching cassandra.yaml with absolute data paths..."
    sed -i '' \
        -e "s|^hints_directory:.*|hints_directory: $CASSANDRA_DATA_DIR/hints|" \
        -e "s|^commitlog_directory:.*|commitlog_directory: $CASSANDRA_DATA_DIR/commitlog|" \
        -e "s|^saved_caches_directory:.*|saved_caches_directory: $CASSANDRA_DATA_DIR/saved_caches|" \
        "$CASSANDRA_YAML"
    sed -i '' \
        -e '/^data_file_directories:/{n;s|.*|    - '"$CASSANDRA_DATA_DIR/data"'|;}' \
        "$CASSANDRA_YAML"
    echo "  $CASSANDRA_YAML patched"
elif [[ ! -e "$LOCAL_DIR/apache/cassandra" ]]; then
    echo ""
    echo "Note: no Cassandra install found at $LOCAL_DIR/apache/cassandra"
    echo "Download and extract a Cassandra release into $LOCAL_DIR/apache/, then symlink it, e.g.:"
    echo "  ln -s apache-cassandra-5.0.8 $LOCAL_DIR/apache/cassandra"
    echo "Then re-run this script to patch cassandra.yaml."
fi

# ── Homebrew packages ─────────────────────────────────────────────────────────

PACKAGES=(
    "postgresql@17"
    "redis"
    "minio"
    "liquibase"
    "maven"
    "python@3.11"
)

if ! command -v brew &>/dev/null; then
    echo "Homebrew is required. Install it from https://brew.sh" >&2
    exit 1
fi

echo ""
echo "Installing Homebrew packages..."
for pkg in "${PACKAGES[@]}"; do
    if brew list "$pkg" &>/dev/null; then
        echo "  already installed: $pkg"
    else
        echo "  installing: $pkg"
        brew install "$pkg"
    fi
done

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

echo ""
echo "Done. Run ./infra.sh start to start local services."
