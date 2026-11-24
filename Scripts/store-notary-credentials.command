#!/bin/bash
set -euo pipefail
# Run this yourself in Terminal. Apple prompts for the account, team, and
# app-specific password, then stores them in your local Keychain.
# Do not put password values in this file, environment variables, or chat.
exec /usr/bin/xcrun notarytool store-credentials 'NotchCopy-Notary'
