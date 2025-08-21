/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "Types.h"

const char *power_state_to_string(PowerState state) {
    switch (state) {
        case PowerState::BATTERY:
            return "Battery";
        case PowerState::PLUGGED_IN:
            return "AC Power";
        case PowerState::UNKNOWN:
            return "Unknown";
    }
    return "Unknown";
}

const char *wallpaper_type_to_string(WallpaperType type) {
    switch (type) {
        case WallpaperType::NONE:
            return "None";
        case WallpaperType::STATIC_IMAGE:
            return "Static Image";
        case WallpaperType::DYNAMIC:
            return "Dynamic Wallpaper";
        case WallpaperType::VIDEO:
            return "Video Wallpaper";
    }
    return "Unknown";
}

const char *wallpaper_error_to_string(WallpaperError error) {
    switch (error) {
        case WallpaperError::NONE:
            return "No error";
        case WallpaperError::FILE_NOT_FOUND:
            return "File not found";
        case WallpaperError::INVALID_FORMAT:
            return "Invalid file format";
        case WallpaperError::UNPLAYABLE_VIDEO:
            return "Cannot play video file";
        case WallpaperError::SYSTEM_PERMISSION_DENIED:
            return "System permission denied";
        case WallpaperError::UNKNOWN:
            return "Unknown error";
    }
    return "Unknown error";
}
