#!/usr/bin/env bash
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
home-manager switch --flake "$DIR#archeus"
echo "Rebuild successful!"
