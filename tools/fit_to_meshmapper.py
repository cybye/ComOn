#!/usr/bin/env python3
"""
MeshCore Garmin FIT to MeshMapper CSV Converter
================================================
Extracts GPS trackpoints and MeshCore LoRa developer fields (RSSI, SNR, Peers)
from Garmin .FIT activity files and exports them into the standard MeshMapper CSV format
for direct upload to https://meshmapper.net/ or local GIS visualization.

Usage:
    python fit_to_meshmapper.py --input activity.fit --output mesh_coverage.csv
    python fit_to_meshmapper.py --input activity.fit --node-id "!24a8b1c0"

Requirements:
    pip install fitparse
"""

import argparse
import csv
import sys
from datetime import datetime

try:
    import fitparse
except ImportError:
    fitparse = None


def semicircles_to_degrees(semicircles):
    if semicircles is None:
        return None
    return semicircles * (180.0 / (2**31))


def convert_fit_to_meshmapper(fit_file_path, output_csv_path=None, default_node_id="MeshCore"):
    if fitparse is None:
        print("Fehler: Das Python-Paket 'fitparse' ist nicht installiert.", file=sys.stderr)
        print("Bitte ausführen: pip install fitparse", file=sys.stderr)
        sys.exit(1)

    print(f"Lese FIT-Datei: {fit_file_path} ...")
    fitfile = fitparse.FitFile(fit_file_path)

    records = []
    points_with_lora = 0

    for record in fitfile.get_messages("record"):
        data = {field.name: field.value for field in record.fields}
        dev_data = {field.name: field.value for field in record.dev_fields} if hasattr(record, "dev_fields") else {}

        # Merge developer fields
        for k, v in dev_data.items():
            data[k] = v

        timestamp = data.get("timestamp")
        lat_semi = data.get("position_lat")
        lon_semi = data.get("position_long")
        altitude = data.get("enhanced_altitude") or data.get("altitude")

        # Skip points without valid GPS
        if lat_semi is None or lon_semi is None:
            continue

        lat = semicircles_to_degrees(lat_semi)
        lon = semicircles_to_degrees(lon_semi)

        # Developer fields logged by MeshCoreDataField
        lora_rssi = data.get("lora_rssi") or data.get("Mesh_RSSI")
        lora_snr = data.get("lora_snr") or data.get("Mesh_SNR")
        mesh_peers = data.get("mesh_nodes") or data.get("Mesh_Peers") or 0

        # ISO timestamp or epoch
        if isinstance(timestamp, datetime):
            time_str = timestamp.strftime("%Y-%m-%d %H:%M:%S")
        else:
            time_str = str(timestamp)

        if lora_rssi is not None:
            points_with_lora += 1

        records.append({
            "timestamp": time_str,
            "latitude": f"{lat:.6f}",
            "longitude": f"{lon:.6f}",
            "altitude": f"{altitude:.1f}" if altitude is not None else "",
            "type": "Node",
            "rssi": lora_rssi if lora_rssi is not None else "",
            "snr": lora_snr if lora_snr is not None else "",
            "peers": mesh_peers,
            "node_id": default_node_id
        })

    if not output_csv_path:
        output_csv_path = fit_file_path.rsplit(".", 1)[0] + "_meshmapper.csv"

    print(f"Schreibe {len(records)} Trackpoints ({points_with_lora} mit LoRa-Signal) nach {output_csv_path} ...")

    with open(output_csv_path, "w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        # MeshMapper Standard Header
        writer.writerow(["timestamp", "latitude", "longitude", "altitude", "type", "rssi", "snr", "node_id"])
        for r in records:
            writer.writerow([
                r["timestamp"],
                r["latitude"],
                r["longitude"],
                r["altitude"],
                r["type"],
                r["rssi"],
                r["snr"],
                r["node_id"]
            ])

    print(f"[ERFOLG] MeshMapper CSV exportiert: {output_csv_path}")


def main():
    parser = argparse.ArgumentParser(description="Convert Garmin FIT file with MeshCore LoRa developer fields to MeshMapper CSV")
    parser.add_argument("--input", "-i", required=True, help="Path to Garmin .FIT activity file")
    parser.add_argument("--output", "-o", help="Path to output .CSV file (default: input_meshmapper.csv)")
    parser.add_argument("--node-id", "-n", default="MeshCore", help="Default Node ID to report in MeshMapper records")
    args = parser.parse_args()

    convert_fit_to_meshmapper(args.input, args.output, args.node_id)


if __name__ == "__main__":
    main()
