# local

Local dev infra for pithos-info: postgres, redis, minio, vault, and cassandra,
all managed by the scripts in `scripts/`.

## Layout

```
local/
  apache/     cassandra install + symlink (not checked in)
  configs/    checked-in service config (e.g. rbac-config.yaml)
  data/       postgres/redis/minio data dirs (not checked in)
  logs/       service logs + rotated archive (not checked in)
  pids/       pidfiles for backgrounded services (not checked in)
  metrics/    scratch space for metrics exports (not checked in)
  scripts/    setup and lifecycle scripts (checked in)
```

Only `scripts/`, `configs/`, and `.gitignore` are checked into git.
Everything else is generated locally — see `local/.gitignore`.

## First-time setup

```
cd local/scripts
./setup.sh   # creates dirs, patches cassandra.yaml, brew-installs all deps
```

Cassandra itself isn't installed by this script. Download a release, extract
it into `local/apache/`, and symlink it:

```
cd local/apache
ln -s apache-cassandra-5.0.8 cassandra
```

Then re-run `./setup.sh` — it will patch `cassandra.yaml` with absolute data
paths on the first run that finds the symlink in place.

`infra.sh` sets `JAVA_HOME` to `openjdk@17` before starting Cassandra — update
that line if your Cassandra version needs a different JDK (Cassandra 5.0 wants
Java 11 or 17).

## Day to day

```
cd local/scripts
./infra.sh start     # postgres, redis, minio, vault, cassandra
./infra.sh status
./infra.sh stop
./infra.sh restart
```

To wipe local data and start clean:

```
./cleanup.sh
```

## Notes

- `infra.sh` derives all paths from its own location, so it works whether
  invoked directly or via a symlink/full path.
- Cassandra's `data_file_directories`, `commitlog_directory`, `hints_directory`,
  and `saved_caches_directory` in `apache/cassandra/conf/cassandra.yaml` are
  patched to absolute paths by `setup.sh` — they point to `local/apache/data/cassandra/*`.
