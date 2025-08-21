/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "MotionDeskBridge.h"
#include <memory>
#include <chrono>
#import <ServiceManagement/ServiceManagement.h>

struct ResourceMonitor {
    double smoothed_cpu = 0.0;
    std::chrono::steady_clock::time_point last_time;
    struct rusage last_usage = {};
    bool initialized = false;

    void update_cpu(double measured, double dt, double tau = 5.0) {
        double alpha = 1.0 - exp(-dt / tau);
        smoothed_cpu = alpha * measured + (1.0 - alpha) * smoothed_cpu;
    }

    float get_cpu_percent() {
        auto now = std::chrono::steady_clock::now();
        struct rusage current_usage = {};
        getrusage(RUSAGE_SELF, &current_usage);

        if (!initialized) {
            last_time = now;
            last_usage = current_usage;
            initialized = true;
            return 0.0f;
        }

        auto dt = std::chrono::duration<double>(now - last_time).count();
        auto cpu_time = (current_usage.ru_utime.tv_sec - last_usage.ru_utime.tv_sec) +
                        (current_usage.ru_utime.tv_usec - last_usage.ru_utime.tv_usec) / 1e6;

        double measured = dt > 0 ? (cpu_time / dt) * 100.0 : 0.0;
        update_cpu(measured, dt);

        last_time = now;
        last_usage = current_usage;

        return smoothed_cpu;
    }

    float get_memory_mb()
    {
        struct task_basic_info info = {};
        mach_msg_type_number_t size = TASK_BASIC_INFO_COUNT;
        kern_return_t kr = task_info(mach_task_self(), TASK_BASIC_INFO, (task_info_t)&info, &size);
        return kr == KERN_SUCCESS ? info.resident_size / (1024.0f * 1024.0f) : 0.0f;
    }
};

/**
 * @brief internal bridge implementation
 */
struct MotionDeskBridge
{
    std::unique_ptr<PowerMonitor> power_monitor;
    std::unique_ptr<AudioController> audio_controller;
    std::unique_ptr<WallpaperEngine> wallpaper_engine;
    ResourceMonitor resource_monitor;
    DaemonSettings settings;

    PowerStateChangedCallback power_callback;
    void* power_user_data;

    WallpaperStateChangedCallback wallpaper_callback;
    void* wallpaper_user_data;

    AudioSettingsChangedCallback audio_callback;
    void* audio_user_data;

    MotionDeskBridge()
            : power_callback(nullptr)
            , power_user_data(nullptr)
            , wallpaper_callback(nullptr)
            , wallpaper_user_data(nullptr)
            , audio_callback(nullptr)
            , audio_user_data(nullptr)
    {
        load_settings();
    }

    void load_settings() {
        auto* defaults = [NSUserDefaults standardUserDefaults];
        settings.allow_video_on_battery = [defaults boolForKey:@"MotionDesk_AllowVideoOnBattery"];
        settings.start_at_login = [defaults objectForKey:@"MotionDesk_StartAtLogin"] == nil ||
                                  [defaults boolForKey:@"MotionDesk_StartAtLogin"];
        settings.show_notifications = [defaults boolForKey:@"MotionDesk_ShowNotifications"];
    }

    void save_settings() {
        auto* defaults = [NSUserDefaults standardUserDefaults];
        [defaults setBool:settings.allow_video_on_battery forKey:@"MotionDesk_AllowVideoOnBattery"];
        [defaults setBool:settings.start_at_login forKey:@"MotionDesk_StartAtLogin"];
        [defaults setBool:settings.show_notifications forKey:@"MotionDesk_ShowNotifications"];
        [defaults synchronize];
    }
};

MotionDeskBridgeRef motion_desk_bridge_create(void)
{
    try
    {
        auto* bridge = new MotionDeskBridge();

        /* create components in dependency order */
        bridge->power_monitor = std::make_unique<PowerMonitor>();
        bridge->audio_controller = std::make_unique<AudioController>();
        bridge->wallpaper_engine = std::make_unique<WallpaperEngine>(
                *bridge->power_monitor,
                *bridge->audio_controller
        );

        bridge->wallpaper_engine->set_settings_callback([bridge]() {
            return bridge->settings;
        });

        /* setup internal callbacks */
        bridge->power_monitor->set_power_state_callback([bridge](PowerState state) {
            if (bridge->power_callback != nullptr)
            {
                bridge->power_callback(static_cast<int>(state), bridge->power_user_data);
            }
        });

        bridge->wallpaper_engine->set_wallpaper_state_callback([bridge](WallpaperType type, bool is_playing) {
            if (bridge->wallpaper_callback != nullptr)
            {
                bridge->wallpaper_callback(static_cast<int>(type), is_playing, bridge->wallpaper_user_data);
            }
        });

        bridge->audio_controller->set_audio_settings_callback([bridge](const AudioSettings& settings) {
            if (bridge->audio_callback != nullptr)
            {
                bridge->audio_callback(settings.volume, settings.is_muted, bridge->audio_user_data);
            }
        });

        return bridge;
    }
    catch (...)
    {
        return nullptr;
    }
}

void motion_desk_bridge_destroy(MotionDeskBridgeRef bridge)
{
    delete bridge;
}

void motion_desk_bridge_set_power_callback(MotionDeskBridgeRef bridge, PowerStateChangedCallback callback, void* user_data)
{
    if (bridge != nullptr)
    {
        bridge->power_callback = callback;
        bridge->power_user_data = user_data;
    }
}

void motion_desk_bridge_set_wallpaper_callback(MotionDeskBridgeRef bridge, WallpaperStateChangedCallback callback, void* user_data)
{
    if (bridge != nullptr)
    {
        bridge->wallpaper_callback = callback;
        bridge->wallpaper_user_data = user_data;
    }
}

void motion_desk_bridge_set_audio_callback(MotionDeskBridgeRef bridge, AudioSettingsChangedCallback callback, void* user_data)
{
    if (bridge != nullptr)
    {
        bridge->audio_callback = callback;
        bridge->audio_user_data = user_data;
    }
}

int motion_desk_bridge_get_power_state(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->power_monitor != nullptr)
    {
        return static_cast<int>(bridge->power_monitor->get_current_state());
    }
    return static_cast<int>(PowerState::UNKNOWN);
}

int motion_desk_bridge_get_wallpaper_type(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr)
    {
        auto config = bridge->wallpaper_engine->get_current_wallpaper();
        return static_cast<int>(config.type);
    }
    return static_cast<int>(WallpaperType::NONE);
}

char* motion_desk_bridge_get_wallpaper_path(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr)
    {
        auto config = bridge->wallpaper_engine->get_current_wallpaper();
        if (!config.file_path.empty())
        {
            auto* result = static_cast<char*>(std::malloc(config.file_path.length() + 1));
            if (result != nullptr)
            {
                strcpy(result, config.file_path.c_str());
                return result;
            }
        }
    }
    return nullptr;
}

bool motion_desk_bridge_is_video_playing(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr)
    {
        return bridge->wallpaper_engine->is_video_playing();
    }
    return false;
}

int motion_desk_bridge_set_static_wallpaper(MotionDeskBridgeRef bridge, const char* file_path)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr && file_path != nullptr)
    {
        auto error = bridge->wallpaper_engine->set_static_wallpaper(std::string(file_path));
        return static_cast<int>(error);
    }
    return static_cast<int>(WallpaperError::UNKNOWN);
}

int motion_desk_bridge_set_dynamic_wallpaper(MotionDeskBridgeRef bridge, const char* file_path)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr && file_path != nullptr)
    {
        auto error = bridge->wallpaper_engine->set_dynamic_wallpaper(std::string(file_path));
        return static_cast<int>(error);
    }
    return static_cast<int>(WallpaperError::UNKNOWN);
}

int motion_desk_bridge_set_video_wallpaper(MotionDeskBridgeRef bridge, const char* file_path)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr && file_path != nullptr)
    {
        auto error = bridge->wallpaper_engine->set_video_wallpaper(std::string(file_path));
        return static_cast<int>(error);
    }
    return static_cast<int>(WallpaperError::UNKNOWN);
}

void motion_desk_bridge_clear_wallpaper(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr)
    {
        bridge->wallpaper_engine->clear_wallpaper();
    }
}

void motion_desk_bridge_toggle_video_playback(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->wallpaper_engine != nullptr)
    {
        bridge->wallpaper_engine->toggle_video_playback();
    }
}

float motion_desk_bridge_get_audio_volume(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->audio_controller != nullptr)
    {
        return bridge->audio_controller->get_volume();
    }
    return 0.5f;
}

void motion_desk_bridge_set_audio_volume(MotionDeskBridgeRef bridge, float volume)
{
    if (bridge != nullptr && bridge->audio_controller != nullptr)
    {
        bridge->audio_controller->set_volume(volume);
    }
}

bool motion_desk_bridge_is_audio_muted(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->audio_controller != nullptr)
    {
        return bridge->audio_controller->is_muted();
    }
    return false;
}

void motion_desk_bridge_toggle_audio_mute(MotionDeskBridgeRef bridge)
{
    if (bridge != nullptr && bridge->audio_controller != nullptr)
    {
        bridge->audio_controller->toggle_mute();
    }
}

void motion_desk_bridge_get_resource_stats(MotionDeskBridgeRef bridge, float* memory_mb, float* cpu_percent)
{
    if (bridge != nullptr && memory_mb != nullptr && cpu_percent != nullptr)
    {
        *memory_mb = bridge->resource_monitor.get_memory_mb();
        *cpu_percent = bridge->resource_monitor.get_cpu_percent();
    }
}

void motion_desk_bridge_get_settings(MotionDeskBridgeRef bridge, DaemonSettings* settings) {
    if (bridge != nullptr && settings != nullptr) {
        *settings = bridge->settings;
    }
}

void motion_desk_bridge_set_setting(MotionDeskBridgeRef bridge, const char* setting_name, bool value) {
    if (bridge == nullptr || setting_name == nullptr) return;

    if (strcmp(setting_name, "allow_video_on_battery") == 0) {
        bridge->settings.allow_video_on_battery = value;
        if (bridge->wallpaper_engine != nullptr) {
            auto current_power = bridge->power_monitor->get_current_state();
            if (current_power == PowerState::BATTERY) {
                if (!value && bridge->wallpaper_engine->is_video_playing()) {
                    bridge->wallpaper_engine->pause_video();
                } else if (value && !bridge->wallpaper_engine->is_video_playing()) {
                    bridge->wallpaper_engine->resume_video();
                }
            }
        }
    } else if (strcmp(setting_name, "start_at_login") == 0) {
        bridge->settings.start_at_login = value;

        NSString* bundleID = [[NSBundle mainBundle] bundleIdentifier];
        SMAppService* service = [SMAppService loginItemServiceWithIdentifier:bundleID];

        if (value) {
            NSError* error = nil;
            BOOL success = [service registerAndReturnError:&error];
            if (!success) {
                NSLog(@"Failed to register login item: %@", error.localizedDescription);
            }
        } else {
            NSError* error = nil;
            BOOL success = [service unregisterAndReturnError:&error];
            if (!success) {
                NSLog(@"Failed to unregister login item: %@", error.localizedDescription);
            }
        }
    } else if (strcmp(setting_name, "show_notifications") == 0) {
        bridge->settings.show_notifications = value;
    }

    bridge->save_settings();
}
