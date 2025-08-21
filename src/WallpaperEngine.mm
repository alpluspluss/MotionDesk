/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "WallpaperEngine.h"
#import <UserNotifications/UserNotifications.h>

WallpaperEngine::WallpaperEngine(PowerMonitor &power_monitor, AudioController &audio_controller)
        : power_monitor_(power_monitor), audio_controller_(audio_controller), video_player_(nullptr),
          video_end_observer_(nil), is_video_paused_(false), pause_video_on_battery_(true) {
    /* setup power state monitoring */
    power_monitor_.set_power_state_callback([this](PowerState state) {
        handle_power_state_change(state);
    });

    load_persisted_wallpaper_config();
}

WallpaperEngine::~WallpaperEngine() {
    cleanup();
}

WallpaperError WallpaperEngine::set_static_wallpaper(const std::string &file_path) {
    cleanup_current_wallpaper();

    auto *ns_string = [NSString stringWithUTF8String:file_path.c_str()];
    auto *file_url = [NSURL fileURLWithPath:ns_string];

    auto error = create_static_wallpaper_windows(file_url);
    if (error == WallpaperError::NONE) {
        current_config_.type = WallpaperType::STATIC_IMAGE;
        current_config_.file_path = file_path;
        persist_wallpaper_config();
        notify_wallpaper_state_changed();
    }

    return error;
}

WallpaperError WallpaperEngine::set_dynamic_wallpaper(const std::string &file_path) {
    cleanup_current_wallpaper();

    auto *ns_string = [NSString stringWithUTF8String:file_path.c_str()];
    auto *file_url = [NSURL fileURLWithPath:ns_string];

    auto error = create_dynamic_wallpaper_windows(file_url);
    if (error == WallpaperError::NONE) {
        current_config_.type = WallpaperType::DYNAMIC;
        current_config_.file_path = file_path;
        persist_wallpaper_config();
        notify_wallpaper_state_changed();
    }

    return error;
}

WallpaperError WallpaperEngine::set_video_wallpaper(const std::string &file_path) {
    cleanup_current_wallpaper();

    auto *ns_string = [NSString stringWithUTF8String:file_path.c_str()];
    auto *file_url = [NSURL fileURLWithPath:ns_string];

    auto error = create_video_wallpaper_windows(file_url);
    if (error == WallpaperError::NONE) {
        current_config_.type = WallpaperType::VIDEO;
        current_config_.file_path = file_path;
        persist_wallpaper_config();
        notify_wallpaper_state_changed();
    }

    return error;
}

void WallpaperEngine::clear_wallpaper() {
    cleanup_current_wallpaper();
    current_config_ = WallpaperConfig{};
    persist_wallpaper_config();
    notify_wallpaper_state_changed();
}

WallpaperConfig WallpaperEngine::get_current_wallpaper() const {
    return current_config_;
}

void WallpaperEngine::toggle_video_playback() {
    if (current_config_.type != WallpaperType::VIDEO || video_player_ == nullptr) {
        return;
    }

    if (is_video_paused_) {
        resume_video();
    } else {
        pause_video();
    }
}

void WallpaperEngine::pause_video() {
    if (video_player_ != nullptr) {
        [video_player_ pause];
        is_video_paused_ = true;
        notify_wallpaper_state_changed();
    }
}

void WallpaperEngine::resume_video() {
    if (video_player_ != nullptr && should_video_play()) {
        [video_player_ play];
        is_video_paused_ = false;
        notify_wallpaper_state_changed();
    }
}

bool WallpaperEngine::is_video_playing() const {
    if (current_config_.type != WallpaperType::VIDEO || video_player_ == nullptr) {
        return false;
    }

    return video_player_.rate > 0.0f && !is_video_paused_;
}

void WallpaperEngine::set_wallpaper_state_callback(WallpaperStateCallback callback) {
    state_callback_ = std::move(callback);
}

void WallpaperEngine::cleanup() {
    cleanup_current_wallpaper();
}

void WallpaperEngine::cleanup_current_wallpaper() {
    /* cleanup video observer first */
    cleanup_video_observer();

    /* disconnect and release video player */
    if (video_player_ != nullptr) {
        [video_player_ pause];
        [video_player_ replaceCurrentItemWithPlayerItem:nil];
        video_player_ = nullptr;
    }

    /* disconnect player layers */
    for (auto *layer: player_layers_) {
        layer.player = nil;
        [layer removeFromSuperlayer];
    }
    player_layers_.clear();

    /* close windows */
    for (auto *window: wallpaper_windows_) {
        [window orderOut:nil];
        [window close];
    }
    wallpaper_windows_.clear();

    is_video_paused_ = false;
}

WallpaperError WallpaperEngine::create_static_wallpaper_windows(NSURL *image_url) {
    auto *image = [[NSImage alloc] initWithContentsOfURL:image_url];
    if (image == nil) {
        return WallpaperError::INVALID_FORMAT;
    }

    for (NSScreen *screen in [NSScreen screens]) {
        auto *window = create_desktop_window_for_screen(screen);
        auto *image_view = [[NSImageView alloc] initWithFrame:window.contentView.bounds];

        image_view.image = image;
        image_view.imageScaling = NSImageScaleProportionallyUpOrDown;
        image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        [window.contentView addSubview:image_view];
        wallpaper_windows_.push_back(window);
    }

    return WallpaperError::NONE;
}

WallpaperError WallpaperEngine::create_dynamic_wallpaper_windows(NSURL *heic_url) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:heic_url.path]) {
        return WallpaperError::FILE_NOT_FOUND;
    }

    /* use imageio to parse heic for time-based variants */
    auto image_source = CGImageSourceCreateWithURL(static_cast<CFURLRef>(heic_url), nullptr);
    if (image_source == nullptr) {
        return WallpaperError::INVALID_FORMAT;
    }

    auto count = CGImageSourceGetCount(image_source);
    NSImage *final_image = nil;

    if (count > 1) {
        /* select image based on current time */
        auto *calendar = [NSCalendar currentCalendar];
        auto *date = [NSDate date];
        auto hour = [calendar component:NSCalendarUnitHour fromDate:date];
        auto image_index = std::min(static_cast<size_t>(hour * count / 24), count - 1);

        auto cg_image = CGImageSourceCreateImageAtIndex(image_source, image_index, nullptr);
        if (cg_image != nullptr) {
            final_image = [[NSImage alloc] initWithCGImage:cg_image size:NSZeroSize];
            CGImageRelease(cg_image);
        }
    } else {
        /* single image - treat as static */
        final_image = [[NSImage alloc] initWithContentsOfURL:heic_url];
    }

    CFRelease(image_source);

    if (final_image == nil) {
        return WallpaperError::INVALID_FORMAT;
    }

    for (NSScreen *screen in [NSScreen screens]) {
        auto *window = create_desktop_window_for_screen(screen);
        auto *image_view = [[NSImageView alloc] initWithFrame:window.contentView.bounds];

        image_view.image = final_image;
        image_view.imageScaling = NSImageScaleProportionallyUpOrDown;
        image_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        [window.contentView addSubview:image_view];
        wallpaper_windows_.push_back(window);
    }

    return WallpaperError::NONE;
}

WallpaperError WallpaperEngine::create_video_wallpaper_windows(NSURL *video_url) {
    if (![[NSFileManager defaultManager] fileExistsAtPath:video_url.path]) {
        return WallpaperError::FILE_NOT_FOUND;
    }

    /* create video player */
    auto *asset = [AVURLAsset URLAssetWithURL:video_url options:nil];
    auto *player_item = [AVPlayerItem playerItemWithAsset:asset];
    video_player_ = [AVPlayer playerWithPlayerItem:player_item];

    if (video_player_ == nil) {
        return WallpaperError::UNPLAYABLE_VIDEO;
    }

    /* setup looping and audio */
    setup_video_looping();
    audio_controller_.configure_for_video(video_player_);

    /* create player layers for each screen */
    for (NSScreen *screen in [NSScreen screens]) {
        auto *window = create_desktop_window_for_screen(screen);

        /* create container view for player layer */
        auto *container_view = [[NSView alloc] initWithFrame:window.contentView.bounds];
        container_view.wantsLayer = YES;
        container_view.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

        auto *player_layer = [AVPlayerLayer playerLayerWithPlayer:video_player_];
        player_layer.frame = container_view.bounds;
        player_layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        player_layer.autoresizingMask = kCALayerWidthSizable | kCALayerHeightSizable;

        /* direct layer assignment for cleaner hierarchy */
        container_view.layer = player_layer;
        [window.contentView addSubview:container_view];

        player_layers_.push_back(player_layer);
        wallpaper_windows_.push_back(window);
    }

    /* start playback if appropriate */
    if (should_video_play()) {
        [video_player_ play];
    }

    return WallpaperError::NONE;
}

NSWindow *WallpaperEngine::create_desktop_window_for_screen(NSScreen *screen) {
    auto *window = [[NSWindow alloc]
            initWithContentRect:screen.frame
                      styleMask:NSWindowStyleMaskBorderless
                        backing:NSBackingStoreBuffered
                          defer:NO
                         screen:screen];

    window.level = kCGDesktopWindowLevel;
    window.ignoresMouseEvents = YES;
    window.opaque = YES;
    window.backgroundColor = [NSColor blackColor];
    window.collectionBehavior = NSWindowCollectionBehaviorCanJoinAllSpaces
                                | NSWindowCollectionBehaviorStationary
                                | NSWindowCollectionBehaviorIgnoresCycle;

    [window makeKeyAndOrderFront:nil];
    return window;
}

void WallpaperEngine::setup_video_looping() {
    if (video_player_ == nil || video_player_.currentItem == nil) {
        return;
    }

    /* store observer token for proper cleanup */
    video_end_observer_ = [[NSNotificationCenter defaultCenter]
            addObserverForName:AVPlayerItemDidPlayToEndTimeNotification
                        object:video_player_.currentItem
                         queue:[NSOperationQueue mainQueue]
                    usingBlock:^(NSNotification *notification) {
                        [video_player_ seekToTime:kCMTimeZero];
                        if (should_video_play() && !is_video_paused_) {
                            [video_player_ play];
                        }
                    }];
}

void WallpaperEngine::cleanup_video_observer() {
    if (video_end_observer_ != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:video_end_observer_];
        video_end_observer_ = nil;
    }
}

void WallpaperEngine::handle_power_state_change(PowerState new_state) {
    if (current_config_.type != WallpaperType::VIDEO || video_player_ == nullptr) {
        return;
    }

    if (pause_video_on_battery_ && new_state == PowerState::BATTERY) {
        pause_video();
    } else if (new_state == PowerState::PLUGGED_IN && !is_video_paused_) {
        resume_video();
    }
}

bool WallpaperEngine::should_video_play() const {
    if (get_settings_ && get_settings_().allow_video_on_battery) {
        return true;
    }

    if (pause_video_on_battery_ && power_monitor_.get_current_state() == PowerState::BATTERY) {
        return false;
    }

    return true;
}

void WallpaperEngine::persist_wallpaper_config() {
    auto *defaults = [NSUserDefaults standardUserDefaults];

    [defaults setInteger:static_cast<int>(current_config_.type) forKey:@"MotionDesk_WallpaperType"];

    if (!current_config_.file_path.empty()) {
        auto *path_string = [NSString stringWithUTF8String:current_config_.file_path.c_str()];
        [defaults setObject:path_string forKey:@"MotionDesk_WallpaperPath"];
    } else {
        [defaults removeObjectForKey:@"MotionDesk_WallpaperPath"];
    }

    [defaults setBool:pause_video_on_battery_ forKey:@"MotionDesk_PauseOnBattery"];
    [defaults synchronize];
}

void WallpaperEngine::load_persisted_wallpaper_config() {
    auto *defaults = [NSUserDefaults standardUserDefaults];

    if ([defaults objectForKey:@"MotionDesk_WallpaperType"] != nil) {
        current_config_.type = static_cast<WallpaperType>([defaults integerForKey:@"MotionDesk_WallpaperType"]);

        auto *path_string = [defaults stringForKey:@"MotionDesk_WallpaperPath"];
        if (path_string != nil) {
            current_config_.file_path = [path_string UTF8String];
        }
    }

    pause_video_on_battery_ = [defaults objectForKey:@"MotionDesk_PauseOnBattery"] == nil ||
                              [defaults boolForKey:@"MotionDesk_PauseOnBattery"];

    /* restore wallpaper if valid configuration exists */
    if (current_config_.type != WallpaperType::NONE && !current_config_.file_path.empty()) {
        switch (current_config_.type) {
            case WallpaperType::STATIC_IMAGE:
                set_static_wallpaper(current_config_.file_path);
                break;
            case WallpaperType::DYNAMIC:
                set_dynamic_wallpaper(current_config_.file_path);
                break;
            case WallpaperType::VIDEO:
                set_video_wallpaper(current_config_.file_path);
                break;
            default:
                break;
        }
    }
}

void WallpaperEngine::notify_wallpaper_state_changed() {
    if (state_callback_) {
        /* notify on main queue to avoid threading issues */
        dispatch_async(dispatch_get_main_queue(), ^{
            state_callback_(current_config_.type, is_video_playing());
        });
    }

    if (get_settings_ && get_settings_().show_notifications) {
        send_wallpaper_notification();
    }
}

void WallpaperEngine::set_settings_callback(SettingsCallback callback) {
    get_settings_ = std::move(callback);
}

void WallpaperEngine::send_wallpaper_notification() {
    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center getNotificationSettingsWithCompletionHandler:^(UNNotificationSettings* settings) {
        if (settings.authorizationStatus == UNAuthorizationStatusAuthorized) {
            UNMutableNotificationContent* content = [[UNMutableNotificationContent alloc] init];
            content.title = @"MotionDesk";

            switch (current_config_.type) {
                case WallpaperType::STATIC_IMAGE:
                    content.body = @"Static wallpaper applied";
                    break;
                case WallpaperType::DYNAMIC:
                    content.body = @"Dynamic wallpaper applied";
                    break;
                case WallpaperType::VIDEO:
                    content.body = @"Video wallpaper applied";
                    break;
                default:
                    content.body = @"Wallpaper cleared";
                    break;
            }

            UNNotificationRequest* request = [UNNotificationRequest requestWithIdentifier:@"wallpaper_change"
                                                                                  content:content
                                                                                  trigger:nil];

            [center addNotificationRequest:request withCompletionHandler:nil];
        }
    }];
}
