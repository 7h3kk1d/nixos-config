# Push a copy of a Firefox profile's history (places.sqlite) to the homelab collectors'
# receiver (7h3kk1d/collectors, sources/firefox: `firefox-collector serve`).
#
#   firefox-history-push <profile-dir> <url> <token-file>
#
# A running Firefox keeps places.sqlite locked against other readers ("database is locked",
# 2026-10-30), so the database and its -wal file are copied as files, the copy is opened (taking
# in the WAL changes) and backed up into one file, and that is checked. A copy caught mid-write
# fails the check and is taken again. It goes up gzipped. The token is sent from a header file so
# it never appears in the process list. Plain bash, sqlite3, gzip and curl: also runs on macOS.
set -euo pipefail

profile=$1 url=$2 token_file=$3
db=$profile/places.sqlite
[[ -f $db ]] || { echo >&2 "firefox-history-push: no $db"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

for try in 1 2 3; do
  rm -rf "$tmp/copy" "$tmp/places.sqlite"
  mkdir "$tmp/copy"
  cp "$db" "$tmp/copy/"
  if [[ -f $db-wal ]]; then cp "$db-wal" "$tmp/copy/"; fi
  if sqlite3 "$tmp/copy/places.sqlite" ".backup '$tmp/places.sqlite'" &&
     [[ $(sqlite3 "$tmp/places.sqlite" 'PRAGMA quick_check') == ok ]]; then
    break
  fi
  [[ $try -lt 3 ]] || { echo >&2 "firefox-history-push: no consistent copy after 3 tries"; exit 1; }
  echo >&2 "copy $try was inconsistent; trying again"
  sleep 10
done
gzip -6 "$tmp/places.sqlite"
printf 'Authorization: Bearer %s\n' "$(tr -d '[:space:]' <"$token_file")" >"$tmp/headers"

echo "pushing $(du -h "$tmp/places.sqlite.gz" | cut -f1) from $profile"
curl -fsS --retry 3 --retry-all-errors --max-time 900 \
  -H @"$tmp/headers" -H 'Content-Encoding: gzip' -H 'Content-Type: application/vnd.sqlite3' \
  -H "X-Hostname: $(hostname)" \
  --data-binary @"$tmp/places.sqlite.gz" "$url"
echo
