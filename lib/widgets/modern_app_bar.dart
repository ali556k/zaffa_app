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
      title: CustomAppBarTitle(title: title, showZaffaLogo: showZaffaLogo),
      centerTitle: true,
      actions: actions,
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(70);
}
