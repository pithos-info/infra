#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOCAL_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

DATA_DIR="$LOCAL_DIR/data"
CASSANDRA_DATA_DIR="$LOCAL_DIR/apache/data/cassandra"

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

if [[ ! -e "$LOCAL_DIR/apache/cassandra" ]]; then
    echo ""
    echo "Note: no Cassandra install found at $LOCAL_DIR/apache/cassandra"
    echo "Download and extract a Cassandra release into $LOCAL_DIR/apache/, then symlink it, e.g.:"
    echo "  ln -s apache-cassandra-5.0.8 $LOCAL_DIR/apache/cassandra"
fi

echo ""
echo "Done. Next steps:"
echo "  1. ./prereqs.sh   (installs postgres, redis, minio, vault, cassandra deps via Homebrew)"
echo "  2. ./infra.sh start"
