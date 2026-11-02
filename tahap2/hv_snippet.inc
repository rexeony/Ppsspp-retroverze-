// ===================== Penyedia data lobby (universal) =====================
// 0 = RetroVerze (status.xml), 1 = HunterVerse (new_gh_getter.php, potongan HTML).
static const char *kHunterVerseGhUrl = "https://hunstermonter.net/new_gh_getter.php";
static const size_t kHunterVerseMaxNickChars = 12;
static int g_lobbyProvider = -1;  // -1 = belum dipilih (ditentukan otomatis dari alamat server ad hoc)

static int LobbyProviderIndex() {
	if (g_lobbyProvider < 0) {
		std::string host = g_Config.sProAdhocServer;
		std::transform(host.begin(), host.end(), host.begin(), [](unsigned char c) { return (char)tolower(c); });
		g_lobbyProvider = (host.find("hunster") != std::string::npos) ? 1 : 0;
	}
	return g_lobbyProvider;
}

static const char *LobbyProviderName() {
	return LobbyProviderIndex() == 1 ? "HunterVerse" : "RetroVerze";
}

static void ReplaceAllInPlace(std::string &s, const std::string &from, const std::string &to) {
	size_t pos = 0;
	while ((pos = s.find(from, pos)) != std::string::npos) {
		s.replace(pos, from.size(), to);
		pos += to.size();
	}
}

static std::string HtmlDecodeBasic(std::string s) {
	ReplaceAllInPlace(s, "&nbsp;", " ");
	ReplaceAllInPlace(s, "&lt;", "<");
	ReplaceAllInPlace(s, "&gt;", ">");
	ReplaceAllInPlace(s, "&quot;", "\"");
	ReplaceAllInPlace(s, "&#039;", "'");
	ReplaceAllInPlace(s, "&amp;", "&");
	return s;
}

// Teks mulai dari posisi pos sampai tanda '<' berikutnya.
static std::string HtmlTextFrom(const std::string &h, size_t pos) {
	const size_t end = h.find('<', pos);
	return TrimCopy(HtmlDecodeBasic(h.substr(pos, end == std::string::npos ? std::string::npos : end - pos)));
}

// Parse satu blok <div class="EntireGame">...</div> milik HunterVerse. Hanya GH yang ada pemainnya.
static void ParseHunterVerseGame(const std::string &seg, std::vector<LobbySection> *sections) {
	static const std::string kGameName = "<div class='GameName'>";
	static const std::string kFullGH = "<div class='FullGH ";
	static const std::string kTot = "<div class='TotName'>";

	const size_t gn = seg.find(kGameName);
	if (gn == std::string::npos)
		return;
	LobbySection sec;
	sec.game = HtmlTextFrom(seg, gn + kGameName.size());
	if (sec.game.empty())
		return;

	size_t q = seg.find(kFullGH);
	while (q != std::string::npos) {
		size_t nextGh = seg.find(kFullGH, q + kFullGH.size());
		const size_t tot = seg.find(kTot, q);
		size_t end = nextGh;
		if (tot != std::string::npos && (end == std::string::npos || tot < end))
			end = tot;
		const std::string block = seg.substr(q, end == std::string::npos ? std::string::npos : end - q);
		q = (nextGh != std::string::npos && (tot == std::string::npos || nextGh < tot)) ? nextGh : std::string::npos;

		if (block.compare(kFullGH.size(), 12, "emptyGHClass") == 0)
			continue;

		static const std::string kCtx = "<span class='megaCtxt'> <b>";
		const size_t c = block.find(kCtx);
		if (c == std::string::npos)
			continue;
		const std::string ghName = HtmlTextFrom(block, c + kCtx.size());
		if (ghName.empty())
			continue;

		std::string pop;
		const size_t pp = block.find("class='GHPop GHPop");
		if (pp != std::string::npos) {
			const size_t gt = block.find('>', pp);
			if (gt != std::string::npos)
				pop = HtmlTextFrom(block, gt + 1);
		}

		std::string names;
		int count = 0;
		static const std::string kHunter = "class='Hunter'>";
		size_t h = block.find(kHunter);
		while (h != std::string::npos) {
			const size_t sp = block.find("<span", h);
			const size_t nextH = block.find(kHunter, h + kHunter.size());
			if (sp != std::string::npos && (nextH == std::string::npos || sp < nextH)) {
				const size_t gt = block.find('>', sp);
				if (gt != std::string::npos) {
					std::string n = TruncateUtf8(HtmlTextFrom(block, gt + 1), kHunterVerseMaxNickChars);
					if (!n.empty()) {
						if (count)
							names += ", ";
						names += n;
						count++;
					}
				}
			}
			h = nextH;
		}
		if (count == 0 && pop.empty())
			continue;
		std::string line = ghName;
		if (!pop.empty())
			line += " (" + pop + ")";
		if (count)
			line += " - " + names;
		sec.players += count ? count : atoi(pop.c_str());
		sec.lines.push_back(line);
	}
	if (sec.lines.empty())
		return;
	std::sort(sec.lines.begin(), sec.lines.end());
	sections->push_back(std::move(sec));
}

static bool ParseHunterVerseHtml(const std::string &html, std::vector<LobbySection> *sections) {
	sections->clear();
	static const std::string kGame = "<div class=\"EntireGame\">";
	size_t p = html.find(kGame);
	if (p == std::string::npos)
		return false;  // bukan format yang dikenal
	while (p != std::string::npos) {
		const size_t next = html.find(kGame, p + kGame.size());
		ParseHunterVerseGame(html.substr(p, next == std::string::npos ? std::string::npos : next - p), sections);
		p = next;
	}
	std::sort(sections->begin(), sections->end(), [](const LobbySection &a, const LobbySection &b) {
		const int ra = LobbySectionRank(a.game), rb = LobbySectionRank(b.game);
		if (ra != rb)
			return ra < rb;
		return a.game < b.game;
	});
	return true;
}

static bool ParseLobbyData(const std::string &data, std::vector<LobbySection> *sections) {
	return LobbyProviderIndex() == 1 ? ParseHunterVerseHtml(data, sections) : ParseLobbyXml(data, sections);
}

