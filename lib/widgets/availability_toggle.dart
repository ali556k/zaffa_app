import 'package:flutter/material.dart';
import '../models/booking_model.dart';
import '../services/booking_service.dart';

/// Availability toggle widget for non-bookable services
/// Used for services like food, dresses, flowers, etc.
/// Shows "متوفر" or "غير متوفر" badge and allows provider to toggle availability
class AvailabilityToggle extends StatefulWidget {
  final String itemId;
  final String category;
  final bool isProviderView;
  final VoidCallback? onAvailabilityChanged;

  const AvailabilityToggle({
    super.key,
    required this.itemId,
    required this.category,
    this.isProviderView = false,
    this.onAvailabilityChanged,
  });

  @override
  State<AvailabilityToggle> createState() => _AvailabilityToggleState();
}

class _AvailabilityToggleState extends State<AvailabilityToggle> {
  final BookingService _bookingService = BookingService();
  bool _isAvailable = true;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAvailability();
  }

  /// Load current availability status
  Future<void> _loadAvailability() async {
    setState(() => _isLoading = true);

    try {
      final availability = await _bookingService.getItemAvailabilityOnce(widget.itemId);
      setState(() {
        _isAvailable = availability;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading availability: $e');
      setState(() {
        _isAvailable = true; // Default to available
        _isLoading = false;
      });
    }
  }

  /// Toggle availability status
  Future<void> _toggleAvailability(bool newValue) async {
    setState(() => _isLoading = true);

    try {
      await _bookingService.updateItemAvailability(widget.itemId, newValue);

      setState(() {
        _isAvailable = newValue;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newValue ? 'تم تحديث الحالة إلى متوفر' : 'تم تحديث الحالة إلى غير متوفر',
            ),
            backgroundColor: newValue ? Colors.green : Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );

        widget.onAvailabilityChanged?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحديث الحالة: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }

      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    // Provider view - show toggle switch
    if (widget.isProviderView) {
      return _buildProviderToggle();
    }

    // Customer view - show availability badge
    return _buildCustomerBadge();
  }

  /// Build provider toggle switch
  Widget _buildProviderToggle() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _isAvailable ? Colors.green.shade300 : Colors.red.shade300,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.2),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'حالة التوفر',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Switch(
                value: _isAvailable,
                onChanged: _toggleAvailability,
                activeColor: Colors.green,
                inactiveThumbColor: Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: _isAvailable ? Colors.green.shade50 : Colors.red.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isAvailable ? Icons.check_circle : Icons.cancel,
                  color: _isAvailable ? Colors.green : Colors.red,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  _isAvailable ? 'متوفر حالياً' : 'غير متوفر حالياً',
                  style: TextStyle(
                    color: _isAvailable ? Colors.green.shade800 : Colors.red.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Build customer badge
  Widget _buildCustomerBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _isAvailable ? Colors.green : Colors.red,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (_isAvailable ? Colors.green : Colors.red).withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isAvailable ? Icons.check_circle : Icons.cancel,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _isAvailable ? 'متوفر' : 'غير متوفر',
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

/// Availability indicator for item cards
class AvailabilityBadge extends StatelessWidget {
  final String itemId;
  final String category;

  const AvailabilityBadge({
    super.key,
    required this.itemId,
    required this.category,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for non-bookable services
    if (bookableCategories.contains(category)) {
      return const SizedBox.shrink();
    }

    return AvailabilityToggle(
      itemId: itemId,
      category: category,
      isProviderView: false,
    );
  }
}

/// Availability management panel for providers
class AvailabilityManagementPanel extends StatelessWidget {
  final String itemId;
  final String category;
  final VoidCallback? onAvailabilityChanged;

  const AvailabilityManagementPanel({
    super.key,
    required this.itemId,
    required this.category,
    this.onAvailabilityChanged,
  });

  @override
  Widget build(BuildContext context) {
    // Only show for non-bookable services
    if (bookableCategories.contains(category)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: const [
                Icon(
                  Icons.settings,
                  color: Color(0xFF8B0000),
                  size: 24,
                ),
                SizedBox(width: 8),
                Text(
                  'إدارة التوفر',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF8B0000),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AvailabilityToggle(
              itemId: itemId,
              category: category,
              isProviderView: true,
              onAvailabilityChanged: onAvailabilityChanged,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: const [
                  Icon(
                    Icons.info_outline,
                    color: Colors.blue,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'استخدم هذا الخيار لتحديد ما إذا كانت الخدمة متوفرة للزبائن حالياً',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
