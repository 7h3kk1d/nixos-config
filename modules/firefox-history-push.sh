# Push a copy of a Firefox profile's history (places.sqlite) to the homelab collectors'
# receiver (7h3kk1d/collectors, sources/firefox: `firefox-collector serve`).
#
#   firefox-history-push <profile-dir> <url> <token-file>
#
# The copy is SQLite's online backup, so it is consistent (WAL changes included) without closing
# Firefox; if Firefox holds the database locked, it fails and the next run tries again. It goes
# up gzipped. The token is sent from a header file so it never appears in the process list.
# Plain bash, sqlite3, gzip and curl: also runs on macOS.
set -euo pipefail

profile=$1 url=$2 token_file=$3
db=$profile/places.sqlite
[[ -f $db ]] || { echo >&2 "firefox-history-push: no $db"; exit 1; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
chmod 700 "$tmp"

sqlite3 "file:$db?mode=ro" ".timeout 30000" ".backup '$tmp/places.sqlite'"
gzip -6 "$tmp/places.sqlite"
printf 'Authorization: Bearer %s\n' "$(tr -d '[:space:]' <"$token_file")" >"$tmp/headers"

echo "pushing $(du -h "$tmp/places.sqlite.gz" | cut -f1) from $profile"
curl -fsS --retry 3 --retry-all-errors --max-time 900 \
  -H @"$tmp/headers" -H 'Content-Encoding: gzip' -H 'Content-Type: application/vnd.sqlite3' \
  -H "X-Hostname: $(hostname)" \
  --data-binary @"$tmp/places.sqlite.gz" "$url"
echo
