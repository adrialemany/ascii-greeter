#!/bin/bash

ART_DIR="$HOME/ascii-greeter"

WHITE=$'\033[97m'
RED=$'\033[31m'
RESET=$'\033[0m'

IFS= read -r -d $'\0' ART_FILE < <(find "$ART_DIR" -type f -name '*.txt' -print0 | shuf -z -n1)

if [[ -z "$ART_FILE" ]]; then
  echo "No ASCII art files found in $ART_DIR"
  exit 1
fi

mapfile -t ascii_lines_raw < "$ART_FILE"

if [[ ${#ascii_lines_raw[@]} -eq 0 && ! -s "$ART_FILE" && -f "$ART_FILE" ]]; then
    : # File exists but is empty, acceptable.
elif [[ ${#ascii_lines_raw[@]} -eq 0 && -n "$ART_FILE" ]]; then
    echo "Error reading ASCII art file: $ART_FILE"
    exit 1
fi

declare -a ascii_lines_cleaned
declare -a visible_lengths
ascii_width=0

for raw_line in "${ascii_lines_raw[@]}"; do
  cleaned_line=$(echo -n "$raw_line" | tr -d '\r')
  interpreted=$(printf '%b' "$cleaned_line")
  visible_part=$(echo -n "$interpreted" | sed -E 's/\x1b\[[0-9;]*[[:alpha:]]//g')
  visible_len=${#visible_part}

  ascii_lines_cleaned+=("$cleaned_line")
  visible_lengths+=("$visible_len")

  (( visible_len > ascii_width )) && ascii_width=$visible_len
done

for i in "${!ascii_lines_cleaned[@]}"; do
  cleaned_line="${ascii_lines_cleaned[i]}"
  visible_len="${visible_lengths[i]}"

  if (( visible_len < ascii_width )); then
    padding=$(( ascii_width - visible_len ))
    cleaned_line="$cleaned_line$(printf '%*s' "$padding" "")"
    ascii_lines_cleaned[i]="$cleaned_line"
    visible_lengths[i]=$ascii_width
  fi

  interpreted=$(printf '%b' "$cleaned_line")
  stripped=$(echo -n "$interpreted" | sed -E 's/\x1b\[[0-9;]*[[:alpha:]]//g')
done

# Get battery percentage
battery_device=$(upower -e | grep -m 1 'BAT')
battery_percent="N/A"
if [[ -n "$battery_device" ]]; then
  battery_percent=$(upower -i "$battery_device" | awk '/percentage:/ {print $2; exit}')
fi

# System Information
# Feel free to add here whatever Text/info you want to see each time you open a terminal!
sys_info_lines=(
  "Welcome back, Master"
  "User: $(whoami)"
  "Device: $(hostname)"
  "OS: $(lsb_release -ds 2>/dev/null || (grep PRETTY_NAME /etc/os-release | cut -d'=' -f2 | tr -d '"') || echo 'N/A')"
  "Uptime: $(uptime -p)"
  # If you're using a laptop, you can see the battery % with "echo "Battery: $battery_percent""
  "Kernel: $(uname -r)"
  "CPU: $(lscpu | grep 'Model name:' | sed -e 's/Model name:[ \t]*//' -e 's/ CPU @ .*//' || echo 'N/A')"
  "RAM: $(free -h | awk '/^Mem:/ {print $3 " / " $2}' || echo 'N/A')"
  "Alive since: $(date -d "$(cat /sys/class/dmi/id/bios_date 2>/dev/null)" +'%d/%m/%y' 2>/dev/null || echo 'N/A')"
)

info_width=0
for line in "${sys_info_lines[@]}"; do
  if [[ ${#line} -gt $info_width ]]; then
    info_width=${#line}
  fi
done

gap="    "

block_width=$((ascii_width + ${#gap} + info_width))

lines_total=${#ascii_lines_cleaned[@]}
info_total=${#sys_info_lines[@]}
text_start_offset=$(( (lines_total - info_total) / 2 ))
if [[ $text_start_offset -lt 0 ]]; then
  text_start_offset=0
fi

current_art_filename=$(basename "$ART_FILE")
art_color_override=""

if [[ "$current_art_filename" == "arasaka.txt" ]]; then
  art_color_override="${WHITE}"
# elif [[ "$current_art_filename" == "samurai.txt" ]]; then
  # art_color_override="${RED}" # Keep commented if samurai.txt has its own embedded "\033" codes
fi

for ((i=0; i<lines_total; i++)); do
  current_cleaned_ascii_line="${ascii_lines_cleaned[i]:-}"
  visible_length_of_current_line=${visible_lengths[i]:-0}
  
  padding_spaces_for_this_line=$((ascii_width - visible_length_of_current_line))
  if [[ $padding_spaces_for_this_line -lt 0 ]]; then
    padding_spaces_for_this_line=0
  fi

  current_info_line=""
  if (( i >= text_start_offset && i < text_start_offset + info_total )); then
    info_array_index=$((i - text_start_offset))
    if [[ $info_array_index -ge 0 && $info_array_index -lt $info_total ]]; then
      current_info_line="${sys_info_lines[info_array_index]}"
    fi
  fi

  printf "%*s" "$left_padding" ""

  if [[ -n "$art_color_override" ]]; then
    printf '%s' "${art_color_override}"
  fi

  printf '%b' "$current_cleaned_ascii_line"

  if [[ -n "$art_color_override" ]]; then
    printf '%s' "${RESET}"
  fi

  if [[ $padding_spaces_for_this_line -gt 0 ]]; then
    printf "%*s" "$padding_spaces_for_this_line" ""
  fi

  printf "%s%s\n" "$gap" "$current_info_line"
done

if (( info_total > lines_total )); then
    remaining_info_start_index=$lines_total 
    
    for ((j=remaining_info_start_index; j<info_total; j++)); do
        current_info_line="${sys_info_lines[j]}"
        printf "%*s%*s%s%s\n" "$left_padding" "" "$ascii_width" "" "$gap" "$current_info_line"
    done
fi
