import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Rounded search field used on Home, the location-disabled state and the
/// Search Results header. Matches the 56px pill design.
///
/// The arrow button submits the field's current text via [onSubmitted];
/// [onClear] is called when the user taps the clear (x) button.
class SearchBarWidget extends StatefulWidget {
  final TextEditingController? controller;
  final String hint;
  final String? initialText;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onClear;
  final EdgeInsets padding;

  const SearchBarWidget({
    super.key,
    this.controller,
    this.hint = 'Search for a drug...',
    this.initialText,
    this.onSubmitted,
    this.onClear,
    this.padding = AppSpace.pageMargin,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late final TextEditingController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? TextEditingController(text: widget.initialText);
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final text = _controller.text.trim();
    if (text.isNotEmpty) widget.onSubmitted?.call(text);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          children: [
            const Icon(Icons.search, color: AppColors.outline),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _controller,
                textInputAction: TextInputAction.search,
                style:
                    AppTextStyles.bodyLg.copyWith(color: AppColors.onSurface),
                decoration: InputDecoration(
                  hintText: widget.hint,
                  hintStyle: AppTextStyles.bodyLg
                      .copyWith(color: AppColors.outlineVariant),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                onSubmitted: (_) => _submit(),
              ),
            ),
            if (widget.onClear != null)
              IconButton(
                icon: const Icon(Icons.close,
                    size: 20, color: AppColors.onSurfaceVariant),
                onPressed: () {
                  _controller.clear();
                  widget.onClear?.call();
                },
              ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _submit,
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.arrow_forward,
                  size: 20,
                  color: AppColors.onPrimary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
