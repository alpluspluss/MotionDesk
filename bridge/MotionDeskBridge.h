/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include "../src/AudioController.h"
#include "../src/PowerMonitor.h"
#include "../src/Types.h"
#include "../src/WallpaperEngine.h"

#import <Foundation/Foundation.h>

/**
 * @brief c-compatible function pointers for swift callbacks
 */
typedef void (*PowerStateChangedCallback)(int power_state, void* user_data);
typedef void (*WallpaperStateChangedCallback)(int wallpaper_type, bool is_playing, void* user_data);
typedef void (*AudioSettingsChangedCallback)(float volume, bool is_muted, void* user_data);

/**
 * @brief opaque handle for motiondesk bridge instance
 */
typedef struct MotionDeskBridge* MotionDeskBridgeRef;

/* c api for swift interop */
extern "C"
{
/**
 * @brief create motiondesk bridge instance
 * @return bridge handle or null on failure
 */
MotionDeskBridgeRef motion_desk_bridge_create(void);

/**
 * @brief destroy motiondesk bridge instance
 * @param bridge bridge handle to destroy
 */
void motion_desk_bridge_destroy(MotionDeskBridgeRef bridge);

/**
 * @brief set power state change callback
 * @param bridge bridge handle
 * @param callback function to call on power state changes
 * @param user_data pointer passed to callback
 */
void motion_desk_bridge_set_power_callback(MotionDeskBridgeRef bridge, PowerStateChangedCallback callback, void* user_data);

/**
 * @brief set wallpaper state change callback
 * @param bridge bridge handle
 * @param callback function to call on wallpaper state changes
 * @param user_data pointer passed to callback
 */
void motion_desk_bridge_set_wallpaper_callback(MotionDeskBridgeRef bridge, WallpaperStateChangedCallback callback, void* user_data);

/**
 * @brief set audio settings change callback
 * @param bridge bridge handle
 * @param callback function to call on audio settings changes
 * @param user_data pointer passed to callback
 */
void motion_desk_bridge_set_audio_callback(MotionDeskBridgeRef bridge, AudioSettingsChangedCallback callback, void* user_data);

/**
 * @brief get current power state
 * @param bridge bridge handle
 * @return power state as integer
 */
int motion_desk_bridge_get_power_state(MotionDeskBridgeRef bridge);

/**
 * @brief get current wallpaper type
 * @param bridge bridge handle
 * @return wallpaper type as integer
 */
int motion_desk_bridge_get_wallpaper_type(MotionDeskBridgeRef bridge);

/**
 * @brief get current wallpaper file path
 * @param bridge bridge handle
 * @return file path string (caller must free)
 */
char* motion_desk_bridge_get_wallpaper_path(MotionDeskBridgeRef bridge);

/**
 * @brief check if video is currently playing
 * @param bridge bridge handle
 * @return true if video wallpaper is playing
 */
bool motion_desk_bridge_is_video_playing(MotionDeskBridgeRef bridge);

/**
 * @brief set static image wallpaper
 * @param bridge bridge handle
 * @param file_path path to image file
 * @return error code
 */
int motion_desk_bridge_set_static_wallpaper(MotionDeskBridgeRef bridge, const char* file_path);

/**
 * @brief set dynamic heic wallpaper
 * @param bridge bridge handle
 * @param file_path path to heic file
 * @return error code
 */
int motion_desk_bridge_set_dynamic_wallpaper(MotionDeskBridgeRef bridge, const char* file_path);

/**
 * @brief set video wallpaper
 * @param bridge bridge handle
 * @param file_path path to video file
 * @return error code
 */
int motion_desk_bridge_set_video_wallpaper(MotionDeskBridgeRef bridge, const char* file_path);

/**
 * @brief clear current wallpaper
 * @param bridge bridge handle
 */
void motion_desk_bridge_clear_wallpaper(MotionDeskBridgeRef bridge);

/**
 * @brief toggle video playback
 * @param bridge bridge handle
 */
void motion_desk_bridge_toggle_video_playback(MotionDeskBridgeRef bridge);

/**
 * @brief get current audio volume
 * @param bridge bridge handle
 * @return volume level 0.0 to 1.0
 */
float motion_desk_bridge_get_audio_volume(MotionDeskBridgeRef bridge);

/**
 * @brief set audio volume
 * @param bridge bridge handle
 * @param volume volume level 0.0 to 1.0
 */
void motion_desk_bridge_set_audio_volume(MotionDeskBridgeRef bridge, float volume);

/**
 * @brief get audio mute state
 * @param bridge bridge handle
 * @return true if muted
 */
bool motion_desk_bridge_is_audio_muted(MotionDeskBridgeRef bridge);

/**
 * @brief toggle audio mute
 * @param bridge bridge handle
 */
void motion_desk_bridge_toggle_audio_mute(MotionDeskBridgeRef bridge);

/**
 * @brief get current resource usage
 * @param bridge bridge handle
 * @param memory_mb pointer to store memory usage in MB
 * @param cpu_percent pointer to store CPU usage percentage
 */
void motion_desk_bridge_get_resource_stats(MotionDeskBridgeRef bridge, float* memory_mb, float* cpu_percent);

/**
 * @brief get daemon settings
 * @param bridge bridge handle
 * @param settings pointer to settings struct to fill
 */
void motion_desk_bridge_get_settings(MotionDeskBridgeRef bridge, DaemonSettings* settings);

/**
 * @brief set daemon setting
 * @param bridge bridge handle
 * @param setting_name name of setting to change
 * @param value new boolean value
 */
void motion_desk_bridge_set_setting(MotionDeskBridgeRef bridge, const char* setting_name, bool value);
}
