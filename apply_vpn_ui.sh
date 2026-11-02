#!/usr/bin/env bash
# Tahap 2 (bagian Java): kontrol VPN tertanam + izin VPN + file .ovpn RetroVerze.
# Pakai: bash apply_vpn_ui.sh <folder ppsspp> <folder ics-openvpn> <folder repo retroverze>
set -euo pipefail

PPSSPP="$(cd "${1:?Pakai: apply_vpn_ui.sh <ppsspp> <ics> <retroverze>}" && pwd)"
ICS="$(cd "${2:?Pakai: apply_vpn_ui.sh <ppsspp> <ics> <retroverze>}" && pwd)"
RV="$(cd "${3:?Pakai: apply_vpn_ui.sh <ppsspp> <ics> <retroverze>}" && pwd)"
HERE="$RV/tahap2"

JAVA_DIR="$PPSSPP/android/src/org/ppsspp/ppsspp"
MANIFEST="$PPSSPP/android/AndroidManifest.xml"

[ -d "$JAVA_DIR" ] || { echo "ERROR: $JAVA_DIR tidak ada"; exit 1; }
[ -f "$MANIFEST" ] || { echo "ERROR: $MANIFEST tidak ada"; exit 1; }
[ -f "$RV/retroverze.ovpn" ] || { echo "ERROR: retroverze.ovpn harus ada di root repo RetroVerze"; exit 1; }

# 1) Class Java
cp "$HERE/RetroVerzeVpn.java" "$HERE/RetroVerzeVpnPermissionActivity.java" "$JAVA_DIR/"
echo "OK  class Java disalin"

# 2) File .ovpn -> assets modul VPN (ikut ter-merge ke APK)
mkdir -p "$ICS/main/src/main/assets"
cp "$RV/retroverze.ovpn" "$ICS/main/src/main/assets/retroverze.ovpn"
echo "OK  retroverze.ovpn disalin ke assets"

# 3) Manifest: daftarkan activity izin VPN
python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", newline="").read()
if "RetroVerzeVpnPermissionActivity" in s:
    print("OK  manifest sudah dipatch"); sys.exit(0)
act = ('\n\t\t<!-- RETROVERZE-VPN-UI -->\n'
       '\t\t<activity android:name="org.ppsspp.ppsspp.RetroVerzeVpnPermissionActivity"\n'
       '\t\t\tandroid:exported="false"\n'
       '\t\t\tandroid:theme="@android:style/Theme.Translucent.NoTitleBar" />\n')
assert s.count("</application>") == 1, "tag </application> tidak tunggal"
s = s.replace("</application>", act + "\t</application>", 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("OK  manifest dipatch (activity izin VPN)")
PY

echo "OK: Tahap 2 (Java) selesai. Tombol UI native (MainScreen) dipasang terpisah."
