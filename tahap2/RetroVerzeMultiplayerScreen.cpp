// RetroVerze: layar Multiplayer.
// Mode 0 = OpenVPN (profil .ovpn milik pemain), mode 1 = Server Relay (daftar server publik PPSSPP).
// Pengaman: hanya satu server aktif. Selama VPN menyambung/aktif, profil lain dan mode relay terkunci.
#include <algorithm>
#include <cctype>
#include <string>
#include <vector>

#include "Common/UI/Notice.h"
#include "Common/UI/View.h"
#include "Common/UI/ViewGroup.h"
#include "Core/Config.h"
#include "Core/HLE/sceNetAdhoc.h"
#include "UI/AdhocServerScreen.h"
#include "UI/RetroVerzeMultiplayerScreen.h"
#include "UI/RetroVerzeVpn.h"

static int g_rvMpMode = 0;
static std::string g_rvSelectedProfile;

static std::string RvLower(std::string s) {
	std::transform(s.begin(), s.end(), s.begin(), [](unsigned char c) { return (char)tolower(c); });
	return s;
}

std::string RetroVerze_MultiplayerLabel() {
	switch (RetroVerze_VpnState()) {
	case RetroVerzeVpnState::On:
		return "Multiplayer: VPN " + RetroVerze_VpnActiveProfile();
	case RetroVerzeVpnState::Connecting:
		return "Multiplayer: menyambung...";
	case RetroVerzeVpnState::Failed:
		return "Multiplayer: VPN gagal";
	default:
		break;
	}
	if (g_Config.bEnableWlan)
		return "Multiplayer: On (" + g_Config.sProAdhocServer + ")";
	return "Multiplayer: Off";
}

RetroVerzeMultiplayerScreen::RetroVerzeMultiplayerScreen() : UISimpleBaseDialogScreen(Path(), SimpleDialogFlags::ContentsCanScroll) {
	RetroVerze_VpnCommand("refresh");
	lastRevision_ = RetroVerze_VpnRevision();
}

void RetroVerzeMultiplayerScreen::update() {
	UISimpleBaseDialogScreen::update();
	const int rev = RetroVerze_VpnRevision();
	if (rev != lastRevision_) {
		lastRevision_ = rev;
		RecreateViews();
	}
}

void RetroVerzeMultiplayerScreen::dialogFinished(const Screen *dialog, DialogResult dr) {
	RecreateViews();
}

void RetroVerzeMultiplayerScreen::CreateDialogViews(UI::ViewGroup *parent) {
	using namespace UI;

	const bool vpnSupported = RetroVerze_VpnSupported();
	const RetroVerzeVpnState vs = RetroVerze_VpnState();
	const bool vpnBusy = vs == RetroVerzeVpnState::Connecting || vs == RetroVerzeVpnState::On;
	if (vpnBusy)
		g_rvMpMode = 0;  // VPN aktif => mode relay tidak boleh dipakai bersamaan
	if (!vpnSupported)
		g_rvMpMode = 1;  // platform tanpa mesin VPN: hanya relay

	parent->Add(new TextView("PPSSPP Openvpn - By Hafizd M.S", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));

	// ---- Saklar utama: berlaku juga saat game sedang berjalan ----
	parent->Add(new CheckBox(&g_Config.bEnableWlan, "Aktifkan multiplayer (jaringan ad hoc)"));
	parent->Add(new TextView("Jika game sudah berjalan offline, buka ulang menu multiplayer di dalam game setelah ini aktif.", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));

	// ---- Pilih mode ----
	parent->Add(new ItemHeader("Mode"));
	LinearLayout *modeRow = parent->Add(new LinearLayout(ORIENT_HORIZONTAL, new LinearLayoutParams(FILL_PARENT, WRAP_CONTENT)));
	if (vpnSupported) {
		Choice *modeVpn = modeRow->Add(new Choice("OpenVPN", new LinearLayoutParams(1.0f)));
		modeVpn->SetEnabled(g_rvMpMode != 0);  // mode yang aktif ditampilkan nonaktif sebagai penanda
		modeVpn->OnClick.Add([this](UI::EventParams &) {
			g_rvMpMode = 0;
			RecreateViews();
		});
	}
	Choice *modeRelay = modeRow->Add(new Choice("Server Relay", new LinearLayoutParams(1.0f)));
	modeRelay->SetEnabled(g_rvMpMode != 1 && !vpnBusy);
	modeRelay->OnClick.Add([this](UI::EventParams &) {
		g_rvMpMode = 1;
		g_Config.bEnableWlan = true;
		g_Config.Save("RetroVerze::Relay");
		RecreateViews();
	});
	if (vpnBusy) {
		parent->Add(new TextView("Mode Relay terkunci selama VPN aktif (hanya boleh satu server).", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));
	}

	if (g_rvMpMode == 1) {
		// ---- Mode Server Relay ----
		parent->Add(new ItemHeader("Server Relay"));
		parent->Add(new TextView("Bermain lewat server relay publik tanpa VPN. Pilih salah satu server dari daftar.", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));
		Choice *pick = parent->Add(new Choice("Server relay: " + g_Config.sProAdhocServer));
		pick->OnClick.Add([this](UI::EventParams &) {
			screenManager()->push(new AdhocServerScreen(&g_Config.sProAdhocServer, "Ad hoc server address"));
		});
		AdhocServerListEntry entry{};
		if (AdhocGetServerByHost(g_Config.sProAdhocServer, &entry)) {
			Choice *info = parent->Add(new Choice("Info server: " + entry.name));
			info->SetIconLeft(ImageID("I_INFO"));
			info->OnClick.Add([this, entry](UI::EventParams &) {
				screenManager()->push(new AdhocServerInfoScreen(entry));
			});
		}
		return;
	}

	// ---- Mode OpenVPN ----
	const std::vector<std::string> profiles = RetroVerze_VpnProfiles();
	const std::string active = RetroVerze_VpnActiveProfile();
	if (!active.empty())
		g_rvSelectedProfile = active;
	if (std::find(profiles.begin(), profiles.end(), g_rvSelectedProfile) == profiles.end())
		g_rvSelectedProfile = profiles.size() == 1 ? profiles[0] : std::string();

	parent->Add(new ItemHeader("Status VPN"));
	std::string msg = RetroVerze_VpnMessage();
	if (msg.empty())
		msg = "VPN mati";
	NoticeLevel level = NoticeLevel::INFO;
	if (vs == RetroVerzeVpnState::On)
		level = NoticeLevel::SUCCESS;
	else if (vs == RetroVerzeVpnState::Failed)
		level = NoticeLevel::ERROR;
	parent->Add(new NoticeView(level, msg, ""));

	parent->Add(new ItemHeader("Profil OpenVPN (pilih satu)"));
	if (profiles.empty()) {
		parent->Add(new TextView("Belum ada profil. Tekan \"Impor .ovpn\" lalu pilih file .ovpn dari RetroVerze, HunterVerse, atau server lain. Atau taruh file .ovpn di folder Android/data/<nama aplikasi>/files/ovpn/ lalu buka ulang layar ini.", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));
	}
	for (const std::string &name : profiles) {
		LinearLayout *row = parent->Add(new LinearLayout(ORIENT_HORIZONTAL, new LinearLayoutParams(FILL_PARENT, WRAP_CONTENT)));
		const bool selected = name == g_rvSelectedProfile;
		Choice *c = row->Add(new Choice((selected ? "(*) " : "( ) ") + name, new LinearLayoutParams(1.0f)));
		c->SetEnabled(!vpnBusy);
		c->OnClick.Add([this, name](UI::EventParams &) {
			g_rvSelectedProfile = name;
			RecreateViews();
		});
		Choice *del = row->Add(new Choice("Hapus", new LinearLayoutParams(WRAP_CONTENT, WRAP_CONTENT)));
		del->SetEnabled(!vpnBusy);
		del->OnClick.Add([name](UI::EventParams &) {
			RetroVerze_VpnCommand("delete:" + name);
		});
	}

	Choice *imp = parent->Add(new Choice("Impor .ovpn"));
	imp->SetEnabled(!vpnBusy);
	imp->OnClick.Add([](UI::EventParams &) {
		RetroVerze_VpnCommand("import");
	});
	parent->Add(new TextView("Peringatan: impor hanya profil dari sumber yang kamu percaya. Direktif yang bisa menjalankan skrip otomatis dibuang. Hanya PPSSPP yang melewati VPN, bukan seluruh HP.", FLAG_WRAP_TEXT, true, new LinearLayoutParams(Margins(8, 4))));

	if (vpnBusy) {
		Choice *off = parent->Add(new Choice("Putuskan VPN"));
		off->OnClick.Add([](UI::EventParams &) {
			RetroVerze_VpnCommand("disconnect");
		});
	} else {
		const std::string sel = g_rvSelectedProfile;
		Choice *on = parent->Add(new Choice(sel.empty() ? std::string("Pilih profil dulu") : "Sambungkan: " + sel));
		on->SetEnabled(!sel.empty());
		on->OnClick.Add([sel](UI::EventParams &) {
			// Pengaturan jaringan ad hoc untuk bermain online.
			g_Config.bEnableWlan = true;
			if (RvLower(sel).find("retroverze") != std::string::npos) {
				g_Config.sProAdhocServer = "10.42.0.1";
				g_Config.bEnableNetworkChat = true;
				g_Config.iPortOffset = 0;
			}
			g_Config.Save("RetroVerze::Multiplayer");
			RetroVerze_VpnCommand("connect:" + sel);
		});
	}

	Choice *server = parent->Add(new Choice("Alamat server Ad Hoc: " + g_Config.sProAdhocServer));
	server->OnClick.Add([this](UI::EventParams &) {
		screenManager()->push(new AdhocServerScreen(&g_Config.sProAdhocServer, "Ad hoc server address"));
	});
}
