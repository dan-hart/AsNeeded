#!/bin/bash

# Deprecated wrapper for hook installation.
# Use ./scripts/install-hooks.sh instead.

set -e

echo "⚠️  install-git-hooks.sh is deprecated."
echo "   Use: ./scripts/install-hooks.sh"

exec ./scripts/install-hooks.sh
