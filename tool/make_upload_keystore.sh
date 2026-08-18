#!/usr/bin/env bash
# Generates the production upload keystore for com.eminentsite.czechify.
#
# Run this yourself. It is deliberately not something an assistant or a CI job
# does for you: whatever key signs the first upload is the only key Google Play
# will ever accept for this package name, and its password should exist in your
# head and your password manager — not in a chat transcript, a shell history, or
# a log.
#
#   bash tool/make_upload_keystore.sh
#
# Passwords are read with `read -s` and handed to keytool through the
# environment, so they never appear in `ps`, in your shell history, or on screen.

set -euo pipefail

KEYSTORE_DIR="${HOME}/secure"
KEYSTORE_PATH="${KEYSTORE_DIR}/czechify-upload.jks"
ALIAS="upload"
PROPS="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/android/key.properties"

if [[ -e "${KEYSTORE_PATH}" ]]; then
  echo "Refusing to overwrite ${KEYSTORE_PATH}."
  echo "If you truly mean to replace it, move the old one aside first — and be"
  echo "certain it has never signed a Play upload."
  exit 1
fi

echo "Creating the Czechify upload keystore."
echo "Use a long random password from your password manager, and save it there"
echo "BEFORE you continue. Losing it means losing the ability to update the app."
echo

read -r -s -p "Keystore password: " KS_PASS; echo
read -r -s -p "Confirm password:  " KS_PASS_CONFIRM; echo
if [[ "${KS_PASS}" != "${KS_PASS_CONFIRM}" ]]; then
  echo "Passwords did not match." >&2
  exit 1
fi
if (( ${#KS_PASS} < 12 )); then
  echo "Use at least 12 characters — this key has to last a decade." >&2
  exit 1
fi

mkdir -p "${KEYSTORE_DIR}"
chmod 700 "${KEYSTORE_DIR}"

# One password for store and key: Play's upload key has no threat model in
# which two differing secrets help, and a mismatch is a common way to lock
# yourself out of your own release pipeline.
export CZECHIFY_KS_PASS="${KS_PASS}"
keytool -genkeypair -v \
  -keystore "${KEYSTORE_PATH}" \
  -storepass:env CZECHIFY_KS_PASS \
  -keypass:env CZECHIFY_KS_PASS \
  -alias "${ALIAS}" \
  -keyalg RSA -keysize 4096 -validity 10000 \
  -dname "CN=Czechify, O=Czechify, L=Prague, C=CZ"
unset CZECHIFY_KS_PASS

chmod 600 "${KEYSTORE_PATH}"

umask 077
cat > "${PROPS}" <<EOF
storeFile=${KEYSTORE_PATH}
storePassword=${KS_PASS}
keyAlias=${ALIAS}
keyPassword=${KS_PASS}
EOF
chmod 600 "${PROPS}"

echo
echo "Keystore : ${KEYSTORE_PATH}"
echo "Config   : ${PROPS}  (gitignored — keep it that way)"
echo
echo "Certificate fingerprint, for your records:"
CZECHIFY_KS_PASS="${KS_PASS}" keytool -list -v \
  -keystore "${KEYSTORE_PATH}" \
  -storepass:env CZECHIFY_KS_PASS \
  -alias "${ALIAS}" 2>/dev/null | grep -E "SHA1:|SHA256:" || true

cat <<'EOF'

Before you upload anything:

  1. Back the .jks up somewhere that survives this laptop dying. Encrypted
     cloud storage or a password manager attachment — not only Time Machine.
  2. Store the password in your password manager, if you have not already.
  3. Enrol in Play App Signing on first upload. It lets Google recover things
     if the upload key is ever lost; without it, a lost key ends the app.
  4. For CI, set these repository secrets:
       ANDROID_KEYSTORE_BASE64    base64 -i <the .jks>
       ANDROID_KEYSTORE_PASSWORD  the password you just chose
       ANDROID_KEY_ALIAS          upload
       ANDROID_KEY_PASSWORD       the same password

Then build:

  flutter build appbundle --release --dart-define-from-file=env/prod.json \
    --obfuscate --split-debug-info=build/symbols
EOF
