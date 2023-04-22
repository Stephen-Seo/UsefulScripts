#!/bin/bash

# Note that this script only sets up client connections to a server.
# This means that the confs will be generated without
# client-to-client connections.

set -e

function print_help {
    echo "Generates config for wireguard"
    echo "-h - prints this help"
    echo "-n <name> - gives a name to the config"
    echo "-c <count> - number of clients to generate for. Mutually exclusive with \"-u\""
    echo "-s <ipv4_second> - sets the second byte of the ipv4"
    echo "-i <ipv4_third> - sets the third byte of the ipv4"
    echo "-e <endpoint> - ip address or domain name (required)"
    echo "-p <port> - listen port of server (defaults to 50000)"
    echo "-k - enables persistent keepalive for clients"
    echo "-o <directory> - output dir to place configs (required)"
    echo "-u <subnet> - subnet to use (default 24). Mutually exclusive with \"-c\""
    echo "-f <ipv4_fourth> - must use with \"-u\" to set partial fourth byte"
}

WGNAME="wg$(date | sha1sum | head -c 8)"
CLIENT_COUNT=1
IPV4_FIRST=10
IPV4_SECOND=8 # this can be modified with "-s <integer>"
IPV4_THIRD=0 # this can be modified with "-i <integer>"
IPV4_FOURTH=0 # used when "-u <subnet>" is used
SERVER_ENDPOINT="REQUIRED"
SERVER_LISTEN_PORT=50000
ENABLE_PERSISTENT_KEEPALIVE=0
CONFIG_OUTPUT_DIRECTORY="REQUIRED"
WG_SUBNET=24
CLIENT_COUNT_SET=0
WG_SUBNET_SET=0
IPV4_FOURTH_SET=0

# OPTARG
while getopts 'hn:c:s:i:e:p:ko:u:f:' opt; do
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
        CLIENT_COUNT_SET=1
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
    elif [ "$opt" == "u" ]; then
        WG_SUBNET="$OPTARG"
        WG_SUBNET_SET=1
    elif [ "$opt" == "f" ]; then
        IPV4_FOURTH="$OPTARG"
        IPV4_FOURTH_SET=1
    fi
done

# validation
if [ "$SERVER_ENDPOINT" == "REQUIRED" ]; then
    echo "ERROR: Endpoint is not set with \"-e\" !"
    exit 2
elif [ "$CONFIG_OUTPUT_DIRECTORY" == "REQUIRED" ]; then
    echo "ERROR: Output directory is not set with \"-o\" !"
    exit 3
elif [ ! -d "$CONFIG_OUTPUT_DIRECTORY" ]; then
    echo "ERROR: dir set with \"-o\" is not a directory!"
    exit 4
elif (( $CLIENT_COUNT_SET )) && (( $WG_SUBNET_SET )); then
    echo "ERROR: \"-c\" and \"-u\" is mutually exclusive!"
    exit 12
elif (( $IPV4_FOURTH_SET )) && (( $WG_SUBNET_SET == 0 )); then
    echo "ERROR: fourth byte set but \"-u\" not used!"
    exit 13
fi

# validation of "-u <subnet>"
if (( $WG_SUBNET < 24 )); then
    echo "ERROR: subnet cannot be less than 24!"
    exit 9
elif (( $WG_SUBNET > 24 )); then
    USED_BITS=$(( 32 - $WG_SUBNET ))
    if (( $USED_BITS < 2 )); then
        echo "ERROR: subnet \"$WG_SUBNET\" is too large! Use 24-30!"
        exit 11
    fi
    TEMP_A="$IPV4_FOURTH"
    while (( $USED_BITS > 0 )); do
        if (( $TEMP_A & 1 != 0 )); then
            echo "ERROR: Invalid IPV4_FOURTH when using subnet \"$WG_SUBNET\"!"
            exit 10
        fi
        TEMP_A=$(( $TEMP_A >> 1 ))
        USED_BITS=$(( $USED_BITS - 1 ))
    done

    CLIENT_COUNT=$(( 2**(32 - $WG_SUBNET) - 2 - 1 ))
fi

echo "Creating config with name \"$WGNAME\" with \"$CLIENT_COUNT\" clients and subnet \"$WG_SUBNET\"..."

mkdir -p "$HOME/temp"

TEMP_DIR=$(mktemp -d -p "$HOME/temp")

# first create server config
SERVER_CONF="${TEMP_DIR}/${WGNAME}server.conf"
SERVER_PRK="$(wg genkey)"
SERVER_PUB="$(echo -n ${SERVER_PRK} | wg pubkey)"

echo "Creating server conf (will be appended to with client info)..."
cat >> "${SERVER_CONF}" <<EOF
[Interface]
Address = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$(( 1 | $IPV4_FOURTH ))/$WG_SUBNET
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
AllowedIPs = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$(( (i + 2) | $IPV4_FOURTH ))/32
EOF

    echo "Creating client $((i + 1)) conf..."
    cat >> "${CLIENT_CONF}" <<EOF
[Interface]
Address = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$(( (i + 2) | $IPV4_FOURTH ))/$WG_SUBNET
PrivateKey = ${CLIENT_PRK}

[Peer]
PublicKey = ${SERVER_PUB}
PresharedKey = ${CLIENT_PRE}
AllowedIPs = ${IPV4_FIRST}.${IPV4_SECOND}.${IPV4_THIRD}.$(( 1 | $IPV4_FOURTH ))/32
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
