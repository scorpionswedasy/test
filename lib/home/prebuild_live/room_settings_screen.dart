import 'dart:convert';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import '../streaming/live_audio_room_manager.dart';
import '../streaming/zego_sdk_manager.dart';
import '../../helpers/quick_help.dart';
import '../../models/LiveStreamingModel.dart';
import '../../models/UserModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';

class RoomSettingsScreen extends StatefulWidget {
  final UserModel currentUser;
  final LiveStreamingModel liveStreaming;
  final Function(int)? onSeatsUpdated;

  const RoomSettingsScreen({
    Key? key,
    required this.currentUser,
    required this.liveStreaming,
    this.onSeatsUpdated,
  }) : super(key: key);

  @override
  State<RoomSettingsScreen> createState() => _RoomSettingsScreenState();
}

class _RoomSettingsScreenState extends State<RoomSettingsScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  int selectedSeats = 8;
  bool isPrivateRoom = false;
  bool allowGifts = true;
  bool allowComments = true;
  bool autoMuteNewUsers = false;
  String roomQuality = 'high';

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );

    _slideAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    ));

    // ✅ تهيئة القيم الحالية بطريقة آمنة
    selectedSeats = widget.liveStreaming.getNumberOfChairs ?? 8;
    isPrivateRoom = widget.liveStreaming.getPrivate ?? false;

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
        return Transform.translate(
          offset: Offset(0, _slideAnimation.value * MediaQuery.of(context).size.height),
          child: Opacity(
            opacity: _fadeAnimation.value,
            child: Scaffold(
              backgroundColor: Colors.black.withOpacity(0.5),
              body: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  color: Colors.transparent,
                  child: GestureDetector(
                    onTap: () {}, // منع إغلاق الشاشة عند النقر على المحتوى
                    child: DraggableScrollableSheet(
                      initialChildSize: 0.6,
                      minChildSize: 0.4,
                      maxChildSize: 0.8,
                      builder: (context, scrollController) {
                        return Container(
                          decoration: BoxDecoration(
                            color: QuickHelp.isDarkMode(context)
                                ? kContentColorLightTheme
                                : Colors.white,
                            borderRadius: BorderRadius.only(
                              topLeft: Radius.circular(25),
                              topRight: Radius.circular(25),
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: Offset(0, -5),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              _buildHeader(),
                              Expanded(
                                child: SingleChildScrollView(
                                  controller: scrollController,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    child: Column(
                                      children: [
                                        _buildSeatsSection(),
                                        SizedBox(height: 25),
                                        _buildPrivacySection(),
                                        SizedBox(height: 30),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              _buildActionButtons(),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ✅ رأس الشاشة مع العنوان والمقبض
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          // مقبض السحب
          Container(
            width: 50,
            height: 5,
            decoration: BoxDecoration(
              color: kGrayColor,
              borderRadius: BorderRadius.circular(50),
            ),
          ),
          SizedBox(height: 15),
          // العنوان مع الأيقونة
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: kPrimaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: SvgPicture.asset(
                  "assets/svg/ic_settings.svg",
                  width: 24,
                  height: 24,
                  color: kPrimaryColor,
                ),
              ),
              SizedBox(width: 12),
              TextWithTap(
                "إعدادات الغرفة",
                fontWeight: FontWeight.bold,
                fontSize: 20,
                color: QuickHelp.isDarkMode(context) ? Colors.white : Colors.black,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ✅ قسم إعدادات المقاعد
  Widget _buildSeatsSection() {
    return _buildSection(
      title: "عدد المقاعد",
      icon: Icons.event_seat,
      iconColor: Colors.blue,
      child: Column(
        children: [
          SizedBox(height: 15),
          Text(
            "اختر عدد المقاعد في الغرفة",
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
          SizedBox(height: 20),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [2, 8, 16, 20].map((number) {
              return _buildSeatOption(number);
            }).toList(),
          ),
        ],
      ),
    );
  }

  // ✅ قسم إعدادات الخصوصية
  Widget _buildPrivacySection() {
    return _buildSection(
      title: "الخصوصية والأمان",
      icon: Icons.security,
      iconColor: Colors.green,
      child: Column(
        children: [
          _buildSwitchTile(
            title: "غرفة خاصة",
            subtitle: "تتطلب دعوة للانضمام",
            value: isPrivateRoom,
            onChanged: (value) {
              setState(() {
                isPrivateRoom = value;
              });
            },
            icon: Icons.lock,
          ),
        ],
      ),
    );
  }

  // ✅ بناء قسم عام
  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: QuickHelp.isDarkMode(context)
            ? Colors.grey[800]?.withOpacity(0.3)
            : Colors.grey[50],
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    color: iconColor,
                    size: 20,
                  ),
                ),
                SizedBox(width: 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: QuickHelp.isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
              ],
            ),
            child,
          ],
        ),
      ),
    );
  }

  // ✅ خيار المقاعد
  Widget _buildSeatOption(int number) {
    final isSelected = selectedSeats == number;
    return GestureDetector(
      onTap: () {
        setState(() {
          selectedSeats = number;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        decoration: BoxDecoration(
          color: isSelected ? kPrimaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? kPrimaryColor : Colors.grey[400]!,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Text(
              "$number",
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[700],
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            Text(
              "مقعد",
              style: TextStyle(
                color: isSelected ? Colors.white70 : Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ✅ مفتاح التبديل
  Widget _buildSwitchTile({
    required String title,
    required String subtitle,
    required bool value,
    required Function(bool) onChanged,
    required IconData icon,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 20,
              color: Colors.grey[600],
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: QuickHelp.isDarkMode(context) ? Colors.white : Colors.black,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: kPrimaryColor,
          ),
        ],
      ),
    );
  }

  // ✅ أزرار الإجراءات
  Widget _buildActionButtons() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: QuickHelp.isDarkMode(context)
            ? kContentColorLightTheme
            : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: ContainerCorner(
              color: Colors.grey[300],
              borderRadius: 12,
              height: 50,
              onTap: () => Navigator.pop(context),
              child: Center(
                child: TextWithTap(
                  "إلغاء",
                  color: Colors.grey[700],
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          SizedBox(width: 15),
          Expanded(
            flex: 2,
            child: ContainerCorner(
              color: kPrimaryColor,
              borderRadius: 12,
              height: 50,
              onTap: _saveSettings,
              child: Center(
                child: TextWithTap(
                  "حفظ الإعدادات",
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ✅ حفظ الإعدادات مع إصلاح مشكلة null
  void _saveSettings() async {
    QuickHelp.showLoadingDialog(context);

    try {
      // ✅ التأكد من أن النموذج ليس null
      if (widget.liveStreaming == null) {
        throw Exception("بيانات الغرفة غير متوفرة");
      }

      // تحديث عدد المقاعد إذا تغير
      if (selectedSeats != widget.liveStreaming.getNumberOfChairs) {
        await _updateSeatsNumber(selectedSeats);
      }

      // ✅ تحديث إعدادات الخصوصية بطريقة آمنة
      if (isPrivateRoom != (widget.liveStreaming.getPrivate ?? false)) {
        widget.liveStreaming.setPrivate = isPrivateRoom;
        ParseResponse response = await widget.liveStreaming.save();

        if (!response.success) {
          throw Exception("فشل في حفظ إعدادات الخصوصية: ${response.error?.message}");
        }
      }

      QuickHelp.hideLoadingDialog(context);

      // إشعار بنجاح الحفظ
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('تم حفظ الإعدادات بنجاح'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // إغلاق الشاشة
      Navigator.pop(context);

    } catch (e) {
      QuickHelp.hideLoadingDialog(context);

      // عرض رسالة خطأ واضحة
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('فشل في حفظ الإعدادات: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );

      debugPrint('خطأ في حفظ الإعدادات: $e');
    }
  }

  // ✅ تحديث عدد المقاعد مع معالجة أفضل للأخطاء
  Future<void> _updateSeatsNumber(int newNumber) async {
    try {
      // ✅ التأكد من صحة البيانات
      if (widget.liveStreaming == null) {
        throw Exception("بيانات الغرفة غير متوفرة");
      }

      if (widget.currentUser == null || widget.currentUser.objectId == null) {
        throw Exception("بيانات المستخدم غير متوفرة");
      }

      // تحديث النموذج المحلي
      widget.liveStreaming.setNumberOfChairsDynamic = newNumber;

      // حفظ في قاعدة البيانات
      ParseResponse response = await widget.liveStreaming.save();

      if (response.success) {
        // تحديث مدير غرفة الصوت Zego
        try {
          ZegoLiveAudioRoomManager().updateSeatCount(newNumber);
        } catch (e) {
          debugPrint('تحذير: فشل في تحديث Zego: $e');
          // لا نرمي خطأ هنا لأن الحفظ في قاعدة البيانات نجح
        }

        // إرسال أمر إلى جميع المستخدمين الآخرين
        try {
          final commandMap = {
            'room_command_type': LiveStreamingModel.seatCountChanged,
            'new_seat_count': newNumber,
            'sender_id': widget.currentUser.objectId,
          };

          await ZEGOSDKManager().zimService.sendRoomCommand(jsonEncode(commandMap));
        } catch (e) {
          debugPrint('تحذير: فشل في إرسال الأمر: $e');
          // لا نرمي خطأ هنا لأن الحفظ الأساسي نجح
        }

        // استدعاء callback إذا كان موجوداً
        widget.onSeatsUpdated?.call(newNumber);

      } else {
        throw Exception("فشل في حفظ التحديثات في قاعدة البيانات: ${response.error?.message}");
      }
    } catch (e) {
      throw Exception("خطأ في تحديث عدد المقاعد: ${e.toString()}");
    }
  }
}

