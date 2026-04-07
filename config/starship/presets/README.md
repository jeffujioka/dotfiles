# Starship Prompt Presets

A curated collection of 19 production-ready Starship prompt configurations across 3 layout styles and 7 color palettes.

---

## 📋 Quick Reference

### Layout Styles

| Style | Description | Best For | File Pattern |
|-------|-------------|----------|--------------|
| **Clean Gradient** | Decorative gradient segments with `[░▒▓]` symbols | Visual appeal, terminal aesthetics | `starship-clean-gradient-*.toml` |
| **Powerline** | Powerline-style transitions with arrow separators | Professional, minimalist | `starship-powerline-gradient-*.toml` |
| **Bracket** | Simple bracket notation `[module]` | Lightweight, universal compatibility | `starship-bracket-*.toml` |

### Color Palettes

| Palette | Layout Support | Colors | Use Case |
|---------|---|--------|----------|
| **Aurora** | Clean, Powerline, Bracket | Magenta → Purple → Blue | Northern lights inspired |
| **Forest** | Clean, Powerline, Bracket | Green → Teal → Blue | Nature-inspired, woodland theme |
| **Inferno** | Clean, Powerline, Bracket | Red → Orange → Magenta | Fire spectrum, warm energy |
| **Twilight** | Clean, Bracket | Purple → Blue | Cosmic dusk, evening sky |
| **Ocean** | Clean, Powerline, Bracket | Teal → Cyan → Blue | Water-inspired, cool tones |
| **Solar** | Clean, Powerline, Bracket | Orange → Amber → Brown | Sun-inspired, warm tones |
| **Dusk** | Powerline | Magenta → Purple → Blue | Twilight skies variant |
| **Catppuccin** | Powerline | Official Catppuccin palette | Catppuccin Mocha theme |

---

## 🎨 Preset Breakdown

### Clean Gradient (6 presets)
Decorative prompt with gradient color transitions and ornamental symbols.

- **starship-clean-gradient-aurora.toml** — Aurora: Magenta→Purple→Blue
- **starship-clean-gradient-forest.toml** — Forest: Green→Teal→Blue
- **starship-clean-gradient-inferno.toml** — Inferno: Red→Orange→Magenta
- **starship-clean-gradient-twilight.toml** — Twilight: Purple→Blue
- **starship-clean-gradient-ocean.toml** — Ocean: Teal→Cyan→Blue
- **starship-clean-gradient-solar.toml** — Solar: Orange→Amber→Brown

**Features:**
- Decorative `[░▒▓]` leading symbol
- Tight spacing with double-bracket formatting
- Full color gradients across prompt segments
- All standard modules included

**Best for:** Users who want visual appeal and don't mind slightly longer prompts.

---

### Powerline Gradient (7 presets)
Powerline-style prompt with arrow separator transitions between segments.

- **starship-powerline-gradient-aurora.toml** — Aurora: Magenta→Purple→Blue
- **starship-powerline-gradient-forest.toml** — Forest: Green→Teal→Blue
- **starship-powerline-gradient-inferno.toml** — Inferno: Red→Orange→Magenta
- **starship-powerline-gradient-dusk.toml** — Dusk: Magenta→Purple→Blue
- **starship-powerline-gradient-ocean.toml** — Ocean: Teal→Cyan→Blue
- **starship-powerline-gradient-solar.toml** — Solar: Orange→Amber→Brown
- **starship-powerline-catppuccin.toml** — Catppuccin Mocha official palette

**Features:**
- Powerline arrow separators between segments
- Single-bracket formatting
- Color transitions with arrow glyphs
- Minimal decorative elements
- All standard modules included

**Best for:** Users who prefer Powerline/modern prompt styling.

---

### Bracket Layout (6 presets)
Simple, lightweight bracket-based layout with minimal styling.

- **starship-bracket-aurora.toml** — Aurora: Magenta→Purple→Blue
- **starship-bracket-forest.toml** — Forest: Green→Teal→Blue
- **starship-bracket-inferno.toml** — Inferno: Red→Orange→Magenta
- **starship-bracket-twilight.toml** — Twilight: Purple→Blue
- **starship-bracket-ocean.toml** — Ocean: Teal→Cyan→Blue
- **starship-bracket-solar.toml** — Solar: Orange→Amber→Brown

**Features:**
- Simple `[module]` bracket formatting
- Lightweight, fast rendering
- Good terminal compatibility
- Foreground colors only (no backgrounds)
- All standard modules included

**Best for:** Users who prefer minimal styling or have terminal compatibility concerns.

---

## 📦 What's Included

All presets include:

### Modules
- OS symbol (macOS, Ubuntu, Linux)
- Directory with smart truncation
- Git branch and status
- Language versions (Python, Node.js, Rust, Java, C, C++)
- Docker context
- Command duration (when > 2s)
- Battery status with thresholds
- System time
- Custom indicators (tmux zoom, VPN status)

### Features
- Newline before prompt character
- 1000ms command timeout
- Success/error status symbols
- Read-only directory indicator
- Directory substitutions for common folders
- Smart git status with detailed indicators
- Battery display with color thresholds

---

## 🚀 Installation & Usage

### 1. Choose Your Preset
Select a preset that matches your preferred layout and color palette.

### 2. Copy to Starship Config
```bash
# Replace /path/to/preset with your chosen file
cp /path/to/starship-<layout>-<palette>.toml ~/.config/starship.toml
```

### 3. Reload Your Shell
```bash
# Bash
source ~/.bashrc

# Zsh
source ~/.zshrc

# Fish
source ~/.config/fish/config.fish
```

---

## 🎯 Recommended Combinations

| User Type | Recommended | Reason |
|-----------|-------------|--------|
| **Minimalist** | `starship-bracket-aurora.toml` | Lightweight, universal |
| **Aesthetics** | `starship-clean-gradient-ocean.toml` | Beautiful gradients |
| **Professional** | `starship-powerline-catppuccin.toml` | Established theme |
| **Cozy** | `starship-clean-gradient-forest.toml` | Warm, natural tones |
| **Energetic** | `starship-clean-gradient-inferno.toml` | Bold, fiery energy |

---

## �� Color Palette Details

### Aurora (Magenta→Purple→Blue)
- Primary: `#c00a7a` (Magenta)
- Secondary: `#380525` (Dark Magenta)
- Tertiary: `#250540` (Purple)
- Background: `#050e50` (Deep Blue)

### Forest (Green→Teal→Blue)
- Primary: `#10c050` (Green)
- Secondary: `#0a3015` (Dark Green)
- Tertiary: `#052828` (Teal)
- Background: `#050f25` (Navy)

### Inferno (Red→Orange→Magenta)
- Primary: `#e05050` (Red)
- Secondary: `#3a1515` (Dark Red)
- Tertiary: `#7a1a4a` (Magenta)
- Background: `#5a2a1a` (Burnt Orange)

### Twilight (Purple→Blue)
- Primary: `#c00a7a` (Magenta)
- Secondary: `#380525` (Dark Magenta)
- Tertiary: `#250540` (Purple)
- Background: `#050e50` (Deep Blue)

### Ocean (Teal→Cyan→Blue)
- Primary: `#0aa0c0` (Cyan)
- Secondary: `#052a3a` (Teal)
- Tertiary: `#051a4a` (Blue)
- Background: `#050f3a` (Navy)

### Solar (Orange→Amber→Brown)
- Primary: `#d05000` (Orange)
- Secondary: `#5a2800` (Burnt)
- Tertiary: `#6a3800` (Medium Brown)
- Background: `#4a1a00` (Dark Brown)

### Dusk (Magenta→Purple→Blue)
- Same as Twilight/Aurora palette
- Optimized for Powerline layout

### Catppuccin (Official Mocha)
- Follows official Catppuccin color scheme
- Well-supported across various apps

---

## ⚙️ Requirements

- **Starship** 1.0+
- **Nerd Font** (for proper glyph rendering)
- **Bash/Zsh/Fish** shell
- Terminal with 256-color support

---

## 📝 Customization

Each preset is designed to be standalone but can be customized by:

1. Modifying color hex values
2. Enabling/disabling modules
3. Adjusting format strings
4. Changing icon symbols
5. Tuning timeouts and thresholds

See [Starship docs](https://starship.rs) for full configuration options.

---

## ✨ Features Consistency

All presets maintain feature parity:
- ✅ All modules present (can be disabled individually)
- ✅ Consistent icon usage across layouts
- ✅ Proper spacing and formatting
- ✅ Git status indicators
- ✅ Language version detection
- ✅ Custom indicators (tmux, VPN)
- ✅ Battery status with thresholds
- ✅ Command execution time tracking

---

## 🔄 Version History

**Current:** v2.0 (Complete Overhaul)
- Added Bracket layout (6 new presets)
- Added Twilight and Dusk color palettes
- Fixed color palette alignment with names
- Enhanced feature parity across all presets
- Comprehensive documentation

**Previous:** v1.0
- 11 base presets (5 clean + 5 powerline + 1 catppuccin)

---

## 📬 Support

For issues or suggestions:
1. Check preset headers for intended use case
2. Verify Nerd Font installation
3. Confirm Starship version compatibility
4. Test individual modules in isolation

---

Generated with ❤️ using Starship configuration best practices.
