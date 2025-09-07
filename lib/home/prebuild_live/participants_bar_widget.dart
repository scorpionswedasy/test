import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../streaming/zego_sdk_manager.dart';
import '../streaming/live_audio_room_manager.dart';
import '../../helpers/quick_actions.dart';
import '../../helpers/users_avatars_service.dart';

class ParticipantsBarWidget extends StatefulWidget {
  final int seatCount;
  final Function(String userId)? onUserTap;
  final double bottomPosition;

  const ParticipantsBarWidget({
    Key? key,
    required this.seatCount,
    this.onUserTap,
    this.bottomPosition = 120.0,
  }) : super(key: key);

  @override
  State<ParticipantsBarWidget> createState() => _ParticipantsBarWidgetState();
}

class _ParticipantsBarWidgetState extends State<ParticipantsBarWidget>
    with SingleTickerProviderStateMixin {

  List<ZegoSDKUser> participants = [];
  late StreamSubscription _userListSubscription;
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  final AvatarService _avatarService = AvatarService();
  final Map<String, String?> _avatarCache = {};

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _initializeParticipants();
    _setupUserListListener();
    _animationController.forward();
  }

  void _initializeParticipants() {
    // الحصول على قائمة المستخدمين الحالية
    final userList = ZEGOSDKManager().expressService.userInfoList;
    setState(() {
      participants = List.from(userList);
    });

    // جلب الأفاتار للمستخدمين الحاليين
    _loadAvatarsForUsers(participants);
  }

  void _setupUserListListener() {
    // الاستماع لتحديثات قائمة المستخدمين
    _userListSubscription = ZEGOSDKManager()
        .expressService
        .roomUserListUpdateStreamCtrl
        .stream
        .listen(_onUserListUpdate);
  }

  void _onUserListUpdate(ZegoRoomUserListUpdateEvent event) {
    if (!mounted) return;

    setState(() {
      if (event.updateType == ZegoUpdateType.Add) {
        // إضافة المستخدمين الجدد - تحويل من ZegoUser إلى ZegoSDKUser
        for (final zegoUser in event.userList) {
          // البحث عن المستخدم في قائمة SDK أو إنشاء واحد جديد
          ZegoSDKUser? sdkUser = ZEGOSDKManager().getUser(zegoUser.userID);
          if (sdkUser == null) {
            // إنشاء مستخدم SDK جديد من ZegoUser
            sdkUser = ZegoSDKUser(
                userID: zegoUser.userID,
                userName: zegoUser.userName
            );
          }

          // إضافة المستخدم إذا لم يكن موجوداً
          if (!participants.any((p) => p.userID == sdkUser!.userID)) {
            participants.add(sdkUser);
          }
        }

        // تحويل قائمة ZegoUser إلى ZegoSDKUser لجلب الأفاتار
        final sdkUsers = event.userList.map((zegoUser) {
          return ZEGOSDKManager().getUser(zegoUser.userID) ??
              ZegoSDKUser(userID: zegoUser.userID, userName: zegoUser.userName);
        }).toList();

        // جلب الأفاتار للمستخدمين الجدد
        _loadAvatarsForUsers(sdkUsers);
      } else {
        // إزالة المستخدمين الذين غادروا
        for (final zegoUser in event.userList) {
          participants.removeWhere((p) => p.userID == zegoUser.userID);
          _avatarCache.remove(zegoUser.userID);
        }
      }
    });

    // تحديث الرسوم المتحركة
    _animationController.reset();
    _animationController.forward();
  }

  Future<void> _loadAvatarsForUsers(List<ZegoSDKUser> users) async {
    for (final user in users) {
      if (!_avatarCache.containsKey(user.userID)) {
        try {
          final avatarUrl = await _avatarService.fetchUserAvatar(user.userID);
          if (mounted) {
            setState(() {
              _avatarCache[user.userID] = avatarUrl;
            });
          }
        } catch (e) {
          _avatarCache[user.userID] = null;
        }
      }
    }
  }

  @override
  void dispose() {
    _userListSubscription.cancel();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (participants.isEmpty) {
      return SizedBox.shrink();
    }

    return AnimatedBuilder(
      animation: _slideAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(0, (1 - _slideAnimation.value) * 30),
          child: Opacity(
            opacity: _slideAnimation.value,
            child: _buildRectangularParticipantsBar(),
          ),
        );
      },
    );
  }

  // ✅ شريط مستطيل شفاف للمتواجدين
  Widget _buildRectangularParticipantsBar() {
    return Positioned(
      bottom: widget.bottomPosition,
      left: 15,
      right: 15,
      child: Container(
        height: 60,
        decoration: BoxDecoration(
          // ✅ خلفية شفافة مستطيلة
          color: Colors.black.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.3),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // ✅ أيقونة المتواجدين
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  Icons.people,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              SizedBox(width: 12),

              // ✅ قائمة المتواجدين المرتبة
              Expanded(
                child: _buildParticipantsList(),
              ),

              // ✅ عداد المتواجدين في النهاية
              _buildParticipantsCounter(),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ قائمة المتواجدين مرتبة أفقياً
  Widget _buildParticipantsList() {
    // عرض أول 10 مستخدمين لتوفير مساحة أكبر
    final displayUsers = participants.take(10).toList();

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: displayUsers.asMap().entries.map((entry) {
          final index = entry.key;
          final user = entry.value;
          return _buildParticipantAvatar(user, index);
        }).toList(),
      ),
    );
  }

  // ✅ أفاتار المشارك مع تصميم مستطيل
  Widget _buildParticipantAvatar(ZegoSDKUser user, int index) {
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      margin: EdgeInsets.only(
        left: index > 0 ? 6 : 0,
        top: 2,
        bottom: 2,
      ),
      child: GestureDetector(
        onTap: () => widget.onUserTap?.call(user.userID),
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10), // ✅ حواف مستطيلة مدورة
            border: Border.all(
              color: Colors.white.withOpacity(0.8),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 4,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: _buildUserAvatarImage(user),
          ),
        ),
      ),
    );
  }

  Widget _buildUserAvatarImage(ZegoSDKUser user) {
    final avatarUrl = _avatarCache[user.userID];

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: avatarUrl,
        fit: BoxFit.cover,
        placeholder: (context, url) => _buildDefaultAvatar(user),
        errorWidget: (context, url, error) => _buildDefaultAvatar(user),
      );
    } else {
      return _buildDefaultAvatar(user);
    }
  }

  Widget _buildDefaultAvatar(ZegoSDKUser user) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _getColorFromUserId(user.userID),
            _getColorFromUserId(user.userID).withOpacity(0.7),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          user.userName.isNotEmpty
              ? user.userName.substring(0, 1).toUpperCase()
              : user.userID.substring(0, 1).toUpperCase(),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Color _getColorFromUserId(String userId) {
    // إنشاء لون فريد بناءً على معرف المستخدم
    final hash = userId.hashCode;
    final colors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.teal,
      Colors.indigo,
      Colors.pink,
      Colors.cyan,
      Colors.amber,
      Colors.deepOrange,
    ];
    return colors[hash.abs() % colors.length];
  }

  // ✅ عداد المتواجدين مع تصميم مستطيل
  Widget _buildParticipantsCounter() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: 6),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child: Text(
              '${participants.length}',
              key: ValueKey(participants.length),
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ ويدجت مساعد لحساب الموضع الديناميكي للشريط المستطيل
class DynamicParticipantsBar extends StatelessWidget {
  final int seatCount;
  final Function(String userId)? onUserTap;

  const DynamicParticipantsBar({
    Key? key,
    required this.seatCount,
    this.onUserTap,
  }) : super(key: key);

  double _calculateBottomPosition(int seatCount) {
    // حساب الموضع بناءً على عدد المقاعد - أسفل المايكات مباشرة
    if (seatCount <= 8) {
      return 140.0; // موضع أساسي للأعداد الصغيرة
    } else if (seatCount <= 16) {
      return 160.0; // موضع أعلى قليلاً للأعداد المتوسطة
    } else if (seatCount == 20) {
      return 180.0; // موضع أعلى للـ 20 مقعد
    } else if (seatCount == 24) {
      return 200.0; // موضع أعلى للـ 24 مقعد لترك مساحة للدردشة
    } else {
      return 220.0; // موضع أعلى للأعداد الكبيرة
    }
  }

  @override
  Widget build(BuildContext context) {
    return ParticipantsBarWidget(
      seatCount: seatCount,
      bottomPosition: _calculateBottomPosition(seatCount),
      onUserTap: onUserTap,
    );
  }
}

