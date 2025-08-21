/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "MenuBarBridge.h"
//#include "../bridge/MotionDeskBridge.h"
#import <UserNotifications/UserNotifications.h>
#import <AppKit/AppKit.h>

/**
 * @brief application delegate for motiondesk
 */
@interface MotionDeskAppDelegate : NSObject <NSApplicationDelegate>

@property(assign, nonatomic) MotionDeskBridgeRef motion_desk_bridge;
@property(assign, nonatomic) MenuBarBridgeRef menu_bar_bridge;

@end

@implementation MotionDeskAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    /* hide from dock as this is a menu bar only application */
    [NSApp setActivationPolicy:NSApplicationActivationPolicyAccessory];

    UNUserNotificationCenter* center = [UNUserNotificationCenter currentNotificationCenter];
    [center requestAuthorizationWithOptions:(UNAuthorizationOptionAlert | UNAuthorizationOptionSound)
                          completionHandler:^(BOOL granted, NSError* error) {
                              if (!granted) {
                                  NSLog(@"Notification permission denied");
                              }
                          }];
    /* create core bridge */
    self.motion_desk_bridge = motion_desk_bridge_create();
    if (self.motion_desk_bridge == nullptr) {
        NSLog(@"Failed to create MotionDesk bridge");
        [NSApp terminate:nil];
        return;
    }

    /* create menu bar interface */
    self.menu_bar_bridge = menu_bar_bridge_create(self.motion_desk_bridge);
    if (self.menu_bar_bridge == nullptr) {
        NSLog(@"Failed to create menu bar bridge");
        motion_desk_bridge_destroy(self.motion_desk_bridge);
        [NSApp terminate:nil];
        return;
    }

    /* setup menu bar action handling */
    menu_bar_bridge_set_action_callback(self.menu_bar_bridge, menu_bar_action_handler, (__bridge void *) self);

    /* setup state change callbacks */
    motion_desk_bridge_set_power_callback(self.motion_desk_bridge, power_state_changed, (__bridge void *) self);
    motion_desk_bridge_set_wallpaper_callback(self.motion_desk_bridge, wallpaper_state_changed, (__bridge void *) self);
    motion_desk_bridge_set_audio_callback(self.motion_desk_bridge, audio_settings_changed, (__bridge void *) self);

    NSLog(@"MotionDesk started successfully");
}

- (void)applicationWillTerminate:(NSNotification *)notification {
    /* cleanup bridges */
    if (self.menu_bar_bridge != nullptr) {
        menu_bar_bridge_destroy(self.menu_bar_bridge);
        self.menu_bar_bridge = nullptr;
    }

    if (self.motion_desk_bridge != nullptr) {
        motion_desk_bridge_destroy(self.motion_desk_bridge);
        self.motion_desk_bridge = nullptr;
    }

    NSLog(@"MotionDesk shutdown complete");
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)application {
    /* prevent app from terminating when settings window closes */
    return NO;
}

/* callback handlers */

static void menu_bar_action_handler(int action_type, void *user_data) {
    auto *app_delegate = (__bridge MotionDeskAppDelegate *) user_data;
    [app_delegate handleMenuBarAction:action_type];
}

static void power_state_changed(int power_state, void *user_data) {
    auto *app_delegate = (__bridge MotionDeskAppDelegate *) user_data;
    [app_delegate handlePowerStateChanged:power_state];
}

static void wallpaper_state_changed(int wallpaper_type, bool is_playing, void *user_data) {
    auto *app_delegate = (__bridge MotionDeskAppDelegate *) user_data;
    [app_delegate handleWallpaperStateChanged:wallpaper_type isPlaying:is_playing];
}

static void audio_settings_changed(float volume, bool is_muted, void *user_data) {
    auto *app_delegate = (__bridge MotionDeskAppDelegate *) user_data;
    [app_delegate handleAudioSettingsChanged:volume isMuted:is_muted];
}

- (void)handleMenuBarAction:(int)action_type {
    switch (action_type) {
        case MENU_ACTION_SET_STATIC_WALLPAPER:
            [self selectStaticWallpaper];
            break;

        case MENU_ACTION_SET_DYNAMIC_WALLPAPER:
            [self selectDynamicWallpaper];
            break;

        case MENU_ACTION_SET_VIDEO_WALLPAPER:
            [self selectVideoWallpaper];
            break;

        case MENU_ACTION_CLEAR_WALLPAPER:
            motion_desk_bridge_clear_wallpaper(self.motion_desk_bridge);
            break;

        case MENU_ACTION_TOGGLE_VIDEO_PLAYBACK:
            motion_desk_bridge_toggle_video_playback(self.motion_desk_bridge);
            break;

        case MENU_ACTION_TOGGLE_AUDIO_MUTE:
            motion_desk_bridge_toggle_audio_mute(self.motion_desk_bridge);
            break;

        case MENU_ACTION_SHOW_SETTINGS:
            [self showSettings];
            break;

        case MENU_ACTION_QUIT_APPLICATION:
            [NSApp terminate:nil];
            break;

        default:
            NSLog(@"Unknown menu bar action: %d", action_type);
            break;
    }
}

- (void)handlePowerStateChanged:(int)power_state {
    /* update menu bar to reflect power state changes */
    menu_bar_bridge_update_state(self.menu_bar_bridge);

    NSString *state_name = @"Unknown";
    switch (power_state) {
        case 0:
            state_name = @"Battery";
            break;
        case 1:
            state_name = @"AC Power";
            break;
        default:
            break;
    }

    NSLog(@"Power state changed to: %@", state_name);
}

- (void)handleWallpaperStateChanged:(int)wallpaper_type isPlaying:(bool)is_playing {
    /* update menu bar to reflect wallpaper changes */
    menu_bar_bridge_update_state(self.menu_bar_bridge);

    NSString *type_name = @"None";
    switch (wallpaper_type) {
        case 1:
            type_name = @"Static Image";
            break;
        case 2:
            type_name = @"Dynamic Wallpaper";
            break;
        case 3:
            type_name = is_playing ? @"Video (Playing)" : @"Video (Paused)";
            break;
        default:
            break;
    }

    NSLog(@"Wallpaper changed to: %@", type_name);
}

- (void)handleAudioSettingsChanged:(float)volume isMuted:(bool)is_muted {
    /* update menu bar to reflect audio changes */
    menu_bar_bridge_update_state(self.menu_bar_bridge);

    NSLog(@"Audio settings changed - Volume: %.0f%%, Muted: %@",
          volume * 100.0f, is_muted ? @"Yes" : @"No");
}

/* file selection methods */

- (void)selectStaticWallpaper {
    auto *open_panel = [NSOpenPanel openPanel];
    open_panel.allowedContentTypes = @[
            [UTType typeWithIdentifier:@"public.jpeg"],
            [UTType typeWithIdentifier:@"public.png"],
            [UTType typeWithIdentifier:@"public.heic"],
            [UTType typeWithIdentifier:@"public.tiff"],
            [UTType typeWithIdentifier:@"com.compuserve.gif"]
    ];
    open_panel.allowsMultipleSelection = NO;
    open_panel.canChooseDirectories = NO;
    open_panel.message = @"Select a static image for wallpaper";

    [open_panel beginWithCompletionHandler:^(NSModalResponse response) {
        if (response == NSModalResponseOK && open_panel.URL != nil) {
            auto *file_path = [open_panel.URL.path UTF8String];
            auto error = motion_desk_bridge_set_static_wallpaper(self.motion_desk_bridge, file_path);

            if (error != 0) {
                [self showErrorAlert:@"Failed to set static wallpaper" error:error];
            }
        }
    }];
}

- (void)selectDynamicWallpaper {
    auto *open_panel = [NSOpenPanel openPanel];
    open_panel.allowedContentTypes = @[
            [UTType typeWithIdentifier:@"public.heic"]
    ];
    open_panel.allowsMultipleSelection = NO;
    open_panel.canChooseDirectories = NO;
    open_panel.message = @"Select a dynamic HEIC wallpaper";

    [open_panel beginWithCompletionHandler:^(NSModalResponse response) {
        if (response == NSModalResponseOK && open_panel.URL != nil) {
            auto *file_path = [open_panel.URL.path UTF8String];
            auto error = motion_desk_bridge_set_dynamic_wallpaper(self.motion_desk_bridge, file_path);

            if (error != 0) {
                [self showErrorAlert:@"Failed to set dynamic wallpaper" error:error];
            }
        }
    }];
}

- (void)selectVideoWallpaper {
    auto *open_panel = [NSOpenPanel openPanel];
    open_panel.allowedContentTypes = @[
            [UTType typeWithIdentifier:@"public.mpeg-4"],
            [UTType typeWithIdentifier:@"com.apple.quicktime-movie"],
            [UTType typeWithIdentifier:@"public.avi"]
    ];
    open_panel.allowsMultipleSelection = NO;
    open_panel.canChooseDirectories = NO;
    open_panel.message = @"Select a video file for wallpaper";

    [open_panel beginWithCompletionHandler:^(NSModalResponse response) {
        if (response == NSModalResponseOK && open_panel.URL != nil) {
            auto *file_path = [open_panel.URL.path UTF8String];
            auto error = motion_desk_bridge_set_video_wallpaper(self.motion_desk_bridge, file_path);

            if (error != 0) {
                [self showErrorAlert:@"Failed to set video wallpaper" error:error];
            }
        }
    }];
}

- (void)showSettings {
    /* for now, just show an info alert - swift ui integration would go here */
    auto *alert = [[NSAlert alloc] init];
    alert.messageText = @"MotionDesk Settings";
    alert.informativeText = @"Settings panel not yet implemented. Use menu bar controls for now.";
    alert.alertStyle = NSAlertStyleInformational;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

- (void)showErrorAlert:(NSString *)message error:(int)error_code {
    auto *alert = [[NSAlert alloc] init];
    alert.messageText = @"MotionDesk Error";
    alert.informativeText = [NSString stringWithFormat:@"%@ (Error code: %d)", message, error_code];
    alert.alertStyle = NSAlertStyleWarning;
    [alert addButtonWithTitle:@"OK"];
    [alert runModal];
}

@end

/**
 * @brief main entry point
 */
int main(int argc, char *argv[]) {
    @autoreleasepool {
        /* create application */
        auto *app = [NSApplication sharedApplication];

        /* create and set delegate */
        auto *delegate = [[MotionDeskAppDelegate alloc] init];
        app.delegate = delegate;

        /* run application */
        [app run];
    }

    return 0;
}
