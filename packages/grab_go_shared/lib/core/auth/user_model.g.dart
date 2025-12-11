// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

RegisterRequest _$RegisterRequestFromJson(Map<String, dynamic> json) =>
    RegisterRequest(
      username: json['username'] as String,
      email: json['email'] as String,
      password: json['password'] as String,
      dateOfBirth: json['DateOfBirth'] as String?,
      phone: (json['phone'] as num?)?.toInt(),
      profilePicture: json['profilePicture'] as String?,
      referralCode: json['referralCode'] as String?,
      role: json['role'] as String?,
    );

Map<String, dynamic> _$RegisterRequestToJson(RegisterRequest instance) =>
    <String, dynamic>{
      'username': instance.username,
      'email': instance.email,
      'password': instance.password,
      'DateOfBirth': instance.dateOfBirth,
      'phone': instance.phone,
      'profilePicture': instance.profilePicture,
      'referralCode': instance.referralCode,
      'role': instance.role,
    };

UserPermissions _$UserPermissionsFromJson(Map<String, dynamic> json) =>
    UserPermissions(
      canManageUsers: json['canManageUsers'] as bool?,
      canManageProducts: json['canManageProducts'] as bool?,
      canManageOrders: json['canManageOrders'] as bool?,
      canManageContent: json['canManageContent'] as bool?,
    );

Map<String, dynamic> _$UserPermissionsToJson(UserPermissions instance) =>
    <String, dynamic>{
      'canManageUsers': instance.canManageUsers,
      'canManageProducts': instance.canManageProducts,
      'canManageOrders': instance.canManageOrders,
      'canManageContent': instance.canManageContent,
    };

User _$UserFromJson(Map<String, dynamic> json) => User(
  id: json['_id'] as String?,
  username: json['username'] as String?,
  email: json['email'] as String?,
  phone: (json['phone'] as num?)?.toInt(),
  isPhoneVerified: json['isPhoneVerified'] as bool?,
  isEmailVerified: json['isEmailVerified'] as bool?,
  dateOfBirth: json['DateOfBirth'] as String?,
  profilePicture: json['profilePicture'] as String?,
  isAdmin: json['isAdmin'] as bool?,
  role: json['role'] as String?,
  isActive: json['isActive'] as bool?,
  permissions: json['permissions'] == null
      ? null
      : UserPermissions.fromJson(json['permissions'] as Map<String, dynamic>),
  createdAt: json['createdAt'] as String?,
  vehicleType: json['vehicleType'] as String?,
);

Map<String, dynamic> _$UserToJson(User instance) => <String, dynamic>{
  '_id': instance.id,
  'username': instance.username,
  'email': instance.email,
  'phone': instance.phone,
  'isPhoneVerified': instance.isPhoneVerified,
  'isEmailVerified': instance.isEmailVerified,
  'DateOfBirth': instance.dateOfBirth,
  'profilePicture': instance.profilePicture,
  'isAdmin': instance.isAdmin,
  'role': instance.role,
  'isActive': instance.isActive,
  'permissions': instance.permissions,
  'createdAt': instance.createdAt,
  'vehicleType': instance.vehicleType,
};

UserResponse _$UserResponseFromJson(Map<String, dynamic> json) => UserResponse(
  message: json['message'] as String,
  user: json['user'] == null
      ? null
      : User.fromJson(json['user'] as Map<String, dynamic>),
  data: json['data'] == null
      ? null
      : User.fromJson(json['data'] as Map<String, dynamic>),
  token: json['token'] as String?,
);

Map<String, dynamic> _$UserResponseToJson(UserResponse instance) =>
    <String, dynamic>{
      'message': instance.message,
      'user': instance.user,
      'data': instance.data,
      'token': instance.token,
    };

GoogleSignInRequest _$GoogleSignInRequestFromJson(Map<String, dynamic> json) =>
    GoogleSignInRequest(
      googleId: json['googleId'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String,
      photoUrl: json['photoUrl'] as String?,
      idToken: json['idToken'] as String?,
      role: json['role'] as String?,
    );

Map<String, dynamic> _$GoogleSignInRequestToJson(
  GoogleSignInRequest instance,
) => <String, dynamic>{
  'googleId': instance.googleId,
  'email': instance.email,
  'displayName': instance.displayName,
  'photoUrl': instance.photoUrl,
  'idToken': instance.idToken,
  'role': instance.role,
};

LoginRequest _$LoginRequestFromJson(Map<String, dynamic> json) => LoginRequest(
  email: json['email'] as String,
  password: json['password'] as String,
);

Map<String, dynamic> _$LoginRequestToJson(LoginRequest instance) =>
    <String, dynamic>{'email': instance.email, 'password': instance.password};

PhoneVerificationRequest _$PhoneVerificationRequestFromJson(
  Map<String, dynamic> json,
) => PhoneVerificationRequest(
  phoneNumber: json['phoneNumber'] as String,
  isPhoneVerified: json['isPhoneVerified'] as bool,
);

Map<String, dynamic> _$PhoneVerificationRequestToJson(
  PhoneVerificationRequest instance,
) => <String, dynamic>{
  'phoneNumber': instance.phoneNumber,
  'isPhoneVerified': instance.isPhoneVerified,
};
