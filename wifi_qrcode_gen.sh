#!/usr/bin/env bash

# MIT License
#
# Copyright (c) 2025 Stephen Seo
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.

# Requires "qrcode[pil]" to be in PATH. (Use `pip install "qrcode[pil]"` or use
# your OS's packages.)

unset WIFI_PSSWD_TXT_FILENAME
unset WIFI_NAME
unset OUTPUT_FILENAME

set -e
set -o pipefail

while getopts 'f:n:o:h' op; do
    case $op in
        f) WIFI_PSSWD_TXT_FILENAME="$OPTARG";;
        n) WIFI_NAME="$OPTARG";;
        o) OUTPUT_FILENAME="$OPTARG";;
        h) echo '-f <psswd_filename>, -n <wifi_name>, -o <output_png>'; exit 0;;
    esac
done

if [[ -z "$WIFI_PSSWD_TXT_FILENAME" ]]; then
    echo 'Use -f <psswd_filename>'
    exit 1
elif [[ -z "$WIFI_NAME" ]]; then
    echo 'Use -n <wifi_name>'
    exit 2
elif [[ -z "$OUTPUT_FILENAME" ]]; then
    echo 'Use -o <output_png>'
    exit 3
fi

cat <(echo "WIFI:T:WPA;S:") <(echo -n "$WIFI_NAME" | sed -e 's|[\\";,]|\\&|g') <(echo ";P:") <(sed -e 's|[\\";,]|\\&|g' < "$WIFI_PSSWD_TXT_FILENAME" | tr -d $'\r'$'\n') <(echo ';;') | qr > "$OUTPUT_FILENAME"
echo "Exported qrcode to \"$OUTPUT_FILENAME\"."
