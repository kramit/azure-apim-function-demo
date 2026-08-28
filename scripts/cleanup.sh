#!/usr/bin/env bash
set -euo pipefail
: "${RESOURCE_GROUP:?Set RESOURCE_GROUP to the demo resource group}"
az group delete --name "$RESOURCE_GROUP" --yes --no-wait
echo "Deletion started for $RESOURCE_GROUP."
