// RetroVerze: antarmuka status/aksi VPN tertanam untuk UI native.
// Di Android diimplementasikan di android/jni/app-android.cpp; platform lain berupa stub.
#pragma once

#include <string>
#include <vector>

#include "ppsspp_config.h"

enum class RetroVerzeVpnState {
	Off = 0,
	Connecting = 1,
	On = 2,
	Failed = 3,
};

#if PPSSPP_PLATFORM(ANDROID)
RetroVerzeVpnState RetroVerze_VpnState();
int RetroVerze_VpnRevision();                       // naik setiap ada perubahan (status/pesan/profil)
std::string RetroVerze_VpnMessage();
std::string RetroVerze_VpnActiveProfile();          // kosong bila VPN mati
std::vector<std::string> RetroVerze_VpnProfiles();
// "refresh", "import", "delete:<nama>", "connect:<nama>", "disconnect"
void RetroVerze_VpnCommand(const std::string &cmd);
inline bool RetroVerze_VpnSupported() { return true; }
#else
inline RetroVerzeVpnState RetroVerze_VpnState() { return RetroVerzeVpnState::Off; }
inline int RetroVerze_VpnRevision() { return 0; }
inline std::string RetroVerze_VpnMessage() { return std::string(); }
inline std::string RetroVerze_VpnActiveProfile() { return std::string(); }
inline std::vector<std::string> RetroVerze_VpnProfiles() { return {}; }
inline void RetroVerze_VpnCommand(const std::string &) {}
inline bool RetroVerze_VpnSupported() { return false; }
#endif
