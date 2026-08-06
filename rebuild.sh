#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"

if [[ "${1:-}" == "--packages" ]]; then
  bash "$DIR/build/system-packages.sh"
fi

home-manager switch --flake "$DIR#archeus"
echo "Rebuild successful!"
