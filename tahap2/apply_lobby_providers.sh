#!/usr/bin/env bash
# Tahap 3: pause screen universal (RetroVerze + HunterVerse) + info server untuk server ad hoc non-publik.
# Pakai: bash apply_lobby_providers.sh <folder ppsspp> <folder repo retroverze>
# Jalankan SETELAH apply_retroverze.sh (yang menyalin PauseScreen.cpp/.h RetroVerze).
set -euo pipefail

PPSSPP="$(cd "${1:?Pakai: apply_lobby_providers.sh <ppsspp> <retroverze>}" && pwd)"
RV="$(cd "${2:?Pakai: apply_lobby_providers.sh <ppsspp> <retroverze>}" && pwd)"
TARGET="$PPSSPP/UI/PauseScreen.cpp"
SNIPPET="$RV/tahap2/hv_snippet.inc"

[ -f "$TARGET" ] || { echo "ERROR: $TARGET tidak ada"; exit 1; }
[ -f "$SNIPPET" ] || { echo "ERROR: $SNIPPET tidak ada"; exit 1; }

python3 - "$TARGET" "$SNIPPET" <<'PY'
import sys
target, snippet = sys.argv[1], sys.argv[2]
s = open(target, encoding="utf-8", newline="").read()
if "kHunterVerseGhUrl" in s:
    print("OK  PauseScreen.cpp sudah dipatch"); sys.exit(0)
nl = "\r\n" if "\r\n" in s else "\n"
inc = open(snippet, encoding="utf-8").read().replace("\r\n", "\n")

def sub(old, new):
    global s
    old = old.replace("\n", nl); new = new.replace("\n", nl)
    assert s.count(old) == 1, f"anchor tidak tunggal/tidak ada (n={s.count(old)}): {old[:70]!r}"
    s = s.replace(old, new, 1)

# 1) MHP3rd tetap di urutan teratas untuk HunterVerse juga
sub('\tif (game == kLobbyPriorityGame)\n\t\treturn 0;',
    '\tif (game == kLobbyPriorityGame || game == "MHP3rd")\n\t\treturn 0;')

# 2) Kode penyedia HunterVerse (sebelum LobbyEnabled)
sub('bool GamePauseScreen::LobbyEnabled() const {',
    inc + 'bool GamePauseScreen::LobbyEnabled() const {')

# 3) URL + jenis konten sesuai penyedia
sub('lobbyRequest_ = g_DownloadManager.StartDownload(kLobbyStatusUrl, Path(), http::RequestFlags::KeepInMemory, "application/xml", "lobby");',
    'const bool hv = LobbyProviderIndex() == 1;\n'
    '\tlobbyRequest_ = g_DownloadManager.StartDownload(hv ? kHunterVerseGhUrl : kLobbyStatusUrl, Path(), http::RequestFlags::KeepInMemory, hv ? "text/html" : "application/xml", "lobby");')

# 4) Pesan error + parser sesuai penyedia
sub('lobbyError_ = code > 0 ? "Server RetroVerze mengalami gangguan (HTTP " + std::to_string(code) + ")" : "Gagal terhubung ke server RetroVerze";',
    'lobbyError_ = code > 0 ? std::string("Server ") + LobbyProviderName() + " mengalami gangguan (HTTP " + std::to_string(code) + ")" : std::string("Gagal terhubung ke server ") + LobbyProviderName();')
sub('ParseLobbyXml(data, &lobbySections_)', 'ParseLobbyData(data, &lobbySections_)')
sub('lobbyError_ = "Koneksi ke server RetroVerze timeout";',
    'lobbyError_ = std::string("Koneksi ke server ") + LobbyProviderName() + " timeout";')

# 5) Tombol pilih penyedia di atas isi lobby
sub('\tlobbyContent_->Clear();\n',
    '''\tlobbyContent_->Clear();

\t// Pilih penyedia data: RetroVerze atau HunterVerse.
\t{
\t\tLinearLayout *row = lobbyContent_->Add(new LinearLayout(ORIENT_HORIZONTAL, new LinearLayoutParams(WRAP_CONTENT, WRAP_CONTENT, Margins(4, 2))));
\t\tauto addProvider = [&](const char *label, int idx) {
\t\t\tChoice *c = row->Add(new Choice(label, new LinearLayoutParams(WRAP_CONTENT, WRAP_CONTENT)));
\t\t\tc->SetEnabled(LobbyProviderIndex() != idx);  // yang aktif ditampilkan nonaktif (sebagai penanda)
\t\t\tc->OnClick.Add([this, idx](UI::EventParams &) {
\t\t\t\tg_lobbyProvider = idx;
\t\t\t\tCancelLobby();
\t\t\t\tlobbySections_.clear();
\t\t\t\tlobbyError_.clear();
\t\t\t\tlobbyLoaded_ = false;
\t\t\t\tlobbyLastRefresh_ = 0.0;
\t\t\t\tRefreshLobby();
\t\t\t\tRecreateViews();
\t\t\t});
\t\t};
\t\taddProvider("RetroVerze", 0);
\t\taddProvider("HunterVerse", 1);
\t}
''')

# 6) Info server untuk server ad hoc yang tidak ada di daftar publik (mis. RetroVerze 10.42.0.1)
sub('''\t\t\t\tnetworkInfo->Add(new NoticeView(NoticeLevel::SUCCESS, ApplySafeSubstitutions("%1: %2 (%3)", nw->T("AdHoc server"), nw->T("Connected"), g_Config.sProAdhocServer), ""));
''',
'''\t\t\t\tnetworkInfo->Add(new NoticeView(NoticeLevel::SUCCESS, ApplySafeSubstitutions("%1: %2 (%3)", nw->T("AdHoc server"), nw->T("Connected"), g_Config.sProAdhocServer), ""));
\t\t\t\t// Server pribadi (tidak ada di daftar publik): tetap sediakan tombol info server.
\t\t\t\tAdhocServerListEntry custom{};
\t\t\t\tcustom.host = g_Config.sProAdhocServer;
\t\t\t\tconst bool isRetroVerze = custom.host == "10.42.0.1";
\t\t\t\tcustom.name = isRetroVerze ? "RetroVerze" : custom.host;
\t\t\t\tif (isRetroVerze)
\t\t\t\t\tcustom.statusXmlUrl = kLobbyStatusUrl;
\t\t\t\tChoice *customStatus = networkInfo->Add(new Choice(ApplySafeSubstitutions(nw->T("Server status: %1"), custom.name), new LinearLayoutParams(WRAP_CONTENT, ITEM_HEIGHT)));
\t\t\t\tcustomStatus->SetIconLeft(ImageID("I_INFO"));
\t\t\t\tcustomStatus->OnClick.Add([this, custom](UI::EventParams &) {
\t\t\t\t\tscreenManager()->push(new AdhocServerInfoScreen(custom));
\t\t\t\t});
''')

open(target, "w", encoding="utf-8", newline="").write(s)
print("OK  PauseScreen.cpp dipatch (penyedia RetroVerze/HunterVerse + info server)")
PY
