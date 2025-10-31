import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:grab_go_customer/features/auth/model/user_model.dart';
import 'package:photo_view/photo_view.dart';

class ViewProfile extends StatelessWidget {
  final User user;
  const ViewProfile({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.black,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.black,
          systemNavigationBarDividerColor: Colors.transparent,
        ),
        child: SafeArea(
          child: Center(
            child: PhotoView(
              imageProvider: NetworkImage(user.profilePicture.toString()),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.contained * 4,
              initialScale: PhotoViewComputedScale.contained,
              enableRotation: false,
              backgroundDecoration: const BoxDecoration(color: Colors.black),
              heroAttributes: PhotoViewHeroAttributes(tag: user.profilePicture.toString()),
            ),
          ),
        ),
      ),
    );
  }
}


// child: CachedImageWidget(
//                 imageUrl: user.profilePicture.toString(),
//                 width: double.infinity,
//                 height: size.height * 0.5,
//                 fit: BoxFit.cover,
//                 placeholder: Container(
//                   width: double.infinity,
//                   height: size.height * 0.5,
//                   child: SvgPicture.asset(Assets.icons.noProfile.path),
//                 ),
//                 errorWidget: Assets.icons.noProfile.image(
//                   width: double.infinity,
//                   height: size.height * 0.5,
//                   fit: BoxFit.cover,
//                 ),
//               ),