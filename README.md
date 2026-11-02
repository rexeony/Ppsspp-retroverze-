# PPSSPP Openvpn

PPSSPP 1.20.4 + layar Multiplayer. Dibangun lewat GitHub Actions (`retroverze_apk.yml`, jalankan manual).

## Fitur Multiplayer
Tombol **Multiplayer** ada di menu utama dan di **pause screen** (labelnya menunjukkan status: Off / On / VPN <profil>).
Layar Multiplayer punya dua mode, hanya satu yang boleh aktif:

1. **OpenVPN** – pemain mengimpor file `.ovpn` sendiri (RetroVerze, HunterVerse, atau server lain).
   Tekan **Impor .ovpn**, atau taruh file di `Android/data/<nama aplikasi>/files/ovpn/` lalu buka ulang layar.
   Tidak ada `.ovpn` yang ditanam di APK. Direktif berbahaya (up/down/plugin/script-security, dll) dibuang saat impor,
   dan hanya PPSSPP yang lewat VPN, bukan seluruh HP.
2. **Server Relay** – pilih server publik dari daftar bawaan PPSSPP (tanpa VPN).

Saklar **Aktifkan multiplayer** di layar yang sama bisa dinyalakan saat game sudah berjalan offline.

## Urutan build (lihat workflow)
`apply_retroverze.sh` -> `apply_vpn_engine.sh` -> `tahap2/apply_vpn_ui.sh` -> `tahap2/apply_vpn_menu.sh` -> `tahap2/apply_lobby_providers.sh`

`retroverze.ovpn` di root tidak dipakai lagi oleh build.
