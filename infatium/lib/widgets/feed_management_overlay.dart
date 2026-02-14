import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/colors.dart';
import '../l10n/generated/app_localizations.dart';

class FeedManagementOverlay {
  static OverlayEntry? _currentOverlay;

  /// Shows a custom overlay below the session item with delete, rename, and read all options
  static void show({
    required BuildContext context,
    required GlobalKey sessionItemKey,
    required String sessionTitle,
    required VoidCallback onDelete,
    VoidCallback? onRename,
    VoidCallback? onReadAll,
  }) {
    // Remove any existing overlay
    hide();

    final isDark = CupertinoTheme.of(context).brightness == Brightness.dark;

    // Get the position of the session item
    final RenderBox? renderBox = sessionItemKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    // Haptic feedback
    HapticFeedback.mediumImpact();

    _currentOverlay = OverlayEntry(
      builder: (context) => _SessionManagementOverlayWidget(
        position: position,
        itemSize: size,
        sessionTitle: sessionTitle,
        isDark: isDark,
        onDelete: () {
          hide();
          onDelete();
        },
        onRename: onRename != null ? () {
          hide();
          onRename();
        } : null,
        onReadAll: onReadAll != null ? () {
          hide();
          onReadAll();
        } : null,
        onDismiss: hide,
      ),
    );

    Overlay.of(context).insert(_currentOverlay!);
  }
  
  /// Hides the current overlay
  static void hide() {
    _currentOverlay?.remove();
    _currentOverlay = null;
  }
}

class _SessionManagementOverlayWidget extends StatefulWidget {
  final Offset position;
  final Size itemSize;
  final String sessionTitle;
  final bool isDark;
  final VoidCallback onDelete;
  final VoidCallback? onRename;
  final VoidCallback? onReadAll;
  final VoidCallback onDismiss;

  const _SessionManagementOverlayWidget({
    required this.position,
    required this.itemSize,
    required this.sessionTitle,
    required this.isDark,
    required this.onDelete,
    this.onRename,
    this.onReadAll,
    required this.onDismiss,
  });

  @override
  State<_SessionManagementOverlayWidget> createState() => _SessionManagementOverlayWidgetState();
}

class _SessionManagementOverlayWidgetState extends State<_SessionManagementOverlayWidget>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  late Animation<double> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    
    // Slide animation from bottom to top (Telegram style)
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    // Slide from bottom
    _slideAnimation = Tween<double>(
      begin: 20.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    // Calculate overlay position - place it below the session item like in Telegram
    final overlayTop = widget.position.dy + widget.itemSize.height + 4; // Just below the chat item
    final overlayLeft = widget.position.dx; // Align with tag position
    // Use estimated max width for positioning (longest label + icon + padding for HIG-compliant buttons)
    const estimatedOverlayWidth = 170.0;

    // Adjust position if it goes off screen
    final adjustedLeft = (overlayLeft + estimatedOverlayWidth > screenSize.width)
        ? screenSize.width - estimatedOverlayWidth - 16
        : overlayLeft.clamp(16.0, screenSize.width - estimatedOverlayWidth - 16);

    // If overlay would go below screen, place it above the session item
    // Calculate height based on number of buttons (2 buttons = ~100px with HIG-compliant touch targets)
    final overlayHeight = 100.0;
    final adjustedTop = (overlayTop + overlayHeight > screenSize.height - 100)
        ? widget.position.dy - overlayHeight - 4 // Above the session item
        : overlayTop;

    return Stack(
      children: [
        // Backdrop - tap to dismiss
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              color: Colors.transparent,
            ),
          ),
        ),
        
        // Main overlay content
        Positioned(
          top: adjustedTop,
          left: adjustedLeft,
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _opacityAnimation.value,
                    child: Material(
                      color: Colors.transparent,
                      child: IntrinsicWidth(
                        child: Container(
                          constraints: const BoxConstraints(minWidth: 140),
                          decoration: BoxDecoration(
                            color: widget.isDark
                                ? AppColors.surface.withValues(alpha: 0.95)
                                : AppColors.lightSurface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(widget.isDark ? 0.4 : 0.2),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Read All action button (if available)
                                if (widget.onReadAll != null)
                                  _buildActionButton(
                                    icon: CupertinoIcons.check_mark_circled,
                                    label: AppLocalizations.of(context)!.readAllPosts,
                                    onTap: widget.onReadAll!,
                                    isDestructive: false,
                                  ),
                                // Delete action button
                                _buildActionButton(
                                  icon: CupertinoIcons.delete,
                                  label: AppLocalizations.of(context)!.deleteSession,
                                  onTap: widget.onDelete,
                                  isDestructive: true,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required bool isDestructive,
  }) {
    final textColor = isDestructive 
        ? CupertinoColors.systemRed
        : (widget.isDark 
            ? AppColors.textPrimary 
            : AppColors.lightTextPrimary);
            
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: textColor,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
