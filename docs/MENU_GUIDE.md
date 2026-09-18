# Mesh Companion: Dokumentation der Menüführung & UI-Navigation

Diese Dokumentation beschreibt die vollständige Navigations- und Menühierarchie der Garmin Smartwatch-App **Mesh Companion** (inklusive Touch-Gesten, Tastenbelegung und Aktivitäts-Datenfeld).

> [!NOTE]
> **Aktualität:** Dieses Dokument wird bei jeder Änderung an Menüs, Screens oder Tasten-Delegates synchron mit der Codebasis gepflegt.

---

## 1. Visuelle Navigationsübersicht (Mermaid Flowchart)

```mermaid
flowchart TD
    Dashboard["<b>1. Hauptbildschirm: Seite 0 (Chat & Dashboard)</b>\n• Statuszeile (Pill, Node, Ziel)\n• Letzte Nachricht (Kartenmodul)\n• Footer: Node-Akku | RSSI | Peers\n• <b>START (2 Uhr)</b>: Chat-Verlauf öffnen\n• <b>MENU (9 Uhr)</b>: Hauptmenü"]

    %% Aktionen von Seite 0
    Dashboard -->|<b>Taste START (2 Uhr)</b>\nTap auf Chat-Karte\nWisch nach Links| ChatThread["<b>Chat-Verlauf (Thread)</b>\n• Scrollbare Nachrichten\n• Eigene (rechts) / Fremde (links)\n• <b>1 Klick im Chat!</b>\n• <b>[Antworten]</b> Button"]
    
    Dashboard -->|<b>Taste MENU (9 Uhr)</b>| MainMenu["<b>Hauptmenü (Optionen)</b>\n1. Chats\n2. SOS Notruf\n3. Einstellungen\n4. Beenden"]

    Dashboard -->|<b>Taste DOWN (7 Uhr)</b>\nWisch nach Oben| TelemPage["<b>2. Hauptbildschirm: Seite 1 (Telemetrie & GPS)</b>\n• 2x2 Kacheln: HF, GPS, Schritte, Akku\n• <b>START (2 Uhr)</b>: Position sofort senden!\n• Navigation: UP zurück zu Seite 0"]

    TelemPage -->|<b>Taste DOWN (7 Uhr)</b>\nWisch nach Oben| SosPage["<b>3. Hauptbildschirm: Seite 2 (SOS Notruf Prompt)</b>\n• Rote Notruf-Aktionskarte\n• Roter 2-Uhr-Akzentbogen\n• <b>START (2 Uhr) / Tap</b>: Notruf auslösen!\n• Navigation: UP zurück zu Seite 1"]

    Dashboard -->|<b>Tap auf Ziel-Badge [#public]</b>| ChatsMenu["<b>Chats-Menü</b>\n• <b>[Aktiv]</b> steht ganz oben!\n• Kanäle (#public, #notruf, ...)\n• Kontakte (Basisstation, Florian, ...)"]

    %% Hauptmenü Verzweigungen
    MainMenu -->|1. Chats| ChatsMenu
    MainMenu -->|2. SOS Notruf| SosView["<b>SOS Notruf Screen</b>\n• 5s Countdown (Pulsierender Ring)\n• Vital- & GPS-Telemetriekarte\n• Zyklischer 60s Auto-Repeat"]
    MainMenu -->|3. Einstellungen| Settings["<b>Einstellungen</b>\n• Tastatur-Typ\n• Hintergrund-Prüfung\n• Wardriving FIT-Log\n• Telemetrie-Format\n• Node koppeln\n• Node neu synchronisieren\n• Node freigeben (BLE)\n• Virtueller Node Sim"]
    MainMenu -->|4. Beenden| Exit["App beenden &\nBackground-Check schärfen"]

    %% SOS Page Verzweigung
    SosPage -->|<b>Taste START (2 Uhr)</b>\nTap auf Karte| SosView

    %% Chat Thread Interaktionen
    ChatThread -->|<b>Touch auf grünen Button</b>| Keyboard["<b>Freitext-Tastatur</b>\n(QWERTY, SMS T9 oder Radial T9)"]
    ChatThread -->|<b>Hardware-Taste START/ENTER</b>| CannedMenu["<b>Schnellantworten / Canned</b>\n• Alles OK\n• Am Treffpunkt\n• Verspätung 15/30 Min\n• Brauche Hilfe / Funkprobe"]
    ChatThread -->|Taste BACK / Wisch Rechts| Dashboard

    %% Telemetrie Interaktion
    TelemPage -->|Taste START| SendPosDirect["<b>Sofortiger LoRa-Versand</b>\n(DOWN + START = 2 Tastendrücke)"]
    TelemPage -->|Taste UP / BACK| Dashboard

    %% Settings Verzweigungen
    Settings -->|Tastatur-Typ| KeySettings["<b>Tastatur-Auswahl</b>\n• Vollbild-QWERTY\n• SMS T9 (3x4)\n• Radial T9"]
    Settings -->|Node freigeben (BLE)| ReleaseBLE["<b>BLE-Freigabe (3 Min)</b>\nunpairDevice() -> Freie Bahn für\nT-1000E Smartphone-App"]
    Settings -->|Virtueller Node Sim| NodeSim["<b>Node-Simulator</b>\n• Offline-Puffer füllen (3 Msgs)\n• Funkspruch / SOS einspeisen\n• Neuer Kontakt (Delta)\n• Echo-Modus AN/AUS"]
    Settings -->|Node neu synchronisieren| FullSync["<b>5-Stufen Session-Sync</b>\nInbox -> Time -> Channels ->\nContacts -> Battery"]

    %% Verknüpfungen
    ChatsMenu -->|Chat auswählen| ChatThread
```

---

## 2. Detaillierte Bildschirm- & Menü-Referenz

### 2.1 Hauptseiten (`DashboardView` & `DashboardDelegate`)

Der Hauptbildschirm umfasst **3 Seiten**, die intuitiv über die Hardware-Tasten **DOWN (7 Uhr)** und **UP (9 Uhr)** bzw. vertikale Wischgesten umgeschaltet werden:

#### Seite 0: Chat & Dashboard (`pageIndex == 0`)
* **Taste START (2 Uhr):** Öffnet **sofort den aktiven Chat-Verlauf** (`ChatThreadView`). *Nur 1 Klick!*
* **Taste MENU (9 Uhr):** Öffnet das **Hauptmenü** (`openMainMenu()`).
* **Taste DOWN (7 Uhr) / Wisch nach oben:** Wechselt zu **Seite 1 (Telemetrie & GPS)**.
* **Tap auf Ziel-Badge (`[#public]`):** Öffnet direkt die Chat- und Kanalliste (`ChatsMenu`).
* **Tap auf Chat-Karte / Wisch nach links:** Öffnet direkt den Chat-Verlauf (`ChatThreadView`).
* **Statuszeile:** **[Remote Node Akku %]** \| **[LoRa RSSI dBm]** \| **[Mesh Peers]**.
* **Navigations-Indikator:** Nach unten zeigendes Dreieck am unteren Rand.

#### Seite 1: Telemetrie & Sensoren (`pageIndex == 1`)
* **Taste START (2 Uhr):** **Sendet sofort GPS-Koordinaten + Vitaldaten** an das aktive Ziel (`sendPositionDirect()`). *Kein Menü nötig!*
* **Taste DOWN (7 Uhr) / Wisch nach oben:** Wechselt zu **Seite 2 (SOS Notruf)**.
* **Taste UP (9 Uhr) / Taste BACK (4 Uhr) / Wisch nach rechts:** Zurück zu **Seite 0 (Chat)**.
* **Anzeige:** 2x2 Kacheln (Herzfrequenz, GPS-Fix-Status, Schritte, Akku).
* **Navigations-Indikatoren:** Dreiecke oben (UP) und unten (DOWN).

#### Seite 2: SOS Notruf Prompt (`pageIndex == 2`)
* **Taste START (2 Uhr) / Tap auf Notruf-Karte:** Startet **sofort die Notruf-Sequenz** (`SosView` mit 5s Countdown).
* **Taste UP (9 Uhr) / Taste BACK (4 Uhr) / Wisch nach rechts:** Zurück zu **Seite 1 (Telemetrie)**.
* **Anzeige (1:1 identisches Layout wie im späteren Notruf-Modus):**
  * **Header:** `SOS NOTRUF` bei `y = 72` (`FONT_SYSTEM_TINY`, Rot).
  * **Notfall-Telemetriekarte (`cardY = 120`, `cardH = 196`):**
    * Titel `NOTFALL-TELEMETRIE` in Rot.
    * Zeile 1: Live-GPS-Koordinaten (Gelb) oder `Warte auf GPS-Fix...`.
    * Zeile 2: Vitaldaten & Höhe (`245m | 72 bpm | 1420 Stp`).
    * Zeile 3: `Kanal 0 (Broadcast)` in Hellgrau.
    * Zeile 4: `* 60s Auto-Beacon` in Grün.
  * **Aktions-Hinweis (unten bei `height - 68`):** `START: Notruf starten` zentriert in der AMOLED-Safezone.
* **Optisches Highlight:** Roter Akzentbogen bei 2 Uhr (`Graphics.COLOR_RED`, 4px Strichstärke).
* **Navigations-Indikator:** Nach oben zeigendes Dreieck am oberen Rand.

---

### 2.2 Hauptmenü (`openMainMenu()`)

Wird durch Druck auf **MENÜ (9 Uhr)** auf Seite 0 geöffnet. Durch die Auslagerung des Standortversands auf Seite 1 (DOWN + START) ist das Menü maximal verschlankt und verzögerungsfrei:

| Menüpunkt | Untertitel | Ziel-Aktion |
|---|---|---|
| **1. Chats** | `Aktiv: <Aktuelles Ziel>` | Öffnet die Chat-Übersicht (`ChatsMenu`) zur Zielauswahl. |
| **2. SOS Notruf** | `Notfall-Broadcast` | Redundanter Schnellzugriff auf Notruf (`SosView`) auf Notfallkanal 0. |
| **3. Einstellungen** | `Tastatur, Node...` | Öffnet das Einstellungsmenü (`SettingsMenu`). |
| **4. Beenden** | - | Schließt die App; aktiviert zyklischen 5-Min-Hintergrund-Check. |

---

### 2.3 Chat-Übersicht (`ChatsMenu`)

Verwaltung aller Kommunikationskanäle und 1:1 Kontakte.

* **Besonderheit (Dynamische Priorisierung):** Der aktuell **aktive Chat** wird automatisch an **Position 1 (ganz oben)** platziert und mit dem Badge `[Aktiv]` gekennzeichnet.
* **Gruppenkanäle:** Erscheinen immer mit führendem `#` (z. B. `#public`, `#notruf`, `#team`).
* **1:1 Kontakte:** Erscheinen mit Klarnamen ohne Sonderzeichen (z. B. `Basisstation`, `Florian`, `Begleiter 1`).
* **Ungelesene Nachrichten:** Werden mit Badge `[X neu]` signalisiert.
* **Auswahl:** Setzt das Ziel in `ContactManager` und öffnet direkt den Verlauf (`ChatThreadView`).

---

### 2.4 Chat-Verlauf (`ChatThreadView` & `ChatThreadDelegate`)

Vollständige Konversationsansicht für das ausgewählte Ziel.

| Interaktion | Steuerung | Verhalten |
|---|---|---|
| **Freitext-Antwort** | **Touch auf grünen [Antworten] Button** | Öffnet **sofort die Tastatur** (`KeyboardHelper.openKeyboard`). |
| **Schnellantwort** | **Hardware-Taste START (2 Uhr)** | Öffnet die Schnellantwort-Vorlagen (`CannedMessageMenu`). |
| **Scrollen** | **Wisch Geste / Tasten UP / DOWN** | Blättert durch ältere/neuere Nachrichten. |
| **Zurück** | **Taste BACK / Wisch Rechts** | Kehrt zum Dashboard zurück. |
| **Offline-Spooling** | Automatisch | Nachrichten erhalten bei getrennter Node den Vermerk `[Wartet auf Node]` und werden bei Reconnect automatisch nachgesendet. |

---

### 2.5 Nachrichten-Aktionen (`MessageActionMenu`)

Erscheint beim direkten Antippen der Nachrichtenvorschau auf dem Hauptbildschirm.

1. **`Antworten (Tastatur)`:** Öffnet direkt die Freitext-Tastatur für diesen Chat.
2. **`Schnellantwort`:** Öffnet die Vorlagenliste.
3. **`Standort senden`:** Sendet aktuelle GPS-Position als Antwort.
4. **`1:1 Direktnachricht`:** *(Nur bei Nachrichten von Einzelpersonen)* Schaltet das globale Sendeziel auf diesen Absender um.

---

### 2.6 Einstellungen (`SettingsMenu` & `SettingsDelegate`)

Zentrale Konfiguration für Hardware, Funk und UI.

| Menüpunkt | Mögliche Werte | Beschreibung |
|---|---|---|
| **Tastatur-Typ** | `Vollbild-QWERTY`<br>`SMS T9 (3x4)`<br>`Radial T9` | Wählt die bevorzugte Eingabemethode für Freitext. |
| **Hintergrund-Prüfung** | `5 Min (Standard)`<br>`15 Min`<br>`30 Min`<br>`1 Std`<br>`Aus` | Intervall für `Toybox.Background`. Prüft bei geschlossener App das Postfach und meldet Nachrichten per Push-Benachrichtigung. |
| **Wardriving FIT-Log** | `Aktiv (AN)`<br>`Inaktiv (AUS)` | Zeichnet LoRa RSSI, SNR und Peer-Count synchron zum GPS-Track in `.fit`-Dateien auf (für MeshMapper.net). |
| **Telemetrie-Format** | `Kompakt-Binär`<br>`Chat-Text` | **Kompakt-Binär (15B):** Minimalste LoRa-Airtime.<br>**Chat-Text:** Lesbar in öffentlichen Chaträumen. |
| **Node koppeln** | Sub: `Bluetooth Suche` | Beendet eventuelle Scan-Pausen (`resumeScan`) und startet den BLE-Suchlauf. |
| **Node neu synchronisieren** | Sub: `Kanäle & Kontakte neu laden` | Forciert den **5-Stufen Session-Sync** von der Node (löscht veraltete Caches atomar). |
| **Node freigeben (BLE)** | Sub: `Verbindung für Smartphone trennen` | Trennt BLE via `unpairDevice()` und pausiert den Auto-Scan für 3 Minuten $\rightarrow$ ermöglicht sofortige Verbindung der Smartphone-App (z. B. Seeed T-1000E). |
| **Virtueller Node Sim** | Sub: `Test-Bench` | Öffnet das Test-Menü für Simulationen ohne Funkhardware. |

---

### 2.7 SOS Notruf (`SosView` & `SosDelegate`)

Lebensrettende Notfallfunktion mit Absicherung gegen Fehlbedienung.

```text
[ START SOS ] 
      │
      ▼
Phase 1: 5-Sekunden Countdown
  • Roter pulsierender Ring mit großem Zähler (5..4..3..2..1)
  • Taste BACK: Bricht sofort ab (kein Funkverkehr)
  • Taste START: Überspringt Countdown und sendet sofort
      │
      ▼
Phase 2: Notruf aktiv (LoRa Broadcast auf Kanal 0)
  • Rote Notfall-Karte: GPS-Koordinaten, Höhe, Herzfrequenz, Schritte
  • Live Auto-Repeat: Countdown zählt ab 60s herunter
  • Bei 0s: Erneuter Notruf-Aussand mit Vibrations-Bestätigung
  • Taste BACK: Schließt Notruf-Screen (Notruf sendet im Hintergrund weiter)
```

---

## 3. Tastatur-Typen im Überblick

Über **Einstellungen $\rightarrow$ Tastatur-Typ** wählbar:

1. **Vollbild-QWERTY:** Vollständiges Tastenfeld mit Touch-Bedienung. Optimal für schnelle Eingaben auf AMOLED-Displays.
2. **SMS T9 (3x4):** Klassische Mobiltelefon-Tastatur (`ABC`, `DEF`, `GHI` ...). Sehr große Trefferflächen für Handschuhe oder ruppige Bedingungen.
3. **Radial T9:** Zirkuläre Anordnung entlang der Uhrenlünette. Ideal für Dreh- und Wischgesten.

---

## 4. Aktivitäts-Datenfeld (`MeshCompanionField`)

Wird während Sportaktivitäten (Wandern, Trailrunning, Bike) als reguläre Datenfeldseite eingebunden:
* **Display:** Pixel-identisches AMOLED-Kartenmodul mit Signalbalken, Node-Akkustand und Beacon-Timer.
* **Menü auf Datenfeldseite (Taste MENÜ lange drücken):**
  * Ermöglicht die Wahl des Zielkanals oder Empfängers für die automatische Telemetrie-Aussendung (Smart Beaconing bei Bewegung alle 60s, bei Stillstand alle 300s).
