#!/usr/bin/env bash

unset SINK_IDENT
unset SET_PERCENTAGE
unset SET_MIDI_PERCENTAGE

while getopts 'n:p:m:' op; do
    case $op in
        n)
            SINK_IDENT="$OPTARG";;
        p)
            SET_PERCENTAGE="$OPTARG";;
        m)
            SET_MIDI_PERCENTAGE="$OPTARG";;
    esac
done

if [[ -z "$SINK_IDENT" ]]; then
    echo 'ERROR: No sink identifier given!'
    exit 1;
fi

if [[ -n "$SET_MIDI_PERCENTAGE" ]]; then
    SET_PERCENTAGE=$(( 100 * SET_MIDI_PERCENTAGE / 127 ))
fi

if [[ -z "$SET_PERCENTAGE" ]]; then
    echo 'ERROR: No percentage given!'
    exit 1
fi

IFS=$'\n'

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

if [[ -z "${SINK_NUMBER_A}" ]]; then
    echo 'ERROR: No Sinks match given ident!'
    exit 1
fi

pactl set-sink-volume ${SINK_NUMBER_A} "${SET_PERCENTAGE}%"

notify-send -t 4000 "Volume ${SET_PERCENTAGE}% Set" "${SINK_IDENT} #${SINK_NUMBER_A}"
