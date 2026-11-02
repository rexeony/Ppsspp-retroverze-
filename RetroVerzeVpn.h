// RetroVerze: antarmuka status/aksi VPN tertanam untuk UI native.
// Di Android diimplementasikan di android/jni/app-android.cpp; platform lain berupa stub.
#pragma once

#include "ppsspp_config.h"

enum class RetroVerzeVpnState {
	Off = 0,
	Connecting = 1,
	On = 2,
	Failed = 3,
};

#if PPSSPP_PLATFORM(ANDROID)
RetroVerzeVpnState RetroVerze_VpnState();
void RetroVerze_VpnToggle();
inline bool RetroVerze_VpnSupported() { return true; }
#else
inline RetroVerzeVpnState RetroVerze_VpnState() { return RetroVerzeVpnState::Off; }
inline void RetroVerze_VpnToggle() {}
inline bool RetroVerze_VpnSupported() { return false; }
#endif
