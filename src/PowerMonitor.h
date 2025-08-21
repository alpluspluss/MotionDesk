/* this project is part of the MotionDesk project; licensed under the MIT license. see LICENSE for more info */

#pragma once

#include <functional>

#include "Types.h"

#import <Foundation/Foundation.h>
#import <IOKit/ps/IOPowerSources.h>

/**
 * @brief callback type for power state change notifications
 */
using PowerStateCallback = std::function<void(PowerState)>;

/**
 * @brief monitors system power state and notifies observers of changes
 */
class PowerMonitor {
public:
    /**
     * @brief construct power monitor and start monitoring
     */
    PowerMonitor();

    /**
     * @brief destroy power monitor and cleanup resources
     */
    ~PowerMonitor();

    /* non-copyable */
    PowerMonitor(const PowerMonitor &) = delete;

    PowerMonitor &operator=(const PowerMonitor &) = delete;

    /**
     * @brief get current power state
     * @return current power source state
     */
    [[nodiscard]] PowerState get_current_state() const;

    /**
     * @brief register callback for power state changes
     * @param callback function to call when power state changes
     */
    void set_power_state_callback(PowerStateCallback callback);

    /**
     * @brief force update of power state (mainly for testing)
     */
    void force_update();

    /**
     * @brief cleanup power monitoring resources
     */
    void cleanup();

/**
 * @brief handle power source change notification
 */
    void handle_power_source_change();

private:
    /**
     * @brief setup iokit power source monitoring
     */
    void setup_power_monitoring();

    /**
     * @brief remove power source observer
     */
    void remove_power_source_observer();

    /**
     * @brief update internal power state from system
     */
    void update_power_state();

    PowerState current_state_;
    PowerStateCallback power_state_callback_;
    CFRunLoopSourceRef power_source_run_loop_;
};
