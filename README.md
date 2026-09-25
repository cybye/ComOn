# ComOn — Garmin Connect IQ LoRa Mesh Communicator

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![Connect IQ](https://img.shields.io/badge/Connect_IQ-v5.1%2B-blue)](https://developer.garmin.com/connect-iq/)
[![Platform](https://img.shields.io/badge/Garmin-F%C3%A9nix%208-orange)](manifest.xml)

**ComOn** is a full-featured Garmin Connect IQ watch app and telemetry companion designed for off-grid LoRa mesh networks (such as MeshCore nodes). It provides standalone two-way tactical messaging, real-time node monitoring, emergency beaconing (SOS), and background inbox synchronisation directly on Garmin multisport smartwatches.

**This app currently only connects with a patched meshcore firmware. PIN authentication is not supported by Connect IQ and missing message chunking in the standard meshcore firmware limits functionality.**

## Key Features

- **Decentralized Messaging:**
  - Full channel and direct message (1:1) chat views.
  - Interactive multi-line chat bubbles with timestamps, unread badges, and delivery states.
  - Canned quick replies, direct text input, and location sharing.
- **Resilient BLE Protocol Stack:**
  - Seamless auto-reconnect and session synchronisation via Nordic UART Service (NUS).
  - Multi-tier background syncing, auto inbox polling, and low-battery alerts for remote nodes.
  - Hardware node release option to hand off connection to mobile apps without unpairing.
- **Off-Grid SOS & Emergency Mode:**
  - 5-second abort countdown to prevent accidental transmissions.
  - Automated repeating emergency beacons with GPS coordinates, vitals, and emergency telemetry.
- **Sensor Telemetry & FIT Wardriving:**
  - Real-time heart rate, cadence, barometric pressure, GPS fix status, and node battery monitoring.
  - Connect IQ DataField integration (`ComOnDatafield`) recording RF metrics (LoRa RSSI, SNR, peer count, node battery) directly into standard Garmin `.FIT` activity files.
- **Embedded Simulation Twin:**
  - Built-in Virtual Mesh Node simulator for rapid desk testing and UI verification without physical radio hardware.

---

## Supported Devices

- Garmin Fénix 8 43mm
- Garmin Fénix 8 47mm
- Garmin Fénix 8 Pro 47mm
- Garmin Fénix 8 Solar 47mm
- Garmin Fénix 8 Solar 51mm

*(Connect IQ System 7 / API Level 5.1.0+)*

---

## Repository Structure

```text
ComOn/
├── .vscode/               # VS Code Connect IQ launch configurations
├── docs/
│   └── MENU_GUIDE.md      # In-depth menu navigation and view hierarchy
├── resources/             # Shared drawables, strings (English default), layouts
├── resources-deu/         # German localization strings
├── source/
│   ├── background/        # Background service delegate & periodic inbox poller
│   ├── ble/               # Bluetooth Low Energy profile, NUS delegate & packet parser
│   ├── notifications/     # Glanceable system notification wrappers
│   ├── protocol/          # MeshCore binary framing, commands & simulation twin
│   ├── telemetry/         # FIT Developer field registry and sensor monitor
│   ├── ui/                # Views, delegates, custom keyboards & chat thread views
│   ├── util/              # Byte buffers, math, and string formatters
│   ├── MeshCoreApp.mc     # Watch-app entry point
│   └── MeshCoreDataFieldApp.mc # Connect IQ DataField entry point
├── architecture_arc42.md  # Comprehensive arc42 architectural documentation
├── datafield.jungle       # Jungle build file for the DataField target
├── manifest.xml           # Watch-app manifest (permissions, targets, languages)
├── manifest_df.xml        # DataField manifest
├── monkey.jungle          # Watch-app jungle configuration
├── LICENSE                # Apache License 2.0
└── README.md
```

---

## Getting Started & Building

### Prerequisites
1. **Garmin Connect IQ SDK** (v7.x+ / API Level 5.1.0+).
2. **VS Code** with the official **Monkey C** extension.
3. A valid Garmin developer key (`developer_key.der`). Note: Never commit your developer key to public repositories.

### Building via Command Line
Compile the watch application using `monkeyc`:

```bash
monkeyc -d fenix847mm \
        -f monkey.jungle \
        -o bin/ComOn.prg \
        -y /path/to/developer_key.der
```

To compile the background DataField:

```bash
monkeyc -d fenix847mm \
        -f datafield.jungle \
        -o bin/ComOnDataField.prg \
        -y /path/to/developer_key.der
```

---

## Documentation

For full architectural blueprints, data structures, ADRs (Architecture Decision Records), and design rationale, please refer to [`architecture_arc42.md`](architecture_arc42.md).
For detailed menu and touch UX workflows, see [`docs/MENU_GUIDE.md`](docs/MENU_GUIDE.md).

---

## License

ComOn is licensed under the **Apache License, Version 2.0**. See the [LICENSE](LICENSE) file for terms and conditions.
