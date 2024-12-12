package com.example.live_location;
//
//import android.app.Dialog;
//import android.location.Location;
//import android.location.LocationListener;
//import android.location.LocationManager;
//import android.os.Bundle;
//import android.util.Log;
//
//import androidx.annotation.NonNull;
//
//import java.util.HashMap;
//
import io.flutter.embedding.android.FlutterActivity;
//import io.flutter.embedding.engine.FlutterEngine;
//import io.flutter.plugin.common.MethodChannel;
//
//import com.google.android.gms.common.ConnectionResult;
//import com.google.android.gms.common.GoogleApiAvailability;
//
public class MainActivity extends FlutterActivity {
//    private static final String CHANNEL = "com.example.location";
//    private LocationManager locationManager;
//    private LocationListener locationListener;
//
//    @Override
//    protected void onCreate(Bundle savedInstanceState) {
//        super.onCreate(savedInstanceState);
//        checkGooglePlayServices();
//    }
//
//    @Override
//    public void configureFlutterEngine(@NonNull FlutterEngine flutterEngine) {
//        super.configureFlutterEngine(flutterEngine);
//
//        new MethodChannel(flutterEngine.getDartExecutor().getBinaryMessenger(), CHANNEL)
//                .setMethodCallHandler((call, result) -> {
//                    if (call.method.equals("startLocationUpdates")) {
//                        startLocationUpdates();
//                        result.success(null);
//                    } else if (call.method.equals("getLastKnownLocation")) {
//                        getLastKnownLocation();
//                    } else {
//                        result.notImplemented();
//                    }
//                });
//    }
//
//    private void startLocationUpdates() {
//        locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
//
//        locationListener = new LocationListener() {
//            @Override
//            public void onLocationChanged(@NonNull Location location) {
//                System.out.println("Lat: " + location.getLatitude() + ", Lon: " + location.getLongitude());
//                sendLocationToFlutter(location);
//            }
//
//            @Override
//            public void onProviderEnabled(@NonNull String provider) {
//                System.out.println("Provider enabled: " + provider);
//            }
//
//            @Override
//            public void onProviderDisabled(@NonNull String provider) {
//                System.out.println("Provider disabled: " + provider);
//            }
//        };
//
//        try {
//            locationManager.requestLocationUpdates(
//                    LocationManager.GPS_PROVIDER, // Use GPS
//                    5000,                        // 5 seconds interval
//                    10,                          // 10 meters distance
//                    locationListener
//            );
//        } catch (SecurityException e) {
//            e.printStackTrace();
//        }
//    }
//
//    private void getLastKnownLocation() {
//        locationManager = (LocationManager) getSystemService(LOCATION_SERVICE);
//
//        try {
//            Location location = locationManager.getLastKnownLocation(LocationManager.GPS_PROVIDER);
//            if (location != null) {
//                sendLocationToFlutter(location);
//            }
//        } catch (SecurityException e) {
//            e.printStackTrace();
//        }
//    }
//
//    private void sendLocationToFlutter(Location location) {
//        new MethodChannel(getFlutterEngine().getDartExecutor().getBinaryMessenger(), CHANNEL)
//                .invokeMethod("locationUpdate", new HashMap<String, Double>() {{
//                    put("latitude", location.getLatitude());
//                    put("longitude", location.getLongitude());
//                }});
//    }
//    private void checkGooglePlayServices() {
//        GoogleApiAvailability googleApiAvailability = GoogleApiAvailability.getInstance();
//        int status = googleApiAvailability.isGooglePlayServicesAvailable(this);
//
//        if (status != ConnectionResult.SUCCESS) {
//            // More detailed logging
//            if (googleApiAvailability.isUserResolvableError(status)) {
//                Dialog errorDialog = googleApiAvailability.getErrorDialog(
//                        this,
//                        status,
//                        2404
//                );
//                if (errorDialog != null) {
//                    errorDialog.show();
//                }
//            } else {
//                Log.e("GooglePlayServices", "Google Play Services not supported on this device");
//            }
//        }
//    }
}