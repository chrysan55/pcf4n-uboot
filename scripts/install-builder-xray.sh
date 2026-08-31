#!/usr/bin/env bash
set -euo pipefail

archive=${1:?usage: install-builder-xray.sh XRAY_ZIP XRAY_DGST CONFIG_JSON [SERVICE_FILE]}
digest_file=${2:?missing digest file}
config_file=${3:?missing config file}
service_file=${4:-ops/xray/xray.service}

for file in "$archive" "$digest_file" "$config_file" "$service_file"; do
  [[ -f "$file" ]] || { printf 'missing file: %s\n' "$file" >&2; exit 1; }
done

expected=$(awk -F '= ' '/256=/ {print $2; exit}' "$digest_file")
actual=$(sha256sum "$archive" | awk '{print $1}')
[[ -n "$expected" && "$expected" == "$actual" ]] || {
  printf 'Xray archive checksum mismatch\n' >&2
  exit 1
}

tmp_dir=$(mktemp -d /tmp/bootstrap-xray-install.XXXXXX)
trap 'rm -rf -- "$tmp_dir"' EXIT
unzip -q "$archive" -d "$tmp_dir"

install -d -m 0755 /usr/local/bin /usr/local/etc/xray /usr/local/share/xray
install -m 0755 "$tmp_dir/xray" /usr/local/bin/xray
install -m 0644 "$tmp_dir/geoip.dat" /usr/local/share/xray/geoip.dat
install -m 0644 "$tmp_dir/geosite.dat" /usr/local/share/xray/geosite.dat
install -o root -g nogroup -m 0640 "$config_file" /usr/local/etc/xray/config.json
install -o root -g root -m 0644 "$service_file" /etc/systemd/system/xray.service

/usr/local/bin/xray run -test -config /usr/local/etc/xray/config.json
systemctl daemon-reload
systemctl enable --now xray.service
systemctl restart xray.service
systemctl is-active --quiet xray.service

git config --system http.proxy http://127.0.0.1:10809
git config --system http.proxyAuthMethod anyauth

printf 'Xray installed: '
/usr/local/bin/xray version | sed -n '1p'
printf 'Git proxy: %s\n' "$(git config --system --get http.proxy)"
