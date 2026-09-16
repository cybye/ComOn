import Toybox.Lang;
import Toybox.System;
import Toybox.Application.Storage;

class ContactManager {
    public static var selectedChannelIdx as Number = 0;
    public static var selectedTargetName as String = "Kanal: Public";
    public static var isContactTarget as Boolean = false;
    public static var selectedContactId as String? = null;

    private static const STORAGE_CHANNELS as String = "cfg_cached_channels";
    private static const STORAGE_CONTACTS as String = "cfg_cached_contacts";
    private static const STORAGE_SYNC_TIME as String = "cfg_last_contact_sync";

    private static var _initialized as Boolean = false;
    private static var _lastContactSyncTime as Number = 0;

    private static var _channels as Array<Dictionary> = [
        { :name => "Public (Kanal 0)", :idx => 0 },
        { :name => "Notruf Kanal", :idx => 1 },
        { :name => "Team Kanal", :idx => 2 }
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
                _channels = cachedCh as Array<Dictionary>;
            }

            var cachedCt = Storage.getValue(STORAGE_CONTACTS);
            if (cachedCt != null && (cachedCt instanceof Array) && (cachedCt as Array).size() > 0) {
                _contacts = cachedCt as Array<Dictionary>;
            }

            var syncT = Storage.getValue(STORAGE_SYNC_TIME);
            if (syncT != null && (syncT instanceof Number)) {
                _lastContactSyncTime = syncT as Number;
            }
        } catch (e) {
            System.println("ContactManager storage read error");
        }
    }

    public static function saveToStorage() as Void {
        try {
            Storage.setValue(STORAGE_CHANNELS, _channels);
            Storage.setValue(STORAGE_CONTACTS, _contacts);
            Storage.setValue(STORAGE_SYNC_TIME, _lastContactSyncTime);
        } catch (e) {
            System.println("ContactManager storage write error");
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
        selectedTargetName = name;
        isContactTarget = false;
        selectedContactId = null;
    }

    public static function selectContact(id as String, name as String) as Void {
        selectedTargetName = name;
        isContactTarget = true;
        selectedContactId = id;
    }

    public static function getTargetDisplayName() as String {
        return selectedTargetName;
    }

    public static function addChannel(idx as Number, name as String) as Void {
        loadFromStorage();
        for (var i = 0; i < _channels.size(); i++) {
            if (_channels[i][:idx] == idx) {
                return;
            }
        }
        _channels.add({ :name => name, :idx => idx });
        saveToStorage();
    }

    public static function addContact(id as String, name as String) as Void {
        loadFromStorage();
        for (var i = 0; i < _contacts.size(); i++) {
            if (_contacts[i][:id].equals(id)) {
                _contacts[i][:name] = name;
                saveToStorage();
                return;
            }
        }
        _contacts.add({ :name => name, :id => id, :isChannel => false });
        saveToStorage();
    }
}
