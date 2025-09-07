// ignore_for_file: must_be_immutable

import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../models/LiveStreamingModel.dart';
import '../../../../models/UserModel.dart';
import '../../components/components.dart';
import '../../live_audio_room_manager.dart';
import '../../utils/zegocloud_token.dart';
import '../../zego_sdk_key_center.dart';

part 'audio_room_gift.dart';

class AudioRoomPage extends StatefulWidget {
  UserModel? currentUser;
  SharedPreferences? preferences;
  AudioRoomPage({
    this.currentUser,
    this.preferences,
    super.key,
    required this.roomID,
    required this.role,
  });

  final String roomID;
  final ZegoLiveAudioRoomRole role;

  @override
  State<AudioRoomPage> createState() => AudioRoomPageState();
}

class AudioRoomPageState extends State<AudioRoomPage> {
  List<StreamSubscription> subscriptions = [];
  String? currentRequestID;
  ValueNotifier<bool> isApplyStateNoti = ValueNotifier(false);
  // استخدام notifier محلي لعدد المقاعد
  final ValueNotifier<int> seatCountNotifier = ValueNotifier<int>(8);

  @override
  void initState() {
    super.initState();
    final zimService = ZEGOSDKManager().zimService;
    final expressService = ZEGOSDKManager().expressService;

    // تهيئة عدد المقاعد من طول قائمة المقاعد الحالية
    seatCountNotifier.value = ZegoLiveAudioRoomManager.instance.seatList.length;

    subscriptions.addAll([
      expressService.roomStateChangedStreamCtrl.stream.listen(onExpressRoomStateChanged),
      zimService.roomStateChangedStreamCtrl.stream.listen(onZIMRoomStateChanged),
      zimService.connectionStateStreamCtrl.stream.listen(onZIMConnectionStateChanged),
      zimService.onInComingRoomRequestStreamCtrl.stream.listen(onInComingRoomRequest),
      zimService.onOutgoingRoomRequestAcceptedStreamCtrl.stream.listen(onOutgoingRoomRequestAccepted),
      zimService.onOutgoingRoomRequestRejectedStreamCtrl.stream.listen(onOutgoingRoomRequestRejected),
      // الاستماع لأمر الغرفة لتحديث عدد المقاعد
      zimService.onRoomCommandReceivedEventStreamCtrl.stream.listen(onRoomCommandReceived),
    ]);

    loginRoom();
    initGift();
  }

  void loginRoom() {
    final token = kIsWeb
        ? ZegoTokenUtils.generateToken(
        SDKKeyCenter.appID, SDKKeyCenter.serverSecret, ZEGOSDKManager().currentUser!.userID)
        : null;
    ZegoLiveAudioRoomManager.instance.loginRoom(widget.roomID, widget.role, token: token).then((result) {
      if (result.errorCode == 0) {
        hostTakeSeat();
      } else {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("room_failed".tr()+' error: ${result.errorCode}')));
      }
    });
  }

  void onRoomCommandReceived(OnRoomCommandReceivedEvent event) {
    try {
      final Map<String, dynamic> messageMap = jsonDecode(event.command);
      if (messageMap['room_command_type'] == 'seat_count_changed') {
        final newCount = messageMap['new_seat_count'];
        if (mounted) {
          setState(() {
            seatCountNotifier.value = newCount;
          });
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error processing room command: $e");
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    uninitGift();
    ZegoLiveAudioRoomManager.instance.logoutRoom();
    for (final subscription in subscriptions) {
      subscription.cancel();
    }
    seatCountNotifier.dispose();
  }

  Future<void> hostTakeSeat() async {
    if (widget.role == ZegoLiveAudioRoomRole.host) {
      await ZegoLiveAudioRoomManager.instance.setSelfHost();
      await ZegoLiveAudioRoomManager.instance.takeSeat(0, isForce: true).then((result) {
        if (mounted && ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("failed_take_seat".tr(namedArgs: {"error":"$result"}))));
        }
      }).catchError((error) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("failed_take_seat".tr(namedArgs: {"error":"$error"}))));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Scaffold(
        body: Stack(
          children: [
            backgroundImage(),
            Positioned(top: 30, right: 20, child: leaveButton()),
            Positioned(top: 100, child: seatListView()),
            Positioned(bottom: 20, left: 0, right: 0, child: bottomView()),
            giftForeground()
          ],
        ),
      ),
    );
  }

  Widget backgroundImage() {
    return Image.asset('assets/images/audio_bg_start.png', width: double.infinity, height: double.infinity, fit: BoxFit.fill);
  }

  Widget roomTitle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('LiveAudioRoom', style: Theme.of(context).textTheme.titleMedium),
            Text('Room ID: ${widget.roomID}'),
            ValueListenableBuilder(
              valueListenable: ZegoLiveAudioRoomManager.instance.hostUserNoti,
              builder: (BuildContext context, ZegoSDKUser? host, Widget? child) {
                return host != null ? Text('Host: ${host.userName} (id: ${host.userID})') : const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget bottomView() {
    return ValueListenableBuilder<ZegoLiveAudioRoomRole>(
        valueListenable: ZegoLiveAudioRoomManager.instance.roleNoti,
        builder: (context, currentRole, _) {
          if (currentRole == ZegoLiveAudioRoomRole.host) {
            return Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                lockSeatButton(),
                const SizedBox(width: 10),
                requestMemberButton(),
                const SizedBox(width: 10),
                micorphoneButton(),
                const SizedBox(width: 20),
              ],
            );
          } else if (currentRole == ZegoLiveAudioRoomRole.speaker) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  giftButton(),
                  const SizedBox(width: 10),
                  leaveSeatButton(),
                  const SizedBox(width: 10),
                  micorphoneButton(),
                ],
              ),
            );
          } else {
            return Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  giftButton(),
                  const SizedBox(width: 10),
                  requestTakeSeatButton(),
                ],
              ),
            );
          }
        });
  }

  Widget lockSeatButton() {
    return ElevatedButton(onPressed: () => ZegoLiveAudioRoomManager.instance.lockSeat(), child: const Icon(Icons.lock));
  }

  Widget requestMemberButton() {
    return ValueListenableBuilder(
      valueListenable: ZEGOSDKManager().zimService.roomRequestMapNoti,
      builder: (context, Map<String, dynamic> requestMap, child) {
        final requestList = requestMap.values.toList();
        return Badge(smallSize: 12, isLabelVisible: requestList.isNotEmpty, child: child);
      },
      child: ElevatedButton(
        onPressed: () => RoomRequestListView.showBasicModalBottomSheet(context),
        child: const Icon(Icons.link),
      ),
    );
  }

  Widget micorphoneButton() {
    return ValueListenableBuilder(
      valueListenable: ZEGOSDKManager().currentUser!.isMicOnNotifier,
      builder: (context, bool micIsOn, child) {
        return ElevatedButton(
          onPressed: () => ZEGOSDKManager().expressService.turnMicrophoneOn(!micIsOn),
          child: micIsOn ? const Icon(Icons.mic) : const Icon(Icons.mic_off),
        );
      },
    );
  }

  Widget requestTakeSeatButton() {
    return ElevatedButton(
      onPressed: () {
        if (!isApplyStateNoti.value) {
          final senderMap = {'room_request_type': RoomRequestType.audienceApplyToBecomeCoHost};
          ZEGOSDKManager()
              .zimService
              .sendRoomRequest(ZegoLiveAudioRoomManager.instance.hostUserNoti.value?.userID ?? '', jsonEncode(senderMap))
              .then((value) {
            isApplyStateNoti.value = true;
            currentRequestID = value.requestID;
          });
        } else {
          if (currentRequestID != null) {
            ZEGOSDKManager().zimService.cancelRoomRequest(currentRequestID ?? '').then((value) {
              isApplyStateNoti.value = false;
              currentRequestID = null;
            });
          }
        }
      },
      child: ValueListenableBuilder<bool>(
        valueListenable: isApplyStateNoti,
        builder: (context, isApply, _) {
          return Text(isApply ? 'Cancel Application' : 'Apply Take Seat');
        },
      ),
    );
  }

  Widget leaveSeatButton() {
    return ElevatedButton(
        onPressed: () {
          for (final element in ZegoLiveAudioRoomManager.instance.seatList) {
            if (element.currentUser.value?.userID == ZEGOSDKManager().currentUser!.userID) {
              ZegoLiveAudioRoomManager.instance.leaveSeat(element.seatIndex).then((value) {
                ZegoLiveAudioRoomManager.instance.roleNoti.value = ZegoLiveAudioRoomRole.audience;
                isApplyStateNoti.value = false;
                ZEGOSDKManager().expressService.stopPublishingStream();
              });
            }
          }
        },
        child: const Text('Leave Seat'));
  }

  Widget leaveButton() {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context);
      },
      child: SizedBox(
        width: 40,
        height: 40,
        child: Image.asset('assets/icons/top_close.png'),
      ),
    );
  }

  Widget seatListView() {
    return ValueListenableBuilder<int>(
      valueListenable: seatCountNotifier,
      builder: (context, seatCount, _) {
        return SizedBox(
          width: MediaQuery.of(context).size.width,
          height: 300,
          child: GridView.count(
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisCount: 4,
            children: List.generate(seatCount, (seatIndex) {
              if (seatIndex >= ZegoLiveAudioRoomManager.instance.seatList.length) {
                return Container();
              }

              return ZegoSeatItemView(
                seatIndex: seatIndex,
                onPressed: () {
                  final seat = ZegoLiveAudioRoomManager.instance.seatList[seatIndex];
                  if (seatIndex == 0) {
                    return;
                  }
                  if (seat.currentUser.value == null) {
                    if (ZegoLiveAudioRoomManager.instance.roleNoti.value == ZegoLiveAudioRoomRole.audience) {
                      ZegoLiveAudioRoomManager.instance.takeSeat(seatIndex).then((result) {
                        if (mounted &&
                            ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text('take seat failed: $result')));
                        }
                      }).catchError((error) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: $error')));
                      });
                    } else if (ZegoLiveAudioRoomManager.instance.roleNoti.value == ZegoLiveAudioRoomRole.speaker) {
                      if (getLocalUserSeatIndex() != -1) {
                        ZegoLiveAudioRoomManager.instance.switchSeat(getLocalUserSeatIndex(), seatIndex);
                      }
                    }
                  } else {
                    if (widget.role == ZegoLiveAudioRoomRole.host &&
                        (ZEGOSDKManager().currentUser!.userID != seat.currentUser.value?.userID)) {
                      showRemoveSpeakerAndKitOutSheet(context, seat.currentUser.value!);
                    }
                  }
                },
              );
            }),
          ),
        );
      },
    );
  }

  void showRemoveSpeakerAndKitOutSheet(BuildContext context, ZegoSDKUser targetUser) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              title: const Text('remove speaker', textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager.instance.removeSpeakerFromSeat(targetUser.userID);
              },
            ),
            ListTile(
              title: Text(targetUser.isMicOnNotifier.value ? 'mute speaker' : 'unMute speaker',
                  textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager.instance.muteSpeaker(targetUser.userID, targetUser.isMicOnNotifier.value);
              },
            ),
            ListTile(
              title: const Text('kick out user', textAlign: TextAlign.center),
              onTap: () {
                Navigator.pop(context);
                ZegoLiveAudioRoomManager.instance.kickOutRoom(targetUser.userID);
              },
            ),
          ],
        );
      },
    );
  }

  int getLocalUserSeatIndex() {
    for (final element in ZegoLiveAudioRoomManager.instance.seatList) {
      if (element.currentUser.value?.userID == ZEGOSDKManager().currentUser!.userID) {
        return element.seatIndex;
      }
    }
    return -1;
  }

  // zim listener
  void onInComingRoomRequest(OnInComingRoomRequestReceivedEvent event) {}

  void onInComingRoomRequestCancelled(OnInComingRoomRequestCancelledEvent event) {}

  void onInComingRoomRequestTimeOut() {}

  void onOutgoingRoomRequestAccepted(OnOutgoingRoomRequestAcceptedEvent event) {
    isApplyStateNoti.value = false;
    for (final seat in ZegoLiveAudioRoomManager.instance.seatList) {
      if (seat.currentUser.value == null) {
        ZegoLiveAudioRoomManager.instance.takeSeat(seat.seatIndex).then((result) {
          if (mounted && ((result == null) || result.errorKeys.contains(ZEGOSDKManager().currentUser!.userID))) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: $result')));
          }
        }).catchError((error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('take seat failed: $error')));
        });

        break;
      }
    }
  }

  void onOutgoingRoomRequestRejected(OnOutgoingRoomRequestRejectedEvent event) {
    isApplyStateNoti.value = false;
    currentRequestID = null;
  }

  void onExpressRoomStateChanged(ZegoRoomStateEvent event) {
    debugPrint('AudioRoomPage:onExpressRoomStateChanged: $event');
    if (event.errorCode != 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text('onExpressRoomStateChanged: reason:${event.reason.name}, errorCode:${event.errorCode}'),
        ),
      );
    }

    if ((event.reason == ZegoRoomStateChangedReason.KickOut) ||
        (event.reason == ZegoRoomStateChangedReason.ReconnectFailed) ||
        (event.reason == ZegoRoomStateChangedReason.LoginFailed)) {
      Navigator.pop(context);
    }
  }

  void onZIMRoomStateChanged(ZIMServiceRoomStateChangedEvent event) {
    debugPrint('AudioRoomPage:onZIMRoomStateChanged: $event');
    if ((event.event != ZIMRoomEvent.success) && (event.state != ZIMRoomState.connected)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          duration: const Duration(milliseconds: 1000),
          content: Text('onZIMRoomStateChanged: $event'),
        ),
      );
    }
    if (event.state == ZIMRoomState.disconnected) {
      Navigator.pop(context);
    }
  }

  void onZIMConnectionStateChanged(ZIMServiceConnectionStateChangedEvent event) {
    debugPrint('AudioRoomPage:onZIMConnectionStateChanged: $event');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(milliseconds: 1000),
        content: Text('onZIMConnectionStateChanged: $event'),
      ),
    );
    if (event.state == ZIMConnectionState.disconnected) {
      Navigator.pop(context);
    }
  }
}