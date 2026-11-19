#!/usr/bin/env bash
# Prints the SSL pin (base64 SHA-256 of the DER-encoded server certificate)
# for a host, in the format expected by --dart-define=SSL_PINS=...
#
# Usage: tools/generate_ssl_pins.sh your-domain.com [port]
#
# IMPORTANT: this pins the *leaf* certificate. When the certificate is renewed
# (e.g. every 90 days with Let's Encrypt) the pin changes. Ship an app update
# containing BOTH the current and the upcoming certificate's pins before the
# renewal, otherwise users will see the "Connection not secure" screen.
set -euo pipefail

HOST="${1:?usage: $0 your-domain.com [port]}"
PORT="${2:-443}"

PIN=$(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null \
  | openssl x509 -outform DER \
  | openssl dgst -sha256 -binary \
  | base64)

echo "Host:      $HOST"
echo "Expires:   $(echo | openssl s_client -servername "$HOST" -connect "$HOST:$PORT" 2>/dev/null | openssl x509 -noout -enddate | cut -d= -f2)"
echo "SSL pin:   $PIN"
echo
echo "Build with:  --dart-define=SSL_PINS=$PIN"
