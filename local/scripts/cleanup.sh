#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INFRA_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

BREW_PREFIX="$(brew --prefix)"
PG_BIN="$BREW_PREFIX/opt/postgresql@17/bin"

PG_DATA_DIR="$INFRA_DIR/local/data/postgres"
MINIO_DATA_DIR="$INFRA_DIR/local/data/minio"
REDIS_PORT=6379

confirm() {
    read -r -p "This will destroy all local infra data. Are you sure? [y/N] " reply
    [[ "$reply" =~ ^[Yy]$ ]] || { echo "Aborted."; exit 0; }
}

wipe_postgres() {
    if [[ -d "$PG_DATA_DIR" ]]; then
        "$PG_BIN/pg_ctl" stop -D "$PG_DATA_DIR" -m fast 2>/dev/null || true
        rm -rf "${PG_DATA_DIR:?}"
        echo "  postgres: data directory wiped"
    else
        echo "  postgres: data directory does not exist — nothing to wipe"
    fi
}

flush_redis() {
    if redis-cli -p "$REDIS_PORT" ping &>/dev/null; then
        redis-cli -p "$REDIS_PORT" FLUSHALL > /dev/null
        echo "  redis: flushed"
    else
        echo "  redis: not running — skipping flush"
    fi
}

wipe_minio() {
    if [[ -d "$MINIO_DATA_DIR" ]]; then
        rm -rf "${MINIO_DATA_DIR:?}"/*
        echo "  minio: data wiped"
    else
        echo "  minio: data directory does not exist — nothing to wipe"
    fi
}

confirm
echo "Cleaning up local infra data..."
wipe_postgres
flush_redis
wipe_minio
echo "Done. Run infra.sh start to bring services back up."
