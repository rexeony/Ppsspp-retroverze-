// Copyright (c) 2014- PPSSPP Project.

// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, version 2.0 or later versions.

// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License 2.0 for more details.

// A copy of the GPL 2.0 should have been included with the program.
// If not, see http://www.gnu.org/licenses/

// Official git repository and contact information can be found at
// https://github.com/hrydgard/ppsspp and http://www.ppsspp.org/.

#pragma once

#include <functional>
#include <memory>
#include <string>
#include <vector>

#include "Common/File/Path.h"
#include "Common/UI/UIScreen.h"
#include "Common/UI/ViewGroup.h"
#include "Core/ControlMapper.h"
#include "UI/BaseScreens.h"
#include "UI/Screen.h"
#include "UI/GameInfoCache.h"
#include "UI/AdhocServerScreen.h"
#include "Common/Net/HTTPRequest.h"
#include "Common/UI/TabHolder.h"

// Satu game di server RetroVerze beserta GH-nya yang terisi.
struct LobbySection {
	std::string game;
	std::vector<std::string> lines;  // "GH 01 A (2) - nama1, nama2"
	int players = 0;
};

class GamePauseScreen : public UIBaseDialogScreen, protected ControlListener {
public:
	GamePauseScreen(const Path &filename, bool bootPending);
	~GamePauseScreen();

	void dialogFinished(const Screen *dialog, DialogResult dr) override;

	const char *tag() const override { return "GamePause"; }

protected:
	void CreateViews() override;
	void update() override;
	UI::Margins RootMargins() const override;
	ViewLayoutMode LayoutMode() const override {
		return ViewLayoutMode::ApplyInsets;
	}
	// For processing of certain mapped keys.
	bool UnsyncKey(const KeyInput &key) override;
	void UnsyncAxis(const AxisInput *axes, size_t count) override;

	void OnVKey(VirtKey virtualKeyCode, bool down) override;

private:
	void CreateSavestateControls(UI::LinearLayout *viewGroup, UI::LinearLayout **extraRow);

	void OnGameSettings(UI::EventParams &e);
	void OnExit(UI::EventParams &e);
	void OnReportFeedback(UI::EventParams &e);

	void OnCreateConfig(UI::EventParams &e);
	void OnDeleteConfig(UI::EventParams &e);

	void OnState(UI::EventParams &e);
	void ShowContextMenu(UI::View *menuButton, bool portrait);

	void AddExtraOptions(UI::ViewGroup *parent);

	// --- RetroVerze multiplayer (OpenVPN / Server Relay), bisa diaktifkan dari pause screen ---
	std::string lastMultiplayerLabel_;

	// --- RetroVerze lobby status (MHP3rd) ---
	bool LobbyEnabled() const;
	void RefreshLobby();
	void CancelLobby();
	void UpdateLobby();
	void CreateLobbyTab(UI::ViewGroup *parent);
	void RebuildLobbyContent();
	std::shared_ptr<http::Request> lobbyRequest_;
	std::vector<LobbySection> lobbySections_;
	std::string lobbyError_;
	std::string lobbyUpdatedText_;
	bool lobbyLoaded_ = false;
	double lobbyLastRefresh_ = 0.0;
	double lobbyRequestStart_ = 0.0;
	UI::ViewGroup *lobbyContent_ = nullptr;  // valid only between CreateViews() calls
	UI::TabHolder *lobbyTabs_ = nullptr;      // idem

	// hack
	bool finishNextFrame_ = false;
	DialogResult finishNextFrameResult_ = DR_CANCEL;

	UI::Choice *playButton_ = nullptr;

	// State change tracking, a bit ugly heh, but works.
	bool lastOnline_ = false;
	bool lastNetInited_ = false;
	bool lastNetInetInited_ = false;
	bool lastAdhocServerConnected_ = false;
	bool lastDNSConfigLoaded_ = false;

	bool bootPending_ = false;

	std::string saveStatePrefix_;
	double createdTime_ = 0.0;
};

std::string GetConfirmExitMessage();
