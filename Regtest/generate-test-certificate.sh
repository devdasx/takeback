#!/bin/sh
# Local fixture only. Never commit the generated private key.
set -eu
cd "$(dirname "$0")"
mkdir -p tls
if ! openssl x509 -in tls/cert.pem -noout -checkend 604800 >/dev/null 2>&1 || [ ! -s tls/key.pem ]; then
  openssl req -x509 -newkey ec -pkeyopt ec_paramgen_curve:prime256v1     -days 365 -nodes -subj "/CN=localhost"     -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"     -keyout tls/key.pem -out tls/cert.pem
  # The disposable key must be readable by the unprivileged Fulcrum container.
  chmod 644 tls/key.pem tls/cert.pem
fi
