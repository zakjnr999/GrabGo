import 'package:flutter/material.dart';
import '../utils/app_colors_extension.dart';

class AppDrawerTile extends StatelessWidget {
  final String text;
  final IconData? icon;
  final void Function()? onTap;

  const AppDrawerTile({super.key, required this.text, required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    return Padding(
      padding: EdgeInsets.only(left: 10),
      child: ListTile(
        title: Text(text, style: TextStyle(color: colors.textSecondary)),
        leading: Icon(icon, color: colors.textSecondary),
        onTap: onTap,
      ),
    );
  }
}
