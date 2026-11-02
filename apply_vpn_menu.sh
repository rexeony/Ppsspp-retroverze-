#!/usr/bin/env bash
# Tahap 2 (bagian native): tombol Multiplayer On/Off di menu kanan beranda + jembatan C++ <-> Java.
# Pakai: bash apply_vpn_menu.sh <folder ppsspp> <folder repo retroverze>
set -euo pipefail

PPSSPP="$(cd "${1:?Pakai: apply_vpn_menu.sh <ppsspp> <retroverze>}" && pwd)"
RV="$(cd "${2:?Pakai: apply_vpn_menu.sh <ppsspp> <retroverze>}" && pwd)"

for f in UI/MainScreen.cpp UI/MainScreen.h android/jni/app-android.cpp \
         android/src/org/ppsspp/ppsspp/PpssppActivity.java; do
  [ -f "$PPSSPP/$f" ] || { echo "ERROR: $f tidak ada"; exit 1; }
done

cp "$RV/tahap2/RetroVerzeVpn.h" "$PPSSPP/UI/RetroVerzeVpn.h"
echo "OK  UI/RetroVerzeVpn.h disalin"

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

# ---- app-android.cpp: status atomic + fungsi toggle + terima pesan dari Java ----
patch("android/jni/app-android.cpp", [
 ('#include "Core/Config.h"\n',
  '#include "Core/Config.h"\n#include "UI/RetroVerzeVpn.h"  // RETROVERZE-VPN\n'),
 ('// Android implementation of callbacks to the Java part of the app\n',
  '''// RETROVERZE-VPN: status VPN tertanam (diisi dari Java lewat sendMessageFromJava).
static std::atomic<int> g_retroVerzeVpnState{0};

RetroVerzeVpnState RetroVerze_VpnState() {
	return (RetroVerzeVpnState)g_retroVerzeVpnState.load();
}

void RetroVerze_VpnToggle() {
	PushCommand("retroverze_vpn", "toggle");
}

// Android implementation of callbacks to the Java part of the app
'''),
 ('\t} else if (msg == "sustained_perf_supported") {\n',
  '''\t} else if (msg == "retroverze_vpn_state") {
\t\tg_retroVerzeVpnState = atoi(prm.c_str());
\t} else if (msg == "sustained_perf_supported") {
'''),
], "RETROVERZE-VPN")

# ---- PpssppActivity.java: terima perintah dari native ----
patch("android/src/org/ppsspp/ppsspp/PpssppActivity.java", [
 ('\t\t} else if (command.equals("copy_to_clipboard")) {\n',
  '''\t\t} else if (command.equals("retroverze_vpn")) {  // RETROVERZE-VPN
\t\t\tRetroVerzeVpn.get(this).toggle(this);
\t\t\treturn true;
\t\t} else if (command.equals("copy_to_clipboard")) {
'''),
], "RETROVERZE-VPN")

# ---- MainScreen.h: pelacak status ----
patch("UI/MainScreen.h", [
 ('\tbool searchChanged_ = false;\n\tstd::string searchFilter_;\n',
  '\tbool searchChanged_ = false;\n\tint lastVpnState_ = 0;  // RETROVERZE-VPN\n\tstd::string searchFilter_;\n'),
], "RETROVERZE-VPN")

# ---- MainScreen.cpp: tombol + refresh saat status berubah ----
patch("UI/MainScreen.cpp", [
 ('#include "UI/RemoteISOScreen.h"\n',
  '#include "UI/RemoteISOScreen.h"\n#include "UI/RetroVerzeVpn.h"  // RETROVERZE-VPN\n'),
 ('''->OnClick.Handle(this, &MainScreen::OnCredits);

	if (!portrait) {''',
  '''->OnClick.Handle(this, &MainScreen::OnCredits);

	// RETROVERZE-VPN: tombol Multiplayer On/Off (VPN RetroVerze tertanam).
	if (RetroVerze_VpnSupported()) {
		const RetroVerzeVpnState vs = RetroVerze_VpnState();
		lastVpnState_ = (int)vs;
		const char *label = "Multiplayer: Off";
		switch (vs) {
		case RetroVerzeVpnState::Connecting: label = "Multiplayer: Menyambung..."; break;
		case RetroVerzeVpnState::On: label = "Multiplayer: On"; break;
		case RetroVerzeVpnState::Failed: label = "Multiplayer: Gagal (ketuk ulang)"; break;
		default: break;
		}
		Choice *mp = parent->Add(new Choice(label, portrait ? new LinearLayoutParams() : nullptr));
		mp->OnClick.Add([](UI::EventParams &) {
			const RetroVerzeVpnState cur = RetroVerze_VpnState();
			if (cur == RetroVerzeVpnState::Off || cur == RetroVerzeVpnState::Failed) {
				// Pengaturan jaringan RetroVerze (sesuai tutorial di retroverze.my.id).
				g_Config.bEnableWlan = true;
				g_Config.sProAdhocServer = "10.42.0.1";
				g_Config.bEnableNetworkChat = true;
				g_Config.iPortOffset = 0;
				g_Config.Save("RetroVerze::Multiplayer");
			}
			RetroVerze_VpnToggle();
		});
		if (vs == RetroVerzeVpnState::On) {
			mp->SetShine(true);
		}
	}

	if (!portrait) {'''),
 ('''void MainScreen::update() {
	UIScreen::update();
	UpdateUIState(UISTATE_MENU);
''',
  '''void MainScreen::update() {
	UIScreen::update();
	UpdateUIState(UISTATE_MENU);

	// RETROVERZE-VPN: bangun ulang menu saat status VPN berubah.
	if ((int)RetroVerze_VpnState() != lastVpnState_) {
		lastVpnState_ = (int)RetroVerze_VpnState();
		RecreateViews();
	}
'''),
], "RETROVERZE-VPN")
PY
echo "OK: tombol Multiplayer terpasang."
