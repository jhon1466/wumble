import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../features/community/presentation/bloc/community_context_bloc.dart';
import '../theme.dart';

class DynamicThemeWrapper extends StatelessWidget {
  final Widget child;

  const DynamicThemeWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CommunityContextBloc, CommunityContextState>(
      builder: (context, state) {
        final community = state.activeCommunity;
        
        // If no community is active, return the default theme
        if (community == null) {
          return Theme(
            data: Wumbleheme.darkTheme,
            child: child,
          );
        }

        // Create a dynamic theme based on the community's color
        final communityColor = community.themeColor;
        
        final dynamicTheme = Wumbleheme.darkTheme.copyWith(
          colorScheme: Wumbleheme.darkTheme.colorScheme.copyWith(
            secondary: communityColor,
            // You can override other colors here as well
          ),
          // Override specific component themes to match community color
          floatingActionButtonTheme: Wumbleheme.darkTheme.floatingActionButtonTheme.copyWith(
            backgroundColor: communityColor,
          ),
          textSelectionTheme: Wumbleheme.darkTheme.textSelectionTheme.copyWith(
            selectionColor: communityColor.withOpacity(0.3),
            selectionHandleColor: communityColor,
          ),
          indicatorColor: communityColor,
        );

        return Theme(
          data: dynamicTheme,
          child: child,
        );
      },
    );
  }
}
