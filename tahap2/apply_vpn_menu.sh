#!/usr/bin/env bash
# Tahap 2 (bagian native): layar Multiplayer, tombol di menu utama, dan jembatan C++ <-> Java.
# Pakai: bash apply_vpn_menu.sh <folder ppsspp> <folder repo retroverze>
set -euo pipefail

PPSSPP="$(cd "${1:?Pakai: apply_vpn_menu.sh <ppsspp> <retroverze>}" && pwd)"
RV="$(cd "${2:?Pakai: apply_vpn_menu.sh <ppsspp> <retroverze>}" && pwd)"

for f in UI/MainScreen.cpp android/jni/app-android.cpp CMakeLists.txt \
         android/src/org/ppsspp/ppsspp/PpssppActivity.java; do
  [ -f "$PPSSPP/$f" ] || { echo "ERROR: $f tidak ada"; exit 1; }
done

cp "$RV/tahap2/RetroVerzeVpn.h" "$RV/tahap2/RetroVerzeMultiplayerScreen.h" "$RV/tahap2/RetroVerzeMultiplayerScreen.cpp" "$PPSSPP/UI/"
echo "OK  file UI RetroVerze disalin"

python3 - "$PPSSPP" <<'PY'
import os, sys
root = sys.argv[1]

def patch(rel, edits, marker):
    p = os.path.join(root, rel)
    s = open(p, encoding="utf-8", newline="").read()
    if marker in s:
        print(f"OK  {rel} sudah dipatch"); return
    nl = "\r\n" if "\r\n" in s else "\n"
    for old, new in edits:
        old = old.replace("\n", nl); new = new.replace("\n", nl)
        assert s.count(old) == 1, f"{rel}: anchor tidak tunggal/tidak ada: {old[:60]!r} (n={s.count(old)})"
        s = s.replace(old, new, 1)
    open(p, "w", encoding="utf-8", newline="").write(s)
    print(f"OK  {rel} dipatch")

# ---- CMake + Android.mk: daftarkan file baru ----
patch("CMakeLists.txt", [
 ("\tUI/PauseScreen.cpp\n",
  "\tUI/PauseScreen.cpp\n\tUI/RetroVerzeMultiplayerScreen.h\n\tUI/RetroVerzeMultiplayerScreen.cpp  # RETROVERZE-VPN\n"),
], "RETROVERZE-VPN")

mk = os.path.join(root, "android/jni/Android.mk")
if os.path.exists(mk):
    patch("android/jni/Android.mk", [
     ("  $(SRC)/UI/PauseScreen.cpp \\\n",
      "  $(SRC)/UI/PauseScreen.cpp \\\n  $(SRC)/UI/RetroVerzeMultiplayerScreen.cpp \\\n"),
    ], "RetroVerzeMultiplayerScreen")

# ---- app-android.cpp: status VPN (diisi dari Java) + perintah ke Java ----
patch("android/jni/app-android.cpp", [
 ('#include "Core/Config.h"\n',
  '#include "Core/Config.h"\n#include "UI/RetroVerzeVpn.h"  // RETROVERZE-VPN\n'),
 ('// Android implementation of callbacks to the Java part of the app\n',
  '''// RETROVERZE-VPN: status VPN tertanam (diisi dari Java lewat sendMessageFromJava).
static std::mutex g_rvVpnMutex;
static std::string g_rvVpnMessage;
static std::string g_rvVpnActive;
static std::vector<std::string> g_rvVpnProfiles;
static std::atomic<int> g_rvVpnState{0};
static std::atomic<int> g_rvVpnRevision{0};

RetroVerzeVpnState RetroVerze_VpnState() {
	return (RetroVerzeVpnState)g_rvVpnState.load();
}

int RetroVerze_VpnRevision() {
	return g_rvVpnRevision.load();
}

std::string RetroVerze_VpnMessage() {
	std::lock_guard<std::mutex> guard(g_rvVpnMutex);
	return g_rvVpnMessage;
}

std::string RetroVerze_VpnActiveProfile() {
	std::lock_guard<std::mutex> guard(g_rvVpnMutex);
	return g_rvVpnActive;
}

std::vector<std::string> RetroVerze_VpnProfiles() {
	std::lock_guard<std::mutex> guard(g_rvVpnMutex);
	return g_rvVpnProfiles;
}

void RetroVerze_VpnCommand(const std::string &cmd) {
	PushCommand("retroverze_vpn", cmd);
}

// Android implementation of callbacks to the Java part of the app
'''),
 ('\t} else if (msg == "sustained_perf_supported") {\n',
  '''\t} else if (msg == "retroverze_vpn_state") {
\t\tg_rvVpnState = atoi(prm.c_str());
\t\tg_rvVpnRevision++;
\t} else if (msg == "retroverze_vpn_msg") {
\t\t{
\t\t\tstd::lock_guard<std::mutex> guard(g_rvVpnMutex);
\t\t\tg_rvVpnMessage = prm;
\t\t}
\t\tg_rvVpnRevision++;
\t} else if (msg == "retroverze_vpn_active") {
\t\t{
\t\t\tstd::lock_guard<std::mutex> guard(g_rvVpnMutex);
\t\t\tg_rvVpnActive = prm;
\t\t}
\t\tg_rvVpnRevision++;
\t} else if (msg == "retroverze_vpn_profiles") {
\t\t{
\t\t\tstd::lock_guard<std::mutex> guard(g_rvVpnMutex);
\t\t\tg_rvVpnProfiles.clear();
\t\t\tsize_t start = 0;
\t\t\twhile (start <= prm.size() && !prm.empty()) {
\t\t\t\tsize_t end = prm.find('\\n', start);
\t\t\t\tif (end == std::string::npos)
\t\t\t\t\tend = prm.size();
\t\t\t\tif (end > start)
\t\t\t\t\tg_rvVpnProfiles.push_back(prm.substr(start, end - start));
\t\t\t\tstart = end + 1;
\t\t\t}
\t\t}
\t\tg_rvVpnRevision++;
\t} else if (msg == "sustained_perf_supported") {
'''),
], "RETROVERZE-VPN")

# ---- PpssppActivity.java: terima perintah dari native ----
patch("android/src/org/ppsspp/ppsspp/PpssppActivity.java", [
 ('\t\t} else if (command.equals("copy_to_clipboard")) {\n',
  '''\t\t} else if (command.equals("retroverze_vpn")) {  // RETROVERZE-VPN
\t\t\tRetroVerzeVpn.get(this).handleCommand(this, params);
\t\t\treturn true;
\t\t} else if (command.equals("copy_to_clipboard")) {
'''),
], "RETROVERZE-VPN")

# ---- MiscScreens.cpp: nama pembuat versi ini di layar Credits (kredit Henrik tetap utuh) ----
patch("UI/MiscScreens.cpp", [
 ('\t\t"Henrik Rydg\\xc3\\xa5rd",\n\t\t"",\n\t\t"",\n',
  '\t\t"Henrik Rydg\\xc3\\xa5rd",\n\t\t"",\n\t\t"PPSSPP Openvpn",\n\t\t"By Hafizd M.S",\n\t\t"",\n\t\t"",\n'),
], "By Hafizd M.S")

# ---- MainScreen.cpp: tombol Multiplayer membuka layar Multiplayer ----
patch("UI/MainScreen.cpp", [
 ('#include "UI/RemoteISOScreen.h"\n',
  '#include "UI/RemoteISOScreen.h"\n#include "UI/RetroVerzeMultiplayerScreen.h"  // RETROVERZE-VPN\n'),
 ('''->OnClick.Handle(this, &MainScreen::OnCredits);

	if (!portrait) {''',
  '''->OnClick.Handle(this, &MainScreen::OnCredits);

	// RETROVERZE-VPN: tombol Multiplayer (OpenVPN atau Server Relay).
	parent->Add(new Choice("Multiplayer", portrait ? new LinearLayoutParams() : nullptr))->OnClick.Add([this](UI::EventParams &) {
		screenManager()->push(new RetroVerzeMultiplayerScreen());
	});

	if (!portrait) {'''),
], "RETROVERZE-VPN")
PY
echo "OK: layar Multiplayer + jembatan native terpasang."
