// RetroVerze: activity transparan untuk memilih file .ovpn dari penyimpanan dan menyimpannya sebagai profil.
package org.ppsspp.ppsspp;

import android.app.Activity;
import android.content.Intent;
import android.database.Cursor;
import android.net.Uri;
import android.os.Bundle;
import android.provider.OpenableColumns;

import java.io.InputStream;

public class RetroVerzeOvpnImportActivity extends Activity {
	private static final int REQ_PICK = 4712;

	@Override
	protected void onCreate(Bundle savedInstanceState) {
		super.onCreate(savedInstanceState);
		Intent i = new Intent(Intent.ACTION_OPEN_DOCUMENT);
		i.addCategory(Intent.CATEGORY_OPENABLE);
		i.setType("*/*");
		startActivityForResult(i, REQ_PICK);
	}

	@Override
	protected void onActivityResult(int requestCode, int resultCode, Intent data) {
		super.onActivityResult(requestCode, resultCode, data);
		RetroVerzeVpn vpn = RetroVerzeVpn.get(this);
		if (requestCode == REQ_PICK && resultCode == RESULT_OK && data != null && data.getData() != null) {
			Uri uri = data.getData();
			String result;
			try (InputStream in = getContentResolver().openInputStream(uri)) {
				String text = in == null ? null : RetroVerzeVpn.readLimited(in);
				if (text == null) {
					result = "File terlalu besar atau tidak bisa dibaca";
				} else {
					String name = displayName(uri);
					String err = vpn.saveProfile(name, text);
					result = err == null ? "Profil '" + RetroVerzeVpn.safeName(name) + "' ditambahkan" : err;
				}
			} catch (Exception e) {
				result = "Gagal membaca file: " + e.getMessage();
			}
			vpn.report(result);
		}
		finish();
	}

	private String displayName(Uri uri) {
		try (Cursor c = getContentResolver().query(uri, null, null, null, null)) {
			if (c != null && c.moveToFirst()) {
				int idx = c.getColumnIndex(OpenableColumns.DISPLAY_NAME);
				if (idx >= 0) return c.getString(idx);
			}
		} catch (Exception ignored) {}
		return "profil";
	}
}
