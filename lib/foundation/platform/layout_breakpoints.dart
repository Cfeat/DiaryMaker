import 'package:flutter/widgets.dart';

/// Width breakpoints for phone / tablet / desktop journeys (Phase E).
///
/// Split timeline+editor when width ≥ [splitMinWidth], regardless of OS —
/// so iPad / large Android tablets and resized desktop windows behave correctly.
abstract final class LayoutBreakpoints {
  /// Material compact → medium threshold-ish; below = single-stack mobile UI.
  static const double splitMinWidth = 720;

  static bool useSplitLayout(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= splitMinWidth;
}
