/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include <string>
#include <memory>

#import <Foundation/Foundation.h>

/**
 * @brief power source state enumeration
 */
enum class PowerState : int {
    BATTERY = 0,
    PLUGGED_IN = 1,
    UNKNOWN = 2
};

/**
 * @brief wallpaper type enumeration
 */
enum class WallpaperType : int {
    NONE = 0,
    STATIC_IMAGE = 1,
    DYNAMIC = 2,
    VIDEO = 3
};

/**
 * @brief error codes for wallpaper operations
 */
enum class WallpaperError : int {
    NONE = 0,
    FILE_NOT_FOUND = 1,
    INVALID_FORMAT = 2,
    UNPLAYABLE_VIDEO = 3,
    SYSTEM_PERMISSION_DENIED = 4,
    UNKNOWN = 5
};

/**
 * @brief audio settings structure
 */
struct AudioSettings {
    float volume = 0.5f;            /* 0.0 to 1.0 */
    bool is_muted = false;
    bool mix_with_other_audio = true;
};

/**
 * @brief wallpaper configuration structure
 */
struct WallpaperConfig {
    WallpaperType type = WallpaperType::NONE;
    std::string file_path;
};

/**
 * @brief daemon settings structure
 */
struct DaemonSettings {
    bool allow_video_on_battery = false;
    bool start_at_login = true;
    bool show_notifications = false;
};

/* c helper functions for type conversions and swift bridge compatibility */
extern "C"
{
const char *power_state_to_string(PowerState state);
const char *wallpaper_type_to_string(WallpaperType type);
const char *wallpaper_error_to_string(WallpaperError error);

/* c-compatible enum values for swift bridging */
typedef int PowerStateC;
typedef int WallpaperTypeC;
typedef int WallpaperErrorC;
}
