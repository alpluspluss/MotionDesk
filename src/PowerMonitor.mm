/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#include "PowerMonitor.h"
#import <IOKit/ps/IOPSKeys.h>

/* c callback function for iokit power source notifications */
static void power_source_change_callback(void *context) {
    if (context != nullptr) {
        auto *power_monitor = static_cast<PowerMonitor *>(context);
        power_monitor->handle_power_source_change();
    }
}

PowerMonitor::PowerMonitor()
        : current_state_(PowerState::UNKNOWN), power_source_run_loop_(nullptr) {
    setup_power_monitoring();
    update_power_state();
}

PowerMonitor::~PowerMonitor() {
    cleanup();
}

PowerState PowerMonitor::get_current_state() const {
    return current_state_;
}

void PowerMonitor::set_power_state_callback(PowerStateCallback callback) {
    power_state_callback_ = std::move(callback);
}

void PowerMonitor::force_update() {
    update_power_state();
}

void PowerMonitor::cleanup() {
    remove_power_source_observer();
}

void PowerMonitor::setup_power_monitoring() {
    /* register for power source change notifications using iokit */
    auto *context = static_cast<void *>(this);

    power_source_run_loop_ = IOPSNotificationCreateRunLoopSource(
            power_source_change_callback,
            context
    );

    if (power_source_run_loop_ != nullptr) {
        CFRunLoopAddSource(
                CFRunLoopGetCurrent(),
                power_source_run_loop_,
                kCFRunLoopDefaultMode
        );
    }
}

void PowerMonitor::remove_power_source_observer() {
    if (power_source_run_loop_ != nullptr) {
        CFRunLoopRemoveSource(
                CFRunLoopGetCurrent(),
                power_source_run_loop_,
                kCFRunLoopDefaultMode
        );

        CFRelease(power_source_run_loop_);
        power_source_run_loop_ = nullptr;
    }
}

void PowerMonitor::handle_power_source_change() {
    auto previous_state = current_state_;
    update_power_state();

    if (previous_state != current_state_ && power_state_callback_) {
        /* notify on main queue to avoid threading issues */
        dispatch_async(dispatch_get_main_queue(), ^{
            power_state_callback_(current_state_);
        });
    }
}

void PowerMonitor::update_power_state() {
    /* use the simpler api to get providing power source type */
    CFTypeRef power_source_info = IOPSCopyPowerSourcesInfo();
    if (power_source_info == nullptr) {
        current_state_ = PowerState::UNKNOWN;
        return;
    }

    CFStringRef power_source_type = IOPSGetProvidingPowerSourceType(power_source_info);

    if (power_source_type == nullptr) {
        CFRelease(power_source_info);
        current_state_ = PowerState::UNKNOWN;
        return;
    }

    /* determine power state based on power source type */
    if (CFStringCompare(power_source_type, CFSTR(kIOPSACPowerValue), 0) == kCFCompareEqualTo) {
        current_state_ = PowerState::PLUGGED_IN;
    } else if (CFStringCompare(power_source_type, CFSTR(kIOPSBatteryPowerValue), 0) == kCFCompareEqualTo) {
        current_state_ = PowerState::BATTERY;
    } else {
        current_state_ = PowerState::UNKNOWN;
    }

    CFRelease(power_source_info);
}
