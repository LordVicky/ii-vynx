#!/usr/bin/env bash

set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
presets_script="${repo_root}/dots/.config/quickshell/ii/scripts/presets.sh"
tmp_root="$(mktemp -d)"
trap 'rm -rf -- "$tmp_root"' EXIT

export XDG_CONFIG_HOME="${tmp_root}/config"
shell_config_dir="${XDG_CONFIG_HOME}/illogical-impulse"
mkdir -p -- "$shell_config_dir"

cat > "${shell_config_dir}/config.json" <<'JSON'
{
  "appearance": {
    "surfaceStyle": "liquidGlass"
  },
  "background": {
    "wallpaperPath": "/wallpapers/saved.png"
  }
}
JSON

cat > "${shell_config_dir}/liquid-glass.json" <<'JSON'
{
  "followSystemTheme": false,
  "theme": "light",
  "shellTint": 0.12,
  "brightness": 0.08,
  "blurStrength": 0.4,
  "refractionStrength": 0.81,
  "chromaticAberration": 0.06,
  "fresnelStrength": 0.38,
  "specularStrength": 0.45,
  "edgeThickness": 0.05,
  "lensDistortion": 0.74
}
JSON

bash "$presets_script" --save apple-glass "Liquid Glass preset" >/dev/null
preset_file="${shell_config_dir}/presets/apple-glass.json"

jq -e '
  ._presetMeta.description == "Liquid Glass preset"
  and ._presetMeta.liquidGlass.theme == "light"
  and ._presetMeta.liquidGlass.blurStrength == 0.4
  and ._presetMeta.liquidGlass.refractionStrength == 0.81
  and .appearance.surfaceStyle == "liquidGlass"
' "$preset_file" >/dev/null

cat > "${shell_config_dir}/config.json" <<'JSON'
{
  "appearance": {
    "surfaceStyle": "material"
  },
  "background": {
    "wallpaperPath": "/wallpapers/current.png"
  }
}
JSON

cat > "${shell_config_dir}/liquid-glass.json" <<'JSON'
{
  "followSystemTheme": true,
  "theme": "dark",
  "shellTint": 0.5,
  "brightness": -0.4,
  "blurStrength": 3.0,
  "refractionStrength": 0.2,
  "futureSetting": "preserve-me"
}
JSON

bash "$presets_script" --apply apple-glass >/dev/null

jq -e '
  .appearance.surfaceStyle == "liquidGlass"
  and .background.wallpaperPath == "/wallpapers/saved.png"
  and (has("_presetMeta") | not)
' "${shell_config_dir}/config.json" >/dev/null

jq -e '
  .followSystemTheme == false
  and .theme == "light"
  and .shellTint == 0.12
  and .brightness == 0.08
  and .blurStrength == 0.4
  and .refractionStrength == 0.81
  and .futureSetting == "preserve-me"
' "${shell_config_dir}/liquid-glass.json" >/dev/null

cat > "${shell_config_dir}/presets/legacy.json" <<'JSON'
{
  "appearance": {
    "surfaceStyle": "material"
  }
}
JSON

jq '.brightness = 0.33' "${shell_config_dir}/liquid-glass.json" > "${shell_config_dir}/liquid-glass.tmp"
mv -f -- "${shell_config_dir}/liquid-glass.tmp" "${shell_config_dir}/liquid-glass.json"

bash "$presets_script" --apply legacy >/dev/null

jq -e '.appearance.surfaceStyle == "material"' "${shell_config_dir}/config.json" >/dev/null
jq -e '.brightness == 0.33 and .futureSetting == "preserve-me"' "${shell_config_dir}/liquid-glass.json" >/dev/null

printf 'presets liquid glass tests: ok\n'
