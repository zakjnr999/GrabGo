import 'package:json_annotation/json_annotation.dart';

part 'user_model.g.dart';

@JsonSerializable()
class RegisterRequest {
  final String username;
  final String email;
  final String password;
  @JsonKey(name: 'DateOfBirth')
  final String? dateOfBirth;
  final int? phone;
  final String? profilePicture;
  final String? promoCode;
  final String? referralCode;

  RegisterRequest({
    required this.username,
    required this.email,
    required this.password,
    this.dateOfBirth,
    this.phone,
    this.profilePicture,
    this.promoCode,
    this.referralCode,
  });

  factory RegisterRequest.fromJson(Map<String, dynamic> json) => _$RegisterRequestFromJson(json);

  Map<String, dynamic> toJson() => _$RegisterRequestToJson(this);
}

@JsonSerializable()
class UserPermissions {
  final bool? canManageUsers;
  final bool? canManageProducts;
  final bool? canManageOrders;
  final bool? canManageContent;

  UserPermissions({this.canManageUsers, this.canManageProducts, this.canManageOrders, this.canManageContent});

  factory UserPermissions.fromJson(Map<String, dynamic> json) => _$UserPermissionsFromJson(json);

  Map<String, dynamic> toJson() => _$UserPermissionsToJson(this);
}

@JsonSerializable()
class User {
  @JsonKey(name: '_id')
  final String? id;
  final String? username;
  final String? email;
  final int? phone;
  final bool? isPhoneVerified;
  final bool? isEmailVerified;
  @JsonKey(name: 'DateOfBirth')
  final String? dateOfBirth;
  final String? profilePicture;
  final bool? isAdmin;
  final String? role;
  final bool? isActive;
  final UserPermissions? permissions;
  final String? createdAt;

  User({
    this.id,
    this.username,
    this.email,
    this.phone,
    this.isPhoneVerified,
    this.isEmailVerified,
    this.dateOfBirth,
    this.profilePicture,
    this.isAdmin,
    this.role,
    this.isActive,
    this.permissions,
    this.createdAt,
  });

  factory User.fromJson(Map<String, dynamic> json) => _$UserFromJson(json);

  Map<String, dynamic> toJson() => _$UserToJson(this);
}

@JsonSerializable()
class UserResponse {
  final String message;
  final User? user;
  final User? data;
  final String? token;

  UserResponse({required this.message, this.user, this.data, this.token});

  factory UserResponse.fromJson(Map<String, dynamic> json) {
    User? userData;

    if ((json.containsKey('username') || json.containsKey('email')) && !json.containsKey('message')) {
      userData = User.fromJson(json);
    } else if (json['data'] != null) {
      if (json['data'] is Map<String, dynamic>) {
        final dataMap = json['data'] as Map<String, dynamic>;

        if (dataMap.containsKey('username') || dataMap.containsKey('email')) {
          userData = User.fromJson(dataMap);
        } else if (dataMap.containsKey('data') && dataMap['data'] is Map<String, dynamic>) {
          userData = User.fromJson(dataMap['data'] as Map<String, dynamic>);
        }
      }
    }

    return UserResponse(
      message: json['message'] as String? ?? '',
      user: json['user'] != null ? User.fromJson(json['user'] as Map<String, dynamic>) : null,
      data: userData,
      token: json['token'] as String?,
    );
  }

  Map<String, dynamic> toJson() => _$UserResponseToJson(this);
  User? get userData {
    if (user != null) return user;
    if (data != null) return data;

    return null;
  }
}

@JsonSerializable()
class GoogleSignInRequest {
  final String googleId;
  final String email;
  final String displayName;
  final String? photoUrl;
  final String? idToken;

  GoogleSignInRequest({
    required this.googleId,
    required this.email,
    required this.displayName,
    this.photoUrl,
    this.idToken,
  });

  factory GoogleSignInRequest.fromJson(Map<String, dynamic> json) => _$GoogleSignInRequestFromJson(json);

  Map<String, dynamic> toJson() => _$GoogleSignInRequestToJson(this);
}

@JsonSerializable()
class LoginRequest {
  final String email;
  final String password;

  LoginRequest({required this.email, required this.password});

  factory LoginRequest.fromJson(Map<String, dynamic> json) => _$LoginRequestFromJson(json);

  Map<String, dynamic> toJson() => _$LoginRequestToJson(this);
}

@JsonSerializable()
class PhoneVerificationRequest {
  final String phoneNumber;
  final bool isPhoneVerified;
  PhoneVerificationRequest({required this.phoneNumber, required this.isPhoneVerified});

  factory PhoneVerificationRequest.fromJson(Map<String, dynamic> json) => _$PhoneVerificationRequestFromJson(json);

  Map<String, dynamic> toJson() => _$PhoneVerificationRequestToJson(this);
}
