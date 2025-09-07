import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:zego_uikit_prebuilt_live_audio_room/zego_uikit_prebuilt_live_audio_room.dart';
import '../../models/UserModel.dart';
import '../../models/LiveStreamingModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';
import '../../helpers/quick_actions.dart';
import '../../helpers/quick_help.dart';

class SeatManagementDialog extends StatefulWidget {
  final UserModel currentUser;
  final LiveStreamingModel liveStreaming;
  final ZegoUIKitUser? seatUser;
  final int seatIndex;
  final bool isEmpty;
  final List<UserModel> availableUsers;

  const SeatManagementDialog({
    Key? key,
    required this.currentUser,
    required this.liveStreaming,
    this.seatUser,
    required this.seatIndex,
    required this.isEmpty,
    required this.availableUsers,
  }) : super(key: key);

  @override
  State<SeatManagementDialog> createState() => _SeatManagementDialogState();
}

class _SeatManagementDialogState extends State<SeatManagementDialog>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 400),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.elasticOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(
            scale: _scaleAnimation,
            child: Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      kPrimaryColor.withOpacity(0.95),
                      kSecondaryColor.withOpacity(0.95),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 20,
                      offset: Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildHeader(),
                    _buildContent(),
                    _buildActions(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              widget.isEmpty ? Icons.chair_outlined : Icons.person,
              color: Colors.white,
              size: 24,
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextWithTap(
                  widget.isEmpty
                      ? "إدارة المقعد ${widget.seatIndex + 1}"
                      : "إدارة ${widget.seatUser?.name ?? 'المستخدم'}",
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                SizedBox(height: 4),
                TextWithTap(
                  widget.isEmpty ? "مقعد فارغ" : "مقعد مشغول",
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.close,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContent() {
    return Flexible(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            if (widget.isEmpty) ..._buildEmptySeatOptions(),
            if (!widget.isEmpty) ..._buildOccupiedSeatOptions(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildEmptySeatOptions() {
    return [
      _buildOptionCard(
        icon: Icons.person_add,
        title: "دعوة مستخدم",
        subtitle: "اختر مستخدماً من المتواجدين",
        color: Colors.green,
        onTap: () => _showUserSelectionDialog(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.lock,
        title: "إغلاق المقعد",
        subtitle: "منع أي شخص من الجلوس",
        color: Colors.orange,
        onTap: () => _closeSeat(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.lock_open,
        title: "فتح المقعد",
        subtitle: "السماح للجميع بالجلوس",
        color: Colors.blue,
        onTap: () => _openSeat(),
      ),
    ];
  }

  List<Widget> _buildOccupiedSeatOptions() {
    return [
      _buildOptionCard(
        icon: Icons.mic_off,
        title: "كتم المايك",
        subtitle: "إيقاف صوت المستخدم",
        color: Colors.red,
        onTap: () => _muteMicrophone(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.mic,
        title: "تشغيل المايك",
        subtitle: "تفعيل صوت المستخدم",
        color: Colors.green,
        onTap: () => _unmuteMicrophone(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.admin_panel_settings,
        title: "تعيين كمدير",
        subtitle: "منح صلاحيات إدارية",
        color: Colors.purple,
        onTap: () => _makeAdmin(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.person_remove,
        title: "إنزال من المقعد",
        subtitle: "إزالة المستخدم من المقعد",
        color: Colors.orange,
        onTap: () => _removeFromSeat(),
      ),
      SizedBox(height: 12),
      _buildOptionCard(
        icon: Icons.exit_to_app,
        title: "طرد من الغرفة",
        subtitle: "إخراج المستخدم نهائياً",
        color: Colors.red.shade700,
        onTap: () => _kickFromRoom(),
      ),
    ];
  }

  Widget _buildOptionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.2),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextWithTap(
                    title,
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  SizedBox(height: 4),
                  TextWithTap(
                    subtitle,
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: Colors.white.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActions() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: ContainerCorner(
              color: Colors.white.withOpacity(0.2),
              borderRadius: 12,
              height: 45,
              onTap: () => Navigator.pop(context),
              child: Center(
                child: TextWithTap(
                  "إلغاء",
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUserSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          constraints: BoxConstraints(maxHeight: 400),
          decoration: BoxDecoration(
            color: kPrimaryColor.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people, color: Colors.white, size: 24),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextWithTap(
                        "اختر مستخدماً للدعوة",
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: EdgeInsets.all(16),
                  itemCount: widget.availableUsers.length,
                  itemBuilder: (context, index) {
                    final user = widget.availableUsers[index];
                    return Container(
                      margin: EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: QuickActions.avatarWidget(
                          user,
                          width: 40,
                          height: 40,
                        ),
                        title: TextWithTap(
                          user.getFullName ?? "مستخدم",
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        subtitle: TextWithTap(
                          "انقر للدعوة",
                          color: Colors.white.withOpacity(0.7),
                          fontSize: 12,
                        ),
                        onTap: () {
                          _inviteUser(user);
                          Navigator.pop(context);
                          Navigator.pop(context);
                        },
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        tileColor: Colors.white.withOpacity(0.1),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // تنفيذ الإجراءات
  void _inviteUser(UserModel user) {
    // TODO: تنفيذ دعوة المستخدم للمقعد
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم إرسال الدعوة",
      message: "تم دعوة ${user.getFullName} للمقعد ${widget.seatIndex + 1}",
      isError: false,
    );
  }

  void _closeSeat() {
    // TODO: تنفيذ إغلاق المقعد
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم إغلاق المقعد",
      message: "المقعد ${widget.seatIndex + 1} مغلق الآن",
      isError: false,
    );
  }

  void _openSeat() {
    // TODO: تنفيذ فتح المقعد
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم فتح المقعد",
      message: "المقعد ${widget.seatIndex + 1} متاح الآن",
      isError: false,
    );
  }

  void _muteMicrophone() {
    // TODO: تنفيذ كتم المايك
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم كتم المايك",
      message: "تم كتم مايك ${widget.seatUser?.name ?? 'المستخدم'}",
      isError: false,
    );
  }

  void _unmuteMicrophone() {
    // TODO: تنفيذ تشغيل المايك
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم تشغيل المايك",
      message: "تم تشغيل مايك ${widget.seatUser?.name ?? 'المستخدم'}",
      isError: false,
    );
  }

  void _makeAdmin() {
    // TODO: تنفيذ تعيين كمدير
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم التعيين كمدير",
      message: "تم تعيين ${widget.seatUser?.name ?? 'المستخدم'} كمدير",
      isError: false,
    );
  }

  void _removeFromSeat() {
    // TODO: تنفيذ إنزال من المقعد
    Navigator.pop(context);
    QuickHelp.showAppNotificationAdvanced(
      context: context,
      title: "تم الإنزال من المقعد",
      message: "تم إنزال ${widget.seatUser?.name ?? 'المستخدم'} من المقعد",
      isError: false,
    );
  }

  void _kickFromRoom() {
    // TODO: تنفيذ طرد من الغرفة
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kPrimaryColor,
        title: TextWithTap(
          "تأكيد الطرد",
          color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
        content: TextWithTap(
          "هل أنت متأكد من طرد ${widget.seatUser?.name ?? 'المستخدم'} من الغرفة؟",
          color: Colors.white.withOpacity(0.8),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: TextWithTap(
              "إلغاء",
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                title: "تم الطرد",
                message: "تم طرد ${widget.seatUser?.name ?? 'المستخدم'} من الغرفة",
                isError: false,
              );
            },
            child: TextWithTap(
              "طرد",
              color: Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

