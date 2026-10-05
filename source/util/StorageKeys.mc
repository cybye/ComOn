import Toybox.Lang;

(:background)
module StorageKeys {
    // Cross-Process Shared Message Store
    public const CHAT_HISTORY                  as String = "cfg_chat_history";

    // Foreground Lifecycle & Heartbeat
    public const FOREGROUND_ACTIVE             as String = "cfg_foreground_active";
    public const FOREGROUND_ACTIVE_AT          as String = "cfg_foreground_active_at";
    public const SCHEDULER_PROBE               as String = "cfg_bg_scheduler_probe";

    // Background Timing & Notifications
    public const BG_INTERVAL                   as String = "bgInterval";
    public const BG_NODE_UNAVAILABLE_NOTIFIED   as String = "cfg_bg_node_unavailable_notified";
    public const BG_LOW_BATTERY_NOTIFIED       as String = "cfg_bg_low_battery_notified";
    public const LAST_BG_BATTERY_POLL_TIME     as String = "last_bg_battery_poll_time";
    public const BG_QUIET_MODE                 as String = "cfg_bg_quiet_mode";          // Boolean, default true: skip polls in sleep window / DND
    public const BG_FAIL_STREAK                as String = "cfg_bg_fail_streak";         // Number of consecutive runs without node connection
    public const BG_UNPAIR_DROPS_BOND          as String = "cfg_bg_unpair_drops_bond";   // Set if unpairDevice() was observed to remove the system bond

    // Contact & Channel Identity Caches (Foreground -> Background)
    public const BG_CONTACT_NAME_PREFIX        as String = "cfg_bg_contact_name_";
    public const BG_CHANNEL_NAME_PREFIX        as String = "cfg_bg_channel_name_";
    public const BG_IDENTITY_MANIFEST          as String = "cfg_bg_identity_manifest";
    public const LEGACY_BG_CONTACT_NAMES       as String = "cfg_bg_contact_names";
    public const LEGACY_BG_CHANNEL_NAMES       as String = "cfg_bg_channel_names";

    // Stored Notification Localized Strings (for background without WatchUi)
    public const NOTIF_INCOMING_BATCH          as String = "cfg_notif_incoming_batch";
    public const NOTIF_INCOMING_MSG            as String = "cfg_notif_incoming_msg";
    public const NOTIF_OPEN_CHAT               as String = "cfg_notif_open_chat";
    public const NOTIF_OPEN_CHATS              as String = "cfg_notif_open_chats";
    public const NOTIF_REPLY                   as String = "cfg_notif_reply";
    public const NOTIF_POSITION                as String = "cfg_notif_position";
    public const NOTIF_OK                      as String = "cfg_notif_ok";

    // Cached Hardware/Node State
    public const CACHED_NODE_BATTERY_PERCENT   as String = "cached_node_battery_percent";
    public const CACHED_NODE_BATTERY_MV        as String = "cached_node_battery_mv";
    public const CACHED_NODE_BATTERY_TIME      as String = "cached_node_battery_time";

    // Domain Store Keys
    public const CACHED_CHANNELS               as String = "cfg_cached_channels";
    public const CACHED_CONTACTS               as String = "cfg_cached_contacts";
    public const LAST_CONTACT_SYNC             as String = "cfg_last_contact_sync";
    public const PAIRED_NODE_ID                as String = "cfg_paired_node_id";
    public const ACTIVITY_TELEMETRY_TARGET     as String = "cfg_activity_telemetry_target";

    // Diagnostics & Settings
    public const BG_DIAGNOSTICS_V1             as String = "cfg_bg_diagnostics_v1";
    public const FIT_LOGGING_ENABLED           as String = "fitLoggingEnabled";
    public const TELEMETRY_FORMAT              as String = "telemetryFormat";
}
