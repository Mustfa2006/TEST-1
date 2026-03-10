import 'package:flutter/material.dart';

/// ⚡ أنيميشن دخول خفيف جداً — fade + slide بسيط
/// يعمل مرة واحدة فقط عند ظهور الويدجت لأول مرة
/// لا يؤثر على أداء التمرير لأنه:
/// - مدته قصيرة (300ms)
/// - يستخدم SingleTickerProviderStateMixin (ticker واحد فقط)
/// - بعد الانتهاء يصبح static تماماً
class CardEntryAnimation extends StatefulWidget {
  final Widget child;
  final int index;

  const CardEntryAnimation({
    super.key,
    required this.child,
    required this.index,
  });

  @override
  State<CardEntryAnimation> createState() => _CardEntryAnimationState();
}

class _CardEntryAnimationState extends State<CardEntryAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    // ⚡ fade: 0 → 1
    _fadeAnim = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    // ⚡ slide: تحرك طفيف من الأسفل (20px فقط)
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08), // 8% من الارتفاع فقط
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

    // ⚡ تأخير متدرج بسيط: البطاقة الأولى فوراً، الثانية بعد 50ms...
    // فقط لأول 6 بطاقات، الباقي بدون تأخير
    final delay = widget.index < 6 ? widget.index * 50 : 0;

    Future.delayed(Duration(milliseconds: delay), () {
      if (mounted) _ctrl.forward();
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: SlideTransition(
        position: _slideAnim,
        child: widget.child,
      ),
    );
  }
}
