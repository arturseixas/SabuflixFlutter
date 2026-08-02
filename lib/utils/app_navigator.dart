import 'package:flutter/widgets.dart';

/// Navigator of the single [MaterialApp].
///
/// The mini player lives above the navigator (it has to survive route
/// changes), so it cannot reach one through its own context.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();
