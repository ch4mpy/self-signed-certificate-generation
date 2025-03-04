#!/bin/bash
if [ -z "$SERVER_SSL_KEY_PASSWORD" ] || [ -z "$SERVER_SSL_KEY_STORE_PASSWORD" ]; then
  echo "following environment variables must be set (and identical):"
  echo "  - SERVER_SSL_KEY_PASSWORD"
  echo "  - SERVER_SSL_KEY_STORE_PASSWORD"
  exit 1
fi

# Default values
CERTIF_DIR="."
CACERTS_PWD="changeit"
if [ -z "${HOSTNAME}" ]; then
  HOSTNAME=`hostname`
fi

read -p "JAVA_HOME (default: ${JAVA_HOME}): " -r JAVA
JAVA=${JAVA:-${JAVA_HOME}}
JAVA=$(echo "$JAVA" | sed 's/\\/\//g')
if [ -z "${JAVA}" ]; then
  echo "ERROR: could not locate JDK / JRE root directory"
  exit 1
fi
# Locate cacerts file
if [ -f "${JAVA}/lib/security/cacerts" ]; then
  # recent JDKs and JREs style
  CACERTS=("${JAVA}/lib/security/cacerts")
elif [ -f "${JAVA}/jre/lib/security/cacerts" ]; then
  # legacy JDKs style (1.8 and older)
  CACERTS=("${JAVA}/jre/lib/security/cacerts")
else
  echo "ERROR: could not locate cacerts under $JAVA"
  exit 1
fi

read -p "cacerts pasword (default: ${CACERTS_PWD}): " CACERTS_PASSWORD
CACERTS_PASSWORD=${CACERTS_PASSWORD:-${CACERTS_PWD}}

read -p "certificate to import (default: ${CERTIF_DIR}/${HOSTNAME}_self_signed.jks): " JKS
CERTIFICATE=${JKS:-${CERTIF_DIR}/${HOSTNAME}_self_signed.jks}

if [ ! -f "${CERTIFICATE}" ]; then
  echo "${CERTIFICATE} does not exist, exiting"
  exit 1;
else
  "${JAVA}/bin/keytool" -importkeystore -srckeystore "${CERTIF_DIR}/${HOSTNAME}_self_signed.p12" -srckeypass "${SERVER_SSL_KEY_PASSWORD}" -srcstorepass "${SERVER_SSL_KEY_STORE_PASSWORD}" -srcstoretype pkcs12 -srcalias "${HOSTNAME}" -destkeystore "${CACERTS}" -deststorepass "${CACERTS_PASSWORD}" -destalias "${HOSTNAME}"
fi
