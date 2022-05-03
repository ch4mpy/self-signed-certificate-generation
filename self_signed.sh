#!/bin/bash
if [ -z "$SERVER_SSL_KEY_PASSWORD" ] || [ -z "$SERVER_SSL_KEY_STORE_PASSWORD" ]; then
  echo "following environment variables must be set (and identical):"
  echo "  - SERVER_SSL_KEY_PASSWORD"
  echo "  - SERVER_SSL_KEY_STORE_PASSWORD"
  exit 1


  # Check that SERVER_SSL_KEY_PASSWORD and SERVER_SSL_KEY_STORE_PASSWORD are identical
elif [ $SERVER_SSL_KEY_PASSWORD != $SERVER_SSL_KEY_STORE_PASSWORD ]; then
  echo "Due to PCKS12 limitation key and keystore passwords must be the same"
  exit 1
fi

# Default values
CERTIF_DIR="."
CN=$HOSTNAME
if [ -z "${CN}" ]; then
  CN=`hostanme`
fi
CACERTS_PWD="changeit"
OUT_DIR="."
COUNTRY="PF"
STATE="Tahiti"
CITY="Papeete"
ORGANISATION="c4-soft"
EMAIL=`whoami`"@${ORGANISATION}.com"

# User inputs
if [ -z "${CN}" ]; then
  read -p "Failed to auto-detect hostname. Please provide one: " CN
fi
if [ -z "${CN}" ]; then
  echo "ERROR: hostname is required"
  exit 1;
fi
read -p "JAVA_HOME (default: ${JAVA_HOME}): " -r JAVA
read -p "cacerts pasword (default: ${CACERTS_PWD}): " CACERTS_PASSWORD
read -p "Country (2 chars ISO code , default: ${COUNTRY}): " C
read -p "State (default: ${STATE}): " ST
read -p "City (default: ${CITY}): " L
read -p "Organisation (default: ${ORGANISATION}): " O
read -p "e-mail (default: ${EMAIL}): " EMAIL_ADDRESS

# Figure out which JDK to work with
if [ -z "${JAVA}" ]
then
  JAVA=`echo $JAVA_HOME`
fi
if [ -z "${JAVA}" ]; then
  echo "ERROR: could not locate JDK / JRE root directory"
  exit 1
fi
JAVA=$(echo $JAVA | sed 's/\\/\//g')

echo $JAVA
# Locate cacerts file
if [ -f "${JAVA}/lib/security/cacerts" ]; then
  # recent JDKs and JREs style
  CACERTS="${JAVA}/lib/security/cacerts"
elif [ -f "${JAVA}/jre/lib/security/cacerts" ]; then
  # legacy JDKs style (1.8 and older)
  CACERTS="${JAVA}/jre/lib/security/cacerts"
else
  echo "ERROR: could not locate cacerts under $JAVA"
  exit 1
fi

# cacerts file password
if [ -z "${CACERTS_PASSWORD}" ]; then
  CACERTS_PASSWORD=$CACERTS_PWD
fi

# Certificate parameters
if [ -z "${C}" ]; then
  C=$COUNTRY
fi

if [ -z "${ST}" ]; then
  ST=$STATE
fi

if [ -z "${L}" ]; then
  L=$CITY
fi

if [ -z "${O}" ]; then
  O=$ORGANISATION
fi

if [ -z "${EMAIL_ADDRESS}" ]; then
  EMAIL_ADDRESS=$EMAIL
fi

# Update templated config
rm -f ${CN}_self_signed.config;
echo -e "[req]\n\
default_bits       = 2048\n\
default_md         = sha256\n\
prompt             = no\n\
default_keyfile    = [hostname]_self_signed_key.pem\n\
encrypt_key        = no\n\
\n\
distinguished_name = dn\n\
\n\
req_extensions     = v3_req\n\
x509_extensions    = v3_req\n\
\n\
[dn]\n\
C            = [country]\n\
ST           = [state]\n\
L            = [city]\n\
O            = [organisation]\n\
emailAddress = [email]\n\
CN           = [hostname]\n\
\n\
[v3_req]\n\
subjectAltName   = critical, @alt_names\n\
basicConstraints = critical, CA:TRUE\n\
keyUsage         = critical, digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment, keyAgreement, keyCertSign, cRLSign\n\
extendedKeyUsage = critical, serverAuth, clientAuth\n\
\n\
[alt_names]\n\
DNS.1 = [hostname]\n\
DNS.2 = localhost\n\
DNS.3 = 127.0.0.1\n\
DNS.4 = 10.0.2.2" > "./${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[hostname\]/'${CN}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[country\]/'${C}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[state\]/'${ST}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[city\]/'${L}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[organisation\]/'${O}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"
sed -i 's/\[email\]/'${EMAIL_ADDRESS}'/g' "${CERTIF_DIR}/${CN}_self_signed.config"

echo ""
echo openssl req -config \"${CERTIF_DIR}/${CN}_self_signed.config\" -new -keyout \"${CERTIF_DIR}/${CN}_req_key.pem\" -passout pass:${SERVER_SSL_KEY_PASSWORD} -out \"${CERTIF_DIR}/${CN}_cert_req.pem\" -reqexts v3_req
if [ -f "${CERTIF_DIR}/${CN}_cert_req.pem" ]; then
  echo "${CERTIF_DIR}/${CN}_cert_req.pem already exists, doing nothing"
else
  openssl req -config "${CERTIF_DIR}/${CN}_self_signed.config" -new -keyout "${CERTIF_DIR}/${CN}_req_key.pem" -passout pass:${SERVER_SSL_KEY_PASSWORD} -out "${CERTIF_DIR}/${CN}_cert_req.pem" -reqexts v3_req
fi

echo openssl x509 -req -days 365 -extfile \"${CERTIF_DIR}/${CN}_self_signed.config\" -in \"${CERTIF_DIR}/${CN}_cert_req.pem\" -extensions v3_req -signkey \"${CERTIF_DIR}/${CN}_req_key.pem\" -passin pass:${SERVER_SSL_KEY_PASSWORD} -out \"${CERTIF_DIR}/${CN}_self_signed.crt\"
if [ -f "${CERTIF_DIR}/${CN}_self_signed.crt" ]; then
  echo "${CERTIF_DIR}/${CN}_self_signed.crt already exists, doing nothing"
  echo ""
else
  openssl x509 -req -days 365 -extfile "${CERTIF_DIR}/${CN}_self_signed.config" -in "${CERTIF_DIR}/${CN}_cert_req.pem" -extensions v3_req -signkey "${CERTIF_DIR}/${CN}_req_key.pem" -passin pass:${SERVER_SSL_KEY_PASSWORD} -out "${CERTIF_DIR}/${CN}_self_signed.crt"
fi

echo openssl x509 -in \"${CERTIF_DIR}/${CN}_self_signed.crt\" -out \"${CERTIF_DIR}/${CN}_self_signed.pem\" -outform PEM
if [ -f "" ]; then
  echo "${CERTIF_DIR}/${CN}_self_signed.pem already exists, doing nothing"
  echo ""
else
  openssl x509 -in "${CERTIF_DIR}/${CN}_self_signed.crt" -out "${CERTIF_DIR}/${CN}_self_signed.pem" -outform PEM
fi
 
echo openssl pkcs12 -export -in \"${CERTIF_DIR}/${CN}_self_signed.crt\" -inkey \"${CERTIF_DIR}/${CN}_req_key.pem\" -passin pass:${SERVER_SSL_KEY_PASSWORD} -name ${CN} -out \"${CERTIF_DIR}/${CN}_self_signed.p12\" -passout pass:${SERVER_SSL_KEY_STORE_PASSWORD}
if [ -f "${CERTIF_DIR}/${CN}_self_signed.p12" ]; then
  echo " already exists, doing nothing"
  echo ""
else
  openssl pkcs12 -export -in "${CERTIF_DIR}/${CN}_self_signed.crt" -inkey "${CERTIF_DIR}/${CN}_req_key.pem" -passin pass:${SERVER_SSL_KEY_PASSWORD} -name ${CN} -out "${CERTIF_DIR}/${CN}_self_signed.p12" -passout pass:${SERVER_SSL_KEY_STORE_PASSWORD}
fi

echo \"${JAVA}/bin/keytool\" -importkeystore -srckeystore \"${CERTIF_DIR}/${CN}_self_signed.p12\" -srckeypass \"${SERVER_SSL_KEY_PASSWORD}\" -srcstorepass \"${SERVER_SSL_KEY_STORE_PASSWORD}\" -srcstoretype pkcs12 -srcalias ${CN} -destkeystore \"${CERTIF_DIR}/${CN}_self_signed.jks\" -deststoretype PKCS12 -destkeypass ${SERVER_SSL_KEY_PASSWORD} -deststorepass ${SERVER_SSL_KEY_STORE_PASSWORD} -destalias ${CN}
if [ -f "${CERTIF_DIR}/${CN}_self_signed.jks" ]; then
  echo "${CERTIF_DIR}/${CN}_self_signed.jks already exists, doing nothing"
  echo ""
else
  "${JAVA}/bin/keytool" -importkeystore -srckeystore "${CERTIF_DIR}/${CN}_self_signed.p12" -srckeypass "${SERVER_SSL_KEY_PASSWORD}" -srcstorepass "${SERVER_SSL_KEY_STORE_PASSWORD}" -srcstoretype pkcs12 -srcalias ${CN} -destkeystore "${CERTIF_DIR}/${CN}_self_signed.jks" -deststoretype PKCS12 -destkeypass ${SERVER_SSL_KEY_PASSWORD} -deststorepass ${SERVER_SSL_KEY_STORE_PASSWORD} -destalias ${CN}
fi

echo "# Might have to sudo this one"
"${JAVA}/bin/keytool" -importkeystore -srckeystore "${CERTIF_DIR}/${CN}_self_signed.p12" -srckeypass "${SERVER_SSL_KEY_PASSWORD}" -srcstorepass "${SERVER_SSL_KEY_STORE_PASSWORD}" -srcstoretype pkcs12 -srcalias ${CN} -destkeystore "${CACERTS}" -deststorepass ${CACERTS_PASSWORD} -destalias ${CN}
