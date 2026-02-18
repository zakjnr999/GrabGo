import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:grab_go_shared/grub_go_shared.dart';

class ChatAttachmentPreviewPage extends StatelessWidget {
  final String title;
  final String fileLabel;
  final String sentAtLabel;

  const ChatAttachmentPreviewPage({
    super.key,
    required this.title,
    required this.fileLabel,
    required this.sentAtLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;

    return Scaffold(
      backgroundColor: colors.backgroundPrimary,
      appBar: AppBar(
        backgroundColor: colors.backgroundPrimary,
        elevation: 0,
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16.sp,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(20.w, 20.h, 20.w, 20.h),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(18.r),
                decoration: BoxDecoration(
                  color: colors.backgroundSecondary,
                  borderRadius: BorderRadius.circular(16.r),
                  border: Border.all(color: colors.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.insert_drive_file_outlined,
                      size: 56.sp,
                      color: colors.vendorPrimaryBlue,
                    ),
                    SizedBox(height: 10.h),
                    Text(
                      fileLabel,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    SizedBox(height: 6.h),
                    Text(
                      'Sent $sentAtLabel',
                      style: TextStyle(
                        fontSize: 11.sp,
                        fontWeight: FontWeight.w600,
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 14.h),
              SizedBox(
                width: double.infinity,
                child: AppButton(
                  buttonText: 'Download Placeholder',
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Attachment download is UI preview only.',
                        ),
                      ),
                    );
                  },
                  backgroundColor: colors.vendorPrimaryBlue,
                  borderRadius: KBorderSize.borderRadius12,
                  textStyle: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14.sp,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
