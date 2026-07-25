// ============================================
// SEARCH_BAR_WIDGET.DART
// ============================================
// Reusable search bar widget for filtering clothing items
//
// Purpose:
// - Provide search functionality
// - Clean and consistent design
// - Handle search input and clear
// ============================================

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// SearchBarWidget
/// Reusable search bar for wardrobe screen
class SearchBarWidget extends StatefulWidget {
  /// Callback when search text changes
  final Function(String) onSearchChanged;

  /// Initial search value
  final String initialValue;

  /// Hint text
  final String hintText;

  final bool autofocus;

  const SearchBarWidget({
    super.key,
    required this.onSearchChanged,
    this.initialValue = '',
    this.hintText = 'Search clothes...',
    this.autofocus = false,
  });

  @override
  State<SearchBarWidget> createState() => _SearchBarWidgetState();
}

class _SearchBarWidgetState extends State<SearchBarWidget> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: _controller,
        autofocus: widget.autofocus,
        onChanged: (query) {
          setState(() {});
          widget.onSearchChanged(query);
        },
        onSubmitted: (_) {
          FocusScope.of(context).unfocus();
        },
        style: GoogleFonts.poppins(
          fontSize: 16,
          color: const Color(0xFF1E293B),
        ),
        decoration: InputDecoration(
          hintText: widget.hintText,
          hintStyle: GoogleFonts.poppins(
            fontSize: 16,
            color: const Color(0xFF94A3B8),
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: Color(0xFF64748B),
            size: 24,
          ),
          suffixIcon: _controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(
                    Icons.clear,
                    color: Color(0xFF64748B),
                    size: 20,
                  ),
                  onPressed: () {
                    _controller.clear();
                    widget.onSearchChanged('');
                    FocusScope.of(context).unfocus();
                    setState(() {});
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFF4F46E5),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }
}
