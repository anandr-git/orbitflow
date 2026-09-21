import 'package:flutter/widgets.dart';

import '../theme/design_tokens.dart';

enum LayoutSize { compact, medium, expanded }

class Responsive {
  Responsive._(this.width, this.height, this.orientation);

  factory Responsive.of(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Responsive._(size.width, size.height, MediaQuery.orientationOf(context));
  }

  final double width;
  final double height;
  final Orientation orientation;

  LayoutSize get layoutSize {
    if (AppBreakpoints.isCompact(width)) return LayoutSize.compact;
    if (AppBreakpoints.isMedium(width)) return LayoutSize.medium;
    return LayoutSize.expanded;
  }

  bool get isCompact => layoutSize == LayoutSize.compact;
  bool get isMedium => layoutSize == LayoutSize.medium;
  bool get isExpanded => layoutSize == LayoutSize.expanded;
  bool get isTablet => width >= AppBreakpoints.compact;
  bool get isLandscape => orientation == Orientation.landscape;
  bool get useTwoPane => width >= AppBreakpoints.medium;

  double get pageHorizontalPadding {
    if (isExpanded) return AppSpacing.xxl;
    if (isMedium) return AppSpacing.xl;
    return AppSpacing.md;
  }

  double get maxContentWidth {
    if (isExpanded) return AppContentWidth.readable;
    return double.infinity;
  }

  double get masterPaneWidth => AppContentWidth.master.clamp(320, width * 0.42);

  EdgeInsets get pageInsets => EdgeInsets.symmetric(horizontal: pageHorizontalPadding);
}

class ResponsivePadding extends StatelessWidget {
  const ResponsivePadding({super.key, required this.child, this.extra = EdgeInsets.zero});

  final Widget child;
  final EdgeInsets extra;

  @override
  Widget build(BuildContext context) {
    final r = Responsive.of(context);
    return Padding(
      padding: r.pageInsets.add(extra),
      child: child,
    );
  }
}

class ConstrainedContent extends StatelessWidget {
  const ConstrainedContent({
    super.key,
    required this.child,
    this.maxWidth = AppContentWidth.readable,
    this.alignment = Alignment.topCenter,
  });

  final Widget child;
  final double maxWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: alignment,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
