/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include <functional>

#include "Types.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>

/**
 * @brief callback type for audio setting change notifications
 */
using AudioSettingsCallback = std::function<void(const AudioSettings &)>;

/**
 * @brief manages audio settings and playback for video wallpapers
 */
class AudioController {
public:
    /**
     * @brief construct audio controller with default settings
     */
    AudioController();

    /**
     * @brief destroy audio controller and cleanup resources
     */
    ~AudioController();

    /* non-copyable */
    AudioController(const AudioController &) = delete;

    AudioController &operator=(const AudioController &) = delete;

    /**
     * @brief configure audio for a video player
     * @param player the avplayer to configure audio for
     */
    void configure_for_video(AVPlayer *player);

    /**
     * @brief set audio volume
     * @param volume volume level from 0.0 to 1.0
     */
    void set_volume(float volume);

    /**
     * @brief get current audio volume
     * @return current volume level from 0.0 to 1.0
     */
    float get_volume() const;

    /**
     * @brief toggle mute state
     */
    void toggle_mute();

    /**
     * @brief set mute state
     * @param muted true to mute, false to unmute
     */
    void set_muted(bool muted);

    /**
     * @brief get current mute state
     * @return true if muted, false otherwise
     */
    bool is_muted() const;

    /**
     * @brief get current audio settings
     * @return copy of current audio settings
     */
    AudioSettings get_settings() const;

    /**
     * @brief apply audio settings
     * @param settings the settings to apply
     */
    void apply_settings(const AudioSettings &settings);

    /**
     * @brief register callback for audio settings changes
     * @param callback function to call when settings change
     */
    void set_audio_settings_callback(AudioSettingsCallback callback);

    /**
     * @brief cleanup audio resources
     */
    void cleanup();

private:
    /**
     * @brief apply current settings to the configured player
     */
    void apply_current_settings();

    /**
     * @brief persist settings to user defaults
     */
    void persist_settings();

    /**
     * @brief load settings from user defaults
     */
    void load_persisted_settings();

    /**
     * @brief notify callback of settings change
     */
    void notify_settings_changed();

    AudioSettings current_settings_;
    float volume_before_mute_;
    AudioSettingsCallback settings_callback_;
    AVPlayer *audio_player_;    /* weak reference, not owned */
};
