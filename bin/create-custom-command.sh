#!/bin/bash

# Define custom shortcut details
custom_name="My Custom Shortcut"
custom_command="/path/to/your/command"
custom_binding="<Primary><Alt>K"  # Example binding: Ctrl + Alt + K

# Register the custom shortcut
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ name "$custom_name"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ command "$custom_command"
gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/ binding "$custom_binding"
