import 'package:flutter/material.dart';
import '../widgets/custom_app_bar_title.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final bool showZaffaLogo;
  final List<Widget>? actions;
  const ModernAppBar({
    super.key,
    required this.title,
    this.showZaffaLogo = true,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF8D2828), Color(0xFF3A0A0A)],
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
          ),
        ),
      ),
      title: CustomAppBarTitle(title: title, showZaffaLogo: showZaffaLogo),
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(70);
}
