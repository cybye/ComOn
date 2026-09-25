import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Application.Storage;

class ContactManager {
    public static var selectedChannelIdx as Number = 0;
    public static var selectedTargetName as String = "#public";
    public static var isContactTarget as Boolean = false;
    public static var selectedContactId as String? = null;

    private static const STORAGE_CHANNELS as String = "cfg_cached_channels";
    private static const STORAGE_CONTACTS as String = "cfg_cached_contacts";
    private static const STORAGE_BACKGROUND_CONTACT_NAME_PREFIX as String = "cfg_bg_contact_name_";
    private static const STORAGE_BACKGROUND_CHANNEL_NAME_PREFIX as String = "cfg_bg_channel_name_";
    private static const STORAGE_BACKGROUND_IDENTITY_MANIFEST as String = "cfg_bg_identity_manifest";
    private static const STORAGE_LEGACY_BACKGROUND_CONTACT_NAMES as String = "cfg_bg_contact_names";
    private static const STORAGE_LEGACY_BACKGROUND_CHANNEL_NAMES as String = "cfg_bg_channel_names";
    private static const STORAGE_SYNC_TIME as String = "cfg_last_contact_sync";
    private static const STORAGE_PAIRED_NODE as String = "cfg_paired_node_id";
    private static const STORAGE_ACTIVITY_TARGET as String = "cfg_activity_telemetry_target";

    private static var _initialized as Boolean = false;
    private static var _lastContactSyncTime as Number = 0;
    private static var _pairedNodeId as String? = null;
    private static var _activityTargetLoaded as Boolean = false;
    private static var _activityTargetEnabled as Boolean = false;
    private static var _activityTargetIsContact as Boolean = false;
    private static var _activityTargetChannelIdx as Number = 0;
    private static var _activityTargetContactId as String? = null;
    private static var _activityTargetName as String = "Senden Aus";

    private static var _inFullSync as Boolean = false;
    private static var _syncingChannels as Array<Dictionary> = [] as Array<Dictionary>;
    private static var _syncingContacts as Array<Dictionary> = [] as Array<Dictionary>;

    private static var _channels as Array<Dictionary> = [
        { :name => "#public", :idx => 0 }
    ];

    private static var _contacts as Array<Dictionary> = [] as Array<Dictionary>;

    public static function loadFromStorage() as Void {
        if (_initialized) {
            return;
        }
        _initialized = true;

        try {
            var cachedCh = Storage.getValue(STORAGE_CHANNELS);
            if (cachedCh != null && (cachedCh instanceof Array) && (cachedCh as Array).size() > 0) {
                var list = cachedCh as Array<Dictionary>;
                var loadedCh = [] as Array<Dictionary>;
                for (var i = 0; i < list.size(); i++) {
                    var item = list[i];
                    var chName = item["name"] as String;
                    if (chName != null && chName.find("#") != 0) {
                        chName = "#" + chName;
                    }
                    loadedCh.add({ :name => chName, :idx => item["idx"] });
                }
                _channels = loadedCh;
            }

            var cachedCt = Storage.getValue(STORAGE_CONTACTS);
            if (cachedCt != null && (cachedCt instanceof Array) && (cachedCt as Array).size() > 0) {
                var listCt = cachedCt as Array<Dictionary>;
                var loadedCt = [] as Array<Dictionary>;
                for (var j = 0; j < listCt.size(); j++) {
                    var itemCt = listCt[j];
                    var ctName = itemCt["name"] as String;
                    if (ctName != null) {
                        if (ctName.find("@") == 0 || ctName.find("#") == 0) {
                            ctName = ctName.substring(1, ctName.length());
                        }
                    }
                    var typeVal = (itemCt.hasKey("advType") && itemCt["advType"] != null) ? (itemCt["advType"] as Number) : 1;
                    loadedCt.add({
                        :name => ctName,
                        :id => itemCt["id"],
                        :isChannel => itemCt["isChannel"],
                        :idx => itemCt["idx"],
                        :advType => typeVal
                    });
                }
                _contacts = loadedCt;
            }

            var syncT = Storage.getValue(STORAGE_SYNC_TIME);
            if (syncT != null && (syncT instanceof Number)) {
                _lastContactSyncTime = syncT as Number;
            }

            var paired = Storage.getValue(STORAGE_PAIRED_NODE);
            if (paired != null && (paired instanceof String)) {
                _pairedNodeId = paired as String;
            }
        } catch (e) {
            System.println("ContactManager storage read notice");
        }
    }

    public static function saveToStorage() as Void {
        try {
            var chList = [] as Array<Dictionary>;
            for (var i = 0; i < _channels.size(); i++) {
                var c = _channels[i];
                chList.add({ "name" => c[:name], "idx" => c[:idx] });
            }

            var ctList = [] as Array<Dictionary>;
            for (var j = 0; j < _contacts.size(); j++) {
                var ct = _contacts[j];
                ctList.add({
                    "name" => ct[:name],
                    "id" => ct[:id],
                    "isChannel" => (ct[:isChannel] != null) ? ct[:isChannel] : false,
                    "idx" => (ct[:idx] != null) ? ct[:idx] : 0,
                    "advType" => (ct.hasKey(:advType) && ct[:advType] != null) ? ct[:advType] : 1
                });
            }

            Storage.setValue(STORAGE_CHANNELS, chList);
            Storage.setValue(STORAGE_CONTACTS, ctList);
            Storage.setValue(STORAGE_SYNC_TIME, _lastContactSyncTime);
            if (_pairedNodeId != null) {
                Storage.setValue(STORAGE_PAIRED_NODE, _pairedNodeId);
            }
            rebuildBackgroundIdentityCaches();
        } catch (e) {
            System.println("ContactManager storage write notice");
        }
    }

    public static function ensureBackgroundIdentityCaches() as Void {
        loadFromStorage();
        var manifest = Storage.getValue(STORAGE_BACKGROUND_IDENTITY_MANIFEST);
        if (manifest instanceof Dictionary && manifest["version"] instanceof Number && (manifest["version"] as Number) == _lastContactSyncTime) {
            return;
        }
        rebuildBackgroundIdentityCaches();
    }

    private static function rebuildBackgroundIdentityCaches() as Void {
        try {
            deleteManifestIdentityEntries();

            var contactPrefixes = [] as Array<String>;
            var channelIds = [] as Array<String>;
            for (var channelIndex = 0; channelIndex < _channels.size(); channelIndex++) {
                var channel = _channels[channelIndex];
                if (channel[:idx] instanceof Number && channel[:name] instanceof String && (channel[:name] as String).length() > 0) {
                    var channelId = (channel[:idx] as Number).format("%d");
                    Storage.setValue(STORAGE_BACKGROUND_CHANNEL_NAME_PREFIX + channelId, channel[:name] as String);
                    channelIds.add(channelId);
                }
            }

            for (var contactIndex = 0; contactIndex < _contacts.size(); contactIndex++) {
                var contact = _contacts[contactIndex];
                var contactId = contact[:id];
                var contactName = contact[:name];
                if (contactId instanceof String && contactName instanceof String && (contactId as String).length() >= 12 && (contactName as String).length() > 0) {
                    var prefix = (contactId as String).substring(0, 12).toUpper();
                    Storage.setValue(STORAGE_BACKGROUND_CONTACT_NAME_PREFIX + prefix, contactName as String);
                    contactPrefixes.add(prefix);
                }
            }

            Storage.setValue(STORAGE_BACKGROUND_IDENTITY_MANIFEST, {
                "version" => _lastContactSyncTime,
                "contacts" => contactPrefixes,
                "channels" => channelIds
            });
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CONTACT_NAMES);
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CHANNEL_NAMES);
        } catch (e) {
            System.println("ContactManager background identity cache write notice");
        }
    }

    private static function deleteManifestIdentityEntries() as Void {
        var manifest = Storage.getValue(STORAGE_BACKGROUND_IDENTITY_MANIFEST);
        if (!(manifest instanceof Dictionary)) {
            return;
        }
        var contactPrefixes = manifest["contacts"];
        if (contactPrefixes instanceof Array) {
            for (var contactIndex = 0; contactIndex < (contactPrefixes as Array).size(); contactIndex++) {
                var prefix = (contactPrefixes as Array)[contactIndex];
                if (prefix instanceof String) {
                    Storage.deleteValue(STORAGE_BACKGROUND_CONTACT_NAME_PREFIX + (prefix as String));
                }
            }
        }
        var channelIds = manifest["channels"];
        if (channelIds instanceof Array) {
            for (var channelIndex = 0; channelIndex < (channelIds as Array).size(); channelIndex++) {
                var channelId = (channelIds as Array)[channelIndex];
                if (channelId instanceof String) {
                    Storage.deleteValue(STORAGE_BACKGROUND_CHANNEL_NAME_PREFIX + (channelId as String));
                }
            }
        }
        Storage.deleteValue(STORAGE_BACKGROUND_IDENTITY_MANIFEST);
    }
    //! Check if connecting to a different node. If yes, reset sync timestamp for full sync.
    public static function checkNodeBinding(currentNodeId as String) as Boolean {
        loadFromStorage();
        if (_pairedNodeId == null) {
            _pairedNodeId = currentNodeId;
            saveToStorage();
            return false;
        }
        if (!_pairedNodeId.equals(currentNodeId)) {
            System.println("ContactManager: Node changed from '" + _pairedNodeId + "' to '" + currentNodeId + "' -> Triggering Full Sync and purging old node cache");
            _pairedNodeId = currentNodeId;
            _lastContactSyncTime = 0;
            _channels = [ { :name => "#public", :idx => 0 } ];
            _contacts = [] as Array<Dictionary>;
            saveToStorage();
            ChatHistoryManager.clearHistory();
            return true;
        }
        return false;
    }

    public static function getPairedNodeId() as String? {
        loadFromStorage();
        return _pairedNodeId;
    }

    public static function setPairedNodeId(id as String) as Void {
        _pairedNodeId = id;
        saveToStorage();
    }

    public static function resetSyncTime() as Void {
        _lastContactSyncTime = 0;
        saveToStorage();
    }

    public static function isInFullSync() as Boolean {
        return _inFullSync;
    }

    public static function startFullSync() as Void {
        _inFullSync = true;
        _syncingChannels = [] as Array<Dictionary>;
        _syncingContacts = [] as Array<Dictionary>;
        System.println("ContactManager: Full Sync started (staging buffers initialized)");
    }

    public static function addSyncChannel(idx as Number, name as String) as Void {
        var chName = (name.find("#") == 0) ? name : ("#" + name);
        for (var i = 0; i < _syncingChannels.size(); i++) {
            if (_syncingChannels[i][:idx] == idx) {
                _syncingChannels[i][:name] = chName;
                return;
            }
        }
        _syncingChannels.add({ :name => chName, :idx => idx });
    }

    public static function addSyncContact(id as String, name as String, advType as Number?) as Void {
        var cleanName = name;
        if (cleanName.find("@") == 0 || cleanName.find("#") == 0) {
            cleanName = cleanName.substring(1, cleanName.length());
        }
        var typeVal = (advType != null) ? advType : 1;
        for (var i = 0; i < _syncingContacts.size(); i++) {
            if (_syncingContacts[i][:id].equals(id)) {
                _syncingContacts[i][:name] = cleanName;
                _syncingContacts[i][:advType] = typeVal;
                return;
            }
        }
        _syncingContacts.add({ :name => cleanName, :id => id, :isChannel => false, :advType => typeVal });
    }

    public static function commitFullSync() as Void {
        if (_inFullSync) {
            if (_syncingChannels.size() > 0) {
                _channels = _syncingChannels;
            } else {
                _channels = [ { :name => "#public", :idx => 0 } ];
            }
            _contacts = _syncingContacts;
            _inFullSync = false;
            _lastContactSyncTime = Time.now().value();
            validateSelection();
            saveToStorage();
            System.println("ContactManager: Full Sync committed (" + _channels.size() + " channels, " + _contacts.size() + " contacts)");
        }
    }

    public static function clearAll() as Void {
        deleteManifestIdentityEntries();
        _channels = [ { :name => "#public", :idx => 0 } ];
        _contacts = [] as Array<Dictionary>;
        _lastContactSyncTime = 0;
        _pairedNodeId = null;
        selectedChannelIdx = 0;
        selectedTargetName = "#public";
        isContactTarget = false;
        selectedContactId = null;
        try {
            Storage.deleteValue(STORAGE_CHANNELS);
            Storage.deleteValue(STORAGE_CONTACTS);
            Storage.deleteValue(STORAGE_SYNC_TIME);
            Storage.deleteValue(STORAGE_PAIRED_NODE);
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CONTACT_NAMES);
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CHANNEL_NAMES);
        } catch (e) {
            // ignore
        }
    }

    public static function resetForFullNodeSync() as Void {
        loadFromStorage();
        deleteManifestIdentityEntries();
        _channels = [ { :name => "#public", :idx => 0 } ];
        _contacts = [] as Array<Dictionary>;
        _lastContactSyncTime = 0;
        selectedChannelIdx = 0;
        selectedTargetName = "#public";
        isContactTarget = false;
        selectedContactId = null;
        ChatHistoryManager.clearHistory();
        try {
            Storage.deleteValue(STORAGE_CHANNELS);
            Storage.deleteValue(STORAGE_CONTACTS);
            Storage.deleteValue(STORAGE_SYNC_TIME);
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CONTACT_NAMES);
            Storage.deleteValue(STORAGE_LEGACY_BACKGROUND_CHANNEL_NAMES);
        } catch (e) {
            System.println("ContactManager full sync reset notice");
        }
    }

    public static function cancelFullSync() as Void {
        _inFullSync = false;
        _syncingChannels = [] as Array<Dictionary>;
        _syncingContacts = [] as Array<Dictionary>;
    }

    public static function validateSelection() as Void {
        if (!isContactTarget) {
            var found = false;
            for (var i = 0; i < _channels.size(); i++) {
                if (_channels[i][:idx] == selectedChannelIdx) {
                    found = true;
                    selectedTargetName = _channels[i][:name] as String;
                    break;
                }
            }
            if (!found && _channels.size() > 0) {
                selectedChannelIdx = _channels[0][:idx] as Number;
                selectedTargetName = _channels[0][:name] as String;
            }
        } else {
            var foundCt = false;
            if (selectedContactId != null) {
                for (var j = 0; j < _contacts.size(); j++) {
                    if (_contacts[j][:id].equals(selectedContactId)) {
                        foundCt = true;
                        selectedTargetName = _contacts[j][:name] as String;
                        break;
                    }
                }
            }
            if (!foundCt && _channels.size() > 0) {
                // Fallback to channel 0 if previous contact is no longer present on node
                isContactTarget = false;
                selectedContactId = null;
                selectedChannelIdx = _channels[0][:idx] as Number;
                selectedTargetName = _channels[0][:name] as String;
            }
        }
    }

    public static function getLastContactSyncTime() as Number {
        loadFromStorage();
        return _lastContactSyncTime;
    }

    public static function setLastContactSyncTime(t as Number) as Void {
        _lastContactSyncTime = t;
        saveToStorage();
    }

    public static function getChannels() as Array<Dictionary> {
        loadFromStorage();
        return _channels;
    }

    public static function getContacts() as Array<Dictionary> {
        loadFromStorage();
        return _contacts;
    }

    //! Returns only client / companion contacts, filtering out Repeaters (adv_type=2) and Sensors (adv_type=4)
    public static function getClientContacts() as Array<Dictionary> {
        loadFromStorage();
        var res = [] as Array<Dictionary>;
        for (var i = 0; i < _contacts.size(); i++) {
            var c = _contacts[i];
            var typeVal = (c.hasKey(:advType) && c[:advType] != null) ? (c[:advType] as Number) : 1;
            if (typeVal != 2 && typeVal != 4) {
                res.add(c);
            }
        }
        return res;
    }

    //! Returns count of client contacts (excluding Repeaters and Sensors)
    public static function getClientContactsCount() as Number {
        loadFromStorage();
        var count = 0;
        for (var i = 0; i < _contacts.size(); i++) {
            var c = _contacts[i];
            var typeVal = (c.hasKey(:advType) && c[:advType] != null) ? (c[:advType] as Number) : 1;
            if (typeVal != 2 && typeVal != 4) {
                count++;
            }
        }
        return count;
    }

    public static function selectChannel(idx as Number, name as String) as Void {
        selectedChannelIdx = idx;
        if (name.find("#") != 0) {
            selectedTargetName = "#" + name;
        } else {
            selectedTargetName = name;
        }
        isContactTarget = false;
        selectedContactId = null;
    }

    public static function selectContact(id as String, name as String) as Void {
        var cleanName = name;
        if (cleanName.find("@") == 0 || cleanName.find("#") == 0) {
            cleanName = cleanName.substring(1, cleanName.length());
        }
        selectedTargetName = cleanName;
        isContactTarget = true;
        selectedContactId = id;
    }

    public static function getTargetDisplayName() as String {
        return selectedTargetName;
    }

    private static function loadActivityTelemetryTarget() as Void {
        if (_activityTargetLoaded) {
            return;
        }
        _activityTargetLoaded = true;
        try {
            var stored = Storage.getValue(STORAGE_ACTIVITY_TARGET);
            if (stored == null || !(stored instanceof Dictionary)) {
                _activityTargetEnabled = false;
                _activityTargetName = "Senden Aus";
                return;
            }
            var target = stored as Dictionary;
            var enabled = target["enabled"];
            var isContact = target["isContact"];
            var channelIdx = target["channelIdx"];
            var contactId = target["contactId"];
            var name = target["name"];
            if (enabled instanceof Boolean) {
                _activityTargetEnabled = enabled as Boolean;
            } else {
                _activityTargetEnabled = false;
            }
            if (isContact instanceof Boolean) {
                _activityTargetIsContact = isContact as Boolean;
            }
            if (channelIdx instanceof Number) {
                _activityTargetChannelIdx = channelIdx as Number;
            }
            if (contactId instanceof String && (contactId as String).length() > 0) {
                _activityTargetContactId = contactId as String;
            }
            if (name instanceof String && (name as String).length() > 0) {
                _activityTargetName = name as String;
            }
            if (!_activityTargetEnabled) {
                _activityTargetName = "Senden Aus";
            } else if (_activityTargetIsContact && _activityTargetContactId == null) {
                _activityTargetIsContact = false;
                _activityTargetName = "#public";
            }
        } catch (e) {
            System.println("ContactManager: activity target read notice");
        }
    }

    private static function saveActivityTelemetryTarget() as Void {
        try {
            Storage.setValue(STORAGE_ACTIVITY_TARGET, {
                "enabled" => _activityTargetEnabled,
                "isContact" => _activityTargetIsContact,
                "channelIdx" => _activityTargetChannelIdx,
                "contactId" => (_activityTargetContactId != null) ? _activityTargetContactId : "",
                "name" => _activityTargetName
            });
        } catch (e) {
            System.println("ContactManager: activity target write notice");
        }
    }

    public static function hasActivityTelemetryTarget() as Boolean {
        loadActivityTelemetryTarget();
        return _activityTargetEnabled;
    }

    public static function disableActivityTelemetryTarget() as Void {
        _activityTargetLoaded = true;
        _activityTargetEnabled = false;
        _activityTargetName = "Senden Aus";
        saveActivityTelemetryTarget();
    }

    public static function isActivityTelemetryContactTarget() as Boolean {
        loadActivityTelemetryTarget();
        return _activityTargetIsContact;
    }

    public static function getActivityTelemetryChannelIdx() as Number {
        loadActivityTelemetryTarget();
        return _activityTargetChannelIdx;
    }

    public static function getActivityTelemetryContactId() as String? {
        loadActivityTelemetryTarget();
        return _activityTargetContactId;
    }

    public static function getActivityTelemetryTargetName() as String {
        loadActivityTelemetryTarget();
        return _activityTargetName;
    }

    public static function selectActivityTelemetryChannel(idx as Number, name as String) as Void {
        _activityTargetLoaded = true;
        _activityTargetEnabled = true;
        _activityTargetIsContact = false;
        _activityTargetChannelIdx = idx;
        _activityTargetContactId = null;
        _activityTargetName = (name.find("#") == 0) ? name : ("#" + name);
        saveActivityTelemetryTarget();
    }

    public static function selectActivityTelemetryContact(id as String, name as String) as Void {
        _activityTargetLoaded = true;
        _activityTargetEnabled = true;
        _activityTargetIsContact = true;
        _activityTargetContactId = id;
        _activityTargetName = (name.find("@") == 0) ? name.substring(1, name.length()) : name;
        saveActivityTelemetryTarget();
    }

    public static function addChannel(idx as Number, name as String) as Void {
        loadFromStorage();
        var chName = (name.find("#") == 0) ? name : ("#" + name);
        for (var i = 0; i < _channels.size(); i++) {
            if (_channels[i][:idx] == idx) {
                _channels[i][:name] = chName;
                saveToStorage();
                return;
            }
        }
        _channels.add({ :name => chName, :idx => idx });
        saveToStorage();
    }

    public static function addContact(id as String, name as String, advType as Number?) as Void {
        loadFromStorage();
        var cleanName = name;
        if (cleanName.find("@") == 0 || cleanName.find("#") == 0) {
            cleanName = cleanName.substring(1, cleanName.length());
        }
        var typeVal = (advType != null) ? advType : 1;
        for (var i = 0; i < _contacts.size(); i++) {
            if (_contacts[i][:id].equals(id)) {
                _contacts[i][:name] = cleanName;
                _contacts[i][:advType] = typeVal;
                saveToStorage();
                return;
            }
        }
        _contacts.add({ :name => cleanName, :id => id, :isChannel => false, :advType => typeVal });
        saveToStorage();
    }

    public static function getContactById(id as String) as Dictionary? {
        loadFromStorage();
        var upperId = id.toUpper();
        for (var i = 0; i < _contacts.size(); i++) {
            var ct = _contacts[i];
            var ctId = ct[:id] as String;
            if (ctId != null && ctId.toUpper().equals(upperId)) {
                return ct;
            }
        }
        return null;
    }
}
