package com.example.live_location;

import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;

import androidx.annotation.NonNull;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;



public class MainActivity extends FlutterActivity {
    private static final String CHANNEL = "com.example.location";
    private LocationManager locationManager;
    private LocationListener locationListener;

    @Override
    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
                .setMethodCallHandler((call, result) -> {
                    if (call.method.equals("startLocationUpdates")) {
                        startLocationUpdates();
                        result.success(null);
                    } else {
                        result.notImplemented();
                    }
                });
    }

    private void startLocationUpdates() {
        locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);

        locationListener = new LocationListener() {
            @Override
            public void onLocationChanged(@NonNull Location location) {
                System.out.println("Lat: " + location.getLatitude() + ", Lon: " + location.getLongitude());
            }

            @Override
            public void onProviderEnabled(@NonNull String provider) {
                System.out.println("Provider enabled: " + provider);
            }

            @Override
            public void onProviderDisabled(@NonNull String provider) {
                System.out.println("Provider disabled: " + provider);
            }
        };

        // Request updates from GPS_PROVIDER every 5 seconds and 10 meters
        try {
            locationManager.requestLocationUpdates(
                    LocationManager.GPS_PROVIDER, // Use GPS
                    5000,                        // 5 seconds interval
                    10,                          // 10 meters distance
                    locationListener
            );
        } catch (SecurityException e) {
            e.printStackTrace();
        }
    }
}
