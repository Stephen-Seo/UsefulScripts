#!/bin/bash

# Note that this script only sets up client connections to a server.
# This means that the confs will be generated without
# client-to-client connections.

set -e

function print_help {
    echo "Generates config for wireguard"
    echo "-h - prints this help"
    echo "-n <name> - gives a name to the config"
    echo "-c <count> - number of clients to generate for"
    echo "-s <ipv4_second> - sets the second byte of the ipv4"
    echo "-i <ipv4_third> - sets the third byte of the ipv4"
    echo "-e <endpoint> - ip address or domain name (required)"
    echo "-p <port> - listen port of server (defaults to 50000)"
    echo "-k - enables persistent keepalive for clients"
    echo "-o <directory> - output dir to place configs (required)"
}

WGNAME="wg$(date | sha1sum | head -c 8)"
CLIENT_COUNT=1
IPV4_FIRST=10
IPV4_SECOND=8 # this can be modified with "-s <integer>"
IPV4_THIRD=0 # this can be modified with "-i <integer>"
# IPV4_FOURTH is generated automatically. Server starts with 1, and clients increment afterward.
SERVER_ENDPOINT="REQUIRED"
SERVER_LISTEN_PORT=50000
ENABLE_PERSISTENT_KEEPALIVE=0
CONFIG_OUTPUT_DIRECTORY="REQUIRED"

# OPTARG
while getopts 'hn:c:s:i:e:p:ko:' opt; do
    if [ "$opt" == "?" ]; then
        print_help
        exit 1
    elif [ "$opt" == "h" ]; then
        print_help
        exit 0
    elif [ "$opt" == "n" ]; then
        WGNAME="$OPTARG"
    elif [ "$opt" == "c" ]; then
        CLIENT_COUNT="$OPTARG"
    elif [ "$opt" == "s" ]; then
        IPV4_SECOND="$OPTARG"
        if (($IPV4_SECOND < 0 || $IPV4_SECOND > 255)); then
            echo "ERROR: IPV4_SECOND is out of range of a byte"
            exit 7
        fi
    elif [ "$opt" == "i" ]; then
        IPV4_THIRD="$OPTARG"
        if (($IPV4_THIRD < 0 || $IPV4_THIRD > 255)); then
            echo "ERROR: IPV4_THIRD is out of range of a byte"
            exit 8
        fi
    elif [ "$opt" == "e" ]; then
        SERVER_ENDPOINT="$OPTARG"
    elif [ "$opt" == "p" ]; then
        SERVER_LISTEN_PORT="$OPTARG"
        if [[ ! "${SERVER_LISTEN_PORT}" =~ [0-9]+ ]]; then
            echo "ERROR: Given port is not a number"
            exit 5
        elif (($SERVER_LISTEN_PORT > 65536)); then
            echo "ERROR: Given port is too large"
            exit 6
        fi
    elif [ "$opt" == "k" ]; then
        ENABLE_PERSISTENT_KEEPALIVE=1
    elif [ "$opt" == "o" ]; then
        CONFIG_OUTPUT_DIRECTORY="$OPTARG"
    fi
done

if [ "$SERVER_ENDPOINT" == "REQUIRED" ]; then
    echo "ERROR: Endpoint is not set with \"-e\" !"
    exit 2
elif [ "$CONFIG_OUTPUT_DIRECTORY" == "REQUIRED" ]; then
    echo "ERROR: Output directory is not set with \"-o\" !"
    exit 3
elif [ ! -d "$CONFIG_OUTPUT_DIRECTORY" ]; then
    echo "ERROR: dir set with \"-o\" is not a directory!"
    exit 4
fi

echo "Creating config with name \"$WGNAME\" with \"$CLIENT_COUNT\" clients..."

mkdir -p "$HOME/temp"

TEMP_DIR=$(mktemp -d -p "$HOME/temp")

# first create server config
SERVER_CONF="${TEMP_DIR}/${WGNAME}server.conf"
SERVER_PRK="$(wg genkey)"
SERVER_PUB="$(echo -n ${SERVER_PRK} | wg pubkey)"

echo "Creating server conf (will be appended to with client info)..."
cat >> "${SERVER_CONF}" <<EOF
[Interface]
Address = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.1/24
ListenPort = ${SERVER_LISTEN_PORT}
PrivateKey = ${SERVER_PRK}
EOF

# generate config per each client
for ((i = 0; i < $CLIENT_COUNT; ++i)); do
    CLIENT_CONF="${TEMP_DIR}/${WGNAME}client${i}.conf"
    CLIENT_PRK="$(wg genkey)"
    CLIENT_PUB="$(echo -n ${CLIENT_PRK} | wg pubkey)"
    CLIENT_PRE="$(wg genpsk)"

    echo "Appending client $((i + 1)) to server conf..."
    cat >> "${SERVER_CONF}" <<EOF

[Peer]
PublicKey = ${CLIENT_PUB}
PresharedKey = ${CLIENT_PRE}
AllowedIPs = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$((i + 2))/32
EOF

    echo "Creating client $((i + 1)) conf..."
    cat >> "${CLIENT_CONF}" <<EOF
[Interface]
Address = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$((i + 2))/24
PrivateKey = ${CLIENT_PRK}

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${CLIENT_PRE}
AllowedIPs = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.1/32
Endpoint = ${SERVER_ENDPOINT}:${SERVER_LISTEN_PORT}
EOF

    if (($ENABLE_PERSISTENT_KEEPALIVE)); then
        cat >> "${CLIENT_CONF}" <<EOF
PersistentKeepAlive = 25
EOF
    fi

done

# output configs to output directory
echo "Placing generated configs to output directory..."

cp -v "$SERVER_CONF" "${CONFIG_OUTPUT_DIRECTORY}/"
for ((i = 0; i < $CLIENT_COUNT; ++i)); do
    cp -v "${TEMP_DIR}/${WGNAME}client${i}.conf" "${CONFIG_OUTPUT_DIRECTORY}/"
done

echo "Removing temporary directory..."
rm -rvf "$TEMP_DIR"

echo "Done. Configs should exist at \"$CONFIG_OUTPUT_DIRECTORY\" ."
