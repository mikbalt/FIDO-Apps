#!/bin/sh
# Copies the synthetic test fixtures (the source of truth) into the app's mock traces.
set -eu
root="$(cd "$(dirname "$0")/.." && pwd)"
src="$root/FIDOKit/Tests/CardCoreTests/Fixtures/synthetic"
dst="$root/App/FIDOSims/Resources/MockTraces"
mkdir -p "$dst"
rm -f "$dst"/synthetic-*.json
cp "$src"/synthetic-*.json "$dst"/
echo "Copied $(ls "$src"/synthetic-*.json | wc -l | tr -d ' ') fixtures to App/FIDOSims/Resources/MockTraces"
