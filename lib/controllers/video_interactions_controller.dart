// ignore_for_file: deprecated_member_use

import 'package:device_info_plus/device_info_plus.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:gallery_saver_plus/gallery_saver.dart';
import 'package:get/get.dart';
import 'package:parse_server_sdk_flutter/parse_server_sdk_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flamingo/helpers/quick_actions.dart';
import 'package:flamingo/helpers/quick_cloud.dart';
import 'package:flamingo/helpers/quick_help.dart';
import 'package:flamingo/home/reels/reels_video_screen.dart';
import 'package:flamingo/models/NotificationsModel.dart';
import 'package:flamingo/models/PostsModel.dart';
import 'package:flamingo/models/ReportModel.dart';
import 'package:flamingo/models/UserModel.dart';
import 'package:flamingo/home/feed/video_reels_comments_screen.dart';
import 'package:flamingo/controllers/reels_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flamingo/controllers/video_recommendation_controller.dart';
import 'package:flamingo/services/posts_service.dart';

import '../app/setup.dart';
import '../services/deep_links_service.dart';

class VideoInteractionsController extends GetxController {
  final PostsModel video;
  final UserModel? currentUser;
  late final ReelsController _reelsController;
  final PostsService _postsService = Get.find<PostsService>();

  final RxBool isLiked = false.obs;
  final RxBool isSaved = false.obs;
  final RxBool isFollowing = false.obs;
  final RxInt likesCount = 0.obs;
  final RxInt savesCount = 0.obs;
  final RxInt commentsCount = 0.obs;
  final RxInt viewsCount = 0.obs;
  final RxInt sharesCount = 0.obs;
  final RxDouble videoProgress = 0.0.obs;
  bool viewCounted = false;

  VideoInteractionsController({
    required this.video,
    required this.currentUser,
  }) {
    if (Get.isRegistered<ReelsController>()) {
      _reelsController = Get.find<ReelsController>();
    }
  }

  @override
  void onInit() {
    super.onInit();
    _initializeValues();
    _loadCachedInteractions();
  }

  void _initializeValues() {
    isLiked.value = video.getLikes.contains(currentUser?.objectId);
    isSaved.value = video.getSaves.contains(currentUser?.objectId);

    // Verificar se o autor e o usuário atual são válidos antes de acessar following
    if (video.getAuthor != null &&
        currentUser != null &&
        currentUser!.getFollowing != null) {
      isFollowing.value =
          currentUser!.getFollowing!.contains(video.getAuthor!.objectId);
    } else {
      isFollowing.value = false;
    }

    likesCount.value = video.getLikes.length;
    savesCount.value = video.getSaves.length;
    commentsCount.value = video.getComments.length;
    viewsCount.value = video.getViews;
    sharesCount.value = video.getShares.length;
  }

  void updateVideoProgress(Duration position, Duration duration) {
    if (duration.inSeconds > 0) {
      videoProgress.value = position.inSeconds / duration.inSeconds;

      if (videoProgress.value >= 0.6 && !viewCounted) {
        _countView();
      }
    }
  }

  Future<void> _countView() async {
    try {
      if (currentUser != null &&
          !video.getViewers!.contains(currentUser!.objectId)) {

        video.setViewer = currentUser!.objectId!;

        video.setViews = video.getViews + 1;

        await video.save();

        _updateVideoInReels();

        viewCounted = true;

        _recordViewInteraction();
      }
    } catch (e) {
      print('Error counting view: $e');
    }
  }

  void _recordViewInteraction() {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController = Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
      );
    }
  }

  void resetViewProgress() {
    videoProgress.value = 0.0;
    viewCounted = false;
  }

  Future<void> sharePost(BuildContext context) async {
    String linkToShare = await DeepLinksService.createLink(
      branchObject: DeepLinksService.branchObject(
        shareAction: DeepLinksService.keyPostShare,
        objectID: video.objectId!,
        imageURL: QuickHelp.getImageToShare(video),
        title: QuickHelp.getTitleToShare(video),
        description: video.getAuthor!.getFullName,
      ),
      branchProperties: DeepLinksService.linkProperties(
        channel: "link",
      ),
      context: context,
    );
    if (linkToShare.isNotEmpty) {
      Share.share(
        tr("share_post",
            namedArgs: {"link": linkToShare, "app_name": Setup.appName}),
      );
      sharesCount.value += 1;
      video.setShares = currentUser!.objectId!;
      video.save();
      _updateVideoInReels();
    }
  }

  void _loadCachedInteractions() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedLikes = prefs.getStringList('cached_likes') ?? [];
      final cachedSaves = prefs.getStringList('cached_saves') ?? [];

      if (cachedLikes.contains(video.objectId)) {
        isLiked.value = true;
      }

      if (cachedSaves.contains(video.objectId)) {
        isSaved.value = true;
      }
    } catch (e) {
      print('Error loading cached interactions: $e');
    }
  }

  Future<void> _updateInteractionCache(
      String key, String videoId, bool add) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cached = prefs.getStringList(key) ?? [];

      if (add) {
        cached.add(videoId);
      } else {
        cached.remove(videoId);
      }

      await prefs.setStringList(key, cached);
    } catch (e) {
      print('Error updating interaction cache: $e');
    }
  }

  Future<void> toggleLike() async {
    try {
      if (isLiked.value) {
        video.removeLike = currentUser!.objectId!;
        await _deleteLikeNotification();
        await _updateInteractionCache('cached_likes', video.objectId!, false);
      } else {
        video.setLikes = currentUser!.objectId!;
        video.setLastLikeAuthor = currentUser!;
        await _createLikeNotification();
        await _updateInteractionCache('cached_likes', video.objectId!, true);
      }

      await video.save();
      _updateVideoInReels();

      isLiked.value = !isLiked.value;
      likesCount.value = video.getLikes.length;

      // Registrar interação para recomendações com peso
      _recordLikeInteraction(weight: isLiked.value ? 1.0 : -0.5);

      // Atualizar recomendações em tempo real
      _updateRecommendations();
    } catch (e) {
      print('Error toggling like: $e');
    }
  }

  Future<void> toggleSave() async {
    try {
      if (isSaved.value) {
        video.removeSave = currentUser!.objectId!;
        await _updateInteractionCache('cached_saves', video.objectId!, false);
      } else {
        video.setSaves = currentUser!.objectId!;
        await _updateInteractionCache('cached_saves', video.objectId!, true);
      }

      await video.save();
      _updateVideoInReels();

      isSaved.value = !isSaved.value;
      savesCount.value = video.getSaves.length;

      // Registrar interação para recomendações com peso maior
      _recordSaveInteraction(weight: isSaved.value ? 2.0 : -1.0);

      // Atualizar recomendações em tempo real
      _updateRecommendations();
    } catch (e) {
      print('Error toggling save: $e');
    }
  }

  Future<void> toggleFollow() async {
    try {
      if (isFollowing.value) {
        currentUser!.removeFollowing = video.getAuthor!.objectId!;
      } else {
        currentUser!.setFollowing = video.getAuthor!.objectId!;
      }

      await currentUser!.save();

      ParseResponse parseResponse = await QuickCloudCode.followUser(
        author: currentUser!,
        receiver: video.getAuthor!,
      );

      if (parseResponse.success) {
        QuickActions.createOrDeleteNotification(
          currentUser!,
          video.getAuthor!,
          NotificationsModel.notificationTypeFollowers,
        );
      }

      isFollowing.value = !isFollowing.value;
    } catch (e) {
      print('Error toggling follow: $e');
    }
  }

  Future<void> _createLikeNotification() async {
    await QuickActions.createOrDeleteNotification(
      currentUser!,
      video.getAuthor!,
      NotificationsModel.notificationTypeLikedReels,
      post: video,
    );
  }

  Future<void> _deleteLikeNotification() async {
    QueryBuilder<NotificationsModel> queryBuilder =
    QueryBuilder<NotificationsModel>(NotificationsModel())
      ..whereEqualTo(NotificationsModel.keyAuthor, currentUser)
      ..whereEqualTo(NotificationsModel.keyPost, video);

    ParseResponse parseResponse = await queryBuilder.query();
    if (parseResponse.success && parseResponse.results != null) {
      NotificationsModel notification = parseResponse.results!.first;
      await notification.delete();
    }
  }

  void _updateVideoInReels() {
    // Usar o PostsService para atualizar o vídeo
    _postsService.updatePost(video);

    // Manter a chamada ao ReelsController para compatibilidade
    if (Get.isRegistered<ReelsController>()) {
      _reelsController.updateVideo(video);
    }
  }

  void _recordLikeInteraction({double weight = 1.0}) {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
      Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        liked: isLiked.value,
      );
    }
  }


  Future<void> downloadVideo(BuildContext context) async {
    try {
      // Verificar permissão de armazenamento
      if (QuickHelp.isAndroidPlatform()) {
        DeviceInfoPlugin deviceInfo = DeviceInfoPlugin();
        AndroidDeviceInfo androidInfo = await deviceInfo.androidInfo;
        int sdkInt = androidInfo.version.sdkInt;

        if (sdkInt >= 33) {
          if (!await Permission.photos.isGranted) {
            final status = await Permission.photos.request();
            if (!status.isGranted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                title: tr("permissions.photo_access_denied"),
                message: tr("permissions.photo_access_denied_explain"),
              );
              return;
            }
          }
        } else {
          if (!await Permission.storage.isGranted) {
            final status = await Permission.storage.request();
            if (!status.isGranted) {
              QuickHelp.showAppNotificationAdvanced(
                context: context,
                title: tr("permissions.storage_access_denied"),
                message: tr("permissions.storage_access_denied_explain"),
              );
              return;
            }
          }
        }
      }

      // Mostrar progresso
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: tr("download_video.downloading"),
        message: "15%",
        isError: false,
      );

      // Obter URL do vídeo
      String videoUrl = video.getVideo!.url!;

      // Salvar vídeo na galeria
      final success = await GallerySaver.saveVideo(videoUrl);

      if (success == true) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("download_video.success_title"),
          message: tr("download_video.success_message"),
          isError: false,
        );
        savesCount.value += 1;
        video.setSaves = currentUser!.objectId!;
        video.save();
        _updateVideoInReels();
      } else {
        throw Exception(tr("download_video.failed"));
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      QuickHelp.showAppNotificationAdvanced(
        context: context,
        title: tr("error"),
        message: tr("download_video.error_message"),
      );
    }
  }

  void _recordSaveInteraction({double weight = 1.0}) {
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
      Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        saved: isSaved.value,
      );
    }
  }

  void showComments(BuildContext context) {
    QuickHelp.goToNavigatorScreen(
      context,
      VideoReelsCommentScreen(
        currentUser: currentUser,
        post: video,
      ),
    );

    // Registrar interação para recomendações
    if (Get.isRegistered<VideoRecommendationController>()) {
      final recommendationController =
      Get.find<VideoRecommendationController>();
      recommendationController.recordInteraction(
        video: video,
        user: currentUser!,
        commented: true,
      );
    }
  }

  void goToProfile(BuildContext context) {
    if (video.getAuthor!.objectId == currentUser!.objectId!) {
      QuickHelp.goToNavigatorScreen(
        context,
        ReelsVideosScreen(
          currentUser: currentUser,
        ),
      );
    } else {
      QuickHelp.goToNavigatorScreen(
        context,
        ReelsVideosScreen(
          currentUser: currentUser,
          mUser: video.getAuthor,
        ),
      );
    }
  }

  void openOptionsSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      enableDrag: true,
      isDismissible: true,
      builder: (_) => _buildOptionsSheet(context),
    );
  }

  Widget _buildOptionsSheet(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.5),
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(25.0),
          topRight: Radius.circular(25.0),
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (currentUser!.objectId != video.getAuthorId) ...[
              ListTile(
                leading:
                Icon(Icons.report_problem_outlined, color: Colors.white),
                title: Text(
                  tr("feed.report_post",
                      namedArgs: {"name": video.getAuthor!.getFullName!}),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showReportDialog(context),
              ),
              ListTile(
                leading: Icon(Icons.block, color: Colors.white),
                title: Text(
                  tr("feed.block_user",
                      namedArgs: {"name": video.getAuthor!.getFullName!}),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showBlockDialog(context),
              ),
            ],
            if (currentUser!.objectId == video.getAuthorId ||
                currentUser!.isAdmin!) ...[
              ListTile(
                leading: Icon(Icons.delete, color: Colors.white),
                title: Text(
                  tr("feed.delete_post"),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showDeleteDialog(context),
              ),
            ],
            if (currentUser!.isAdmin!) ...[
              ListTile(
                leading: Icon(Icons.person_off, color: Colors.white),
                title: Text(
                  tr("feed.suspend_user"),
                  style: TextStyle(color: Colors.white),
                ),
                onTap: () => _showSuspendDialog(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showReportDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.report_post_title"),
      message: tr("feed.report_post_message"),
      cancelButtonText: tr("cancel"),
      confirmButtonText: tr("feed.report_confirm"),
      onPressed: () => _reportPost(context),
    );
  }

  void _showBlockDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.block_user_title"),
      message: tr("feed.block_user_message",
          namedArgs: {"name": video.getAuthor!.getFullName!}),
      cancelButtonText: tr("cancel"),
      confirmButtonText: tr("feed.block_confirm"),
      onPressed: () => _blockUser(context),
    );
  }

  void _showDeleteDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.delete_post_alert"),
      message: tr("feed.delete_post_message"),
      cancelButtonText: tr("no"),
      confirmButtonText: tr("feed.yes_delete"),
      onPressed: () => _deletePost(context),
    );
  }

  void _showSuspendDialog(BuildContext context) {
    Navigator.pop(context);
    QuickHelp.showDialogWithButtonCustom(
      context: context,
      title: tr("feed.suspend_user_alert"),
      message: tr("feed.suspend_user_message"),
      cancelButtonText: tr("no"),
      confirmButtonText: tr("feed.yes_suspend"),
      onPressed: () => _suspendUser(context),
    );
  }

  Future<void> _reportPost(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      ParseResponse parseResponse = await QuickActions.report(
        type: ReportModel.reportTypePost,
        message: "Reported post",
        accuser: currentUser!,
        accused: video.getAuthor!,
        postsModel: video,
      );

      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("feed.post_report_success_title"),
          message: tr("feed.post_report_success_message"),
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("try_again_later"),
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error reporting post: $e');
    }
  }

  Future<void> _blockUser(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      currentUser!.setBlockedUser = video.getAuthor!;
      currentUser!.setBlockedUserIds = video.getAuthor!.objectId!;

      ParseResponse response = await currentUser!.save();
      QuickHelp.hideLoadingDialog(context);

      if (response.success) {
        // Remover posts do usuário bloqueado
        _postsService.allPosts.removeWhere(
                (post) => post.getAuthorId == video.getAuthor!.objectId);
        _postsService.videoPosts.removeWhere(
                (video) => video.getAuthorId == video.getAuthor!.objectId);

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("feed.block_success_title"),
          message: tr("feed.block_success_message"),
          isError: false,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("try_again_later"),
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error blocking user: $e');
    }
  }

  Future<void> _deletePost(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      ParseResponse parseResponse = await video.delete();
      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        // Remover o vídeo do PostsService
        _postsService.removePost(video.objectId!);

        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("deleted"),
          message: tr("feed.post_deleted"),
          user: video.getAuthor,
          isError: null,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("feed.post_not_deleted"),
          user: video.getAuthor,
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error deleting post: $e');
    }
  }

  Future<void> _suspendUser(BuildContext context) async {
    Navigator.pop(context);
    QuickHelp.showLoadingDialog(context);

    try {
      video.getAuthor!.setActivationStatus = true;
      ParseResponse parseResponse = await QuickCloudCode.suspendUSer(
        objectId: video.getAuthor!.objectId!,
      );

      QuickHelp.hideLoadingDialog(context);

      if (parseResponse.success) {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("suspended"),
          message: tr("feed.user_suspended"),
          user: video.getAuthor,
          isError: null,
        );
      } else {
        QuickHelp.showAppNotificationAdvanced(
          context: context,
          title: tr("error"),
          message: tr("feed.user_not_suspended"),
          user: video.getAuthor,
          isError: true,
        );
      }
    } catch (e) {
      QuickHelp.hideLoadingDialog(context);
      print('Error suspending user: $e');
    }
  }

  Future<void> _updateRecommendations() async {
    if (Get.isRegistered<ReelsController>()) {
      // Atualizar feed com vídeos recomendados
      await _reelsController.updateRecommendedVideos();
    }
  }
}
