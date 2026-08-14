package inventree.inventree_app;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.RestrictionsManager;
import android.os.Build;
import android.os.Bundle;

import androidx.annotation.NonNull;

import java.util.HashMap;
import java.util.Map;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.EventChannel;
import io.flutter.plugin.common.MethodChannel;

public class MainActivity extends FlutterActivity {

    static final String ACTION_CUSTOM_SCAN = "inventree.inventree_app.SCAN";

    // Datalogic default wedge settings
    static final String ACTION_DATALOGIC_DECODE = "com.datalogic.decodewedge.decode_action";
    static final String CATEGORY_DATALOGIC_DECODE = "com.datalogic.decodewedge.decode_category";

    private static final String EVENT_CHANNEL = "inventree/datawedge_scans";
    private static final String MANAGED_CONFIG_CHANNEL = "inventree/managed_config";
    private static final String WEDGE_CHANNEL = "inventree/wedge";

    private EventChannel.EventSink eventSink;

    private final BroadcastReceiver scanReceiver = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            if (intent == null) return;

            String action = intent.getAction();
            if (action == null) return;

            // Check if it matches one of the strings
            if (!ACTION_CUSTOM_SCAN.equals(action) && !ACTION_DATALOGIC_DECODE.equals(action)) {
                return;
            }

            String data = intent.getStringExtra("com.symbol.datawedge.data_string");
            if (data == null || data.isEmpty()) {
                data = intent.getStringExtra("com.datalogic.decode.intentwedge.barcode_string");
            }
            if (data == null || data.isEmpty()) return;
            if (eventSink == null) return;

            Map<String, Object> payload = new HashMap<>();
            payload.put("data", data);
            payload.put("action", action);
            eventSink.success(payload);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        // Auto-configure the datawedge for Zebra/Datalogic
        WedgeConfigurator.configure(this);
    }

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new EventChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), EVENT_CHANNEL)
                .setStreamHandler(new EventChannel.StreamHandler() {
                    @Override
                    public void onListen(Object arguments, EventChannel.EventSink events) {
                        eventSink = events;
                    }

                    @Override
                    public void onCancel(Object arguments) {
                        eventSink = null;
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), MANAGED_CONFIG_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("getManagedConfiguration".equals(call.method)) {
                        Map<String, Object> config = new HashMap<>();

                        RestrictionsManager rm =
                                (RestrictionsManager) getSystemService(Context.RESTRICTIONS_SERVICE);

                        if (rm != null) {
                            Bundle restrictions = rm.getApplicationRestrictions();

                            if (restrictions != null) {
                                for (String key : restrictions.keySet()) {
                                    @SuppressWarnings("deprecation")
                                    Object value = restrictions.get(key);

                                    if (value instanceof Boolean
                                            || value instanceof Integer
                                            || value instanceof Long
                                            || value instanceof Double
                                            || value instanceof String) {
                                        config.put(key, value);
                                    } else if (value instanceof String[]) {
                                        config.put(key, java.util.Arrays.asList((String[]) value));
                                    } else if (value != null) {
                                        config.put(key, value.toString());
                                    }
                                }
                            }
                        }

                        result.success(config);
                    } else {
                        result.notImplemented();
                    }
                });

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), WEDGE_CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if ("detectWedge".equals(call.method)) {
                        String vendor = WedgeConfigurator.detectVendor(this);

                        Map<String, Object> info = new HashMap<>();
                        info.put("vendor", vendor);
                        info.put("supported", !WedgeConfigurator.VENDOR_NONE.equals(vendor));

                        result.success(info);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    @Override
    public void cleanUpFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        eventSink = null;
        super.cleanUpFlutterEngine(flutterEngine);
    }

    @Override
    protected void onResume() {
        super.onResume();

        IntentFilter filter = new IntentFilter();
        filter.addAction(ACTION_CUSTOM_SCAN);
        filter.addAction(ACTION_DATALOGIC_DECODE);
        filter.addCategory(CATEGORY_DATALOGIC_DECODE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(scanReceiver, filter, Context.RECEIVER_EXPORTED);
        } else {
            registerReceiver(scanReceiver, filter);
        }
    }

    @Override
    protected void onPause() {
        try {
            unregisterReceiver(scanReceiver);
        } catch (IllegalArgumentException ignored) {
            // Receiver was never registered
        }
        super.onPause();
    }

}
