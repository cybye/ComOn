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
    private static const STORAGE_SYNC_TIME as String = "cfg_last_contact_sync";
    private static const STORAGE_PAIRED_NODE as String = "cfg_paired_node_id";

    private static var _initialized as Boolean = false;
    private static var _lastContactSyncTime as Number = 0;
    private static var _pairedNodeId as String? = null;

    private static var _inFullSync as Boolean = false;
    private static var _syncingChannels as Array<Dictionary> = [] as Array<Dictionary>;
    private static var _syncingContacts as Array<Dictionary> = [] as Array<Dictionary>;

    private static var _channels as Array<Dictionary> = [
        { :name => "#public", :idx => 0 },
        { :name => "#notruf", :idx => 1 },
        { :name => "#team", :idx => 2 }
    ];

    private static var _contacts as Array<Dictionary> = [
        { :name => "Alle (Broadcast)", :id => "ALL", :isChannel => true, :idx => 0 },
        { :name => "Basisstation", :id => "NODE_BASE", :isChannel => false },
        { :name => "Florian", :id => "NODE_FLO", :isChannel => false },
        { :name => "Begleiter 1", :id => "NODE_COMP1", :isChannel => false }
    ];

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
                    loadedCt.add({
                        :name => ctName,
                        :id => itemCt["id"],
                        :isChannel => itemCt["isChannel"],
                        :idx => itemCt["idx"]
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
                    "idx" => (ct[:idx] != null) ? ct[:idx] : 0
                });
            }

            Storage.setValue(STORAGE_CHANNELS, chList);
            Storage.setValue(STORAGE_CONTACTS, ctList);
            Storage.setValue(STORAGE_SYNC_TIME, _lastContactSyncTime);
            if (_pairedNodeId != null) {
                Storage.setValue(STORAGE_PAIRED_NODE, _pairedNodeId);
            }
        } catch (e) {
            System.println("ContactManager storage write notice");
        }
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
            System.println("ContactManager: Node changed from '" + _pairedNodeId + "' to '" + currentNodeId + "' -> Triggering Full Sync");
            _pairedNodeId = currentNodeId;
            _lastContactSyncTime = 0;
            saveToStorage();
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

    public static function addSyncContact(id as String, name as String) as Void {
        var cleanName = name;
        if (cleanName.find("@") == 0 || cleanName.find("#") == 0) {
            cleanName = cleanName.substring(1, cleanName.length());
        }
        for (var i = 0; i < _syncingContacts.size(); i++) {
            if (_syncingContacts[i][:id].equals(id)) {
                _syncingContacts[i][:name] = cleanName;
                return;
            }
        }
        _syncingContacts.add({ :name => cleanName, :id => id, :isChannel => false });
    }

    public static function commitFullSync() as Void {
        if (_inFullSync) {
            if (_syncingChannels.size() > 0) {
                _channels = _syncingChannels;
            }
            if (_syncingContacts.size() > 0) {
                _contacts = _syncingContacts;
            }
            _inFullSync = false;
            _lastContactSyncTime = Time.now().value();
            validateSelection();
            saveToStorage();
            System.println("ContactManager: Full Sync committed (" + _channels.size() + " channels, " + _contacts.size() + " contacts)");
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

    public static function addContact(id as String, name as String) as Void {
        loadFromStorage();
        var cleanName = name;
        if (cleanName.find("@") == 0 || cleanName.find("#") == 0) {
            cleanName = cleanName.substring(1, cleanName.length());
        }
        for (var i = 0; i < _contacts.size(); i++) {
            if (_contacts[i][:id].equals(id)) {
                _contacts[i][:name] = cleanName;
                saveToStorage();
                return;
            }
        }
        _contacts.add({ :name => cleanName, :id => id, :isChannel => false });
        saveToStorage();
    }
}
