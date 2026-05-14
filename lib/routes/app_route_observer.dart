import 'package:flutter/material.dart';

/// Observes route changes for widgets that implement [RouteAware] (e.g. pause feed video when another screen opens).
final RouteObserver<ModalRoute<dynamic>> appRouteObserver = RouteObserver<ModalRoute<dynamic>>();
