# AutoWallpaper

Automatically change your desktop wallpaper based on the time of day using Bash and GNOME's `gsettings`.

## Features
- **Time-based wallpaper switching**: Different wallpapers for Sunrise, Noon, Sunset, and Night.
- **Random selection**: Picks a random image from the appropriate directory for each time period.
- **Smart detection**: Only changes wallpaper if the current one is not from the correct time period.
- **Supports multiple image formats**: jpg, jpeg, png, bmp, gif, tiff, webp.
- **Status and setup checks**: Easily check your configuration and current wallpaper status.

## Time Periods
See explanation about `auto.conf` below.

## Setup
1. **Create or edit your `auto.conf` configuration file.**

   Each line defines a session (time period) with the following columns:

   ```
   SessionName  StartHour-EndHour  /path/to/wallpapers  Theme  DND_Status
   ```
   - `SessionName`: Label for the time period (e.g., Sunrise, Dhuha, etc.)
   - `StartHour-EndHour`: Hour range in 24h format (e.g., 5-8)
   - `/path/to/wallpapers`: Directory containing wallpapers for this session
   - `Theme`: `light` or `dark` (controls GNOME color scheme)
   - `DND_Status`: `true` or `false` (enables/disables Do Not Disturb)

   Example:
   ```
   Sunrise     5-8     /home/user/Pictures/AutoWallpapers/0_sunrise    light   false
   Maghrib     17-19   /home/user/Pictures/AutoWallpapers/4_maghrib    dark    true
   ```

   > You can use any supported image format. Add as many images as you like to each directory.

2. **Make the script executable:**
   ```bash
   chmod +x auto.sh
   ```

3. **Test your setup:**
   ```bash
   ./auto.sh -c   # Check configuration
   ./auto.sh -l   # List all available wallpapers
   ./auto.sh -s   # Show current status
   ```

4. **Run the script manually:**
   ```bash
   ./auto.sh
   ```

5. **Automate with cron (optional):**
   Run every hour:
   ```bash
   crontab -e
   # Add this line:
   0 * * * * /path/to/auto.sh
   ```

## Usage
```
./auto.sh [OPTIONS]
```

### Options
- `-h`, `--help`     Show help message
- `-c`, `--check`    Check setup and configuration
- `-s`, `--status`   Show current wallpaper and time period
- `-f`, `--force`    Force wallpaper change regardless of current setting
- `-l`, `--list`     List all available wallpapers in each directory

## Requirements
- Bash
- GNOME desktop environment (uses `gsettings`)
- `find` utility (standard on most Linux systems)

## How it works
- The script checks the current hour and determines the session based on your `auto.conf`.
- It selects a random wallpaper from the configured directory for that session.
- It sets the GNOME color scheme (`light` or `dark`) and Do Not Disturb status according to the session's config.
- If the current wallpaper is already from the correct directory, it does nothing (unless `--force` is used).
- You can check status, list wallpapers, or verify your setup with the provided options.

## Configuration Example

```
# Session   Time_Range   Wallpaper_Location     Theme       DND_Status
Sunrise     5-8     /home/user/Pictures/AutoWallpapers/0_sunrise    light   false
Dhuha       8-11    /home/user/Pictures/AutoWallpapers/1_dhuha      light   false
Maghrib     17-19   /home/user/Pictures/AutoWallpapers/4_maghrib    dark    true
```

This allows you to control not only the wallpaper, but also the desktop theme and notification (DND) status for each time period.

## Troubleshooting
- Make sure your wallpaper directories exist and contain at least one supported image file.
- The script only works with GNOME (uses `gsettings`).
- If you see errors about missing files or directories, run `./auto.sh -c` to diagnose.

## License
MIT 