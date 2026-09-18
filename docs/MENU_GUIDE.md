# Mesh Companion: Dokumentation der Menüführung & UI-Navigation

Diese Dokumentation beschreibt die vollständige Navigations- und Menühierarchie der Garmin Smartwatch-App **Mesh Companion** (inklusive Touch-Gesten, Tastenbelegung und Aktivitäts-Datenfeld).

> [!NOTE]
> **Aktualität:** Dieses Dokument wird bei jeder Änderung an Menüs, Screens oder Tasten-Delegates synchron mit der Codebasis gepflegt.

---

## 1. Visuelle Navigationsübersicht (Mermaid Flowchart)

```mermaid
flowchart TD
    Dashboard["<b>1. Hauptbildschirm (Dashboard)</b>\n• Statuszeile (Pill, Node, Ziel)\n• Letzte Nachricht (Kartenmodul)\n• Footer: Node-Akku | RSSI | Peers"]

    %% Aktionen vom Dashboard
    Dashboard -->|Taste START (2 Uhr)\nTaste MENU (9 Uhr)| MainMenu["<b>2. Hauptmenü</b>\n1. Chats\n2. Nachricht senden\n3. Position senden\n4. SOS Notruf\n5. Einstellungen\n6. Beenden"]
    Dashboard -->|Tap auf Chat-Karte| MsgActionMenu["<b>3. Nachrichten-Aktionen</b>\n• Antworten (Tastatur)\n• Schnellantwort\n• Standort senden\n• 1:1 Direktnachricht"]
    Dashboard -->|Wisch Links / START| ChatThread["<b>4. Chat-Verlauf (Thread)</b>\n• Scrollbare Nachrichten\n• Eigene (rechts) / Fremde (links)\n• Status: [Wartet auf Node]\n• <b>[Antworten]</b> Button"]

    %% Hauptmenü Verzweigungen
    MainMenu -->|1. Chats| ChatsMenu["<b>5. Chats-Menü</b>\n• <b>[Aktiv]</b> steht ganz oben!\n• Kanäle (#public, #notruf, ...)\n• Kontakte (Basisstation, Florian, ...)"]
    MainMenu -->|2. Nachricht senden| CannedMenu["<b>6. Schnellantworten / Canned</b>\n• Freitext schreiben...\n• Alles OK\n• Am Treffpunkt\n• Verspätung 15/30 Min\n• Brauche Hilfe\n• Funkprobe"]
    MainMenu -->|3. Position senden| SendPos["<b>GPS-Sofortversand</b>\nSendet aktuellen Fix & Vitaldaten\nan das aktive Ziel"]
    MainMenu -->|4. SOS Notruf| SosView["<b>7. SOS Notruf Screen</b>\n• 5s Countdown (Pulsierender Ring)\n• Vital- & GPS-Telemetriekarte\n• Zyklischer 60s Auto-Repeat"]
    MainMenu -->|5. Einstellungen| Settings["<b>8. Einstellungen</b>\n• Tastatur-Typ\n• Hintergrund-Prüfung\n• Wardriving FIT-Log\n• Telemetrie-Format\n• Node koppeln\n• Node neu synchronisieren\n• Node freigeben (BLE)\n• Virtueller Node Sim"]
    MainMenu -->|6. Beenden| Exit["App beenden &\nBackground-Check schärfen"]

    %% Chat Thread Interaktionen
    ChatThread -->|<b>Touch auf grünen Button</b>| Keyboard["<b>Freitext-Tastatur</b>\n(QWERTY, SMS T9 oder Radial T9)"]
    ChatThread -->|<b>Hardware-Taste START/ENTER</b>| CannedMenu
    ChatThread -->|Taste BACK / Wisch Rechts| Dashboard

    %% Settings Verzweigungen
    Settings -->|Tastatur-Typ| KeySettings["<b>Tastatur-Auswahl</b>\n• Vollbild-QWERTY\n• SMS T9 (3x4)\n• Radial T9"]
    Settings -->|Node freigeben (BLE)| ReleaseBLE["<b>BLE-Freigabe (3 Min)</b>\nunpairDevice() -> Freie Bahn für\nT-1000E Smartphone-App"]
    Settings -->|Virtueller Node Sim| NodeSim["<b>9. Node-Simulator</b>\n• Offline-Puffer füllen (3 Msgs)\n• Funkspruch / SOS einspeisen\n• Neuer Kontakt (Delta)\n• Echo-Modus AN/AUS"]
    Settings -->|Node neu synchronisieren| FullSync["<b>5-Stufen Session-Sync</b>\nInbox -> Time -> Channels ->\nContacts -> Battery"]

    %% Verknüpfungen
    ChatsMenu -->|Chat auswählen| ChatThread
    MsgActionMenu -->|Antworten (Tastatur)| Keyboard
    MsgActionMenu -->|Schnellantwort| CannedMenu
```

---

## 2. Detaillierte Bildschirm- & Menü-Referenz

### 2.1 Hauptbildschirm (`DashboardView` & `DashboardDelegate`)

Der primäre Kontrollbildschirm beim Starten der App.

| Element / Interaktion | Eingabemethode | Aktion / Auswirkung |
|---|---|---|
| **Status-Pill (oben)** | Nur Anzeige | Zeigt Verbindungsstatus (`Bereit`, `Suche...`, `Verbunden`, `Offline`). |
| **Ziel-Badge (oben rechts)** | Nur Anzeige | Zeigt das aktive Sendeziel (z. B. `[#public]` oder `[Florian]`). |
| **Chat-Kartenmodul (Mitte)** | **Tap auf Karte** | Öffnet das **Nachrichten-Aktionsmenü** (Schnellantwort, Standort, Tastatur). |
| **Karten-Auswahl** | **Taste START (2 Uhr)** | Öffnet bei fokussierter Karte den vollen Chatverlauf (`ChatThreadView`). |
| **Menü-Aufruf** | **Taste START / MENU (9 Uhr)** | Öffnet das **Hauptmenü** (`openMainMenu()`). |
| **Akzentbogen (2 Uhr)** | Nur Anzeige | Gelber/Oranger Bogen weist haptisch/visuell auf die START-Taste hin. |
| **Statuszeile (unten)** | Nur Anzeige | **[Remote Node Akku %]** \| **[LoRa RSSI dBm]** \| **[Mesh Peers]**. |

---

### 2.2 Hauptmenü (`openMainMenu()`)

Wird durch Druck auf START (2 Uhr) oder MENÜ (9 Uhr) geöffnet.

| Menüpunkt | Untertitel | Ziel-Aktion |
|---|---|---|
| **1. Chats** | `Aktiv: <Aktuelles Ziel>` | Öffnet die Chat-Übersicht (`ChatsMenu`). |
| **2. Nachricht senden** | `Aus Liste` | Öffnet die Vorlagenliste (`CannedMessageMenu`). |
| **3. Position senden** | `GPS + Vitals` | Sendet sofort Koordinaten + Vitaldaten an das aktive Ziel. |
| **4. SOS Notruf** | `Notfall-Broadcast` | Startet den Notruf-Ablauf (`SosView`) auf Notfallkanal 0. |
| **5. Einstellungen** | `Tastatur, Node...` | Öffnet das Einstellungsmenü (`SettingsMenu`). |
| **6. Beenden** | - | Schließt die App; aktiviert zyklischen 5-Min-Hintergrund-Check. |

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
