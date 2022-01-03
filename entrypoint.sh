#!/bin/sh -e

set -o errexit
set -o nounset
set -o pipefail

conf_dir="${HOME}/.config/qBittorrent"
# Default configuration file
if [ ! -f "${conf_dir}/qBittorrent.conf" ]; then
  # Check if QBITTORRENT_CONFIG_SOURCE is set (bootstrap Config Map?), use it from there. If not, use clean config from /default,
  # set in docker file
  echo "Getting seed config in"
  seed_dir="${QBITTORRENT_CONFIG_SOURCE:-/default}"
  mkdir -p "${conf_dir}"
  mkdir -p "${HOME}/.local/share/qBittorrent"
  # by some reason direct copy is adding "seed" subdir to destination
	(cd "${seed_dir}" && cp -Rv . "${conf_dir}")
	chown -R qbittorrent: "${conf_dir}"
	chmod go+rw -R "${HOME}/.local" "${HOME}/.config"
fi

# if QBITTORRENT_USER_PROBE_DIR is set:
#   1. find out user ID
#   2. Create user
#   3. chown home folder
#   4. run as this user
if [ ! -z "${QBITTORRENT_USER_PROBE_DIR}" ]; then
  echo "Changing executing user "
  uid=$(stat -c %u "${QBITTORRENT_USER_PROBE_DIR}")
  run_as_user="qrunner"
  adduser -S -D -u ${uid} -g ${uid} -s /sbin/nologin -h "${HOME}" -H "${run_as_user}"
  chown -R "${run_as_user}": "${HOME}"
else
  run_as_user="qbittorrent"
fi

# Allow groups to change files.
umask u=rwx,g=rwx,o=rx

ln -sf /dev/stdout "${HOME}/.local/share/qBittorrent/logs/qbittorrent.log"

exec su-exec "${run_as_user}" "$@"
