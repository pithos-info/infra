#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
LOCAL_DIR="$ROOT_DIR/local"
LOGS_DIR="$LOCAL_DIR/logs"
ARCHIVE_DIR="$LOGS_DIR/archive"
PIDS_DIR="$LOCAL_DIR/pids"
DATA_DIR="$LOCAL_DIR/data"
PG_DATA_DIR="$DATA_DIR/postgres"
MINIO_DATA_DIR="$DATA_DIR/minio"
REDIS_DATA_DIR="$DATA_DIR/redis"
APACHE_DIR="$LOCAL_DIR/apache"
CASSANDRA_HOME="$APACHE_DIR/cassandra"

BREW_PREFIX="$(brew --prefix)"
PG_BIN="$BREW_PREFIX/opt/postgresql@17/bin"

PG_PORT=5432
REDIS_PORT=6379
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
VAULT_PORT=8200
VAULT_DEV_TOKEN="dev-root-token"
CASSANDRA_PORT=9042

echo "root + $ROOT_DIR"
echo $LOCAL_DIR
echo "scripts + $SCRIPT_DIR"

# ---- helpers ----------------------------------------------------------------

rotate_log() {
    local name="$1"
    local log="$LOGS_DIR/${name}.log"
    if [[ -f "$log" ]]; then
        mkdir -p "$ARCHIVE_DIR"
        mv "$log" "$ARCHIVE_DIR/${name}-$(date +%Y%m%dT%H%M%S).log"
    fi
}

write_pid() { echo "$1" > "$PIDS_DIR/$2.pid"; }

read_pid() {
    local file="$PIDS_DIR/$1.pid"
    [[ -f "$file" ]] && cat "$file" || echo ""
}

is_running() {
    local pid
    pid="$(read_pid "$1")"
    [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

# ---- postgres ---------------------------------------------------------------

start_postgres() {
    if "$PG_BIN/pg_ctl" status -D "$PG_DATA_DIR" &>/dev/null; then
        echo "  postgres: already running"
        return
    fi
    if [[ ! -f "$PG_DATA_DIR/PG_VERSION" ]]; then
        echo "  postgres: initialising data dir..."
        mkdir -p "$PG_DATA_DIR"
        "$PG_BIN/initdb" -D "$PG_DATA_DIR" --no-locale --encoding=UTF8
    fi
    rotate_log postgres
    "$PG_BIN/pg_ctl" start -D "$PG_DATA_DIR" -l "$LOGS_DIR/postgres.log" \
        -o "-p $PG_PORT"
    echo "  postgres: started (port $PG_PORT)"
}

stop_postgres() {
    if ! "$PG_BIN/pg_ctl" status -D "$PG_DATA_DIR" &>/dev/null; then
        echo "  postgres: not running"
        return
    fi
    "$PG_BIN/pg_ctl" stop -D "$PG_DATA_DIR" -m fast
    echo "  postgres: stopped"
}

status_postgres() {
    if "$PG_BIN/pg_ctl" status -D "$PG_DATA_DIR" &>/dev/null; then
        echo "  postgres: running (port $PG_PORT)"
    else
        echo "  postgres: stopped"
    fi
}

# ---- redis ------------------------------------------------------------------

start_redis() {
    if is_running redis; then
        echo "  redis: already running"
        return
    fi
    rotate_log redis
    mkdir -p "$REDIS_DATA_DIR"
    redis-server \
        --daemonize yes \
        --port "$REDIS_PORT" \
        --dir "$REDIS_DATA_DIR" \
        --logfile "$LOGS_DIR/redis.log" \
        --pidfile "$PIDS_DIR/redis.pid"
    echo "  redis: started (port $REDIS_PORT)"
}

stop_redis() {
    if ! is_running redis; then
        echo "  redis: not running"
        return
    fi
    redis-cli -p "$REDIS_PORT" shutdown nosave 2>/dev/null || true
    rm -f "$PIDS_DIR/redis.pid"
    echo "  redis: stopped"
}

status_redis() {
    if is_running redis; then
        echo "  redis: running (port $REDIS_PORT)"
    else
        echo "  redis: stopped"
    fi
}

# ---- minio ------------------------------------------------------------------

start_minio() {
    if is_running minio; then
        echo "  minio: already running"
        return
    fi
    rotate_log minio
    mkdir -p "$MINIO_DATA_DIR"
    MINIO_ROOT_USER=minioadmin \
    MINIO_ROOT_PASSWORD=minioadmin \
    minio server "$MINIO_DATA_DIR" \
        --address ":$MINIO_PORT" \
        --console-address ":$MINIO_CONSOLE_PORT" \
        > "$LOGS_DIR/minio.log" 2>&1 &
    write_pid $! minio
    echo "  minio: started (port $MINIO_PORT, console $MINIO_CONSOLE_PORT)"
}

stop_minio() {
    local pid
    pid="$(read_pid minio)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        echo "  minio: not running"
        rm -f "$PIDS_DIR/minio.pid"
        return
    fi
    kill "$pid"
    rm -f "$PIDS_DIR/minio.pid"
    echo "  minio: stopped"
}

status_minio() {
    if is_running minio; then
        echo "  minio: running (port $MINIO_PORT)"
    else
        echo "  minio: stopped"
    fi
}

# ---- vault ------------------------------------------------------------------

start_vault() {
    if is_running vault; then
        echo "  vault: already running"
        return
    fi
    rotate_log vault
    VAULT_DEV_LISTEN_ADDRESS="127.0.0.1:$VAULT_PORT" \
    vault server \
        -dev \
        -dev-root-token-id="$VAULT_DEV_TOKEN" \
        > "$LOGS_DIR/vault.log" 2>&1 &
    write_pid $! vault
    echo "  vault: started (port $VAULT_PORT, token $VAULT_DEV_TOKEN)"
}

stop_vault() {
    local pid
    pid="$(read_pid vault)"
    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        echo "  vault: not running"
        rm -f "$PIDS_DIR/vault.pid"
        return
    fi
    kill "$pid"
    rm -f "$PIDS_DIR/vault.pid"
    echo "  vault: stopped"
}

status_vault() {
    if is_running vault; then
        echo "  vault: running (port $VAULT_PORT)"
    else
        echo "  vault: stopped"
    fi
}

# ---- cassandra ----------------------------------------------------------------

start_cassandra() {
    if is_running cassandra; then
        echo "  cassandra: already running"
        return
    fi
    rotate_log cassandra
    (
        cd "$APACHE_DIR"
        source "$APACHE_DIR/setup.sh"
        "$CASSANDRA_HOME/bin/cassandra" -p "$PIDS_DIR/cassandra.pid"
    ) > "$LOGS_DIR/cassandra.log" 2>&1
    echo "  cassandra: started (port $CASSANDRA_PORT)"
}

stop_cassandra() {
    if ! is_running cassandra; then
        echo "  cassandra: not running"
        rm -f "$PIDS_DIR/cassandra.pid"
        return
    fi
    kill "$(read_pid cassandra)"
    rm -f "$PIDS_DIR/cassandra.pid"
    echo "  cassandra: stopped"
}

status_cassandra() {
    if is_running cassandra; then
        echo "  cassandra: running (port $CASSANDRA_PORT)"
    else
        echo "  cassandra: stopped"
    fi
}

# ---- main -------------------------------------------------------------------

case "${1:-}" in
    start)
        echo "Starting infra..."
        start_postgres
        start_redis
        start_minio
        start_vault
        start_cassandra
        ;;
    stop)
        echo "Stopping infra..."
        stop_cassandra
        stop_vault
        stop_minio
        stop_redis
        stop_postgres
        ;;
    restart)
        "$0" stop
        "$0" start
        ;;
    status)
        echo "Infra status:"
        status_postgres
        status_redis
        status_minio
        status_vault
        status_cassandra
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}" >&2
        exit 1
        ;;
esac
