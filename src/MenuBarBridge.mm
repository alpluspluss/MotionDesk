/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "MenuBarBridge.h"

/**
 * @brief internal menu bar bridge implementation
 */
struct MenuBarBridge {
    MotionDeskBridgeRef motion_desk_bridge;
    MenuBarController *menu_controller;
    MenuBarActionCallback action_callback;
    void *action_user_data;

    MenuBarBridge(MotionDeskBridgeRef bridge)
            : motion_desk_bridge(bridge), menu_controller(nil), action_callback(nullptr), action_user_data(nullptr) {
    }
};

@implementation MenuBarController

- (instancetype)initWithMotionDeskBridge:(MotionDeskBridgeRef)bridge {
    self = [super init];
    if (self) {
        _motion_desk_bridge = bridge;
        _action_callback = nullptr;
        _action_user_data = nullptr;
        [self setupMenuBar];
    }
    return self;
}

- (void)setupMenuBar {
    /* create status item */
    self.status_item = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];

    if (self.status_item.button != nil) {
        self.status_item.button.image = [NSImage imageWithSystemSymbolName:@"rectangle.on.rectangle" accessibilityDescription:@"MotionDesk"];
        [self.status_item.button.image setTemplate:YES];
    }

    /* create menu */
    self.status_item.menu = [self createMenu];
    [self updateMenuState];
}

- (NSMenu *)createMenu {
    auto *menu = [[NSMenu alloc] init];

    /* current wallpaper status */
    auto *current_item = [[NSMenuItem alloc] initWithTitle:@"Current: None" action:nil keyEquivalent:@""];
    current_item.enabled = NO;
    [menu addItem:current_item];
    [menu addItem:[NSMenuItem separatorItem]];

    /* wallpaper selection */
    auto *static_item = [[NSMenuItem alloc] initWithTitle:@"Set Static Wallpaper..." action:@selector(setStaticWallpaper:) keyEquivalent:@"s"];
    static_item.target = self;
    [menu addItem:static_item];

    auto *dynamic_item = [[NSMenuItem alloc] initWithTitle:@"Set Dynamic Wallpaper..." action:@selector(setDynamicWallpaper:) keyEquivalent:@"d"];
    dynamic_item.target = self;
    [menu addItem:dynamic_item];

    auto *video_item = [[NSMenuItem alloc] initWithTitle:@"Set Video Wallpaper..." action:@selector(setVideoWallpaper:) keyEquivalent:@"v"];
    video_item.target = self;
    [menu addItem:video_item];

    auto *clear_item = [[NSMenuItem alloc] initWithTitle:@"Clear Wallpaper" action:@selector(clearWallpaper:) keyEquivalent:@""];
    clear_item.target = self;
    [menu addItem:clear_item];
    [menu addItem:[NSMenuItem separatorItem]];

    /* audio controls */
    auto *volume_item = [[NSMenuItem alloc] initWithTitle:@"Volume" action:nil keyEquivalent:@""];

    NSView* volume_container = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 140, 28)];
    NSSlider* slider = [[NSSlider alloc] initWithFrame:NSMakeRect(10, 4, 120, 20)];
    slider.minValue = 0.0;
    slider.maxValue = 1.0;
    slider.target = self;
    slider.action = @selector(volumeChanged:);
    [volume_container addSubview:slider];
    volume_item.view = volume_container;

    auto *mute_item = [[NSMenuItem alloc] initWithTitle:@"Mute" action:@selector(toggleMute:) keyEquivalent:@"m"];
    mute_item.target = self;
    [menu addItem:mute_item];
    [menu addItem:[NSMenuItem separatorItem]];

    /* video controls */
    auto *playback_item = [[NSMenuItem alloc] initWithTitle:@"Pause Video" action:@selector(toggleVideoPlayback:) keyEquivalent:@"p"];
    playback_item.target = self;
    [menu addItem:playback_item];
    [menu addItem:[NSMenuItem separatorItem]];

    /** power and resource monitoring **/

    /* power status */
    auto *power_item = [[NSMenuItem alloc] initWithTitle:@"Power: Unknown" action:nil keyEquivalent:@""];
    power_item.enabled = NO;
    [menu addItem:power_item];

    /* resources consumption */
    auto* resources_item = [[NSMenuItem alloc] initWithTitle:@"Resources: 0MB • 0% CPU" action:nil keyEquivalent:@""];
    resources_item.enabled = NO;
    [menu addItem:resources_item];

    [menu addItem:[NSMenuItem separatorItem]];

    /* app controls */
    /* settings submenu */
    auto *settings_menu = [[NSMenu alloc] init];

    auto *battery_video_item = [[NSMenuItem alloc] initWithTitle:@"Allow Video on Battery"
                                                          action:@selector(toggleBatteryVideo:)
                                                   keyEquivalent:@""];
    battery_video_item.target = self;
    [settings_menu addItem:battery_video_item];

    auto *login_item = [[NSMenuItem alloc] initWithTitle:@"Start at Login"
                                                  action:@selector(toggleStartAtLogin:)
                                           keyEquivalent:@""];
    login_item.target = self;
    [settings_menu addItem:login_item];

    auto *notifications_item = [[NSMenuItem alloc] initWithTitle:@"Show Notifications"
                                                          action:@selector(toggleNotifications:)
                                                   keyEquivalent:@""];
    notifications_item.target = self;
    [settings_menu addItem:notifications_item];

    auto *settings_parent = [[NSMenuItem alloc] initWithTitle:@"Settings" action:nil keyEquivalent:@""];
    settings_parent.submenu = settings_menu;
    [menu addItem:settings_parent];

    auto *quit_item = [[NSMenuItem alloc] initWithTitle:@"Quit MotionDesk" action:@selector(quitApplication:) keyEquivalent:@"q"];
    quit_item.target = self;
    [menu addItem:quit_item];

    return menu;
}

- (void)updateMenuState {
    if (self.status_item.menu == nil || self.motion_desk_bridge == nullptr) {
        return;
    }

    /* update current wallpaper display */
    auto wallpaper_type = motion_desk_bridge_get_wallpaper_type(self.motion_desk_bridge);
    auto *wallpaper_path = motion_desk_bridge_get_wallpaper_path(self.motion_desk_bridge);

    NSString *current_text = @"Current: None";
    if (wallpaper_type != 0 && wallpaper_path != nullptr) {
        auto *path_string = [NSString stringWithUTF8String:wallpaper_path];
        auto *filename = [path_string lastPathComponent];

        switch (wallpaper_type) {
            case 1:
                current_text = [NSString stringWithFormat:@"Current: Static - %@", filename];
                break;
            case 2:
                current_text = [NSString stringWithFormat:@"Current: Dynamic - %@", filename];
                break;
            case 3:
                current_text = [NSString stringWithFormat:@"Current: Video - %@", filename];
                break;
        }

        free(wallpaper_path);
    }

    [self.status_item.menu.itemArray[0] setTitle:current_text];

    /* update power status */
    auto power_state = motion_desk_bridge_get_power_state(self.motion_desk_bridge);
    NSString *power_text = @"Power: Unknown";
    NSImage *menu_icon = nil;

    switch (power_state) {
        case 0: /* battery */
            power_text = @"Power: Battery";
            menu_icon = [NSImage imageWithSystemSymbolName:@"battery.25" accessibilityDescription:@"MotionDesk (Battery)"];
            break;
        case 1: /* plugged in */
            power_text = @"Power: AC Power";
            menu_icon = [NSImage imageWithSystemSymbolName:@"rectangle.on.rectangle" accessibilityDescription:@"MotionDesk"];
            break;
        default:
            menu_icon = [NSImage imageWithSystemSymbolName:@"questionmark.rectangle" accessibilityDescription:@"MotionDesk"];
            break;
    }

    if (menu_icon != nil) {
        [menu_icon setTemplate:YES];
        self.status_item.button.image = menu_icon;
    }

    /* find and update power menu item */
    for (NSMenuItem *item in self.status_item.menu.itemArray) {
        if ([item.title hasPrefix:@"Power:"]) {
            item.title = power_text;
            break;
        }
    }

    /* update resources consumption */
    float memory_mb, cpu_percent;
    motion_desk_bridge_get_resource_stats(self.motion_desk_bridge, &memory_mb, &cpu_percent);
    NSString* resources_text = [NSString stringWithFormat:@"Resources: %.1fMB • %.1f%% CPU", memory_mb, cpu_percent];

    for (NSMenuItem* item in self.status_item.menu.itemArray)
    {
        if ([item.title hasPrefix:@"Resources:"])
        {
            item.title = resources_text;
            break;
        }
    }

    /* update audio controls */
    auto volume = motion_desk_bridge_get_audio_volume(self.motion_desk_bridge);
    auto is_muted = motion_desk_bridge_is_audio_muted(self.motion_desk_bridge);

    for (NSMenuItem *item in self.status_item.menu.itemArray) {
        if (item.view != nil && [item.view isKindOfClass:[NSSlider class]]) {
            auto *slider = static_cast<NSSlider *>(item.view);
            slider.doubleValue = volume;
            break;
        }
    }

    for (NSMenuItem *item in self.status_item.menu.itemArray) {
        if ([item.title hasPrefix:@"Mute"] || [item.title hasPrefix:@"Unmute"]) {
            item.title = is_muted ? @"Unmute" : @"Mute";
            break;
        }
    }

    /* update video controls */
    auto is_playing = motion_desk_bridge_is_video_playing(self.motion_desk_bridge);
    for (NSMenuItem *item in self.status_item.menu.itemArray) {
        if ([item.title hasPrefix:@"Pause"] || [item.title hasPrefix:@"Resume"]) {
            item.title = is_playing ? @"Pause Video" : @"Resume Video";
            item.hidden = (wallpaper_type != 3); /* only show for video wallpapers */
            break;
        }
    }

    /* show/hide audio controls based on wallpaper type */
    bool show_audio = (wallpaper_type == 3);
    for (NSMenuItem *item in self.status_item.menu.itemArray) {
        if ([item.title isEqualToString:@"Volume"] ||
            [item.title hasPrefix:@"Mute"] ||
            [item.title hasPrefix:@"Unmute"]) {
            item.hidden = !show_audio;
        }
    }

    /* update settings submenu checkmarks */
    DaemonSettings settings;
    motion_desk_bridge_get_settings(self.motion_desk_bridge, &settings);

    for (NSMenuItem* item in self.status_item.menu.itemArray) {
        if ([item.title isEqualToString:@"Settings"] && item.submenu != nil) {
            for (NSMenuItem* subItem in item.submenu.itemArray) {
                if ([subItem.title isEqualToString:@"Allow Video on Battery"]) {
                    subItem.state = settings.allow_video_on_battery ? NSControlStateValueOn : NSControlStateValueOff;
                } else if ([subItem.title isEqualToString:@"Start at Login"]) {
                    subItem.state = settings.start_at_login ? NSControlStateValueOn : NSControlStateValueOff;
                } else if ([subItem.title isEqualToString:@"Show Notifications"]) {
                    subItem.state = settings.show_notifications ? NSControlStateValueOn : NSControlStateValueOff;
                }
            }
            break;
        }
    }
}

- (void)cleanup {
    if (self.status_item != nil) {
        [[NSStatusBar systemStatusBar] removeStatusItem:self.status_item];
        self.status_item = nil;
    }
}

/* menu action handlers */

- (void)setStaticWallpaper:(id)sender {
    if (self.action_callback != nullptr) {
        self.action_callback(MENU_ACTION_SET_STATIC_WALLPAPER, self.action_user_data);
    }
}

- (void)setDynamicWallpaper:(id)sender {
    if (self.action_callback != nullptr) {
        self.action_callback(MENU_ACTION_SET_DYNAMIC_WALLPAPER, self.action_user_data);
    }
}

- (void)setVideoWallpaper:(id)sender {
    if (self.action_callback != nullptr) {
        self.action_callback(MENU_ACTION_SET_VIDEO_WALLPAPER, self.action_user_data);
    }
}

- (void)clearWallpaper:(id)sender {
    motion_desk_bridge_clear_wallpaper(self.motion_desk_bridge);
    [self updateMenuState];
}

- (void)toggleVideoPlayback:(id)sender {
    motion_desk_bridge_toggle_video_playback(self.motion_desk_bridge);
    [self updateMenuState];
}

- (void)volumeChanged:(NSSlider *)sender {
    motion_desk_bridge_set_audio_volume(self.motion_desk_bridge, static_cast<float>(sender.doubleValue));
}

- (void)toggleMute:(id)sender {
    motion_desk_bridge_toggle_audio_mute(self.motion_desk_bridge);
    [self updateMenuState];
}

- (void)showSettings:(id)sender {
    if (self.action_callback != nullptr) {
        self.action_callback(MENU_ACTION_SHOW_SETTINGS, self.action_user_data);
    }
}

- (void)quitApplication:(id)sender {
    if (self.action_callback != nullptr) {
        self.action_callback(MENU_ACTION_QUIT_APPLICATION, self.action_user_data);
    }
}

- (void)toggleBatteryVideo:(id)sender {
    DaemonSettings settings;
    motion_desk_bridge_get_settings(self.motion_desk_bridge, &settings);
    motion_desk_bridge_set_setting(self.motion_desk_bridge, "allow_video_on_battery", !settings.allow_video_on_battery);
    [self updateMenuState];
}

- (void)toggleStartAtLogin:(id)sender {
    DaemonSettings settings;
    motion_desk_bridge_get_settings(self.motion_desk_bridge, &settings);
    motion_desk_bridge_set_setting(self.motion_desk_bridge, "start_at_login", !settings.start_at_login);
    [self updateMenuState];
}

- (void)toggleNotifications:(id)sender {
    DaemonSettings settings;
    motion_desk_bridge_get_settings(self.motion_desk_bridge, &settings);
    motion_desk_bridge_set_setting(self.motion_desk_bridge, "show_notifications", !settings.show_notifications);
    [self updateMenuState];
}

@end

MenuBarBridgeRef menu_bar_bridge_create(MotionDeskBridgeRef motion_desk_bridge) {
    if (motion_desk_bridge == nullptr) {
        return nullptr;
    }

    try {
        auto *bridge = new MenuBarBridge(motion_desk_bridge);
        bridge->menu_controller = [[MenuBarController alloc] initWithMotionDeskBridge:motion_desk_bridge];

        return bridge;
    }
    catch (...) {
        return nullptr;
    }
}

void menu_bar_bridge_destroy(MenuBarBridgeRef bridge) {
    if (bridge != nullptr) {
        if (bridge->menu_controller != nil) {
            [bridge->menu_controller cleanup];
            bridge->menu_controller = nil;
        }
        delete bridge;
    }
}

void menu_bar_bridge_set_action_callback(MenuBarBridgeRef bridge, MenuBarActionCallback callback, void *user_data) {
    if (bridge != nullptr && bridge->menu_controller != nil) {
        bridge->action_callback = callback;
        bridge->action_user_data = user_data;
        bridge->menu_controller.action_callback = callback;
        bridge->menu_controller.action_user_data = user_data;
    }
}

void menu_bar_bridge_update_state(MenuBarBridgeRef bridge) {
    if (bridge != nullptr && bridge->menu_controller != nil) {
        [bridge->menu_controller updateMenuState];
    }
}
