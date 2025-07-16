# AutoWallpaper

Automatically change your desktop wallpaper based on the time of day using Bash and GNOME's `gsettings`.

## Features
- **Time-based wallpaper switching**: Different wallpapers for Sunrise, Noon, Sunset, and Night.
- **Random selection**: Picks a random image from the appropriate directory for each time period.
- **Smart detection**: Only changes wallpaper if the current one is not from the correct time period.
- **Supports multiple image formats**: jpg, jpeg, png, bmp, gif, tiff, webp.
- **Status and setup checks**: Easily check your configuration and current wallpaper status.

## Time Periods
- **Sunrise**: 05:00 - 08:59
- **Noon**:    09:00 - 15:59
- **Sunset**:  16:00 - 18:59
- **Night**:   19:00 - 04:59

## Setup
1. **Place your wallpapers in the following directories:**
   - `~/Pictures/0_sunrise/`  (for sunrise wallpapers)
   - `~/Pictures/1_noon/`     (for noon wallpapers)
   - `~/Pictures/2_sunset/`   (for sunset wallpapers)
   - `~/Pictures/3_night/`    (for night wallpapers)

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
- The script checks the current hour and determines the time period.
- It selects a random wallpaper from the corresponding directory.
- If the current wallpaper is already from the correct directory, it does nothing (unless `--force` is used).
- You can check status, list wallpapers, or verify your setup with the provided options.

## Troubleshooting
- Make sure your wallpaper directories exist and contain at least one supported image file.
- The script only works with GNOME (uses `gsettings`).
- If you see errors about missing files or directories, run `./auto.sh -c` to diagnose.

## License
MIT 