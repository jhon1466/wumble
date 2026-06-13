import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

enum ConnectivityStatus { online, offline }

class ConnectivityCubit extends Cubit<ConnectivityStatus> {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _subscription;

  ConnectivityCubit() : super(ConnectivityStatus.online) {
    _checkInitialConnectivity();
    _subscription = _connectivity.onConnectivityChanged.listen((results) {
      debugPrint('ConnectivityCubit: Results changed: $results');
      final bool hasConnection = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
      if (!hasConnection) {
        emit(ConnectivityStatus.offline);
      } else {
        emit(ConnectivityStatus.online);
      }
      debugPrint('ConnectivityCubit: Status emitted: ${state.name}');
    });
  }

  Future<void> check() async {
    debugPrint('ConnectivityCubit: Manual refresh requested');
    await _checkInitialConnectivity();
  }

  Future<void> _checkInitialConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    debugPrint('ConnectivityCubit: Initial check: $results');
    final bool hasConnection = results.isNotEmpty && results.any((r) => r != ConnectivityResult.none);
    if (!hasConnection) {
      emit(ConnectivityStatus.offline);
    } else {
      emit(ConnectivityStatus.online);
    }
    debugPrint('ConnectivityCubit: Initial status emitted: ${state.name}');
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
