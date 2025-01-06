#!/bin/bash

connected=false
x=1

SONY_WH_1000XM3_SINK_NAME="bluez_sink.CC_98_8B_21_38_7B.a2dp_sink"

trap ctrl_c INT

function ctrl_c() {
        echo "** Trapped CTRL-C"
        connected=true
}

while [ $connected == false ]
do
    echo "Number of attempts $x"
    bluetoothctl untrust CC:98:8B:21:38:7B \
    && bluetoothctl trust CC:98:8B:21:38:7B \
    && bluetoothctl disconnect CC:98:8B:21:38:7B \
    && bluetoothctl connect CC:98:8B:21:38:7B

    x=$(( $x + 1))
    if [[ $(pactl list short sinks | grep $SONY_WH_1000XM3_SINK_NAME) ]]; then
        pactl set-default-sink $SONY_WH_1000XM3_SINK_NAME
        pactl set-default-sink alsa_output.pci-0000_00_1f.3.analog-stereo
        pactl set-default-sink $SONY_WH_1000XM3_SINK_NAME

        pactl set-default-source alsa_input.usb-CMEDIA_USB_PnP_Audio_Device-00.multichannel-input
        pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo
        pactl set-default-source alsa_input.usb-CMEDIA_USB_PnP_Audio_Device-00.multichannel-input

        audio-move-all-streams-to-sink.sh $SONY_WH_1000XM3_SINK_NAME

        connected=true
    fi
done
