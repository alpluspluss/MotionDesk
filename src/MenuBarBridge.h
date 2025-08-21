/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include "../bridge/MotionDeskBridge.h"

#import <AppKit/AppKit.h>

/**
 * @brief callback type for menu bar actions
 */
typedef void (*MenuBarActionCallback)(int action_type, void *user_data);

/**
 * @brief menu bar action types
 */
typedef enum {
    MENU_ACTION_SET_STATIC_WALLPAPER = 0,
    MENU_ACTION_SET_DYNAMIC_WALLPAPER = 1,
    MENU_ACTION_SET_VIDEO_WALLPAPER = 2,
    MENU_ACTION_CLEAR_WALLPAPER = 3,
    MENU_ACTION_TOGGLE_VIDEO_PLAYBACK = 4,
    MENU_ACTION_TOGGLE_AUDIO_MUTE = 5,
    MENU_ACTION_SHOW_SETTINGS = 6,
    MENU_ACTION_QUIT_APPLICATION = 7
} MenuBarActionType;

/**
 * @brief opaque handle for menu bar bridge instance
 */
typedef struct MenuBarBridge *MenuBarBridgeRef;

/* c api for menu bar management */
extern "C"
{
/**
 * @brief create menu bar bridge instance
 * @param motion_desk_bridge associated motiondesk bridge
 * @return menu bar bridge handle or null on failure
 */
MenuBarBridgeRef menu_bar_bridge_create(MotionDeskBridgeRef motion_desk_bridge);

/**
 * @brief destroy menu bar bridge instance
 * @param bridge bridge handle to destroy
 */
void menu_bar_bridge_destroy(MenuBarBridgeRef bridge);

/**
 * @brief set menu bar action callback
 * @param bridge bridge handle
 * @param callback function to call for menu actions
 * @param user_data pointer passed to callback
 */
void menu_bar_bridge_set_action_callback(MenuBarBridgeRef bridge, MenuBarActionCallback callback, void *user_data);

/**
 * @brief update menu bar state
 * @param bridge bridge handle
 */
void menu_bar_bridge_update_state(MenuBarBridgeRef bridge);
}

/* objective-c menu bar controller interface */
@interface MenuBarController : NSObject

@property(strong, nonatomic) NSStatusItem *status_item;
@property(assign, nonatomic) MotionDeskBridgeRef motion_desk_bridge;
@property(assign, nonatomic) MenuBarActionCallback action_callback;
@property(assign, nonatomic) void *action_user_data;

- (instancetype)initWithMotionDeskBridge:(MotionDeskBridgeRef)bridge;

- (void)setupMenuBar;

- (void)updateMenuState;

- (void)cleanup;

@end
