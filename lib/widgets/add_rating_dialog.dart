import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import '../models/rating_model.dart';
import '../services/rating_service.dart';

/// نافذة إضافة تقييم
class AddRatingDialog extends StatefulWidget {
  final String bookingId;
  final String itemId;
  final String itemName;
  final String providerId;
  final String customerId;
  final String customerName;

  const AddRatingDialog({
    super.key,
    required this.bookingId,
    required this.itemId,
    required this.itemName,
    required this.providerId,
    required this.customerId,
    required this.customerName,
  });

  @override
  State<AddRatingDialog> createState() => _AddRatingDialogState();
}

class _AddRatingDialogState extends State<AddRatingDialog> {
  final RatingService _ratingService = RatingService();
  final TextEditingController _commentController = TextEditingController();
  double _rating = 0.0;
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitRating() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى اختيار تقييم'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_commentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('يرجى كتابة تعليق'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final rating = RatingModel(
        bookingId: widget.bookingId,
        itemId: widget.itemId,
        providerId: widget.providerId,
        customerId: widget.customerId,
        customerName: widget.customerName,
        rating: _rating,
        comment: _commentController.text.trim(),
      );

      await _ratingService.addRating(rating);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('شكراً لك! تم إضافة تقييمك بنجاح'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // أيقونة
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B0000).withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.star_rounded,
                    size: 48,
                    color: Color(0xFF8B0000),
                  ),
                ),

                const SizedBox(height: 20),

                // العنوان
                const Text(
                  'تقييم الخدمة',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF2D3748),
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  widget.itemName,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 24),

                // النجوم
                RatingBar.builder(
                  initialRating: _rating,
                  minRating: 1,
                  direction: Axis.horizontal,
                  allowHalfRating: false,
                  itemCount: 5,
                  itemSize: 50,
                  unratedColor: Colors.grey.shade300,
                  itemBuilder: (context, _) => const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFC107),
                  ),
                  onRatingUpdate: (rating) {
                    setState(() => _rating = rating);
                  },
                ),

                const SizedBox(height: 8),

                if (_rating > 0)
                  Text(
                    _getRatingText(_rating),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: _getRatingColor(_rating),
                    ),
                  ),

                const SizedBox(height: 24),

                // حقل التعليق
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  maxLength: 500,
                  textAlign: TextAlign.right,
                  decoration: InputDecoration(
                    hintText: 'اكتب تعليقك هنا...',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Color(0xFF8B0000), width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),

                const SizedBox(height: 24),

                // الأزرار
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isSubmitting ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'إلغاء',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitRating,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF8B0000),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : const Text(
                                'إرسال التقييم',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRatingText(double rating) {
    if (rating >= 4.5) return 'ممتاز جداً 🌟';
    if (rating >= 3.5) return 'جيد جداً 👍';
    if (rating >= 2.5) return 'جيد 👌';
    if (rating >= 1.5) return 'مقبول 🙂';
    return 'يحتاج تحسين 😔';
  }

  Color _getRatingColor(double rating) {
    if (rating >= 4) return Colors.green;
    if (rating >= 3) return Colors.blue;
    if (rating >= 2) return Colors.orange;
    return Colors.red;
  }
}
