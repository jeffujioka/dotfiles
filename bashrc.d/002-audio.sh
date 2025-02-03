#!/usr/bin/zsh

alias audio-sonyheadset-2-hsp-hfp="pacmd set-card-profile bluez_card.CC_98_8B_21_38_7B headset_head_unit"
alias audio-sonyheadset-2-a2dp="pacmd set-card-profile bluez_card.CC_98_8B_21_38_7B a2dp_sink"

alias audio-set-sink-port-builtin-speaker="pactl set-sink-port alsa_output.pci-0000_00_1f.3.analog-stereo analog-output-speaker"
alias audio-set-sink-port-builtin-headphones="pactl set-sink-port alsa_output.pci-0000_00_1f.3.analog-stereo analog-output-headphones"

alias audio-set-default-sink-builtin-output="pactl set-default-sink alsa_output.pci-0000_00_1f.3.analog-stereo"
alias audio-set-default-sink-sony-bluetooth="pactl set-default-sink bluez_sink.CC_98_8B_21_38_7B.a2dp_sink"

alias audio-list-sink-inputs-short="pacmd list-sink-inputs | grep -e 'sink:' -e 'client:' -e 'index:'"

alias audio-pulseaudio-restart="pulseaudio -k"

alias audio-move-all-streams-to-builtin-sink="audio-move-all-streams-to-sink.sh alsa_output.pci-0000_00_1f.3.analog-stereo"
alias audio-move-all-streams-to-WH-1000XM3-sink="audio-move-all-streams-to-sink.sh bluez_sink.CC_98_8B_21_38_7B.a2dp_sink"

# microphone
alias audio-set-default-mic-usb="pactl set-default-source alsa_input.usb-CMEDIA_USB_PnP_Audio_Device-00.multichannel-input"
alias audio-set-default-mic-internal="pactl set-default-source alsa_input.pci-0000_00_1f.3.analog-stereo"

alias audio-move-mic-usb="pactl move-source-output 1 alsa_input.usb-CMEDIA_USB_PnP_Audio_Device-00.multichannel-input"
alias audio-move-mic-internal="pactl move-source-output 1 alsa_input.pci-0000_00_1f.3.analog-stereo"

alias karaoke-on="pactl load-module module-loopback latency_msec=1"
alias karaoke-off="pactl unload-module module-loopback"
