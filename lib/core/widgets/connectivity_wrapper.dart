import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/auth/presentation/bloc/connectivity_cubit.dart';
import 'offline_screen.dart';

class ConnectivityWrapper extends StatelessWidget {
  final Widget child;
  const ConnectivityWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ConnectivityCubit, ConnectivityStatus>(
      builder: (context, state) {
        debugPrint('ConnectivityWrapper: Building with state: $state');
        if (state == ConnectivityStatus.offline) {
          return const OfflineScreen();
        }
        return child;
      },
    );
  }
}
