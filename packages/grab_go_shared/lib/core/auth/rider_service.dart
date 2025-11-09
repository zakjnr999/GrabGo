import 'package:chopper/chopper.dart';
import 'package:grab_go_shared/core/auth/rider_model.dart';

part 'rider_service.chopper.dart';

@ChopperApi()
abstract class RiderService extends ChopperService {
  @POST(path: '/riders/verification')
  @multipart
  Future<Response<RiderResponse>> submitVerification({
    @Part('vehicleType') String? vehicleType,
    @Part('licensePlateNumber') String? licensePlateNumber,
    @Part('vehicleBrand') String? vehicleBrand,
    @Part('vehicleModel') String? vehicleModel,
    @Part('nationalIdType') String? nationalIdType,
    @Part('nationalIdNumber') String? nationalIdNumber,
    @Part('paymentMethod') String? paymentMethod,
    @Part('bankName') String? bankName,
    @Part('accountNumber') String? accountNumber,
    @Part('accountHolderName') String? accountHolderName,
    @Part('mobileMoneyProvider') String? mobileMoneyProvider,
    @Part('mobileMoneyNumber') String? mobileMoneyNumber,
    @Part('agreedToTerms') String? agreedToTerms,
    @Part('agreedToLocationAccess') String? agreedToLocationAccess,
    @Part('agreedToAccuracy') String? agreedToAccuracy,
    @PartFile('vehicleImage') String? vehicleImagePath,
  });

  @GET(path: '/riders/verification')
  Future<Response<RiderResponse>> getVerification();

  @PUT(path: '/riders/verification')
  @multipart
  Future<Response<RiderResponse>> updateVerification({
    @Part('vehicleType') String? vehicleType,
    @Part('licensePlateNumber') String? licensePlateNumber,
    @Part('vehicleBrand') String? vehicleBrand,
    @Part('vehicleModel') String? vehicleModel,
    @Part('nationalIdType') String? nationalIdType,
    @Part('nationalIdNumber') String? nationalIdNumber,
    @Part('paymentMethod') String? paymentMethod,
    @Part('bankName') String? bankName,
    @Part('accountNumber') String? accountNumber,
    @Part('accountHolderName') String? accountHolderName,
    @Part('mobileMoneyProvider') String? mobileMoneyProvider,
    @Part('mobileMoneyNumber') String? mobileMoneyNumber,
    @Part('agreedToTerms') String? agreedToTerms,
    @Part('agreedToLocationAccess') String? agreedToLocationAccess,
    @Part('agreedToAccuracy') String? agreedToAccuracy,
    @PartFile('vehicleImage') String? vehicleImagePath,
  });

  @POST(path: '/riders/verification/upload-id')
  @multipart
  Future<Response<RiderResponse>> uploadIdImage({
    @Part('imageType') required String imageType,
    @PartFile('idImage') required String imagePath,
  });

  static RiderService create([ChopperClient? client]) => _$RiderService(client);
}
