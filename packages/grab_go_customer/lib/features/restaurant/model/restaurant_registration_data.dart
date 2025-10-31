import 'dart:io';

class RestaurantRegistrationData {
  final String restaurantName;
  final String restaurantEmail;
  final String restaurantPhone;
  final String restaurantAddress;
  final String restaurantCity;
  final File? restaurantLogo;

  final String ownerName;
  final String ownerPhone;
  final String businessId;
  final File? businessIdImage;
  final File? ownerPhoto;

  final String password;
  final String confirmPassword;

  final bool termsAccepted;

  const RestaurantRegistrationData({
    required this.restaurantName,
    required this.restaurantEmail,
    required this.restaurantPhone,
    required this.restaurantAddress,
    required this.restaurantCity,
    this.restaurantLogo,
    required this.ownerName,
    required this.ownerPhone,
    required this.businessId,
    this.businessIdImage,
    this.ownerPhoto,
    required this.password,
    required this.confirmPassword,
    required this.termsAccepted,
  });

  bool get isComplete {
    return restaurantName.isNotEmpty &&
        restaurantEmail.isNotEmpty &&
        restaurantPhone.isNotEmpty &&
        restaurantAddress.isNotEmpty &&
        restaurantCity.isNotEmpty &&
        ownerName.isNotEmpty &&
        ownerPhone.isNotEmpty &&
        businessId.isNotEmpty &&
        password.isNotEmpty &&
        confirmPassword.isNotEmpty &&
        termsAccepted &&
        restaurantLogo != null &&
        businessIdImage != null &&
        ownerPhoto != null;
  }

  RestaurantRegistrationData copyWith({
    String? restaurantName,
    String? restaurantEmail,
    String? restaurantPhone,
    String? restaurantAddress,
    String? restaurantCity,
    File? restaurantLogo,
    String? ownerName,
    String? ownerPhone,
    String? businessId,
    File? businessIdImage,
    File? ownerPhoto,
    String? password,
    String? confirmPassword,
    bool? termsAccepted,
  }) {
    return RestaurantRegistrationData(
      restaurantName: restaurantName ?? this.restaurantName,
      restaurantEmail: restaurantEmail ?? this.restaurantEmail,
      restaurantPhone: restaurantPhone ?? this.restaurantPhone,
      restaurantAddress: restaurantAddress ?? this.restaurantAddress,
      restaurantCity: restaurantCity ?? this.restaurantCity,
      restaurantLogo: restaurantLogo ?? this.restaurantLogo,
      ownerName: ownerName ?? this.ownerName,
      ownerPhone: ownerPhone ?? this.ownerPhone,
      businessId: businessId ?? this.businessId,
      businessIdImage: businessIdImage ?? this.businessIdImage,
      ownerPhoto: ownerPhoto ?? this.ownerPhoto,
      password: password ?? this.password,
      confirmPassword: confirmPassword ?? this.confirmPassword,
      termsAccepted: termsAccepted ?? this.termsAccepted,
    );
  }
}
