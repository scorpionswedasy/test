import 'dart:ui';

class Config {
  static const String packageNameAndroid = "com.flamingolive.hus";
  static const String packageNameiOS = "com.exemple.app";
  static const String iosAppStoreId = "com.exemple.app";
  static final String appName = "Flamingo";
  static final String appVersion = "1.0.0";
  static final String companyName = "Flamingo, inc";
  static final String appOrCompanyUrl = "https://flamingotar.flamingochat.net";
  static final String initialCountry = 'AO'; // Angola
  static final String serverUrl =
      "https://parseapi.back4app.com";
  static final String liveQueryUrl =
      "wss://tarve.b4a.io";
  static final String appId = "dr1zqC6eOjj6k6gkszwfp6DzU1S4vwtzuWuawV0s";
  static final String clientKey = "cKmqAuST1hoqiow8Drlc9YS1k3vxLSEWeHHY2gBg";
  //OneSignal
  static final String oneSignalAppId = "9ace5151-c2c9-4881-8d56-c8f43eed6287";

  // Firebase Cloud Messaging
  static final String pushGcm = "419482297256";
  static final String webPushCertificate =
      "BE529HxFzKo3OYSVlt6Xp3muuFg59vXQUcF2Y8RhoRYwpo3GXMvIkBDgOT7D8IKwUOg_nJG7v1b7H355EoN5FLI";

  // User support objectId
  static final String supportId = "";

  // Play Store and App Store public keys
  static final String publicGoogleSdkKey = "MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAiaohbXekj5zh+E2ujphHRqiezYT0bUjzksbwpP+QbhGwQYiVnT12EckQRkXQo2yNKu5igO1qwuhRohwTSo6cBvVnSxuRZAKBsGjyZ29o1WBCMmtec1qdqBE6vhYmNb3NXReN0yTaoOD0xGNSna2Wm+lrhhNki4Law4dhVPTDQFEuCiS10BAG1+8dgMKZ1dSP3rAHUKzo0RW61HIOTAeHCSiG/VNVCegYNkwWCT/Xd57J6GlAhUdAy/9Me+126+lrG/Vbyc9pdP2irhLg/3X/W6tnQxb62hSUVU7PtbdmaNeharDb1WAOoQT8ibBn7iek3BTLYFnzL1BnPeuL7D+n4QIDAQAB";
  static final String publicIosSdkKey = "";

  // Languages
  static String defaultLanguage = "ar"; // English is default language.
  static List<Locale> languages = [
    Locale(defaultLanguage),
    //Locale('pt'),
    //Locale('fr')
  ];

  // Android Admob ad
  static const String admobAndroidOpenAppAd =
      "ca-app-pub-9318890613494690/4325316561";
  static const String admobAndroidHomeBannerAd =
      "ca-app-pub-9318890613494690/8240828077";
  static const String admobAndroidFeedNativeAd =
      "ca-app-pub-9318890613494690/9362338057";
  static const String admobAndroidChatListBannerAd =
      "ca-app-pub-9318890613494690/6736174716";
  static const String admobAndroidLiveBannerAd =
      "ca-app-pub-9318890613494690/7959371442";
  static const String admobAndroidFeedBannerAd =
      "ca-app-pub-9318890613494690/9362338057";

  // iOS Admob ad
  static const String admobIOSOpenAppAd =
      "ca-app-pub-1084112649181796/6328973508";
  static const String admobIOSHomeBannerAd =
      "ca-app-pub-1084112649181796/1185447057";
  static const String admobIOSFeedNativeAd =
      "ca-app-pub-1084112649181796/7224203806";
  static const String admobIOSChatListBannerAd =
      "ca-app-pub-1084112649181796/5811376758";
  static const String admobIOSLiveBannerAd =
      "ca-app-pub-1084112649181796/8093979063";
  static const String admobIOSFeedBannerAd =
      "ca-app-pub-1084112649181796/6907075815";

  // Web links for help, privacy policy and terms of use.
  static final String helpCenterUrl = "https://flamingotar-32ba6.web.app";
  static final String privacyPolicyUrl = "https://flamingotar-32ba6.web.app/privacy/";
  static final String termsOfUseUrl = "https://flamingotar-32ba6.web.app/terms";
  static final String termsOfUseInAppUrl = "https://flamingotar-32ba6.web.app/terms";
  static final String dataSafetyUrl = "https://flamingotar-32ba6.web.app";
  static final String openSourceUrl = "https://flamingotar-32ba6.web.app";
  static final String instructionsUrl = "https://flamingotar-32ba6.web.app";
  static final String cashOutUrl = "https://flamingotar-32ba6.web.app";
  static final String supportUrl = "https://flamingotar-32ba6.web.app";
  static final String liveAgreementUrl = "https://flamingotar-32ba6.web.app/live/";
  static final String userAgreementUrl = "https://flamingotar-32ba6.web.app/user/";

  // Google Play and Apple Pay In-app Purchases IDs
  static final String credit100 = "flamingo.3000.credits";
  static final String credit200 = "flamingo.15000.credits";
  static final String credit500 = "flamingo.30000.credits";
  static final String credit1000 = "flamingo.75000.credits";
  static final String credit2100 = "flamingo.150000.credits";
  static final String credit5250 = "flamingo.225000.credits";
  static final String credit10500 = "flamingo.300000.credits";
}
