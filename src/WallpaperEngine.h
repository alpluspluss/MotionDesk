/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include <functional>
#include <memory>
#include <vector>

#include "AudioController.h"
#include "PowerMonitor.h"
#include "Types.h"

#import <AppKit/AppKit.h>
#import <AVFoundation/AVFoundation.h>
#import <ImageIO/ImageIO.h>

/**
 * @brief callback type for wallpaper state change notifications
 */
using WallpaperStateCallback = std::function<void(WallpaperType, bool)>;

/**
 * @brief callback type for settings retrieval
 * used to get current daemon settings when needed
 */
using SettingsCallback = std::function<DaemonSettings()>;

/**
 * @brief core wallpaper management and rendering engine
 */
class WallpaperEngine {
public:
    /**
     * @brief construct wallpaper engine with required dependencies
     * @param power_monitor power state monitor instance
     * @param audio_controller audio control instance
     */
    WallpaperEngine(PowerMonitor &power_monitor, AudioController &audio_controller);

    /**
     * @brief destroy wallpaper engine and cleanup resources
     */
    ~WallpaperEngine();

    /* non-copyable */
    WallpaperEngine(const WallpaperEngine &) = delete;

    WallpaperEngine &operator=(const WallpaperEngine &) = delete;

    /**
     * @brief set static image wallpaper
     * @param file_path path to image file
     * @return error code or NONE on success
     */
    WallpaperError set_static_wallpaper(const std::string &file_path);

    /**
     * @brief set dynamic heic wallpaper
     * @param file_path path to heic file
     * @return error code or NONE on success
     */
    WallpaperError set_dynamic_wallpaper(const std::string &file_path);

    /**
     * @brief set video wallpaper
     * @param file_path path to video file
     * @return error code or NONE on success
     */
    WallpaperError set_video_wallpaper(const std::string &file_path);

    /**
     * @brief clear current wallpaper
     */
    void clear_wallpaper();

    /**
     * @brief get current wallpaper configuration
     * @return current wallpaper config
     */
    [[nodiscard]] WallpaperConfig get_current_wallpaper() const;

    /**
     * @brief toggle video playback (if current wallpaper is video)
     */
    void toggle_video_playback();

    /**
     * @brief pause video playback
     */
    void pause_video();

    /**
     * @brief resume video playback
     */
    void resume_video();

    /**
     * @brief check if video is currently playing
     * @return true if video wallpaper is playing
     */
    bool is_video_playing() const;

    /**
     * @brief register callback for wallpaper state changes
     * @param callback function to call when wallpaper state changes
     */
    void set_wallpaper_state_callback(WallpaperStateCallback callback);

    /**
     * @brief cleanup wallpaper engine resources
     */
    void cleanup();

    /**
     * @brief For setting callback to get the Daemon setting
     */
    void set_settings_callback(SettingsCallback callback);

private:
    /**
     * @brief cleanup current wallpaper before setting new one
     */
    void cleanup_current_wallpaper();

    /**
     * @brief create static image wallpaper windows
     * @param image_url nsurl for image file
     * @return error code or NONE on success
     */
    WallpaperError create_static_wallpaper_windows(NSURL *image_url);

    /**
     * @brief create dynamic wallpaper windows from heic
     * @param heic_url nsurl for heic file
     * @return error code or NONE on success
     */
    WallpaperError create_dynamic_wallpaper_windows(NSURL *heic_url);

    /**
     * @brief create video wallpaper windows
     * @param video_url nsurl for video file
     * @return error code or NONE on success
     */
    WallpaperError create_video_wallpaper_windows(NSURL *video_url);

    /**
     * @brief create desktop window for specific screen
     * @param screen target screen
     * @return configured desktop window
     */
    NSWindow *create_desktop_window_for_screen(NSScreen *screen);

    /**
     * @brief setup video looping for current player
     */
    void setup_video_looping();

    /**
     * @brief cleanup video looping observer
     */
    void cleanup_video_observer();

    /**
     * @brief handle power state changes
     * @param new_state the new power state
     */
    void handle_power_state_change(PowerState new_state);

    /**
     * @brief determine if video should be playing based on power state
     * @return true if video should play
     */
    bool should_video_play() const;

    /**
     * @brief persist current wallpaper configuration
     */
    void persist_wallpaper_config();

    /**
     * @brief load persisted wallpaper configuration
     */
    void load_persisted_wallpaper_config();

    /**
     * @brief notify callback of wallpaper state change
     */
    void notify_wallpaper_state_changed();

    /**
     * @brief Send windows notification for wallpaper change
     */
    void send_wallpaper_notification();

    PowerMonitor &power_monitor_;
    AudioController &audio_controller_;
    WallpaperConfig current_config_;
    WallpaperStateCallback state_callback_;
    SettingsCallback  get_settings_;

    std::vector<NSWindow *> wallpaper_windows_;
    std::vector<AVPlayerLayer *> player_layers_;
    AVPlayer *video_player_;                /* strong reference */
    id video_end_observer_;                    /* nsobjectprotocol token */
    bool is_video_paused_;
    bool pause_video_on_battery_;
};
