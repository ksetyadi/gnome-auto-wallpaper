#!/bin/bash

# AutoWallpaper Script
# Automatically sets wallpaper based on the time of day

# Supported image extensions
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "bmp" "gif" "tiff" "webp")

# Read configuration from auto.conf
CONFIG_FILE="$(dirname "$0")/auto.conf"

SESSION_NAMES=()
TIME_STARTS=()
TIME_ENDS=()
WALLPAPER_DIRS=()
THEMES=()
DND_STATUSES=()

# Parse auto.conf
parse_config() {
    while read -r line; do
        [[ "$line" =~ ^#.*$ || -z "$line" ]] && continue
        session=$(echo "$line" | awk '{print $1}')
        time_range=$(echo "$line" | awk '{print $2}')
        dir=$(echo "$line" | awk '{print $3}')
        theme=$(echo "$line" | awk '{print $4}')
        dnd=$(echo "$line" | awk '{print $5}')
        start_hour=$(echo "$time_range" | cut -d'-' -f1)
        end_hour=$(echo "$time_range" | cut -d'-' -f2)
        SESSION_NAMES+=("$session")
        TIME_STARTS+=("$start_hour")
        TIME_ENDS+=("$end_hour")
        WALLPAPER_DIRS+=("$dir")
        THEMES+=("$theme")
        DND_STATUSES+=("$dnd")
    done < "$CONFIG_FILE"
}

# Function to log messages
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Function to get current wallpaper
get_current_wallpaper() {
    gsettings get org.gnome.desktop.background picture-uri | sed 's/^.\(.*\).$/\1/' | sed 's/file:\/\///'
}

# Function to get random wallpaper from directory
get_random_wallpaper() {
    local directory="$1"
    local wallpapers=()
    
    # Build array of find arguments
    local find_args=()
    for ext in "${IMAGE_EXTENSIONS[@]}"; do
        if [[ ${#find_args[@]} -gt 0 ]]; then
            find_args+=(-o)
        fi
        find_args+=(-iname "*.${ext}")
    done
    
    # Find all image files in the directory
    while IFS= read -r -d '' file; do
        wallpapers+=("$file")
    done < <(find "$directory" -type f \( "${find_args[@]}" \) -print0 2>/dev/null)
    
    # Check if any wallpapers found
    if [[ ${#wallpapers[@]} -eq 0 ]]; then
        log_message "ERROR: No image files found in directory: $directory" >&2
        return 1
    fi
    
    # Select random wallpaper
    local random_index=$((RANDOM % ${#wallpapers[@]}))
    echo "${wallpapers[$random_index]}"
}

# Function to check if current wallpaper is from specified directory
is_wallpaper_from_directory() {
    local current_wallpaper="$1"
    local target_directory="$2"
    
    # Check if current wallpaper path starts with target directory path
    if [[ "$current_wallpaper" == "$target_directory"* ]]; then
        return 0  # True - wallpaper is from this directory
    else
        return 1  # False - wallpaper is not from this directory
    fi
}

# Function to set wallpaper
set_wallpaper() {
    local wallpaper_dir="$1"
    local time_period="$2"
    local theme="$3"
    local dnd="$4"
    
    # Check if wallpaper directory exists
    if [[ ! -d "$wallpaper_dir" ]]; then
        log_message "ERROR: Wallpaper directory not found: $wallpaper_dir"
        return 1
    fi
    
    # Get current wallpaper
    current_wallpaper=$(get_current_wallpaper)
    
    # Check if current wallpaper is already from the correct time period directory
    if is_wallpaper_from_directory "$current_wallpaper" "$wallpaper_dir"; then
        log_message "Wallpaper already set from $time_period directory: $current_wallpaper"
        return 0
    fi
    
    # Get random wallpaper from directory
    local new_wallpaper
    new_wallpaper=$(get_random_wallpaper "$wallpaper_dir")
    log_message "New wallpaper: $new_wallpaper"
    
    if [[ $? -ne 0 || -z "$new_wallpaper" ]]; then
        log_message "ERROR: Failed to get random wallpaper from $wallpaper_dir"
        return 1
    fi

    # Getting the GUI environement, since cron doesn't have it
    export DISPLAY=:0
    export DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/$(id -u)/bus
    
    # Set the wallpaper
    gsettings set org.gnome.desktop.background picture-uri "file://$new_wallpaper"
    gsettings set org.gnome.desktop.background picture-uri-dark "file://$new_wallpaper"
    log_message "Wallpaper changed to $time_period: $(basename "$new_wallpaper")"
    log_message "Full path: $new_wallpaper"

    # Change the theme and DND status based on config

    current_theme=$(gsettings get org.gnome.desktop.interface color-scheme | tr -d "'")
    log_message "Current theme: $current_theme"
    
    if [[ $theme == "light" && $current_theme == "prefer-dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'default'
        log_message "Theme set to light (from config)"
    elif [[ $theme == "dark" && $current_theme == "default" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark'
        log_message "Theme set to dark (from config)"
    fi
    
    show_banners=$(gsettings get org.gnome.desktop.notifications show-banners | tr -d "'")
    log_message "Current Show Banners/Notifications status: $show_banners"

    if [[ $dnd == "true" && $show_banners == "true" ]]; then
        gsettings set org.gnome.desktop.notifications show-banners false
        log_message "DND enabled (from config)"
    elif [[ $dnd == "false" && $show_banners == "false" ]]; then
        gsettings set org.gnome.desktop.notifications show-banners true
        log_message "DND disabled (from config)"
    fi
}

# Function to determine time period and set appropriate wallpaper (now uses config)
set_wallpaper_by_time() {
    local hour=$(date +%H)
    local hour_int=$((10#$hour))  # Convert to base 10 to handle leading zeros
    log_message "Current hour: $hour_int"

    local n_sessions=${#SESSION_NAMES[@]}
    local found=0
    for ((i=0; i<n_sessions; i++)); do
        local start=${TIME_STARTS[$i]}
        local end=${TIME_ENDS[$i]}
        local session=${SESSION_NAMES[$i]}
        local dir=${WALLPAPER_DIRS[$i]}
        local theme=${THEMES[$i]}
        local dnd=${DND_STATUSES[$i]}

        # Handle overnight ranges (e.g., 22-5)
        if (( start <= end )); then
            # Normal range
            if (( hour_int >= start && hour_int < end )); then
                set_wallpaper "$dir" "$session" "$theme" "$dnd"
                found=1
                break
            fi
        else
            # Overnight range
            if (( hour_int >= start || hour_int < end )); then
                set_wallpaper "$dir" "$session" "$theme" "$dnd"
                found=1
                break
            fi
        fi
    done
    if (( !found )); then
        log_message "No matching session found for hour $hour_int."
    fi
}

# Function to count images in directory
count_images_in_directory() {
    local directory="$1"
    local count=0
    
    # Build array of find arguments
    local find_args=()
    for ext in "${IMAGE_EXTENSIONS[@]}"; do
        if [[ ${#find_args[@]} -gt 0 ]]; then
            find_args+=(-o)
        fi
        find_args+=(-iname "*.${ext}")
    done
    
    # Count image files
    count=$(find "$directory" -type f \( "${find_args[@]}" \) 2>/dev/null | wc -l)
    echo "$count"
}

# Function to check if required directories and files exist
check_setup() {
    log_message "Checking setup..."

    parse_config
    
    # Check if base wallpaper directory exists (from first entry)
    if [[ ${#WALLPAPER_DIRS[@]} -eq 0 ]]; then
        log_message "WALLPAPER_DIRS: ${WALLPAPER_DIRS[@]}"
        log_message "ERROR: No wallpaper directories configured. Check your auto.conf."
        return 1
    fi
    
    local missing_dirs=()
    local empty_dirs=()
    
    for i in "${!WALLPAPER_DIRS[@]}"; do
        local dir_path="${WALLPAPER_DIRS[$i]}"
        local session="${SESSION_NAMES[$i]}"
        if [[ ! -d "$dir_path" ]]; then
            missing_dirs+=("$session ($dir_path)")
        else
            local image_count=$(count_images_in_directory "$dir_path")
            if [[ $image_count -eq 0 ]]; then
                empty_dirs+=("$session ($dir_path)")
            else
                log_message "✓ $session directory: $image_count image(s) found"
            fi
        fi
    done
    
    # Report missing directories
    if [[ ${#missing_dirs[@]} -gt 0 ]]; then
        log_message "ERROR: Missing directories:"
        for dir in "${missing_dirs[@]}"; do
            log_message "  - $dir"
        done
    fi
    
    # Report empty directories
    if [[ ${#empty_dirs[@]} -gt 0 ]]; then
        log_message "WARNING: Empty directories (no image files):"
        for dir in "${empty_dirs[@]}"; do
            log_message "  - $dir"
        done
    fi
    
    # Check if setup is complete
    if [[ ${#missing_dirs[@]} -gt 0 || ${#empty_dirs[@]} -gt 0 ]]; then
        log_message "Setup incomplete. Please create directories and add image files."
        log_message "Supported image formats: ${IMAGE_EXTENSIONS[*]}"
        return 1
    fi
    
    log_message "Setup check completed successfully"
    return 0
}

# Function to display help
show_help() {
    echo "AutoWallpaper Script - Automatically sets wallpapers based on time of day"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "  -h, --help     Show this help message"
    echo "  -c, --check    Check setup and configuration"
    echo "  -s, --status   Show current wallpaper and time period"
    echo "  -f, --force    Force wallpaper change regardless of current setting"
    echo "  -l, --list     List all available wallpapers in each directory"
    echo ""
    echo "Configuration:"
    echo "  All time periods, session names, and wallpaper directories are read from: $CONFIG_FILE"
    echo "  Example line: SessionName StartHour-EndHour /path/to/wallpapers"
    echo "  Example: Sunrise 5-8 /home/user/Pictures/sunrise"
    echo ""
    echo "Supported formats: ${IMAGE_EXTENSIONS[*]}"
}

# Function to show current status
show_status() {
    local hour=$(date +%H)
    local hour_int=$((10#$hour))
    local current_wallpaper=$(get_current_wallpaper)
    
    echo "Current Status:"
    echo "  Time: $(date '+%H:%M')"
    echo "  Hour: $hour_int"
    
    # Determine current time period/session
    local n_sessions=${#SESSION_NAMES[@]}
    local found=0
    local expected_dir=""
    local session_label=""
    for ((i=0; i<n_sessions; i++)); do
        local start=${TIME_STARTS[$i]}
        local end=${TIME_ENDS[$i]}
        if (( start <= end )); then
            if (( hour_int >= start && hour_int < end )); then
                session_label="${SESSION_NAMES[$i]}"
                expected_dir="${WALLPAPER_DIRS[$i]}"
                found=1
                break
            fi
        else
            if (( hour_int >= start || hour_int < end )); then
                session_label="${SESSION_NAMES[$i]}"
                expected_dir="${WALLPAPER_DIRS[$i]}"
                found=1
                break
            fi
        fi
    done
    if (( found )); then
        echo "  Period: $session_label ($expected_dir)"
    else
        echo "  Period: Unknown"
    fi
    echo "  Current wallpaper: $current_wallpaper"
    if [[ -n "$expected_dir" ]] && is_wallpaper_from_directory "$current_wallpaper" "$expected_dir"; then
        echo "  Status: ✓ Wallpaper matches current time period"
    else
        echo "  Status: ✗ Wallpaper does not match current time period"
        [[ -n "$expected_dir" ]] && echo "  Expected from: $expected_dir"
    fi
}

# Function to list all wallpapers
list_wallpapers() {
    echo "Available wallpapers:"
    echo ""
    for i in "${!WALLPAPER_DIRS[@]}"; do
        local dir_path="${WALLPAPER_DIRS[$i]}"
        local session="${SESSION_NAMES[$i]}"
        echo "[$session] $dir_path:"
        if [[ -d "$dir_path" ]]; then
            local count=$(count_images_in_directory "$dir_path")
            if [[ $count -gt 0 ]]; then
                # Build array of find arguments for listing
                local find_args=()
                for ext in "${IMAGE_EXTENSIONS[@]}"; do
                    if [[ ${#find_args[@]} -gt 0 ]]; then
                        find_args+=(-o)
                    fi
                    find_args+=(-iname "*.${ext}")
                done
                find "$dir_path" -type f \( "${find_args[@]}" \) 2>/dev/null | while read -r file; do
                    echo "  - $(basename "$file")"
                done
            else
                echo "  (no image files found)"
            fi
        else
            echo "  (directory not found)"
        fi
        echo ""
    done
}

# Main script logic
main() {
    case "${1:-}" in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--check)
            check_setup
            exit $?
            ;;
        -s|--status)
            show_status
            exit 0
            ;;
        -l|--list)
            list_wallpapers
            exit 0
            ;;
        -f|--force)
            log_message "Force mode: Setting wallpaper regardless of current setting"
            # Temporarily override the directory check function
            is_wallpaper_from_directory() { return 1; }
            set_wallpaper_by_time
            exit $?
            ;;
        "")
            # Normal execution
            parse_config
            set_wallpaper_by_time
            exit $?
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use -h or --help for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"
