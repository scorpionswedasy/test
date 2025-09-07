// ignore_for_file: must_be_immutable, deprecated_member_use

import 'dart:io';
import 'dart:typed_data';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:mime/mime.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flamingo/helpers/quick_help.dart';
import 'package:flamingo/home/feed/video_player_screen.dart';
import 'package:flamingo/home/home_screen.dart';
import 'package:flamingo/models/PostsModel.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

import '../../app/setup.dart';
import '../../helpers/quick_actions.dart';
import '../../helpers/send_notifications.dart';
import '../../models/UserModel.dart';
import '../../ui/container_with_corner.dart';
import '../../ui/text_with_tap.dart';
import '../../utils/colors.dart';

import 'package:flamingo/widgets/dospace/dospace.dart' as dospace;


class CreateVideoPostScreen extends StatefulWidget {
  static String route = "/create/video/post";
  UserModel? currentUser;

  CreateVideoPostScreen({this.currentUser, Key? key}) : super(key: key);

  @override
  State<CreateVideoPostScreen> createState() => _CreateVideoPostScreenState();
}

class _CreateVideoPostScreenState extends State<CreateVideoPostScreen> {
  TextEditingController captionTextEditing = TextEditingController();
  List<UserModel> selectedUser = [];
  var selectedUserIds = [];

  int maxLength = 10;
  int friendAmount = 0;

  ParseFileBase? parseVideoFile;
  ParseFileBase? parseVideoThumbnailFile;

  List<File> selectedVideos = [];
  File? videoFile;

  int videoDuration = 120;
  int videoMegaByte = 200;

  @override
  void dispose() {
    super.dispose();
    selectedUser.clear();
    selectedUserIds.clear();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;
    return GestureDetector(
      onTap: () => QuickHelp.removeFocusOnTextField(context),
      child: Scaffold(
        appBar: AppBar(
          title: TextWithTap("create_post_screen.post_moment".tr()),
          automaticallyImplyLeading: false,
          leading: Padding(
            padding: const EdgeInsets.only(left: 10),
            child: BackButton(
              color: kGrayColor,
            ),
          ),
          centerTitle: true,
          elevation: 0.0,
          actions: [
            Padding(
              padding: const EdgeInsets.only(right: 15, top: 8, bottom: 8),
              child: TextButton(
                onPressed: () {
                  if (parseVideoFile != null) {
                    createPost();
                  } else {
                    QuickHelp.showAppNotificationAdvanced(
                      title:
                      "create_post_screen.choose_video_advise_title".tr(),
                      message:
                      "create_post_screen.choose_video_advise_explain".tr(),
                      context: context,
                    );
                  }
                },
                child: TextWithTap(
                  "create_post_screen.post_".tr(),
                  color: Colors.blueAccent,
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.only(left: 15, right: 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: TextFormField(
                    keyboardType: TextInputType.multiline,
                    onChanged: (text) {},
                    maxLines: 5,
                    maxLength: 250,
                    controller: captionTextEditing,
                    decoration: InputDecoration(
                      hintText: "create_post_screen.say_something".tr(),
                      border: InputBorder.none,
                    ),
                  ),
                ),
                const SizedBox(
                  height: 10,
                ),
                Wrap(
                  children: [
                    Wrap(
                      children: List.generate(selectedVideos.length, (index) {
                        return Stack(
                          alignment: AlignmentDirectional.center,
                          children: [
                            GestureDetector(
                              onTap: () {
                                QuickHelp.goToNavigatorScreen(
                                  context,
                                  VideoPlayerScreen(
                                    currentUser: widget.currentUser,
                                    video: videoFile,
                                  ),
                                );
                              },
                              child: Stack(
                                children: [
                                  ContainerCorner(
                                    width: size.width / 3.5,
                                    height: size.width / 2.3,
                                    borderRadius: 7,
                                    borderWidth: 0,
                                    marginRight: 7,
                                    marginBottom: 7,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: Image.file(
                                        selectedVideos[0],
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  ContainerCorner(
                                    width: size.width / 3.5,
                                    height: size.width / 2.3,
                                    borderRadius: 7,
                                    borderWidth: 0,
                                    marginRight: 7,
                                    marginBottom: 7,
                                    color: Colors.black.withOpacity(0.5),
                                    child: Center(
                                      child: Icon(
                                        Icons.play_circle_outline,
                                        color: Colors.white.withOpacity(0.4),
                                        size: size.width / 8,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Positioned(
                              top: -3,
                              right: -10,
                              child: ContainerCorner(
                                borderRadius: 50,
                                height: 30,
                                width: 30,
                                marginTop: 4,
                                marginRight: 10,
                                color: QuickHelp.isDarkMode(context)
                                    ? Colors.white
                                    : Colors.black,
                                onTap: () {
                                  setState(() {
                                    selectedVideos.clear();
                                  });
                                },
                                child: Center(
                                  child: Icon(
                                    Icons.close,
                                    color: Colors.redAccent,
                                    weight: 999,
                                    size: 15,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                    Visibility(
                      visible: selectedVideos.length < 1,
                      child: ContainerCorner(
                        width: size.width / 3.5,
                        height: size.width / 3.5,
                        color: kGrayWhite,
                        borderRadius: 10,
                        borderWidth: 0,
                        marginRight: 7,
                        marginBottom: 7,
                        onTap: () => checkPermission(false),
                        child: Center(
                          child: Icon(
                            Icons.add,
                            color: kGrayColor,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 10, top: 10),
                  child: IconButton(
                    onPressed: () => showPeopleToMentionBottomModal(),
                    icon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextWithTap(
                          "@",
                          fontWeight: FontWeight.w700,
                        ),
                        TextWithTap(
                          "audio_chat.mention_".tr(),
                          marginLeft: 5,
                          marginRight: 10,
                        ),
                      ],
                    ),
                  ),
                ),
                if (selectedUserIds.length > 0)
                  Padding(
                    padding: const EdgeInsets.only(left: 10, top: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextWithTap(
                          "create_post_screen.one_target_user_selected".tr(
                              namedArgs: {
                                "name": selectedUser[0].getFullName!
                              }),
                          fontWeight: FontWeight.w900,
                          color: Colors.blueAccent,
                        ),
                        Visibility(
                          visible: selectedUserIds.length > 1,
                          child: TextWithTap(
                            "create_post_screen.multiple_target_users_selected"
                                .tr(namedArgs: {
                              "amount": "${selectedUserIds.length - 1}"
                            }),
                            marginLeft: 5,
                            marginRight: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  showPeopleToMentionBottomModal() {
    showModalBottomSheet(
      context: (context),
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      enableDrag: false,
      isDismissible: true,
      builder: (context) {
        return showPeopleToMention();
      },
    );
  }

  Widget showPeopleToMention() {
    Size size = MediaQuery.of(context).size;
    int? indexSelected;

    QueryBuilder<UserModel> query = QueryBuilder(UserModel.forQuery());
    query.whereContainedIn(
      UserModel.keyObjectId,
      widget.currentUser!.getFollowing!,
    );

    return ContainerCorner(
      color: Colors.black.withOpacity(0.01),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.1,
        maxChildSize: 1.0,
        builder: (_, controller) {
          return StatefulBuilder(
            builder: (context, newState) {
              return ContainerCorner(
                radiusTopRight: 25.0,
                radiusTopLeft: 25.0,
                borderWidth: 0,
                child: ContainerCorner(
                  borderWidth: 0,
                  color: QuickHelp.isDarkMode(context)
                      ? kContentColorLightTheme
                      : Colors.white,
                  child: Scaffold(
                    backgroundColor: kTransparentColor,
                    resizeToAvoidBottomInset: false,
                    appBar: AppBar(
                      backgroundColor: kTransparentColor,
                      automaticallyImplyLeading: false,
                      centerTitle: true,
                      title: TextWithTap(
                        "audio_chat.mention_".tr(),
                      ),
                      leading: BackButton(
                        color: kGrayColor,
                        onPressed: () {
                          newState(() {
                            selectedUser.clear();
                            selectedUserIds.clear();
                          });
                          setState(() {});
                          QuickHelp.goBackToPreviousPage(context);
                        },
                      ),
                      actions: [
                        TextWithTap(
                          "create_post_screen.completed_".tr(namedArgs: {
                            "amount": "${selectedUser.length}/$maxLength"
                          }),
                          color: Colors.blueAccent,
                          marginRight: 10,
                          onTap: () => QuickHelp.goBackToPreviousPage(context),
                        ),
                      ],
                    ),
                    body: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ContainerCorner(
                          height: 45,
                          color: kGrayLight,
                          width: size.width,
                          borderWidth: 0,
                          child: Center(
                            child: TextWithTap(
                              "create_post_screen.follow_each_other"
                                  .tr(namedArgs: {"amount": "$friendAmount"}),
                              color: Colors.black,
                              alignment: Alignment.centerLeft,
                              marginLeft: 15,
                              fontSize: 18,
                            ),
                          ),
                        ),
                        Expanded(
                          child: ContainerCorner(
                            child: ParseLiveListWidget<UserModel>(
                              query: query,
                              reverse: false,
                              lazyLoading: false,
                              shrinkWrap: true,
                              duration: Duration(milliseconds: 30),
                              childBuilder: (BuildContext context,
                                  ParseLiveListElementSnapshot<UserModel>
                                  snapshot) {
                                if (snapshot.hasData) {
                                  UserModel user =
                                  snapshot.loadedData as UserModel;
                                  bool isMale =
                                      user.getGender == UserModel.keyGenderMale;

                                  return Padding(
                                    padding: const EdgeInsets.only(
                                        left: 10, right: 10, bottom: 5),
                                    child: GestureDetector(
                                      onTap: () {
                                        newState(() {
                                          if (selectedUserIds
                                              .contains(user.objectId)) {
                                            for (int i = 0;
                                            i < selectedUserIds.length;
                                            i++) {
                                              if (user.objectId ==
                                                  selectedUserIds[i]) {
                                                indexSelected = i;
                                              }
                                            }

                                            selectedUser
                                                .removeAt(indexSelected!);
                                            selectedUserIds
                                                .removeAt(indexSelected!);
                                          } else {
                                            if (selectedUserIds.length <=
                                                maxLength) {
                                              selectedUser.add(user);
                                              selectedUserIds
                                                  .add(user.objectId!);
                                            }
                                          }
                                        });
                                        setState(() {});
                                      },
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: ContainerCorner(
                                              child: Row(
                                                children: [
                                                  QuickActions.avatarWidget(
                                                    user,
                                                    width: 50,
                                                    height: 50,
                                                  ),
                                                  Padding(
                                                    padding:
                                                    const EdgeInsets.only(
                                                        left: 15),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                      CrossAxisAlignment
                                                          .start,
                                                      children: [
                                                        TextWithTap(
                                                          user.getFullName!,
                                                        ),
                                                        QuickActions.getGender(
                                                          currentUser: user,
                                                          context: context,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                          selectedUserIds
                                              .contains(user.objectId)
                                              ? Icon(
                                            Icons.check_circle,
                                            color: isMale
                                                ? Colors.lightBlue
                                                : Colors.redAccent,
                                          )
                                              : Icon(
                                            Icons.radio_button_unchecked,
                                            color: isMale
                                                ? Colors.lightBlue
                                                : Colors.redAccent,
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                } else {
                                  return Center(
                                    child: CircularProgressIndicator(),
                                  );
                                }
                              },
                              queryEmptyElement: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Center(
                                    child: ContainerCorner(
                                      width: 180,
                                      child: Center(
                                        child: TextWithTap(
                                          "create_post_screen.empty_friend_to_mention"
                                              .tr(),
                                          alignment: Alignment.center,
                                          textAlign: TextAlign.center,
                                          color: kGrayColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              listLoadingElement: Center(
                                child: CircularProgressIndicator(),
                              ),
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
        },
      ),
    );
  }

  Future<void> checkPermission(bool isAvatar) async {
    /*if (QuickHelp.isAndroidPlatform()) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      bool api32 = androidInfo.version.sdkInt <= 32;

      PermissionStatus status = api32 ? await Permission.storage.status : await Permission.photos.status;
      PermissionStatus status2 = await Permission.camera.status;
      PermissionStatus status3 = await Permission.videos.status;
      print('Permission android');

      checkStatus(status, status2, status3, isAvatar);
    } else if (QuickHelp.isIOSPlatform()) {
      PermissionStatus status = await Permission.photos.status;
      PermissionStatus status2 = await Permission.camera.status;
      PermissionStatus status3 = await Permission.videos.status;
      print('Permission ios');

      checkStatus(status, status2, status3, isAvatar);
    } else {
      print('Permission other device');

      _pickVideoFile();
    }*/

    if (QuickHelp.isAndroidPlatform()) {
      DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
      AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
      int sdkInt = androidInfo.version.sdkInt;

      PermissionStatus status;
      PermissionStatus status2 = await Permission.camera.status;
      PermissionStatus status3;

      if (sdkInt >= 33) {
        // Android 13 & higher
        status = await Permission.photos.status;
        status3 = await Permission.videos.status;
        debugPrint("android_14_chamado: $sdkInt");
      } else if (sdkInt >= 31) {
        // Android 12 e 12L
        status = await Permission.storage.status;
        status3 = PermissionStatus.granted;
      } else {
        status = await Permission.storage.status;
        status3 = PermissionStatus.granted;
      }

      print('Permission android');

      checkStatus(status, status2, status3, isAvatar);
    } else if (QuickHelp.isIOSPlatform()) {
      PermissionStatus status = await Permission.photos.status;
      PermissionStatus status2 = await Permission.camera.status;
      PermissionStatus status3 = await Permission.videos.status;

      print('Permission ios');

      checkStatus(status, status2, status3, isAvatar);
    } else {
      print('Permission other device');

      _pickVideoFile();
    }
  }

  void checkStatus(PermissionStatus status, PermissionStatus status2,
      PermissionStatus status3, bool isAvatar) async {
    if (status.isDenied || status2.isDenied || status3.isDenied) {
      // We didn't ask for permission yet or the permission has been denied before but not permanently.

      if (QuickHelp.isAndroidPlatform()) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        bool api32 = androidInfo.version.sdkInt <= 32;
        if (api32) {
          askPermissions();
        } else {
          PermissionStatus statusCamera = await Permission.camera.request();
          PermissionStatus statusVideo = await Permission.videos.request();
          PermissionStatus statusPhoto = await Permission.photos.request();
          debugPrint(
              "permissions_ya_flamingo: camera:${statusCamera.isGranted} video:${statusVideo.isGranted} photo:${statusPhoto.isGranted}");
          if (statusCamera.isGranted &&
              statusVideo.isGranted /*&& statusStorage.isGranted*/) {
            _pickVideoFile();
          }
        }
      } else {
        askPermissions();
      }
    } else if (status.isPermanentlyDenied ||
        status2.isPermanentlyDenied ||
        status3.isPermanentlyDenied) {
      QuickHelp.showDialogPermission(
        context: context,
        title: "permissions.photo_access_denied".tr(),
        confirmButtonText: "permissions.okay_settings".tr().toUpperCase(),
        message: "permissions.photo_access_denied_explain"
            .tr(namedArgs: {"app_name": Setup.appName}),
        onPressed: () {
          QuickHelp.hideLoadingDialog(context);

          openAppSettings();
        },
      );
    } else if (status.isGranted && status2.isGranted && status3.isGranted) {
      _pickVideoFile();
    } else if (status3.isLimited) {
      askPermissions();
    }

    print('Permission ess1 $status');
    print('Permission see2 $status2');
    print('Permission ess3 $status3');
  }

  askPermissions() {
    QuickHelp.showDialogPermission(
        context: context,
        title: "permissions.video_access".tr(),
        confirmButtonText: "permissions.okay_".tr().toUpperCase(),
        message: "permissions.video_access_explain"
            .tr(namedArgs: {"app_name": Setup.appName}),
        onPressed: () async {
          QuickHelp.hideLoadingDialog(context);

          // You can request multiple permissions at once.
          Map<Permission, PermissionStatus> statuses = await [
            Permission.camera,
            Permission.photos,
            Permission.storage,
            Permission.videos,
          ].request();

          if (statuses[Permission.camera]!.isGranted &&
              statuses[Permission.photos]!.isGranted ||
              statuses[Permission.storage]!.isGranted ||
              statuses[Permission.videos]!.isGranted) {
            _pickVideoFile();
          }
        });
  }

  createPost() async {
    QuickHelp.showLoadingDialog(context);

    PostsModel newPost = PostsModel();

    newPost.setVideo = parseVideoFile!;
    newPost.setVideoThumbnail = parseVideoThumbnailFile!;
    newPost.setAuthor = widget.currentUser!;
    newPost.setText = captionTextEditing.text;
    newPost.setAuthorId = widget.currentUser!.objectId!;

    newPost.setTargetPeople = selectedUser;
    newPost.setTargetPeopleID = selectedUserIds;

    ParseResponse parseResponse = await newPost.save();

    if (parseResponse.success && parseResponse.result != null) {
      PostsModel postsModel = parseResponse.result;
      savePostIdOnUser(postsModel.objectId!);

      QuickHelp.hideLoadingDialog(context);

      setState(() {
        captionTextEditing.text = "";
        selectedUser.clear();
        selectedUserIds.clear();
        selectedVideos.clear();
      });

      _sendPushToFollowers(postsModel);

      QuickHelp.goToNavigatorScreen(
        context,
        HomeScreen(
          currentUser: widget.currentUser,
          initialTabIndex: 0,
        ),
        finish: true,
        back: false,
      );

      QuickHelp.showAppNotificationAdvanced(
        title: "create_post_screen.post_created_success_title".tr(),
        context: context,
        message: "create_post_screen.post_created_success_explain".tr(),
        isError: false,
      );
    } else {
      QuickHelp.hideLoadingDialog(context);

      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: "error".tr(),
        message: "try_again_later".tr(),
      );
    }
  }

  _sendPushToFollowers(PostsModel post) async {
    if (widget.currentUser!.getFollowers!.isNotEmpty) {
      QueryBuilder<UserModel> queryUsers =
      QueryBuilder<UserModel>(UserModel.forQuery());

      queryUsers.whereContainedIn(
        UserModel.keyObjectId,
        widget.currentUser!.getFollowers!,
      );

      ParseResponse response = await queryUsers.query();
      if (response.success) {
        if (response.result != null) {
          for (UserModel user in response.results!) {
            SendNotifications.sendPush(
              widget.currentUser!,
              user,
              SendNotifications.typePost,
              objectId: post.objectId!,
              pictureURL: post.getVideoThumbnail != null
                  ? post.getVideoThumbnail!.url
                  : "",
            );
          }
        }
      }
    }
  }

  _pickVideoFile() async {
    final List<AssetEntity>? result = await AssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: 1,
        requestType: RequestType.video,
        previewThumbnailSize: const ThumbnailSize(1080, 1080),
        textDelegate: AssetPickerTextDelegate(),
      ),
    );

    if (result != null && result.length > 0) {
      // Verificar duração do vídeo
      final int? durationInSeconds = await result.first.duration;
      if (durationInSeconds != null && durationInSeconds > videoDuration) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "video_upload.video_too_long".tr(),
          message: "video_upload.video_duration_limit".tr(namedArgs: {"duration": "$videoDuration"}),
          isError: true,
        );
        return;
      }

      final File? file = await result.first.file;
      if (file == null) return;


      if (file.lengthSync() > videoMegaByte * 1024 * 1024) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: "video_upload.video_too_large".tr(),
          message: "video_upload.video_size_limit".tr(namedArgs: {"size": "$videoMegaByte"}),
          isError: true,
        );
        return;
      }

      final preview = await result.first.thumbnailData;
      if (preview == null) return;

      String? mimeStr = lookupMimeType(file.path);
      var fileType = mimeStr!.split('/');

      print('Selected file type $fileType');

      prepareVideo(file, preview);
    }
  }

  prepareVideo(File file, Uint8List previewPath) async {
    DateTime date = DateTime.now();

    // Criar arquivo de thumbnail
    final tempDir = await getTemporaryDirectory();
    String videoThumbnailName =
        'thumbnail_${date.second}_${date.millisecond}.jpg';
    File videoThumbnailFile = File('${tempDir.path}/$videoThumbnailName');
    await videoThumbnailFile.writeAsBytes(previewPath);

    // Configurar arquivo de vídeo
    videoFile = file;

    // Configurar thumbnail
    parseVideoThumbnailFile =
        ParseFile(videoThumbnailFile, name: "thumbnail.jpg");

    setState(() {
      selectedVideos.add(videoThumbnailFile);
    });

    // Configurar arquivo de vídeo para upload
    if (file.absolute.path.isNotEmpty) {
      parseVideoFile = ParseFile(File(file.absolute.path),
          name: "video_${date.second}_${date.millisecond}.mp4");
    } else {
      parseVideoFile = ParseWebFile(file.readAsBytesSync(),
          name: "video_${date.second}_${date.millisecond}.mp4");
    }
  }

  initDoSpaces(File? videoFile) async {
    QuickHelp.showLoadingDialog(context);

    dospace.Spaces spaces = new dospace.Spaces(
      region: "",
      accessKey: "",
      secretKey: "",
    );

    String fileName =
        "video_file_${widget.currentUser!.objectId!}_${DateTime.now().toLocal().millisecond}_${QuickHelp.generateUId()}.mp4";
    String url = "$fileName";
    String? etag = await spaces.bucket("").uploadFile(
      fileName,
      videoFile,
      'video/mp4',
      dospace.Permissions.public,
    );

    print('upload: $etag');
    print('Url: $url');

    await spaces.close();

    parseVideoFile = ParseFile(
      videoFile,
      url: url,
      name: fileName,
    );

    //savePost();
  }

  savePostIdOnUser(String postId) async {
    widget.currentUser!.setIdToPostList = postId;
    await widget.currentUser!.save();
  }
}
