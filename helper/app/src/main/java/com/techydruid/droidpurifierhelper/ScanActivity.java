package com.techydruid.droidpurifierhelper;

import android.app.Activity;
import android.app.admin.DevicePolicyManager;
import android.content.ComponentName;
import android.content.Context;
import android.content.Intent;
import android.content.pm.ApplicationInfo;
import android.content.pm.PackageInfo;
import android.content.pm.PackageManager;
import android.content.pm.ServiceInfo;
import android.os.Build;
import android.os.Bundle;

import org.json.JSONArray;
import org.json.JSONObject;

import java.io.File;
import java.io.FileOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

public class ScanActivity extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        new Thread(() -> {
            try {
                writeScan();
            } catch (Throwable ignored) {
            } finally {
                runOnUiThread(this::finish);
            }
        }, "DroidPurifierScan").start();
    }

    private void writeScan() throws Exception {
        PackageManager pm = getPackageManager();
        int flags = PackageManager.GET_ACTIVITIES
                | PackageManager.GET_SERVICES
                | PackageManager.GET_RECEIVERS
                | PackageManager.GET_PROVIDERS
                | PackageManager.GET_PERMISSIONS
                | PackageManager.GET_META_DATA;
        List<PackageInfo> packages = pm.getInstalledPackages(flags);

        Set<String> activeAdmins = new HashSet<>();
        try {
            DevicePolicyManager dpm = (DevicePolicyManager) getSystemService(Context.DEVICE_POLICY_SERVICE);
            List<ComponentName> admins = dpm.getActiveAdmins();
            if (admins != null) {
                for (ComponentName component : admins) {
                    activeAdmins.add(component.getPackageName());
                }
            }
        } catch (Throwable ignored) {
        }

        JSONArray array = new JSONArray();
        for (PackageInfo pi : packages) {
            ApplicationInfo ai = pi.applicationInfo;
            if (ai == null) continue;
            JSONObject item = new JSONObject();
            item.put("packageName", pi.packageName);
            CharSequence label = pm.getApplicationLabel(ai);
            item.put("label", label == null ? pi.packageName : label.toString());
            item.put("versionName", pi.versionName == null ? "" : pi.versionName);
            item.put("versionCode", Build.VERSION.SDK_INT >= 28 ? pi.getLongVersionCode() : pi.versionCode);
            item.put("sourceDir", ai.sourceDir == null ? "" : ai.sourceDir);
            item.put("uid", ai.uid);
            item.put("system", (ai.flags & ApplicationInfo.FLAG_SYSTEM) != 0);
            item.put("updatedSystem", (ai.flags & ApplicationInfo.FLAG_UPDATED_SYSTEM_APP) != 0);
            item.put("enabled", ai.enabled);
            item.put("privileged", ai.sourceDir != null && ai.sourceDir.contains("/priv-app/"));
            item.put("deviceAdmin", activeAdmins.contains(pi.packageName));

            String installer = "";
            try {
                if (Build.VERSION.SDK_INT >= 30) {
                    String value = pm.getInstallSourceInfo(pi.packageName).getInstallingPackageName();
                    if (value != null) installer = value;
                } else {
                    String value = pm.getInstallerPackageName(pi.packageName);
                    if (value != null) installer = value;
                }
            } catch (Throwable ignored) {
            }
            item.put("installer", installer);

            Intent launch = null;
            try {
                launch = pm.getLaunchIntentForPackage(pi.packageName);
            } catch (Throwable ignored) {
            }
            item.put("hasLauncher", launch != null);

            JSONArray permissions = new JSONArray();
            if (pi.requestedPermissions != null) {
                for (String permission : pi.requestedPermissions) {
                    if (permission != null) permissions.put(permission);
                }
            }
            item.put("requestedPermissions", permissions);

            JSONArray servicePermissions = new JSONArray();
            if (pi.services != null) {
                Set<String> seen = new HashSet<>();
                for (ServiceInfo service : pi.services) {
                    if (service != null && service.permission != null && seen.add(service.permission)) {
                        servicePermissions.put(service.permission);
                    }
                }
            }
            item.put("servicePermissions", servicePermissions);
            array.put(item);
        }

        JSONObject root = new JSONObject();
        root.put("schema", 1);
        root.put("packages", array);
        File dir = getExternalFilesDir(null);
        if (dir == null) throw new IllegalStateException("No external files directory");
        File out = new File(dir, "droid_purifier_scan.json");
        try (FileOutputStream stream = new FileOutputStream(out, false)) {
            stream.write(root.toString().getBytes(StandardCharsets.UTF_8));
            stream.flush();
        }
    }
}
