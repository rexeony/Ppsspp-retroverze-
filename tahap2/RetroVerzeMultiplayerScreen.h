// RetroVerze: layar Multiplayer (OpenVPN atau Server Relay). Dipakai dari menu utama dan pause screen.
#pragma once

#include <string>

#include "UI/SimpleDialogScreen.h"

// Teks ringkas status multiplayer untuk label tombol, mis. "Multiplayer: Off".
std::string RetroVerze_MultiplayerLabel();

class RetroVerzeMultiplayerScreen : public UISimpleBaseDialogScreen {
public:
	RetroVerzeMultiplayerScreen();

	void update() override;
	void dialogFinished(const Screen *dialog, DialogResult dr) override;
	const char *tag() const override { return "RetroVerzeMultiplayer"; }

protected:
	std::string_view GetTitle() const override { return "Multiplayer"; }
	void CreateDialogViews(UI::ViewGroup *parent) override;

private:
	int lastRevision_ = 0;
};
