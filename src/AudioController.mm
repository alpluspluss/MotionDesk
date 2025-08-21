/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "AudioController.h"
#include <algorithm>

AudioController::AudioController()
        : volume_before_mute_(0.5f), audio_player_(nullptr) {
    load_persisted_settings();
}

AudioController::~AudioController() {
    cleanup();
}

void AudioController::configure_for_video(AVPlayer *player) {
    audio_player_ = player;
    apply_current_settings();
}

void AudioController::set_volume(float volume) {
    current_settings_.volume = std::clamp(volume, 0.0f, 1.0f);

    if (!current_settings_.is_muted && audio_player_ != nullptr) {
        audio_player_.volume = current_settings_.volume;
    }

    persist_settings();
    notify_settings_changed();
}

float AudioController::get_volume() const {
    return current_settings_.volume;
}

void AudioController::toggle_mute() {
    set_muted(!current_settings_.is_muted);
}

void AudioController::set_muted(bool muted) {
    if (current_settings_.is_muted == muted) {
        return;
    }

    if (muted) {
        volume_before_mute_ = current_settings_.volume;
        current_settings_.is_muted = true;

        if (audio_player_ != nullptr) {
            audio_player_.volume = 0.0f;
        }
    } else {
        current_settings_.is_muted = false;
        current_settings_.volume = volume_before_mute_;

        if (audio_player_ != nullptr) {
            audio_player_.volume = current_settings_.volume;
        }
    }

    persist_settings();
    notify_settings_changed();
}

bool AudioController::is_muted() const {
    return current_settings_.is_muted;
}

AudioSettings AudioController::get_settings() const {
    return current_settings_;
}

void AudioController::apply_settings(const AudioSettings &settings) {
    current_settings_ = settings;
    current_settings_.volume = std::clamp(settings.volume, 0.0f, 1.0f);

    apply_current_settings();
    persist_settings();
    notify_settings_changed();
}

void AudioController::set_audio_settings_callback(AudioSettingsCallback callback) {
    settings_callback_ = std::move(callback);
}

void AudioController::cleanup() {
    audio_player_ = nullptr;
}

void AudioController::apply_current_settings() {
    if (audio_player_ == nullptr) {
        return;
    }

    if (current_settings_.is_muted) {
        audio_player_.volume = 0.0f;
    } else {
        audio_player_.volume = current_settings_.volume;
    }

    /* macOS avplayer automatically handles audio routing */
}

void AudioController::persist_settings() {
    auto *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setFloat:current_settings_.volume forKey:@"MotionDesk_AudioVolume"];
    [defaults setBool:current_settings_.is_muted forKey:@"MotionDesk_AudioMuted"];
    [defaults setBool:current_settings_.mix_with_other_audio forKey:@"MotionDesk_MixWithOtherAudio"];

    [defaults synchronize];
}

void AudioController::load_persisted_settings() {
    auto *defaults = [NSUserDefaults standardUserDefaults];

    /* load with defaults if keys don't exist */
    current_settings_.volume = [defaults objectForKey:@"MotionDesk_AudioVolume"] != nil
                               ? [defaults floatForKey:@"MotionDesk_AudioVolume"]
                               : 0.5f;

    current_settings_.is_muted =
            [defaults objectForKey:@"MotionDesk_AudioMuted"] != nil && [defaults boolForKey:@"MotionDesk_AudioMuted"];

    current_settings_.mix_with_other_audio = [defaults objectForKey:@"MotionDesk_MixWithOtherAudio"] == nil ||
                                             [defaults boolForKey:@"MotionDesk_MixWithOtherAudio"];

    /* clamp volume to valid range */
    current_settings_.volume = std::clamp(current_settings_.volume, 0.0f, 1.0f);
}

void AudioController::notify_settings_changed() {
    if (settings_callback_) {
        /* notify on main queue to avoid threading issues */
        dispatch_async(dispatch_get_main_queue(), ^{
            settings_callback_(current_settings_);
        });
    }
}