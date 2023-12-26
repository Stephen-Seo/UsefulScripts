#!/usr/bin/env bash

# This script generates a rsa/ed25519 ssh key signed by a CA key (the CA key
# must be on the machine or the CA key's public key can be specified and
# ssh-agent will be used to sign with the CA key).
#
# See the CERTIFICATES section in the `ssh-keygen` man-page.

# Set this to 0 to disable use of gpg-agent.
GPG_AGENT_ENABLED=1
CA_KEY_THROUGH_SSH_AGENT=0
CA_KEY_PATH=""
USER_KEY_RSA=0
USER_KEY_ED25519=0
USER_KEY_NAME=""
USER_KEY_IDENTIFIER="temp_key"
USER_KEY_USER_NAME=""
USER_KEY_EXPIRE_TIME="+15m"

read -p "Set key identifier? (Default \"temp_key\") [y/N]> " user_input

if [[ -n "$user_input" ]] && [[ "$user_input" == [yY] ]]; then
    read -e -p "Specify key identifier: > " user_input
    USER_KEY_IDENTIFIER="$user_input"
    if [[ -z "$USER_KEY_IDENTIFIER" ]]; then
        echo "ERROR: Empty string cannot be used as identifier."
        exit 1
    fi
fi
echo "Using key identifier \"$USER_KEY_IDENTIFIER\"."

read -p "Set expire time? (default \"$USER_KEY_EXPIRE_TIME\") [y/N]> " user_input

if [[ -n "$user_input" ]] && [[ "$user_input" == [yY] ]]; then
    read -p "Specify expire time: > " user_input
    USER_KEY_EXPIRE_TIME="$user_input"
    if [[ -z "$USER_KEY_EXPIRE_TIME" ]]; then
        echo "ERROR: Empty string cannot be used for expire time."
        exit 1
    fi
    echo "Expire time set to \"$USER_KEY_EXPIRE_TIME\"."
fi

read -e -p "Specify user name to identify for (prinicpal(s)): > " user_input
if [[ -z "$user_input" ]]; then
    echo "ERROR: Cannot specify empty string for user name!"
    exit 1
else
    USER_KEY_USER_NAME="$user_input"
fi

echo "Using \"$USER_KEY_USER_NAME\" in cert principals."

read -p "Use CA key through ssh-agent? [y/N]> " user_input

if [[ -n "$user_input" ]] && [[ "$user_input" == [yY] ]]; then
    CA_KEY_THROUGH_SSH_AGENT=1
    echo "Using CA key through ssh-agent."
    while true; do
        read -e -p "Specify the CA public key> " user_input
        if [[ -r $user_input ]]; then
            CA_KEY_PATH="$user_input"
            echo "Using \"$CA_KEY_PATH\" as CA public key."
            break
        else
            echo "ERROR: \"$user_input\" doesn't exist!"
        fi
    done
else
    while true; do
        read -e -p "Specify the CA key> " user_input
        if [[ -r $user_input ]]; then
            CA_KEY_PATH="$user_input"
            echo "Using \"$CA_KEY_PATH\" as CA key."
            break
        else
            echo "ERROR: \"$user_input\" doesn't exist!"
        fi
    done
fi

USING_EXISTING_KEY=0
while true; do
    read -p "Use existing key? [y/N]> " user_input
    if [[ "$user_input" == [yY] ]]; then
        USING_EXISTING_KEY=1
        break;
    else
        break;
    fi
done

unset EXISTING_PUBKEY_PATH
while (( USING_EXISTING_KEY )); do
    read -e -p "Specify the path to the key's pubkey> " user_input
    if [[ -r "$user_input" ]]; then
        EXISTING_PUBKEY_PATH="$user_input"
        echo "Using existing key \"$EXISTING_PUBKEY_PATH\""
        break;
    fi
done

if [[ -z "$EXISTING_PUBKEY_PATH" ]]; then
    while true; do
        read -p "Generate RSA or ED25519 key? [r/e]> " user_input
        if [[ "$user_input" == [rR] ]]; then
            USER_KEY_RSA=1
            echo "Using RSA."
            break
        elif [[ "$user_input" == [eE] ]]; then
            USER_KEY_ED25519=1
            echo "Using ED25519."
            break
        fi
    done

    while true; do
        read -p "Specify key name: > " user_input
        if [[ -n "$user_input" ]]; then
            USER_KEY_NAME="$user_input"
            echo "Using key name \"$USER_KEY_NAME\"."
            break
        fi
    done

    if (( USER_KEY_RSA )); then
        echo ssh-keygen -t rsa -b 4096 -a 100 -o -f "$USER_KEY_NAME"
        ssh-keygen -t rsa -b 4096 -a 100 -o -f "$USER_KEY_NAME"
    elif (( USER_KEY_ED25519 )); then
        echo ssh-keygen -t ed25519 -a 100 -o -f "$USER_KEY_NAME"
        ssh-keygen -t ed25519 -a 100 -o -f "$USER_KEY_NAME"
    else
        echo "ERROR: Neither RSA nor ED25519 specified!"
        exit 1
    fi

    if [[ ! -r "$USER_KEY_NAME" ]] ||  [[ ! -r "${USER_KEY_NAME}.pub" ]]; then
        echo "ERROR: Neither \"$USER_KEY_NAME\" nor \"${USER_KEY_NAME}.pub\" exists!"
        exit 1
    fi
fi

if [[ -z "$USER_KEY_NAME" ]] && [[ -n "$EXISTING_PUBKEY_PATH" ]]; then
    USER_PUBKEY_NAME="$EXISTING_PUBKEY_PATH"
elif [[ -z "$USER_KEY_NAME" ]]; then
    echo "ERROR: Key not generated nor existing key specified!"
    exit 1
else
    USER_PUBKEY_NAME="${USER_KEY_NAME}.pub"
fi

if (( CA_KEY_THROUGH_SSH_AGENT )) && [[ -r "$CA_KEY_PATH" ]]; then
    for ((i=0; i<3; ++i)); do
        echo 'Signing certificate...'
        (( GPG_AGENT_ENABLED )) && gpg-connect-agent updatestartuptty /bye >&/dev/null
        ssh-keygen -Us "$CA_KEY_PATH" -I "$USER_KEY_IDENTIFIER" -V "$USER_KEY_EXPIRE_TIME" -n "$USER_KEY_USER_NAME" "${USER_PUBKEY_NAME}"
        if (( $? != 0 )); then
            echo "ERROR: Failed to sign certificate!"
            if (( i >= 2 )); then
                exit 1
            fi
        else
            break
        fi
    done
elif [[ -r "$CA_KEY_PATH" ]]; then
    for ((i=0; i<3; ++i)); do
        echo 'Signing certificate...'
        (( GPG_AGENT_ENABLED )) && gpg-connect-agent updatestartuptty /bye >&/dev/null
        ssh-keygen -s "$CA_KEY_PATH" -I "$USER_KEY_IDENTIFIER" -V "$USER_KEY_EXPIRE_TIME" -n "$USER_KEY_USER_NAME" "${USER_PUBKEY_NAME}"
        if (( $? != 0 )); then
            echo "ERROR: Failed to sign certificate!"
            if (( i >= 2 )); then
                exit 1
            fi
        else
            break
        fi
    done
else
    echo "ERROR: Invalid settings for CA key!"
    exit 1
fi

echo Done.

if [[ -z "$USER_KEY_NAME" ]] && [[ -n "$USER_PUBKEY_NAME" ]]; then
    if echo "$USER_PUBKEY_NAME" | grep '\.pub$' >&/dev/null; then
        USER_KEY_NAME="$(echo -n "$USER_PUBKEY_NAME" | sed 's/\.pub$//')"
    fi
fi

echo "Hint: Use ssh -o CertificateFile=${USER_KEY_NAME:-key}-cert.pub -i ${USER_KEY_NAME:-key} host"
