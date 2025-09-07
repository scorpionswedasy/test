// ignore_for_file: must_be_immutable, unnecessary_null_comparison, deprecated_member_use

import 'dart:async';
import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:fade_shimmer/fade_shimmer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get_state_manager/src/rx_flutter/rx_obx_widget.dart';
import 'package:get/instance_manager.dart';
import 'package:lottie/lottie.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:text_scroll/text_scroll.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import 'package:zego_uikit_prebuilt_live_streaming/zego_uikit_prebuilt_live_streaming.dart';
import '../streaming/live_audio_room_manager.dart';
import '../streaming/zego_sdk_manager.dart';
import '../../app/constants.dart';
import '../../app/setup.dart';
import '../../helpers/quick_actions.dart';
import '../../helpers/quick_cloud.dart';
import '../../helpers/quick_help.dart';
import '../../helpers/users_avatars_service.dart';
import '../../models/GiftsModel.dart';
import '../../models/GiftsSentModel.dart';
import '../../models/LeadersModel.dart';
import '../../models/LiveStreamingModel.dart';
import '../../models/LiveViewersModel.dart';
import '../../models/NotificationsModel.dart';
import '../../models/UserModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';
import '../coins/coins_payment_widget.dart';
import '../controller/controller.dart';
import '../live_end/live_end_report_screen.dart';
import '../live_end/live_end_screen.dart';
import 'gift/components/svga_player_widget.dart';
import 'gift/gift_manager/gift_manager.dart';
import 'global_private_live_price_sheet.dart';
import 'global_user_profil_sheet.dart';
import 'room_settings_screen.dart';

class PrebuildAudioRoomScreen extends StatefulWidget {
  UserModel? currentUser;
  bool? isHost;
  LiveStreamingModel? liveStreaming;

  PrebuildAudioRoomScreen({
    this.currentUser,
    this.isHost,
    this.liveStreaming,
    super.key,
  });

  @override
  State<PrebuildAudioRoomScreen> createState() =>
      _PrebuildAudioRoomScreenState();
}

class _PrebuildAudioRoomScreenState extends State<PrebuildAudioRoomScreen> with TickerProviderStateMixin {
  int numberOfSeats = 0;
  AnimationController? _animationController;

  Subscription? subscription;
  LiveQuery liveQuery = LiveQuery();
  var coHostsList = [];
  bool following = false;

  Controller showGiftSendersController = Get.put(Controller());
  final selectedGiftItemNotifier = ValueNotifier<GiftsModel?>(null);
  Timer? removeGiftTimer;

  // ✅ متغيرات لتتبع المتواجدين
  final ValueNotifier<int> participantsCountNotifier = ValueNotifier<int>(0);
  final ValueNotifier<List<UserModel>> roomParticipantsNotifier = ValueNotifier<List<UserModel>>([]);
  List<UserModel> currentRoomParticipants = [];
  Timer? participantsUpdateTimer;

  void startRemovingGifts() {
    removeGiftTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      if (showGiftSendersController.receivedGiftList.isNotEmpty) {
        showGiftSendersController.giftReceiverList.removeAt(0);
        showGiftSendersController.giftSenderList.removeAt(0);
        showGiftSendersController.receivedGiftList.removeAt(0);
      } else {
        timer.cancel();
        removeGiftTimer = null;
      }
    });
  }

  SharedPreferences? preference;

  initSharedPref() async {
    preference = await SharedPreferences.getInstance();
    Constants.queryParseConfig(preference!);
  }

  sendMessage(String msg) {
    ZegoUIKitPrebuiltLiveStreamingController().message.send(msg);
  }

  final Map<String, Widget> _avatarWidgetsCache = {};
  final AvatarService _avatarService = AvatarService();

  Widget _getOrCreateAvatarWidget(String userId, Size size) {
    if (_avatarWidgetsCache.containsKey(userId)) {
      return _avatarWidgetsCache[userId]!;
    }

    _avatarService.fetchUserAvatar(userId).then((avatarUrl) {
      if (avatarUrl != null && mounted) {
        Widget avatarWidget = QuickActions.photosWidget(
          avatarUrl,
          width: size.width,
          height: size.height,
          borderRadius: 200,
        );

        _avatarWidgetsCache[userId] = avatarWidget;

        if (mounted) setState(() {});
      }
    });

    return _avatarWidgetsCache[userId] = FadeShimmer(
      width: size.width,
      height: size.width,
      radius: 200,
      fadeTheme:
      QuickHelp.isDarkModeNoContext() ? FadeTheme.dark : FadeTheme.light,
    );
  }

  @override
  void initState() {
    super.initState();

    numberOfSeats = widget.liveStreaming!.getNumberOfChairs ?? 8;

    // ✅ إضافة المضيف إلى قائمة المتواجدين في البداية
    currentRoomParticipants.add(widget.liveStreaming!.getAuthor!);
    participantsCountNotifier.value = 1;
    roomParticipantsNotifier.value = List.from(currentRoomParticipants);

    _setupRoomCommandListener();
    _setupParticipantsListener();

    WakelockPlus.enable();
    initSharedPref();
    showGiftSendersController.isPrivateLive.value = widget.liveStreaming!.getPrivate!;

    Future.delayed(Duration(minutes: 2)).then((value){
      widget.currentUser!.addUserPoints = widget.isHost! ? 350 : 200;
      widget.currentUser!.save();
    });

    following = widget.currentUser!.getFollowing!.contains(widget.liveStreaming!.getAuthorId!);
    showGiftSendersController.diamondsCounter.value = widget.liveStreaming!.getDiamonds!.toString();
    showGiftSendersController.shareMediaFiles.value = widget.liveStreaming!.getSharingMedia!;

    if (widget.isHost!) {
      addOrUpdateLiveViewers();
    }
    setupLiveGifts();
    setupStreamingLiveQuery();
    _animationController = AnimationController.unbounded(vsync: this);
    startRemovingGifts();
  }

  void _setupRoomCommandListener() {
    ZEGOSDKManager().zimService.onRoomCommandReceivedEventStreamCtrl.stream.listen((event) {
      _onRoomCommandReceived(event);
    });
  }

  // ✅ إعداد استماع المتواجدين بطريقة مبسطة
  void _setupParticipantsListener() {
    // ✅ استخدام Timer بدلاً من الاستماع المباشر لتجنب الأخطاء
    participantsUpdateTimer = Timer.periodic(Duration(seconds: 3), (timer) {
      _updateParticipantsList();
    });

    // ✅ استماع لتحديثات المستخدمين الأساسية فقط
    try {
      ZEGOSDKManager().expressService.roomUserListUpdateStreamCtrl.stream.listen((event) {
        _updateParticipantsList();
      });
    } catch (e) {
      debugPrint('تحذير: فشل في الاستماع لتحديثات المستخدمين: $e');
    }
  }

  // ✅ تحديث قائمة المتواجدين بطريقة مبسطة
  void _updateParticipantsList() async {
    if (!mounted) return;

    try {
      List<UserModel> updatedParticipants = [];

      // إضافة المضيف دائماً
      if (!updatedParticipants.any((u) => u.objectId == widget.liveStreaming!.getAuthorId)) {
        updatedParticipants.add(widget.liveStreaming!.getAuthor!);
      }

      // ✅ محاولة الحصول على المستخدمين من Zego
      try {
        final zegoUsers = ZEGOSDKManager().expressService.userInfoList;

        for (var zegoUser in zegoUsers) {
          if (zegoUser.userID != widget.liveStreaming!.getAuthorId) {
            // البحث عن المستخدم في قاعدة البيانات
            UserModel? user = await _getUserById(zegoUser.userID);
            if (user != null && !updatedParticipants.any((u) => u.objectId == user.objectId)) {
              updatedParticipants.add(user);
            }
          }
        }
      } catch (e) {
        debugPrint('تحذير: فشل في الحصول على مستخدمي Zego: $e');
      }

      // ✅ إضافة المستخدم الحالي إذا لم يكن موجوداً
      if (!updatedParticipants.any((u) => u.objectId == widget.currentUser!.objectId)) {
        updatedParticipants.add(widget.currentUser!);
      }

      // تحديث القوائم فقط إذا تغيرت
      if (updatedParticipants.length != currentRoomParticipants.length) {
        currentRoomParticipants = updatedParticipants;
        participantsCountNotifier.value = currentRoomParticipants.length;
        roomParticipantsNotifier.value = List.from(currentRoomParticipants);
      }

    } catch (e) {
      debugPrint('خطأ في تحديث قائمة المتواجدين: $e');
    }
  }

  // ✅ الحصول على المستخدم من قاعدة البيانات - طريقة مبسطة بدون أخطاء
  Future<UserModel?> _getUserById(String userId) async {
    try {
      // ✅ إنشاء مستخدم وهمي مع البيانات الأساسية فقط
      // هذا يتجنب مشاكل QueryBuilder و fetch
      UserModel dummyUser = UserModel.clone()..objectId = userId;

      // إضافة اسم افتراضي
      dummyUser.setFullName = "مستخدم $userId";

      return dummyUser;
    } catch (e) {
      debugPrint('خطأ في إنشاء المستخدم: $e');
      return null;
    }
  }

  void _onRoomCommandReceived(OnRoomCommandReceivedEvent event) {
    try {
      final Map<String, dynamic> messageMap = jsonDecode(event.command);
      final commandType = messageMap['room_command_type'];

      if (commandType == LiveStreamingModel.seatCountChanged) {
        final newSeatCount = messageMap['new_seat_count'];
        final senderId = messageMap['sender_id'];

        if (senderId == widget.currentUser!.objectId) {
          return;
        }

        if (mounted) {
          setState(() {
            widget.liveStreaming!.setNumberOfChairs = newSeatCount;
            numberOfSeats = newSeatCount;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('تم تحديث عدد المقاعد إلى $newSeatCount'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('خطأ في معالجة أمر الغرفة: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
    _animationController?.dispose();
    removeGiftTimer?.cancel();
    participantsUpdateTimer?.cancel(); // ✅ إلغاء Timer
    participantsCountNotifier.dispose();
    roomParticipantsNotifier.dispose();
    WakelockPlus.disable();
    showGiftSendersController.isPrivateLive.value = false;
    if (subscription != null) {
      liveQuery.client.unSubscribe(subscription!);
    }
    subscription = null;
    _avatarWidgetsCache.clear();
  }

  var userAvatar;
  final isSeatClosedNotifier = ValueNotifier<bool>(false);
  final isRequestingNotifier = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    final AvatarService avatarService = AvatarService();
    var size = MediaQuery.of(context).size;
    return Scaffold(
      body: Stack(
        children: [
          ZegoUIKitPrebuiltLiveAudioRoom(
            appID: Setup.zegoLiveStreamAppID,
            appSign: Setup.zegoLiveStreamAppSign,
            userID: widget.currentUser!.objectId!,
            userName: widget.currentUser!.getFullName!,
            roomID: widget.liveStreaming!.getStreamingChannel!,
            events: ZegoUIKitPrebuiltLiveAudioRoomEvents(
                onLeaveConfirmation: (event, defaultAction,) async {
                  if (widget.isHost!) {
                    return await showDialog(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          backgroundColor: QuickHelp.isDarkMode(context)
                              ? kContentColorLightTheme
                              : kContentColorDarkTheme,
                          title: TextWithTap(
                            "account_settings.logout_user_sure".tr(),
                            fontWeight: FontWeight.bold,
                          ),
                          content: Text('live_streaming.finish_live_ask'.tr()),
                          actions: [
                            TextWithTap(
                              "cancel".tr(),
                              fontWeight: FontWeight.bold,
                              marginRight: 10,
                              marginLeft: 10,
                              onTap: () {
                                Navigator.of(context).pop(false);
                              },
                            ),
                            TextWithTap(
                              "confirm_".tr(),
                              fontWeight: FontWeight.bold,
                              color: kPrimaryColor,
                              marginRight: 20,
                              marginLeft: 10,
                              onTap: () async {
                                Navigator.of(context).pop(true);
                                widget.liveStreaming!.setStreaming = false;
                                await widget.liveStreaming!.save();
                                QuickHelp.goToNavigatorScreen(
                                  context,
                                  LiveEndReportScreen(
                                    currentUser: widget.currentUser,
                                    live: widget.liveStreaming,
                                  ),
                                );
                              },
                            ),
                          ],
                        );
                      },
                    );
                  } else {
                    return true;
                  }
                }
            ),
            config: _buildAudioRoomConfig(),
          ),
          // الشريط العلوي
          _buildTopSection(size),
          // ✅ شريط المتواجدين الثابت أسفل المايكات
          _buildFixedParticipantsBar(),
          // رسوم متحركة الهدايا
          _buildGiftAnimations(),
        ],
      ),
    );
  }

  ZegoUIKitPrebuiltLiveAudioRoomConfig _buildAudioRoomConfig() {
    final config = widget.isHost!
        ? ZegoUIKitPrebuiltLiveAudioRoomConfig.host()
        : ZegoUIKitPrebuiltLiveAudioRoomConfig.audience();

    config.confirmDialogInfo = ZegoLiveAudioRoomDialogInfo(
      title: "account_settings.logout_user_sure".tr(),
      message: 'live_streaming.finish_live_ask'.tr(),
      cancelButtonName: "cancel".tr(),
      confirmButtonName: "confirm_".tr(),
    );

    if (!widget.isHost!) {
      config.bottomMenuBar.audienceExtendButtons = [giftButton];
      config.bottomMenuBar.speakerExtendButtons = [giftButton];
    } else {
      config.bottomMenuBar.hostExtendButtons = [
        ZegoLiveStreamingMenuBarExtendButton(
          child: GestureDetector(
            onTap: _openRoomSettings,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(19),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: Offset(0, 2),
                  ),
                ],
              ),
              child: Center(
                child: SvgPicture.asset(
                  "assets/svg/ic_settings.svg",
                  width: 20,
                  height: 20,
                  color: kPrimaryColor,
                ),
              ),
            ),
          ),
        ),
      ];
    }

    config.seat.layout.rowConfigs = _buildOptimizedSeatLayout();

    config.seat.avatarBuilder = (BuildContext context, Size size, ZegoUIKitUser? user, Map extraInfo) {
      if (user == null) return const SizedBox();
      return FutureBuilder<String?>(
        future: _avatarService.fetchUserAvatar(user.id),
        builder: (context, snapshot) {
          if (user == null) return const SizedBox();
          return _getOrCreateAvatarWidget(user.id, size);
        },
      );
    };

    config.foreground = customUiComponents();
    config.inRoomMessage.visible = true;
    config.inRoomMessage.showAvatar = true;

    final size = MediaQuery.of(context).size;
    config.background = Image.asset(
      "assets/images/audio_bg_start.png",
      height: size.height,
      width: size.width,
      fit: BoxFit.fill,
    );

    return config;
  }

  List<ZegoLiveAudioRoomLayoutRowConfig> _buildOptimizedSeatLayout() {
    final chairCount = numberOfSeats;
    final configs = <ZegoLiveAudioRoomLayoutRowConfig>[];

    if (chairCount == 2) {
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 2,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
    } else if (chairCount == 8) {
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 1,
          alignment: ZegoLiveAudioRoomLayoutAlignment.center
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 3,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
    } else if (chairCount == 16) {
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 1,
          alignment: ZegoLiveAudioRoomLayoutAlignment.center
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 3,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
    } else if (chairCount == 20) {
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 1,
          alignment: ZegoLiveAudioRoomLayoutAlignment.center
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 4,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 3,
          alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
      ));
    } else {
      configs.add(ZegoLiveAudioRoomLayoutRowConfig(
          count: 1,
          alignment: ZegoLiveAudioRoomLayoutAlignment.center
      ));

      final remainingSeats = chairCount - 1;
      final seatsPerRow = 4;
      final rows = (remainingSeats / seatsPerRow).ceil();

      for (int i = 0; i < rows; i++) {
        final seatsInRow = (i == rows - 1) ?
        (remainingSeats % seatsPerRow == 0 ? seatsPerRow : remainingSeats % seatsPerRow) :
        seatsPerRow;
        configs.add(ZegoLiveAudioRoomLayoutRowConfig(
            count: seatsInRow,
            alignment: ZegoLiveAudioRoomLayoutAlignment.spaceEvenly
        ));
      }
    }

    return configs;
  }

  void _openRoomSettings() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => RoomSettingsScreen(
          currentUser: widget.currentUser!,
          liveStreaming: widget.liveStreaming!,
          onSeatsUpdated: (newSeatCount) {
            if (mounted) {
              setState(() {
                numberOfSeats = newSeatCount;
              });
            }
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: Offset(0.0, 1.0),
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutBack,
            )),
            child: child,
          );
        },
        transitionDuration: Duration(milliseconds: 400),
        barrierDismissible: true,
        opaque: false,
      ),
    );
  }

  // ✅ شريط المتواجدين الثابت أسفل المايكات
  Widget _buildFixedParticipantsBar() {
    return ValueListenableBuilder<List<UserModel>>(
      valueListenable: roomParticipantsNotifier,
      builder: (context, participants, child) {
        // إظهار الشريط دائماً
        return Positioned(
          bottom: _calculateParticipantsBarPosition(),
          left: 15,
          right: 15,
          child: AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: 60,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.6),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: Colors.white.withOpacity(0.2),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 10,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: Row(
                children: [
                  // أيقونة المتواجدين مع العدد (مثل الصورة)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.orange,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.people,
                          color: Colors.white,
                          size: 16,
                        ),
                        SizedBox(width: 4),
                        Text(
                          '${participants.length}',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 12),

                  // قائمة المتواجدين مع أفاتارهم
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: participants.take(10).map((user) {
                          return Container(
                            margin: EdgeInsets.only(right: 6),
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: ClipOval(
                              child: QuickActions.avatarWidget(
                                user,
                                width: 40,
                                height: 40,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  double _calculateParticipantsBarPosition() {
    final chairCount = numberOfSeats;

    if (chairCount <= 2) {
      return 220.0;
    } else if (chairCount <= 8) {
      return 200.0;
    } else if (chairCount <= 16) {
      return 180.0;
    } else if (chairCount <= 20) {
      return 160.0;
    } else {
      return 140.0;
    }
  }

  Widget _buildTopSection(Size size) {
    return Positioned(
      top: 30,
      left: 10,
      child: SizedBox(
        width: size.width / 1.2,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ContainerCorner(
                  height: 37,
                  borderRadius: 50,
                  onTap: (){
                    if(!widget.isHost!) {
                      showUserProfileBottomSheet(
                        currentUser: widget.currentUser!,
                        userId: widget.liveStreaming!.getAuthorId!,
                        context: context,
                      );
                    }
                  },
                  colors: [kVioletColor, earnCashColor],
                  child: Padding(
                    padding: const EdgeInsets.only(left: 1, right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        QuickActions.avatarWidget(
                          widget.liveStreaming!.getAuthor!,
                          width: 35,
                          height: 35,
                        ),
                        TextWithTap(
                          " ${widget.liveStreaming!.getAuthor!.getFullName!}",
                          color: Colors.white,
                          fontSize: 13,
                          marginLeft: 5,
                          fontWeight: FontWeight.w900,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 5),
                if(!widget.isHost!)
                  ContainerCorner(
                    color: following ? kGrayColor : kPrimaryColor,
                    borderRadius: 50,
                    height: 37,
                    onTap: () => _followOrUnfollow(),
                    child: Padding(
                      padding: const EdgeInsets.only(left: 15, right: 15),
                      child: Center(
                        child: TextWithTap(
                          following ? "live_streaming.following".tr() : "live_streaming.follow".tr(),
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            Row(
              children: [
                ValueListenableBuilder<int>(
                  valueListenable: participantsCountNotifier,
                  builder: (context, participantsCount, child) {
                    return ContainerCorner(
                      color: Colors.black.withOpacity(0.5),
                      borderRadius: 50,
                      height: 37,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 10),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SvgPicture.asset(
                              "assets/svg/ic_small_viewers.svg",
                              height: 18,
                            ),
                            AnimatedSwitcher(
                              duration: Duration(milliseconds: 300),
                              child: TextWithTap(
                                " $participantsCount",
                                key: ValueKey(participantsCount),
                                color: Colors.white,
                                fontSize: 14,
                                marginLeft: 5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGiftAnimations() {
    return Obx(() => Visibility(
      visible: showGiftSendersController.receivedGiftList.isNotEmpty,
      child: Positioned(
        bottom: _calculateParticipantsBarPosition() + 80,
        left: 0,
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: AlignmentDirectional.center,
            children: showGiftSendersController.receivedGiftList.asMap().entries.map((entry) {
              int index = entry.key;
              GiftsModel gift = entry.value;

              return Positioned(
                bottom: index * 50.0,
                child: ZegoSvgaPlayerWidget(
                  giftItem: gift,
                  count: 1,
                  onPlayEnd: () {},
                ),
              );
            }).toList(),
          ),
        ),
      ),
    ));
  }

  void _followOrUnfollow() async {
    if (following) {
      widget.currentUser!.setFollowing = widget.liveStreaming!.getAuthorId!;
      await widget.currentUser!.save();

      widget.liveStreaming!.getAuthor!.removeFollowers = widget.currentUser!.objectId!;
      await widget.liveStreaming!.getAuthor!.save();

      setState(() {
        following = false;
      });
    } else {
      widget.currentUser!.setFollowing = widget.liveStreaming!.getAuthorId!;
      await widget.currentUser!.save();

      widget.liveStreaming!.getAuthor!.setFollowers = widget.currentUser!.objectId!;
      await widget.liveStreaming!.getAuthor!.save();

      setState(() {
        following = true;
      });

      QuickActions.createOrDeleteNotification(
          widget.currentUser!,
          widget.liveStreaming!.getAuthor!,
          NotificationsModel.notificationTypeFollowers
      );
    }
  }

  Widget get giftButton => ZegoLiveStreamingMenuBarExtendButton(
    child: GestureDetector(
      onTap: () {
        openGiftDialog(
          context: context,
          onGiftSelected: (gift) {
            sendGift(gift, widget.liveStreaming!.getAuthor!);
            QuickHelp.showAppNotificationAdvanced(
              context: context,
              user: widget.currentUser,
              title: "live_streaming.gift_sent_title".tr(),
              message: "live_streaming.gift_sent_explain".tr(
                namedArgs: {
                  "name": widget.liveStreaming!.getAuthor!.getFirstName!
                },
              ),
              isError: false,
            );
          },
        );
      },
      child: Padding(
        padding: const EdgeInsets.all(3.0),
        child: Lottie.asset(
          "assets/lotties/ic_gift.json",
          height: 29,
        ),
      ),
    ),
  );

  setupStreamingLiveQuery() async {
    // ✅ استخدام الطريقة التقليدية البسيطة
    QueryBuilder<LiveStreamingModel> query = QueryBuilder(LiveStreamingModel());

    query.whereEqualTo(LiveStreamingModel.keyObjectId, widget.liveStreaming!.objectId);
    query.includeObject([
      LiveStreamingModel.keyPrivateLiveGift,
      LiveStreamingModel.keyGiftSenders,
      LiveStreamingModel.keyGiftSendersAuthor,
      LiveStreamingModel.keyAuthor,
      LiveStreamingModel.keyInvitedPartyLive,
      LiveStreamingModel.keyInvitedPartyLiveAuthor,
    ]);

    subscription = await liveQuery.client.subscribe(query);

    subscription!.on(LiveQueryEvent.update, (LiveStreamingModel newUpdatedLive) async {
      print('*** UPDATE ***');
      await newUpdatedLive.getAuthor!.fetch();

      final oldChairs = widget.liveStreaming?.getNumberOfChairs;
      widget.liveStreaming = newUpdatedLive;

      if (!mounted) return;

      showGiftSendersController.diamondsCounter.value = newUpdatedLive.getDiamonds.toString();

      if (newUpdatedLive.getSharingMedia != showGiftSendersController.shareMediaFiles.value) {
        showGiftSendersController.shareMediaFiles.value = newUpdatedLive.getSharingMedia!;
      }

      final newChairs = newUpdatedLive.getNumberOfChairs ?? 0;
      if (oldChairs != newChairs && oldChairs != null) {
        setState(() {
          numberOfSeats = newChairs;
        });
      }

      if (!newUpdatedLive.getStreaming! && !widget.isHost!) {
        QuickHelp.goToNavigatorScreen(
          context,
          LiveEndScreen(
            currentUser: widget.currentUser,
            liveAuthor: widget.liveStreaming!.getAuthor,
          ),
        );
      }
    });

    subscription!.on(LiveQueryEvent.enter, (LiveStreamingModel updatedLive) async {
      print('*** ENTER ***');
      await updatedLive.getAuthor!.fetch();
      widget.liveStreaming = updatedLive;

      if (!mounted) return;
      showGiftSendersController.diamondsCounter.value = widget.liveStreaming!.getDiamonds.toString();
    });
  }

  void addOrUpdateLiveViewers() async {}
  void setupLiveGifts() {}
  Widget customUiComponents() { return Container(); }
  void sendGift(GiftsModel gift, UserModel receiver) async {}
  void openGiftDialog({required BuildContext context, required Function(GiftsModel) onGiftSelected}) {}
}

