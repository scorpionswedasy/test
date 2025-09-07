import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../../../live_audio_room_manager.dart';

class RoomSeatService {
  int seatCount = 8;
  int hostSeatIndex = 0;
  late List<ZegoLiveAudioRoomSeat> seatList;
  bool isBatchOperation = false;

  // Notifier لتتبع عدد المقاعد
  final ValueNotifier<int> seatCountNotifier = ValueNotifier<int>(8);

  // ✅ إضافة متغيرات للتحكم في التحديث وتجنب التكرار
  bool _isUpdating = false;
  String? _lastUpdateId;
  Timer? _debounceTimer;

  List<StreamSubscription<dynamic>> subscriptions = [];

  RoomSeatService() {
    // تهيئة قائمة المقاعد بالعدد الافتراضي
    _initializeSeats(seatCount);
  }

  // دالة داخلية لتهيئة المقاعد
  void _initializeSeats(int count) {
    seatList = List.generate(count, (index) => ZegoLiveAudioRoomSeat(index));
  }

  // ✅ دالة محسنة لتحديث عدد المقاعد مع منع التحديث المكرر
  void updateSeatCount(int newCount, {String? updateId, bool isFromRemote = false}) {
    // تجنب التحديث المكرر
    if (_isUpdating || (updateId != null && updateId == _lastUpdateId)) {
      if (kDebugMode) {
        print("RoomSeatService: تم تجاهل التحديث المكرر. ID: $updateId");
      }
      return;
    }

    // إلغاء أي تحديث معلق
    _debounceTimer?.cancel();

    // تأخير قصير لتجميع التحديثات المتتالية
    _debounceTimer = Timer(Duration(milliseconds: 100), () {
      _performSeatCountUpdate(newCount, updateId: updateId, isFromRemote: isFromRemote);
    });
  }

  // ✅ تنفيذ التحديث الفعلي مع الحماية
  void _performSeatCountUpdate(int newCount, {String? updateId, bool isFromRemote = false}) {
    if (newCount == seatCount) {
      if (kDebugMode) {
        print("RoomSeatService: عدد المقاعد لم يتغير: $newCount");
      }
      return;
    }

    _isUpdating = true;
    _lastUpdateId = updateId;

    try {
      final oldCount = seatCount;

      if (kDebugMode) {
        print("RoomSeatService: تحديث عدد المقاعد من $oldCount إلى $newCount");
      }

      // حفظ المستخدمين الحاليين في المقاعد
      final oldSeatList = List<ZegoLiveAudioRoomSeat>.from(seatList);

      // تحديث العدد
      seatCount = newCount;
      seatCountNotifier.value = newCount;

      // إعادة إنشاء قائمة المقاعد بالعدد الجديد
      _initializeSeats(seatCount);

      // نسخ المستخدمين الموجودين إلى المقاعد الجديدة
      for (int i = 0; i < oldSeatList.length && i < seatList.length; i++) {
        seatList[i].currentUser.value = oldSeatList[i].currentUser.value;
        seatList[i].lastUser.value = oldSeatList[i].lastUser.value;
      }

      // إذا قل عدد المقاعد، إزالة المستخدمين من المقاعد المحذوفة
      if (newCount < oldSeatList.length) {
        for (int i = newCount; i < oldSeatList.length; i++) {
          if (oldSeatList[i].currentUser.value != null) {
            _clearSeat(i, oldSeatList[i]);
          }
        }
      }

      // إرسال إشعار للواجهة إذا لم يكن التحديث من مصدر خارجي
      if (!isFromRemote) {
        _notifySeatsChanged(updateId);
      }

      if (kDebugMode) {
        print("RoomSeatService: تم تحديث المقاعد بنجاح إلى $newCount");
      }

    } catch (e) {
      if (kDebugMode) {
        print("RoomSeatService: خطأ في تحديث عدد المقاعد: $e");
      }
    } finally {
      // تأخير قصير قبل السماح بتحديثات جديدة
      Future.delayed(Duration(milliseconds: 200), () {
        _isUpdating = false;
      });
    }
  }

  // ✅ دالة محسنة لإخلاء المقعد
  void _clearSeat(int seatIndex, ZegoLiveAudioRoomSeat seat) {
    if (seat.currentUser.value != null) {
      final userID = seat.currentUser.value!.userID;

      // إخلاء المقعد
      seat.currentUser.value = null;

      // إزالة من خصائص الغرفة
      ZEGOSDKManager().zimService.deleteRoomAttributes([seatIndex.toString()]);

      if (kDebugMode) {
        print("RoomSeatService: تم إخلاء المقعد $seatIndex للمستخدم $userID");
      }
    }
  }

  // ✅ دالة محسنة للإعلام بتغيير المقاعد
  void _notifySeatsChanged(String? updateId) {
    // إرسال أمر إلى جميع المستخدمين في الغرفة لتحديث عدد المقاعد
    final commandMap = {
      'room_command_type': 'seat_count_changed',
      'new_seat_count': seatCount,
      'update_id': updateId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      'timestamp': DateTime.now().millisecondsSinceEpoch,
    };

    ZEGOSDKManager().zimService.sendRoomCommand(jsonEncode(commandMap));

    if (kDebugMode) {
      print("RoomSeatService: تم إرسال إشعار تحديث المقاعد: $seatCount");
    }
  }

  void initWithConfig(ZegoLiveAudioRoomRole role) {
    final expressService = ZEGOSDKManager().expressService;
    final zimService = ZEGOSDKManager().zimService;
    subscriptions.addAll([
      expressService.roomUserListUpdateStreamCtrl.stream.listen(onRoomUserListUpdate),
      zimService.roomAttributeUpdateStreamCtrl.stream.listen(onRoomAttributeUpdate),
      zimService.roomAttributeBatchUpdatedStreamCtrl.stream.listen(onRoomAttributeBatchUpdate),
      // استمع لأوامر الغرفة لتحديثات عدد المقاعد
      zimService.onRoomCommandReceivedEventStreamCtrl.stream.listen(onRoomCommandReceived)
    ]);
  }

  // ✅ معالجة محسنة لأوامر الغرفة
  void onRoomCommandReceived(OnRoomCommandReceivedEvent event) {
    try {
      final Map<String, dynamic> messageMap = jsonDecode(event.command);
      final commandType = messageMap['room_command_type'];

      if (commandType == 'seat_count_changed') {
        final newCount = messageMap['new_seat_count'];
        final updateId = messageMap['update_id'];

        if (kDebugMode) {
          print("RoomSeatService: استلام أمر تحديث المقاعد: $newCount, ID: $updateId");
        }

        // تحديث عدد المقاعد مع تمرير معرف التحديث
        updateSeatCount(newCount, updateId: updateId, isFromRemote: true);
      }
    } catch (e) {
      if (kDebugMode) {
        print("RoomSeatService: خطأ في معالجة أمر الغرفة: $e");
      }
    }
  }

  // ✅ تحسين دالة takeSeat مع التحقق من النطاق
  Future<ZIMRoomAttributesOperatedCallResult?> takeSeat(int seatIndex, {bool? isForce}) async {
    if (seatIndex >= seatCount) {
      if (kDebugMode) {
        print("RoomSeatService: فهرس المقعد $seatIndex خارج النطاق (الحد الأقصى: ${seatCount - 1})");
      }
      return null;
    }

    final currentUserID = ZEGOSDKManager().currentUser!.userID;
    final attributes = {seatIndex.toString(): currentUserID};
    final result = await ZEGOSDKManager().zimService.setRoomAttributes(
      attributes,
      isForce: isForce ?? false,
      isUpdateOwner: true,
      isDeleteAfterOwnerLeft: true,
    );

    if (result != null && !result.errorKeys.contains(seatIndex.toString())) {
      for (final element in seatList) {
        if (element.seatIndex == seatIndex) {
          ZEGOSDKManager()
              .zimService
              .roomRequestMapNoti
              .removeWhere((String k, RoomRequest v) => v.senderID == currentUserID);
          element.currentUser.value = ZEGOSDKManager().currentUser;
          break;
        }
      }
    }
    return result;
  }

  // ✅ تحسين دالة switchSeat مع التحقق من النطاق
  Future<ZIMRoomAttributesBatchOperatedResult?> switchSeat(int fromSeatIndex, int toSeatIndex) async {
    if (fromSeatIndex >= seatCount || toSeatIndex >= seatCount) {
      if (kDebugMode) {
        print("RoomSeatService: فهرس المقعد خارج النطاق (من: $fromSeatIndex, إلى: $toSeatIndex, الحد الأقصى: ${seatCount - 1})");
      }
      return null;
    }

    if (!isBatchOperation) {
      ZEGOSDKManager().zimService.beginRoomAttributesBatchOperation(
        isForce: false,
        isUpdateOwner: true,
        isDeleteAfterOwnerLeft: true,
      );
      isBatchOperation = true;
      takeSeat(toSeatIndex);
      leaveSeat(fromSeatIndex);
      final result = await ZEGOSDKManager().zimService.endRoomPropertiesBatchOperation();
      isBatchOperation = false;
      return result;
    }
    return null;
  }

  // ✅ تحسين دالة leaveSeat مع التحقق من النطاق
  Future<ZIMRoomAttributesOperatedCallResult?> leaveSeat(int seatIndex) async {
    if (seatIndex >= seatCount) {
      if (kDebugMode) {
        print("RoomSeatService: فهرس المقعد $seatIndex خارج النطاق (الحد الأقصى: ${seatCount - 1})");
      }
      return null;
    }

    final result = await ZEGOSDKManager().zimService.deleteRoomAttributes([seatIndex.toString()]);
    if (result != null && result.errorKeys.contains(seatIndex.toString())) {
      for (final element in seatList) {
        if (element.seatIndex == seatIndex) {
          element.currentUser.value = null;
        }
      }
    }
    return result;
  }

  Future<ZIMRoomAttributesOperatedCallResult?> removeSpeakerFromSeat(String userID) async {
    for (final seat in seatList) {
      if (seat.currentUser.value?.userID == userID) {
        final result = await leaveSeat(seat.seatIndex);
        return result;
      }
    }
    return null;
  }

  // ✅ تحسين دالة unInit
  void unInit() {
    _debounceTimer?.cancel();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    subscriptions.clear();

    if (kDebugMode) {
      print("RoomSeatService: تم إلغاء تهيئة الخدمة");
    }
  }

  // ✅ تحسين دالة clear
  void clear() {
    _debounceTimer?.cancel();
    _isUpdating = false;
    _lastUpdateId = null;

    seatList.clear();
    isBatchOperation = false;
    unInit();

    if (kDebugMode) {
      print("RoomSeatService: تم مسح جميع البيانات");
    }
  }

  void onRoomUserListUpdate(ZegoRoomUserListUpdateEvent event) {
    if (event.updateType == ZegoUpdateType.Add) {
      final userIDList = <String>[];
      for (final element in event.userList) {
        userIDList.add(element.userID);
        ZEGOSDKManager().zimService.roomAttributesMap.forEach((key, value) {
          if (element.userID == value) {
            for (final seat in seatList) {
              if (seat.seatIndex.toString() == key) {
                seat.currentUser.value = ZEGOSDKManager().getUser(value);
                break;
              }
            }
          }
        });
      }
    } else {
      // empty seat
    }
  }

  void onRoomAttributeBatchUpdate(ZIMServiceRoomAttributeBatchUpdatedEvent event) {
    event.updateInfos.forEach(_onRoomAttributeUpdate);
  }

  void onRoomAttributeUpdate(ZIMServiceRoomAttributeUpdateEvent event) {
    _onRoomAttributeUpdate(event.updateInfo);
  }

  void _onRoomAttributeUpdate(ZIMRoomAttributesUpdateInfo updateInfo) {
    if (updateInfo.action == ZIMRoomAttributesUpdateAction.set) {
      updateInfo.roomAttributes.forEach((key, value) {
        for (final element in seatList) {
          if (element.seatIndex.toString() == key) {
            if (value == ZEGOSDKManager().currentUser!.userID) {
              element.currentUser.value = ZEGOSDKManager().currentUser;
            } else {
              ZIMService().roomRequestMapNoti.removeWhere((String k, RoomRequest v) => v.senderID == value);
              element.currentUser.value = ZEGOSDKManager().getUser(value);
              updateCurrentUserRole();
            }
          }
        }
      });
    } else {
      updateInfo.roomAttributes.forEach((key, value) {
        for (final element in seatList) {
          if (element.seatIndex.toString() == key) {
            element.currentUser.value = null;
            updateCurrentUserRole();
          }
        }
      });
    }
  }

  void updateCurrentUserRole() {
    var isFindSelf = false;
    for (final seat in seatList) {
      if (seat.currentUser.value != null && seat.currentUser.value?.userID == ZEGOSDKManager().currentUser!.userID) {
        isFindSelf = true;
        break;
      }
    }
    final liveAudioRoomManager = ZegoLiveAudioRoomManager();
    if (isFindSelf) {
      if (liveAudioRoomManager.roleNoti.value != ZegoLiveAudioRoomRole.host) {
        liveAudioRoomManager.roleNoti.value = ZegoLiveAudioRoomRole.speaker;
      }
    } else {
      liveAudioRoomManager.roleNoti.value = ZegoLiveAudioRoomRole.audience;
      ZEGOSDKManager().expressService.stopPublishingStream();
    }
  }
}

