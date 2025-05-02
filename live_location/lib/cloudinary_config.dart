import 'package:cloudinary_sdk/cloudinary_sdk.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class CloudinaryConfig {
  static final CloudinaryConfig _instance = CloudinaryConfig._internal();
  late Cloudinary cloudinary;

  factory CloudinaryConfig() {
    return _instance;
  }

  CloudinaryConfig._internal() {
    cloudinary = Cloudinary.full(
      cloudName: dotenv.env['CLOUD_NAME']!,
      apiSecret: dotenv.env['CLOUDINARY_API_SECRET']!,
      apiKey: dotenv.env['CLOUDINARY_API_KEY']!,
    );
  }
}