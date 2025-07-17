#!/bin/bash

# AutoWallpaper Script
# Automatically sets wallpaper based on the time of day

# Configuration - Edit these paths to match your wallpaper directories
WALLPAPER_BASE_DIR="$HOME/Pictures"
SUNRISE_DIR="$WALLPAPER_BASE_DIR/0_sunrise"
NOON_DIR="$WALLPAPER_BASE_DIR/1_noon"
SUNSET_DIR="$WALLPAPER_BASE_DIR/2_sunset"
NIGHT_DIR="$WALLPAPER_BASE_DIR/3_night"

# Supported image extensions
IMAGE_EXTENSIONS=("jpg" "jpeg" "png" "bmp" "gif" "tiff" "webp")

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

    # Get the current theme
    current_theme=$(gsettings get org.gnome.desktop.interface color-scheme | tr -d "'")
    log_message "Current theme: $current_theme"

    # Change the theme to light or dark based on the time of day
    # and also change the Do Not Disturb (DND) status based on the time of day
    if [[ ( $time_period == "Sunrise" || $time_period == "Noon" ) && $current_theme == "prefer-dark" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'default'
        log_message "Theme changed to light"
        gsettings set org.gnome.desktop.notifications show-banners true
        log_message "DND disabled"
    elif [[ ( $time_period == "Sunset" || $time_period == "Night" ) && $current_theme == "default" ]]; then
        gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 
        log_message "Theme changed to dark"
        gsettings set org.gnome.desktop.notifications show-banners false
        log_message "DND enabled"
    fi
}

# Function to determine time period and set appropriate wallpaper
set_wallpaper_by_time() {
    local hour=$(date +%H)
    local hour_int=$((10#$hour))  # Convert to base 10 to handle leading zeros
    
    log_message "Current hour: $hour_int"
    
    # Determine time period and set wallpaper
    if [[ $hour_int -ge 5 && $hour_int -lt 9 ]]; then
        # Sunrise: 5-9
        set_wallpaper "$SUNRISE_DIR" "Sunrise"
    elif [[ $hour_int -ge 9 && $hour_int -lt 16 ]]; then
        # Noon: 9-16
        set_wallpaper "$NOON_DIR" "Noon"
    elif [[ $hour_int -ge 16 && $hour_int -lt 19 ]]; then
        # Sunset: 16-19
        set_wallpaper "$SUNSET_DIR" "Sunset"
    else
        # Night: 19-5 (19-23 and 0-4)
        set_wallpaper "$NIGHT_DIR" "Night"
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
    
    # Check if base wallpaper directory exists
    if [[ ! -d "$WALLPAPER_BASE_DIR" ]]; then
        log_message "ERROR: Base wallpaper directory not found: $WALLPAPER_BASE_DIR"
        return 1
    fi
    
    # Check each time period directory
    local directories=("$SUNRISE_DIR:Sunrise" "$NOON_DIR:Noon" "$SUNSET_DIR:Sunset" "$NIGHT_DIR:Night")
    local missing_dirs=()
    local empty_dirs=()
    
    for dir_info in "${directories[@]}"; do
        local dir_path="${dir_info%:*}"
        local dir_name="${dir_info#*:}"
        
        if [[ ! -d "$dir_path" ]]; then
            missing_dirs+=("$dir_name ($dir_path)")
        else
            local image_count=$(count_images_in_directory "$dir_path")
            if [[ $image_count -eq 0 ]]; then
                empty_dirs+=("$dir_name ($dir_path)")
            else
                log_message "✓ $dir_name directory: $image_count image(s) found"
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
    echo "Time Periods:"
    echo "  Sunrise: 05:00 - 08:59"
    echo "  Noon:    09:00 - 15:59"
    echo "  Sunset:  16:00 - 18:59"
    echo "  Night:   19:00 - 04:59"
    echo ""
    echo "Configuration:"
    echo "  Base directory: $WALLPAPER_BASE_DIR"
    echo "  Directories needed:"
    echo "    - $SUNRISE_DIR/"
    echo "    - $NOON_DIR/"
    echo "    - $SUNSET_DIR/"
    echo "    - $NIGHT_DIR/"
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
    
    # Determine current time period
    local expected_dir=""
    if [[ $hour_int -ge 5 && $hour_int -lt 9 ]]; then
        echo "  Period: Sunrise (05:00 - 08:59)"
        expected_dir="$SUNRISE_DIR"
    elif [[ $hour_int -ge 9 && $hour_int -lt 16 ]]; then
        echo "  Period: Noon (09:00 - 15:59)"
        expected_dir="$NOON_DIR"
    elif [[ $hour_int -ge 16 && $hour_int -lt 19 ]]; then
        echo "  Period: Sunset (16:00 - 18:59)"
        expected_dir="$SUNSET_DIR"
    else
        echo "  Period: Night (19:00 - 04:59)"
        expected_dir="$NIGHT_DIR"
    fi
    
    echo "  Current wallpaper: $current_wallpaper"
    
    # Check if current wallpaper matches expected time period
    if is_wallpaper_from_directory "$current_wallpaper" "$expected_dir"; then
        echo "  Status: ✓ Wallpaper matches current time period"
    else
        echo "  Status: ✗ Wallpaper does not match current time period"
        echo "  Expected from: $expected_dir"
    fi
}

# Function to list all wallpapers
list_wallpapers() {
    echo "Available wallpapers:"
    echo ""
    
    local directories=("$SUNRISE_DIR:Sunrise" "$NOON_DIR:Noon" "$SUNSET_DIR:Sunset" "$NIGHT_DIR:Night")
    
    for dir_info in "${directories[@]}"; do
        local dir_path="${dir_info%:*}"
        local dir_name="${dir_info#*:}"
        
        echo "[$dir_name] $dir_path:"
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
