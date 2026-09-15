import Toybox.Lang;
import Toybox.Application.Storage;

class ContactManager {
    public static var selectedChannelIdx as Number = 0;
    public static var selectedTargetName as String = "Kanal: Public";
    public static var isContactTarget as Boolean = false;
    public static var selectedContactId as String? = null;

    private static var _channels as Array<Dictionary> = [
        { :name => "Public (Kanal 0)", :idx => 0 },
        { :name => "Notruf Kanal", :idx => 1 },
        { :name => "Team Kanal", :idx => 2 }
    ];

    private static var _contacts as Array<Dictionary> = [
        { :name => "Alle (Broadcast)", :id => "ALL", :isChannel => true, :idx => 0 },
        { :name => "Basisstation", :id => "NODE_BASE", :isChannel => false },
        { :name => "Begleiter 1", :id => "NODE_COMP1", :isChannel => false }
    ];

    public static function getChannels() as Array<Dictionary> {
        return _channels;
    }

    public static function getContacts() as Array<Dictionary> {
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
}
