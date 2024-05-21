#!/bin/bash

# Get list of custom shortcuts
custom_shortcuts=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings | tr -d "[]',")

# Iterate over each custom shortcut
for shortcut_path in $custom_shortcuts; do
    schema="org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:"
    # Get binding
    binding=$(gsettings get ${schema}$shortcut_path binding)

    # Get command name
    command_name=$(gsettings get ${schema}$shortcut_path name)

    # Get command
    command=$(gsettings get ${schema}$shortcut_path command)

    # Print details
    echo "Shortcut: $command_name"
    echo "Binding: $binding"
    echo "Command: $command"
    echo
done
