#!/usr/bin/env bash

unset SINK_IDENT

while getopts 'n:' op; do
    case $op in
        n)
            SINK_IDENT="$OPTARG";;
    esac
done

if [[ -z "$SINK_IDENT" ]]; then
    echo 'ERROR: No sink identifier given!'
    exit 1;
fi

SINK_NUMBER_A=($(pactl list sinks | \
    awk "BEGIN {CurrentSink = \"None\";}
        {
            if (\$0 ~ \"^Sink #.*\") {
                CurrentSink = \$2;
            }
            if (\$0 ~ \".*$SINK_IDENT.*\") {
                printf \"%s\\n\", CurrentSink;
            }
        }" | \
    sort | uniq | tr -d '#'))

if (( ${#SINK_NUMBER_A[*]} > 1 )); then
    echo 'ERROR: Mulitple Sinks match given ident!'
    echo "${SINK_NUMBER_A[@]}"
    exit 1
fi

pactl set-sink-mute ${SINK_NUMBER_A} toggle

notify-send -t 4000 "Volume $(pactl get-sink-mute ${SINK_NUMBER_A})" "$SINK_IDENT"
