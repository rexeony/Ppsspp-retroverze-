// RetroVerze: kontrol VPN tertanam (memakai mesin ics-openvpn dari Tahap 1).
// Lisensi mengikuti PPSSPP (GPL 2.0+).
package org.ppsspp.ppsspp;

import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.ServiceConnection;
import android.net.VpnService;
import android.os.IBinder;
import android.os.RemoteException;
import android.util.Log;

import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;

import de.blinkt.openvpn.VpnProfile;
import de.blinkt.openvpn.core.ConfigParser;
import de.blinkt.openvpn.core.ConnectionStatus;
import de.blinkt.openvpn.core.IOpenVPNServiceInternal;
import de.blinkt.openvpn.core.OpenVPNService;
import de.blinkt.openvpn.core.ProfileManager;
import de.blinkt.openvpn.core.VPNLaunchHelper;
import de.blinkt.openvpn.core.VpnStatus;

public final class RetroVerzeVpn implements VpnStatus.StateListener {
	private static final String TAG = "RetroVerzeVpn";

	// File .ovpn dari RetroVerze, ditaruh di assets modul VPN (lihat apply_vpn_ui.sh).
	private static final String OVPN_ASSET = "retroverze.ovpn";

	// Rute tambahan ke jaringan RetroVerze (CIDR dipisah spasi), mis. "10.8.0.0/24".
	// Kosong = hanya subnet terowongan + rute "route ..." yang ada di file .ovpn.
	// Rute "redirect-gateway" dari server SENGAJA diabaikan (route-nopull) agar VPN tidak global.
	private static final String EXTRA_ROUTES = "10.42.0.1/32";

	public static final int STATE_OFF = 0;
	public static final int STATE_CONNECTING = 1;
	public static final int STATE_ON = 2;
	public static final int STATE_ERROR = 3;

	private static RetroVerzeVpn instance;

	private volatile int state = STATE_OFF;
	private volatile String statusText = "Multiplayer: Off";

	public static synchronized RetroVerzeVpn get(Context c) {
		if (instance == null) {
			instance = new RetroVerzeVpn();
			VpnStatus.addStateListener(instance);
		}
		return instance;
	}

	private RetroVerzeVpn() {}

	public int getState() { return state; }
	public boolean isOn() { return state == STATE_ON; }
	public String getStatusText() { return statusText; }

	/** Dipanggil dari tombol Multiplayer On/Off. */
	public void toggle(Context c) {
		if (state == STATE_OFF || state == STATE_ERROR) {
			enable(c);
		} else {
			disable(c);
		}
	}

	public void enable(Context c) {
		Context app = c.getApplicationContext();
		set(STATE_CONNECTING, "Multiplayer: menyambung...");
		Intent need = VpnService.prepare(app);
		if (need == null) {
			startNow(app);
		} else {
			// Izin VPN Android belum diberikan: minta lewat activity transparan.
			Intent i = new Intent(app, RetroVerzeVpnPermissionActivity.class);
			i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
			app.startActivity(i);
		}
	}

	void onPermissionDenied() {
		set(STATE_OFF, "Multiplayer: izin VPN ditolak");
	}

	void startNow(Context app) {
		try {
			VpnProfile vp = buildProfile(app);
			ProfileManager.setTemporaryProfile(app, vp);
			VPNLaunchHelper.startOpenVpn(vp, app, "RetroVerze", true);
		} catch (Exception e) {
			Log.e(TAG, "Gagal memulai VPN", e);
			set(STATE_ERROR, "Multiplayer: gagal (" + e.getMessage() + ")");
		}
	}

	private VpnProfile buildProfile(Context app) throws Exception {
		ConfigParser cp = new ConfigParser();
		try (InputStream in = app.getAssets().open(OVPN_ASSET)) {
			cp.parseConfig(new InputStreamReader(in, StandardCharsets.UTF_8));
		}
		VpnProfile vp = cp.convertProfile();
		vp.mName = "RetroVerze";

		// 1) Hanya aplikasi ini yang lewat VPN (bukan seluruh HP).
		vp.mAllowedAppsVpn.clear();
		vp.mAllowedAppsVpn.add(app.getPackageName());
		vp.mAllowedAppsVpnAreDisallowed = false;

		// 2) Abaikan rute dari server (termasuk redirect-gateway); pakai rute lokal saja.
		vp.mRoutenopull = true;
		vp.mUseDefaultRoute = false;
		if (!EXTRA_ROUTES.isEmpty()) {
			String old = vp.mCustomRoutes == null ? "" : vp.mCustomRoutes.trim();
			vp.mCustomRoutes = (old + " " + EXTRA_ROUTES).trim();
		}
		return vp;
	}

	public void disable(Context c) {
		final Context app = c.getApplicationContext();
		Intent i = new Intent(app, OpenVPNService.class);
		i.setAction(OpenVPNService.START_SERVICE);
		ServiceConnection conn = new ServiceConnection() {
			@Override
			public void onServiceConnected(ComponentName name, IBinder binder) {
				try {
					IOpenVPNServiceInternal.Stub.asInterface(binder).stopVPN(false);
				} catch (RemoteException e) {
					Log.e(TAG, "stopVPN gagal", e);
				}
				app.unbindService(this);
			}
			@Override
			public void onServiceDisconnected(ComponentName name) {}
		};
		if (!app.bindService(i, conn, Context.BIND_AUTO_CREATE)) {
			set(STATE_OFF, "Multiplayer: Off");
		}
	}

	@Override
	public void updateState(String s, String logmessage, int resId, ConnectionStatus level, Intent intent) {
		switch (level) {
		case LEVEL_CONNECTED:
			set(STATE_ON, "Multiplayer: On"); break;
		case LEVEL_NOTCONNECTED:
			// Jangan timpa pesan error/izin ditolak dengan "Off" generik.
			if (state != STATE_ERROR) set(STATE_OFF, "Multiplayer: Off");
			break;
		case LEVEL_AUTH_FAILED:
			set(STATE_ERROR, "Multiplayer: autentikasi gagal"); break;
		case LEVEL_WAITING_FOR_USER_INPUT:
			set(STATE_ERROR, "Multiplayer: butuh input pengguna"); break;
		case LEVEL_NONETWORK:
			set(STATE_CONNECTING, "Multiplayer: menunggu jaringan..."); break;
		case LEVEL_VPNPAUSED:
		case LEVEL_START:
		case LEVEL_CONNECTING_SERVER_REPLIED:
		case LEVEL_CONNECTING_NO_SERVER_REPLY_YET:
			set(STATE_CONNECTING, "Multiplayer: menyambung..."); break;
		default:
			break;
		}
	}

	@Override
	public void setConnectedVPN(String uuid) {}

	private void set(int st, String text) {
		state = st;
		statusText = text;
		// Beri tahu sisi native (tombol di MainScreen membaca status ini).
		try {
			NativeApp.sendMessageFromJava("retroverze_vpn_state", String.valueOf(st));
		} catch (Throwable t) {
			Log.w(TAG, "Native belum siap: " + t);
		}
	}
}
