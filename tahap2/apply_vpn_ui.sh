#!/usr/bin/env bash
# Tahap 2 (bagian Java): kontrol VPN tertanam + izin VPN + impor file .ovpn oleh pemain.
# Tidak ada file .ovpn yang ditanam di APK; pemain mengimpor sendiri lewat layar Multiplayer.
# Pakai: bash apply_vpn_ui.sh <folder ppsspp> <folder ics-openvpn> <folder repo retroverze>
set -euo pipefail

PPSSPP="$(cd "${1:?Pakai: apply_vpn_ui.sh <ppsspp> <ics> <retroverze>}" && pwd)"
RV="$(cd "${3:?Pakai: apply_vpn_ui.sh <ppsspp> <ics> <retroverze>}" && pwd)"
HERE="$RV/tahap2"

JAVA_DIR="$PPSSPP/android/src/org/ppsspp/ppsspp"
MANIFEST="$PPSSPP/android/AndroidManifest.xml"

[ -d "$JAVA_DIR" ] || { echo "ERROR: $JAVA_DIR tidak ada"; exit 1; }
[ -f "$MANIFEST" ] || { echo "ERROR: $MANIFEST tidak ada"; exit 1; }

# 1) Class Java
cp "$HERE/RetroVerzeVpn.java" "$HERE/RetroVerzeVpnPermissionActivity.java" "$HERE/RetroVerzeOvpnImportActivity.java" "$JAVA_DIR/"
echo "OK  class Java disalin"

# 2) Manifest: daftarkan activity izin VPN + activity impor .ovpn
python3 - "$MANIFEST" <<'PY'
import sys
p = sys.argv[1]
s = open(p, encoding="utf-8", newline="").read()
if "RetroVerzeVpnPermissionActivity" in s:
    print("OK  manifest sudah dipatch"); sys.exit(0)
act = ('\n\t\t<!-- RETROVERZE-VPN-UI -->\n'
       '\t\t<activity android:name="org.ppsspp.ppsspp.RetroVerzeVpnPermissionActivity"\n'
       '\t\t\tandroid:exported="false"\n'
       '\t\t\tandroid:theme="@android:style/Theme.Translucent.NoTitleBar" />\n'
       '\t\t<activity android:name="org.ppsspp.ppsspp.RetroVerzeOvpnImportActivity"\n'
       '\t\t\tandroid:exported="false"\n'
       '\t\t\tandroid:theme="@android:style/Theme.Translucent.NoTitleBar" />\n')
assert s.count("</application>") == 1, "tag </application> tidak tunggal"
s = s.replace("</application>", act + "\t</application>", 1)
open(p, "w", encoding="utf-8", newline="").write(s)
print("OK  manifest dipatch (activity izin VPN + impor .ovpn)")
PY

echo "OK: Tahap 2 (Java) selesai."
