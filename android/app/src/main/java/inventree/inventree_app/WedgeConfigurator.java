package inventree.inventree_app;

import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import com.datalogic.decode.BarcodeManager;
import com.datalogic.decode.configuration.IntentDeliveryMode;
import com.datalogic.decode.configuration.ScannerProperties;
import com.datalogic.device.ErrorManager;
import com.datalogic.device.configuration.ConfigException;

public class WedgeConfigurator {

    // Zebra specific settings
    private static final String DATAWEDGE_PROFILE = "InvenTree";
    public static final String ZEBRA_BROADCAST_INTENT = "2";
    private static final String DATAWEDGE_API_ACTION = "com.symbol.datawedge.api.ACTION";
    private static final String DATAWEDGE_SET_CONFIG = "com.symbol.datawedge.api.SET_CONFIG";

    // Datalogic retry settings
    private static final int DATALOGIC_MAX_ATTEMPTS = 5;
    private static final long DATALOGIC_RETRY_DELAY_MS = 2000;

    // Vendor identifiers
    public static final String VENDOR_ZEBRA = "zebra";
    public static final String VENDOR_DATALOGIC = "datalogic";
    public static final String VENDOR_NONE = "none";

    private static final Map<String, String[]> VENDOR_PACKAGES = buildVendorPackages();

    // Spawn a new thread for Datalogic calls
    private static final ExecutorService DATALOGIC_EXECUTOR = Executors.newSingleThreadExecutor();

    private static Map<String, String[]> buildVendorPackages() {
        Map<String, String[]> map = new LinkedHashMap<>();

        map.put(VENDOR_ZEBRA, new String[] {"com.symbol.datawedge"});

        map.put(
                VENDOR_DATALOGIC,
                new String[] {
                        "com.datalogic.decode",
                        "com.datalogic.decodewedge",
                        "com.datalogic.systemsettings"
                });

        return map;
    }

    public static String detectVendor(Context context) {
        try {
            PackageManager pm = context.getPackageManager();

            if (pm == null) {
                return VENDOR_NONE;
            }

            for (Map.Entry<String, String[]> entry : VENDOR_PACKAGES.entrySet()) {
                for (String packageName : entry.getValue()) {
                    if (isPackageInstalled(pm, packageName)) {
                        return entry.getKey();
                    }
                }
            }
        } catch (Throwable e) {
            // PackageManager lookup failed
        }

        return detectVendorByManufacturer();
    }

    private static String detectVendorByManufacturer() {
        String manufacturer = Build.MANUFACTURER == null ? "" : Build.MANUFACTURER.toLowerCase();

        if (manufacturer.contains("zebra") || manufacturer.contains("symbol")) {
            return VENDOR_ZEBRA;
        }

        if (manufacturer.contains("datalogic")) {
            return VENDOR_DATALOGIC;
        }

        return VENDOR_NONE;
    }

    private static boolean isPackageInstalled(PackageManager pm, String packageName) {
        try {
            pm.getPackageInfo(packageName, 0);
            return true;
        } catch (PackageManager.NameNotFoundException e) {
            return false;
        } catch (Throwable e) {
            return false;
        }
    }

    public static void configure(Context context) {
        try {
            String vendor = detectVendor(context);

            if (VENDOR_ZEBRA.equals(vendor)) {
                configureZebra(context);
            } else if (VENDOR_DATALOGIC.equals(vendor)) {
                scheduleDatalogicConfig(1);
            }
        } catch (Throwable e) {
            // Vendor detection was unsuccessful
        }
    }

    /**
     * Schedule the Datalogic wedge configuration.
     * @param attempt Current attempt number
     */
    private static void scheduleDatalogicConfig(int attempt) {
        new Handler(Looper.getMainLooper())
                .postDelayed(
                        () -> DATALOGIC_EXECUTOR.execute(() -> {
                            try {
                                configureDatalogic();
                            } catch (Throwable e) {
                                if (attempt < DATALOGIC_MAX_ATTEMPTS) {
                                    scheduleDatalogicConfig(attempt + 1);
                                }
                            }
                        }),
                        DATALOGIC_RETRY_DELAY_MS);
    }

    /**
     * Configure Zebra datawedge by creating a custom profile for the app.
     * @param context MainActivity instance passed in as context
     */
    private static void configureZebra(Context context) {
        Bundle profileConfig = new Bundle();
        profileConfig.putString("PROFILE_NAME", DATAWEDGE_PROFILE);
        profileConfig.putString("PROFILE_ENABLED", "true");
        profileConfig.putString("CONFIG_MODE", "CREATE_IF_NOT_EXIST");

        Bundle appConfig = new Bundle();
        appConfig.putString("PACKAGE_NAME", context.getPackageName());
        appConfig.putStringArray("ACTIVITY_LIST", new String[] {"*"});
        profileConfig.putParcelableArray("APP_LIST", new Bundle[] {appConfig});

        ArrayList<Bundle> plugins = new ArrayList<>();

        Bundle barcodePlugin = new Bundle();
        barcodePlugin.putString("PLUGIN_NAME", "BARCODE");
        barcodePlugin.putString("RESET_CONFIG", "true");

        Bundle barcodeProps = new Bundle();
        barcodeProps.putString("scanner_input_enabled", "true");
        barcodeProps.putString("scanner_selection", "auto");
        barcodePlugin.putBundle("PARAM_LIST", barcodeProps);
        plugins.add(barcodePlugin);

        Bundle intentPlugin = new Bundle();
        intentPlugin.putString("PLUGIN_NAME", "INTENT");
        intentPlugin.putString("RESET_CONFIG", "true");

        Bundle intentProps = new Bundle();
        intentProps.putString("intent_output_enabled", "true");
        intentProps.putString("intent_action", MainActivity.ACTION_CUSTOM_SCAN);
        intentProps.putString("intent_delivery", ZEBRA_BROADCAST_INTENT);
        intentPlugin.putBundle("PARAM_LIST", intentProps);
        plugins.add(intentPlugin);

        Bundle keystrokePlugin = new Bundle();
        keystrokePlugin.putString("PLUGIN_NAME", "KEYSTROKE");
        keystrokePlugin.putString("RESET_CONFIG", "true");

        Bundle keystrokeProps = new Bundle();
        keystrokeProps.putString("keystroke_output_enabled", "false");
        keystrokePlugin.putBundle("PARAM_LIST", keystrokeProps);
        plugins.add(keystrokePlugin);

        profileConfig.putParcelableArrayList("PLUGIN_CONFIG", plugins);

        Intent intent = new Intent();
        intent.setAction(DATAWEDGE_API_ACTION);
        intent.putExtra(DATAWEDGE_SET_CONFIG, profileConfig);
        context.sendBroadcast(intent);
    }

    /**
     * Attempt to apply Datalogic wedge configuration.
     */
    private static void configureDatalogic() {
        ErrorManager.enableExceptions(false);

        BarcodeManager manager = new BarcodeManager();

        ScannerProperties configuration = ScannerProperties.edit(manager);

        if (configuration == null) {
            throw new IllegalStateException();
        }

        // Keyboard wedge only on focus of a text field
        configuration.keyboardWedge.onlyOnFocus.set(true);
        configuration.intentWedge.enable.set(true);
        // Default action, category
        configuration.intentWedge.action.set(MainActivity.ACTION_DATALOGIC_DECODE);
        configuration.intentWedge.category.set(MainActivity.CATEGORY_DATALOGIC_DECODE);
        // Enable broadcast
        configuration.intentWedge.deliveryMode.set(IntentDeliveryMode.BROADCAST);

        int result = configuration.store(manager, true);

        if (result != ConfigException.SUCCESS) {
            throw new IllegalStateException();
        }
    }
}
