package com.retailbilling.mobile;

import android.content.Intent;
import android.content.SharedPreferences;
import android.net.Uri;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {
    private static final String ACTIONS_CHANNEL = "retail_billing/actions";

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(
                flutterEngine.getDartExecutor().getBinaryMessenger(),
                ACTIONS_CHANNEL
        ).setMethodCallHandler((call, result) -> {
            SharedPreferences preferences = getSharedPreferences(
                    "retail_billing_mobile",
                    MODE_PRIVATE
            );

            if (call.method.equals("getPreference")) {
                String key = call.argument("key");
                result.success(key == null ? null : preferences.getString(key, null));
                return;
            }

            if (call.method.equals("setPreference")) {
                String key = call.argument("key");
                String value = call.argument("value");
                if (key == null || value == null) {
                    result.error("INVALID_PREFERENCE", "Key and value are required.", null);
                    return;
                }
                preferences.edit().putString(key, value).apply();
                result.success(null);
                return;
            }

            if (call.method.equals("removePreference")) {
                String key = call.argument("key");
                if (key != null) {
                    preferences.edit().remove(key).apply();
                }
                result.success(null);
                return;
            }

            if (call.method.equals("openUrl")) {
                String url = call.argument("url");
                if (url == null || url.trim().isEmpty()) {
                    result.error("INVALID_URL", "URL is required.", null);
                    return;
                }

                try {
                    startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse(url)));
                    result.success(null);
                } catch (Exception error) {
                    result.error("OPEN_FAILED", error.getMessage(), null);
                }
                return;
            }

            if (call.method.equals("shareText")) {
                String subject = call.argument("subject");
                String text = call.argument("text");
                Intent intent = new Intent(Intent.ACTION_SEND);
                intent.setType("text/plain");
                intent.putExtra(Intent.EXTRA_SUBJECT, subject == null ? "Retail Billing" : subject);
                intent.putExtra(Intent.EXTRA_TEXT, text == null ? "" : text);
                startActivity(Intent.createChooser(intent, "Share bill"));
                result.success(null);
                return;
            }

            result.notImplemented();
        });
    }
}
