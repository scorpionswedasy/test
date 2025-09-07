// ignore_for_file: deprecated_member_use

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flamingo/helpers/quick_actions.dart';
import 'package:flamingo/helpers/quick_help.dart';
import 'package:flamingo/models/GiftsModel.dart';
import 'package:flamingo/models/PaymentsModel.dart';
import 'package:flamingo/models/UserModel.dart';
import 'package:flamingo/models/others/in_app_model.dart';
import 'package:flamingo/ui/container_with_corner.dart';
import 'package:flamingo/ui/text_with_tap.dart';
import 'package:flamingo/utils/colors.dart';

import '../../app/config.dart';

class CoinsFlowPayment {
  CoinsFlowPayment(
      {required BuildContext context,
        required UserModel currentUser,
        Function(GiftsModel giftsModel)? onGiftSelected,
        Function(int coins)? onCoinsPurchased,
        bool isDismissible = true,
        bool enableDrag = true,
        bool isScrollControlled = false,
        bool showOnlyCoinsPurchase = false,
        Color backgroundColor = Colors.transparent}) {
    showModalBottomSheet(
        context: (context),
        isScrollControlled: isScrollControlled,
        backgroundColor: backgroundColor,
        enableDrag: enableDrag,
        isDismissible: isDismissible,
        builder: (context) {
          return _CoinsFlowWidget(
            currentUser: currentUser,
            onCoinsPurchased: onCoinsPurchased,
            onGiftSelected: onGiftSelected,
            showOnlyCoinsPurchase: showOnlyCoinsPurchase,
          );
        });
  }
}

// ignore: must_be_immutable
class _CoinsFlowWidget extends StatefulWidget {
  final Function? onCoinsPurchased;
  final Function? onGiftSelected;
  final bool? showOnlyCoinsPurchase;
  UserModel currentUser;

  _CoinsFlowWidget({
    required this.currentUser,
    this.onCoinsPurchased,
    this.onGiftSelected,
    this.showOnlyCoinsPurchase = false,
  });

  @override
  State<_CoinsFlowWidget> createState() => _CoinsFlowWidgetState();
}

class _CoinsFlowWidgetState extends State<_CoinsFlowWidget>
    with TickerProviderStateMixin {
  AnimationController? _animationController;
  int bottomSheetCurrentIndex = 0;

  late Offerings offerings;
  bool _isAvailable = false;
  bool _loading = true;
  InAppPurchaseModel? _inAppPurchaseModel;


  List<InAppPurchaseModel> getInAppList() {

    List<Package> myProductList = offerings.current!.availablePackages;

    List<InAppPurchaseModel> inAppPurchaseList = [];

    return inAppPurchaseList;
  }

  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  final countNotifier = ValueNotifier<String>('1');

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController.unbounded(vsync: this);

    initProducts();
  }

  initProducts() async {
    try {
      offerings = await Purchases.getOfferings();

      if (offerings.current!.availablePackages.length > 0) {
        // Display packages for sale

        setState(() {
          _isAvailable = true;
          _loading = false;
        });
        // Display packages for sale
      }
    } on PlatformException {
      // optional error handling

      setState(() {
        _isAvailable = false;
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _showGiftAndGetCoinsBottomSheet();
  }

  _purchaseProduct(InAppPurchaseModel inAppPurchaseModel) async{

    QuickHelp.showLoadingDialog(context);

    try {
      await Purchases.purchasePackage(inAppPurchaseModel.package!);

      widget.currentUser.addCredit = _inAppPurchaseModel!.coins!;
      await widget.currentUser.save();

      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        user: widget.currentUser,
        title: "in_app_purchases.coins_purchased"
            .tr(namedArgs: {"coins": _inAppPurchaseModel!.coins!.toString()}),
        message: "in_app_purchases.coins_added_to_account".tr(),
        isError: false,
      );

    } on PlatformException catch (e) {

      var errorCode = PurchasesErrorHelper.getErrorCode(e);

      if (errorCode != PurchasesErrorCode.purchaseCancelledError) {

        QuickHelp.hideLoadingDialog(context);

        QuickHelp.showAppNotificationAdvanced(
          context:context,
          user: widget.currentUser,
          title: "in_app_purchases.purchase_cancelled_title".tr(),
          message: "in_app_purchases.purchase_cancelled".tr(),
        );

      } else if (errorCode != PurchasesErrorCode.invalidReceiptError) {

        _handleInvalidPurchase();

      } else {
        handleError(e);
      }
    }
  }

  void _handleInvalidPurchase() {

    QuickHelp.showAppNotification(context:context, title: "in_app_purchases.invalid_purchase".tr());
    QuickHelp.hideLoadingDialog(context);
  }


  void registerPayment(CustomerInfo customerInfo, InAppPurchaseModel productDetails) async {

    // Save all payment information
    PaymentsModel paymentsModel = PaymentsModel();
    paymentsModel.setAuthor = widget.currentUser;
    paymentsModel.setAuthorId = widget.currentUser.objectId!;
    paymentsModel.setPaymentType = PaymentsModel.paymentTypeConsumible;

    paymentsModel.setId = productDetails.id!;
    paymentsModel.setTitle = productDetails.storeProduct!.title;
    paymentsModel.setTransactionId = customerInfo.originalPurchaseDate!;
    paymentsModel.setCurrency = productDetails.currency!.toUpperCase();
    paymentsModel.setPrice = productDetails.price.toString();
    paymentsModel.setMethod = QuickHelp.isAndroidPlatform()? "Google Play" : QuickHelp.isIOSPlatform() ? "App Store" : "";
    paymentsModel.setStatus = PaymentsModel.paymentStatusCompleted;

    await paymentsModel.save();
  }

  void handleError(PlatformException error) {

    QuickHelp.hideLoadingDialog(context);
    QuickHelp.showAppNotification(context:context, title: error.message);
  }

  showPendingUI() {
    QuickHelp.showLoadingDialog(context);
    print("InAppPurchase showPendingUI");
  }

  Widget _showGiftAndGetCoinsBottomSheet() {

    return StatefulBuilder(builder: (context, setState) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.5),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(25.0),
            topRight: const Radius.circular(25.0),
          ),
        ),
        child: ContainerCorner(
          color: kTransparentColor,
          child: IndexedStack(
            index: widget.showOnlyCoinsPurchase!
                ? 1
                : bottomSheetCurrentIndex,
            children: [
              Scaffold(
                backgroundColor: kTransparentColor,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  leading: BackButton(color: Colors.white,),
                  actions: [
                    ContainerCorner(
                      height: 30,
                      borderRadius: 50,
                      marginRight: 10,
                      marginTop: 10,
                      marginBottom: 10,
                      color: kWarninngColor,
                      onTap: () {
                        setState(() {
                          bottomSheetCurrentIndex = 1;
                        });
                      },
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 10),
                            child: SvgPicture.asset(
                              "assets/svg/coin.svg",
                              width: 20,
                              height: 20,
                            ),
                          ),
                          TextWithTap(
                            "message_screen.get_coins".tr(),
                            marginRight: 10,
                          )
                        ],
                      ),
                    )
                  ],
                  backgroundColor: kTransparentColor,
                  centerTitle: true,
                  title: Row(
                    children: [
                      SvgPicture.asset(
                        "assets/svg/ic_coin_with_star.svg",
                        width: 20,
                        height: 20,
                      ),
                      TextWithTap(
                        widget.currentUser.getCredits.toString(),
                        color: Colors.white,
                        fontSize: 16,
                        marginLeft: 5,
                      )
                    ],
                  ),
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      ContainerCorner(
                          color: kTransparentColor,
                          child: _tabSection(context, setState)),
                    ],
                  ),
                ),
              ),
              Scaffold(
                backgroundColor: kTransparentColor,
                appBar: AppBar(
                  actions: [
                    Row(
                      children: [
                        SvgPicture.asset(
                          "assets/svg/ic_coin_with_star.svg",
                          width: 20,
                          height: 20,
                        ),
                        TextWithTap(
                          widget.currentUser.getCredits.toString(),
                          color: Colors.white,
                          marginLeft: 5,
                          marginRight: 15,
                        )
                      ],
                    ),
                  ],
                  backgroundColor: kTransparentColor,
                  title: TextWithTap(
                    "message_screen.get_coins".tr(),
                    marginRight: 10,
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  centerTitle: true,
                  automaticallyImplyLeading: false,
                  leading: BackButton(
                    color: Colors.white,
                    onPressed: () {
                      if (widget.showOnlyCoinsPurchase!) {
                        Navigator.of(this.context).pop();
                      } else {
                        setState(() {
                          bottomSheetCurrentIndex = 0;
                        });
                      }
                    },
                  ),
                ),
                body: getBody(),
              )
            ],
          ),
        ),
      );
    });
  }

  Widget _tabSection(BuildContext context, StateSetter stateSetter) {
    return DefaultTabController(
      length: 9,
      child: Column(
        children: [
          getGifts(GiftsModel.giftCategoryTypeClassic, stateSetter),
        ],
      ),
    );
  }

  Widget getGifts(String category, StateSetter setState) {

    QueryBuilder<GiftsModel> giftQuery = QueryBuilder<GiftsModel>(GiftsModel());
    giftQuery.whereValueExists(GiftsModel.keyGiftCategories, true);
    giftQuery.whereEqualTo(
        GiftsModel.keyGiftCategories, GiftsModel.gifStatus);

    return ContainerCorner(
      color: kTransparentColor,
      child: ParseLiveGridWidget<GiftsModel>(
        query: giftQuery,
        crossAxisCount: 4,
        reverse: false,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
        lazyLoading: false,
        //childAspectRatio: 1.0,
        shrinkWrap: true,
        listenOnAllSubItems: true,
        duration: Duration(seconds: 0),
        animationController: _animationController,
        childBuilder: (BuildContext context,
            ParseLiveListElementSnapshot<GiftsModel> snapshot) {
          GiftsModel gift = snapshot.loadedData!;
          return GestureDetector(
            //onTap: () => _checkCredits(gift, setState),
            child: SizedBox(
              width: double.infinity,
              height: double.infinity,
              child: Column(
                children: [
                  GestureDetector(
                    onTap: () => _checkCredits(gift, setState),
                    child: Column(
                      children: [
                        ValueListenableBuilder<GiftsModel?>(
                          valueListenable: selectedGiftItemNotifier,
                          builder: (context, selectedGiftItem, _) {
                            return Container(
                              width: 50,
                              height: 50,
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: QuickActions.photosWidget(
                                    gift.getPreview!.url),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  ContainerCorner(
                    color: kTransparentColor,
                    marginTop: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          "assets/svg/ic_coin_with_star.svg",
                          width: 16,
                          height: 16,
                        ),
                        TextWithTap(
                          gift.getCoins.toString(),
                          color: Colors.white,
                          fontSize: 14,
                          marginLeft: 5,
                        )
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        queryEmptyElement: QuickActions.noContentFound(context),
        gridLoadingElement: Container(
          margin: EdgeInsets.only(top: 50),
          alignment: Alignment.topCenter,
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }

  Tab gefTab(String name, String image) {
    return Tab(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(
            image,
            color: Colors.white.withOpacity(0.7),
            width: 20,
            height: 20,
          ),
          TextWithTap(
            name,
            fontSize: 12,
            marginTop: 5,
          ),
        ],
      ),
    );
  }

  Widget getBody() {

    if (_loading) {
      return QuickHelp.appLoading();
    } else if (_isAvailable) {
      return ContainerCorner(
        color: kTransparentColor,
        marginLeft: 5,
        marginRight: 5,
        child: GridView.count(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: List.generate(
            getInAppList().length,
                (index) {
              InAppPurchaseModel inApp = getInAppList()[index];

              return ContainerCorner(
                color: kDarkColorsTheme,
                borderRadius: 8,
                onTap: () {
                  _inAppPurchaseModel = inApp;
                  _purchaseProduct(inApp);
                },
                child: Column(
                  children: [
                    TextWithTap(
                      QuickHelp.checkFundsWithString(amount: "${inApp.coins}"),
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      marginTop: 5,
                      color: Colors.white,
                    ),
                    Expanded(
                      child: Image.asset(
                        "assets/images/coin_bling.webp",
                        height: 20,
                        width: 20,
                      ),
                    ),
                    ContainerCorner(
                      borderRadius: 50,
                      borderWidth: 0,
                      height: 30,
                      marginRight: 10,
                      marginLeft: 10,
                      color: Colors.deepPurpleAccent,
                      marginBottom: 5,
                      child: TextWithTap(
                        "${inApp.price}",
                        color: Colors.white,
                        alignment: Alignment.center,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
    } else {
      return QuickActions.noContentFound(context);
    }
  }

  _checkCredits(GiftsModel gift, StateSetter setState) {
    if (widget.currentUser.getCredits! >= gift.getCoins!) {
      if (widget.onGiftSelected != null) {
        widget.onGiftSelected!(gift) as void Function()?;
        Navigator.of(context).pop();
      }
    } else {
      setState(() {
        bottomSheetCurrentIndex = 1;
      });
    }
  }
}
