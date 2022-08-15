import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dart_ipify/dart_ipify.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlng/latlng.dart';
import 'package:rxdart/rxdart.dart';
import 'package:system_tray/system_tray.dart';

class MyBloc {
  final SystemTray systemTray = SystemTray();
  final AppWindow appWindow = AppWindow();
  final _latLng = StreamController<LatLng>();
  final _ipLookupResult = BehaviorSubject();

  Stream<LatLng> get latLng => _latLng.stream;
  Stream get ipLookupResult => _ipLookupResult.stream;

  void initialize() {
    initSystemTray();
    runIpCheckInfinitely();
    subscribeConnectivityChange();
    appWindow.hide();
    systemTray.setToolTip('IRNet: NOT READY');
  }

  void subscribeConnectivityChange() {
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        checkIpLocation();
      } else {
        setTrayIconToOffline();
        systemTray.setToolTip('IRNet: OFFLINE');
      }
    });
  }

  void runIpCheckInfinitely() async {
    while (true) {
      checkIpLocation();
      await Future.delayed(const Duration(seconds: 20));
    }
  }

  void checkIpLocation() async {
    final ipv4 = await Ipify.ipv4();
    final response = await http.get(Uri.parse('http://ip-api.com/json/$ipv4?fields=5296093'));
    final json = jsonDecode(response.body);
    final country = json['country'];
    updateTrayIcon(isIran: country == 'Iran');
    systemTray.setToolTip('IRNet: $country');
    if (json['lat'] != null && json['lon'] != null) {
      _latLng.sink.add(LatLng(json['lat'], json['lon']));
    }
    _ipLookupResult.value = json;
    debugPrint('Country => $country');
  }

  void setTrayIconToOffline() {
    systemTray.setImage('assets/offline.ico');
  }

  void onExitClick() {
    systemTray.destroy();
    exit(0);
  }

  void onRefreshButtonClick() {
    checkIpLocation();
  }

  void updateTrayIcon({bool isIran = false}) {
    systemTray.setImage(isIran ? 'assets/iran.ico' : 'assets/globe.ico');
  }

  Future<void> initSystemTray() async {
    // We first init the systray menu
    await systemTray.initSystemTray(
      title: "system tray",
      iconPath: 'assets/globe.ico',
    );

    // create context menu
    final Menu menu = Menu();
    await menu.buildFrom([
      MenuItemLable(label: 'Show', onClicked: (menuItem) => appWindow.show()),
      MenuItemLable(label: 'Hide', onClicked: (menuItem) => appWindow.hide()),
      MenuItemLable(
          label: 'Exit',
          onClicked: (menuItem) {
            systemTray.destroy();
            exit(0);
          }),
    ]);

    // set context menu
    await systemTray.setContextMenu(menu);

    // handle system tray event
    systemTray.registerSystemTrayEventHandler((eventName) {
      debugPrint("eventName: $eventName");
      if (eventName == kSystemTrayEventClick) {
        appWindow.show();
      } else if (eventName == kSystemTrayEventRightClick) {
        systemTray.popUpContextMenu();
      }
    });
  }
}