// ignore_for_file: deprecated_member_use, unused_element

import 'package:easy_localization/easy_localization.dart';
import 'package:expandable_text/expandable_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:like_button/like_button.dart';
import 'package:flamingo/controllers/video_interactions_controller.dart';
import 'package:flamingo/ui/text_with_tap.dart';

import '../../../helpers/quick_actions.dart';
import '../../../helpers/quick_help.dart';
import '../../../models/PostsModel.dart';
import '../../../models/UserModel.dart';
import '../../../ui/container_with_corner.dart';
import '../../../utils/colors.dart';
import '../services/posts_service.dart';

class ReelsInteractions extends GetView<VideoInteractionsController> {
  final PostsModel postModel;
  final UserModel? currentUser;

  ReelsInteractions({
    required this.postModel,
    this.currentUser,
  }) {

    if (!Get.isRegistered<VideoInteractionsController>(
        tag: postModel.objectId)) {
      Get.put(
        VideoInteractionsController(
          video: postModel,
          currentUser: currentUser,
        ),
        tag: postModel.objectId,
      );
    }
  }

  @override
  String? get tag => postModel.objectId;

  @override
  Widget build(BuildContext context) {
    if (postModel.getAuthor == null) {

      if (Get.isRegistered<PostsService>()) {
        final postsService = Get.find<PostsService>();
        Future.microtask(() => postsService.fetchAuthorForPost(postModel));
      }

      return Container(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: 10),
                Text(
                  "Carregando...",
                  style: TextStyle(color: Colors.white),
                ),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: EdgeInsets.all(16),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _userNameAndTimeUploadedWidget(context),
                  SizedBox(height: 8.0),
                  _rainBowBrandWidget(),
                  SizedBox(height: 8.0),
                  if (postModel.getText != null &&
                      postModel.getText!.isNotEmpty)
                    _descriptionWidget(),
                  SizedBox(height: 8.0),
                ],
              ),
              _interactionsWidget(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _interactionsWidget(BuildContext context) {
    return Container(
      alignment: AlignmentDirectional.centerEnd,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Like Button com feedback visual melhorado
          Obx(() => _buildInteractionButton(
            icon: controller.isLiked.value
                ? Icons.favorite
                : Icons.favorite_outline_outlined,
            color: controller.isLiked.value ? kRedColor1 : Colors.white,
            count: controller.likesCount.value,
            onTap: () async {
              HapticFeedback.mediumImpact();
              await controller.toggleLike();
            },
            showAnimation: true,
          )),

          // Save Button com feedback visual melhorado
          Visibility(
            visible: currentUser != null &&
                postModel.getAuthor != null &&
                currentUser!.objectId != postModel.getAuthor!.objectId,
            child: Column(
              children: [
                SizedBox(height: 10),
                Obx(() => _buildInteractionButton(
                  icon: controller.isSaved.value
                      ? Icons.bookmark
                      : Icons.bookmark_border_outlined,
                  color: controller.isSaved.value
                      ? kOrangeColor
                      : Colors.white,
                  count: controller.savesCount.value,
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await controller.toggleSave();
                  },
                  showAnimation: true,
                )),
              ],
            ),
          ),

          // Comments Button com feedback visual melhorado
          SizedBox(height: 10),
          Obx(() => _buildInteractionButton(
            icon: Icons.comment,
            color: Colors.white,
            iconSize: 24,
            count: controller.commentsCount.value,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.showComments(context);
            },
            showAnimation: false,
          )),
          SizedBox(height: 10),
          _buildInteractionButton(
            icon: Icons.save_alt,
            color: Colors.white,
            iconSize: 24,
            count: controller.savesCount.value,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.downloadVideo(context);
            },
            showAnimation: false,
          ),
          SizedBox(height: 10),
          _buildInteractionButton(
            icon: Icons.remove_red_eye_sharp,
            color: Colors.white,
            iconSize: 24,
            count: controller.viewsCount.value,
            onTap: () {
              HapticFeedback.mediumImpact();
            },
            showAnimation: false,
          ),

          SizedBox(height: 10),
          _buildInteractionButton(
            icon: Icons.share_outlined,
            color: Colors.white,
            iconSize: 24,
            count: controller.sharesCount.value,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.sharePost(context);
            },
            showAnimation: false,
          ),

          // More Options Button com feedback visual melhorado
          SizedBox(height: 15),
          _buildInteractionButton(
            icon: Icons.more_horiz,
            color: Colors.white,
            onTap: () {
              HapticFeedback.mediumImpact();
              controller.openOptionsSheet(context);
            },
            showAnimation: false,
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionButton({
    required IconData icon,
    required Color color,
    int? count,
    required VoidCallback onTap,
    bool showAnimation = false,
    double iconSize = 30.0,
  }) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: showAnimation
          ? LikeButton(
        size: iconSize,
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.center,
        countPostion: CountPostion.top,
        circleColor:
        CircleColor(start: color, end: color),
        bubblesColor: BubblesColor(
          dotPrimaryColor: color,
          dotSecondaryColor: color,
        ),
        likeBuilder: (bool isLiked) => Icon(
          icon,
          color: color,
          size: iconSize,
        ),
        likeCount: count,
        countBuilder: (count, bool isLiked, String text) {
          return count == 0
              ? const SizedBox.shrink()
              : Text(
            QuickHelp.convertNumberToK(count!),
            style: TextStyle(color: Colors.white),
          );
        },
        onTap: (isLiked) async {
          onTap();
          return !isLiked;
        },
      )
          : GestureDetector(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.all(8),
          child: Column(
            children: [
              Icon(icon, color: color, size: iconSize),
              if (count != null && count > 0)
                Text(
                  QuickHelp.convertNumberToK(count),
                  style: TextStyle(color: Colors.white),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _descriptionWidget() {
    return Container(
      width: 220,
      child: ExpandableText(
        postModel.getText!,
        expandText: tr('show_more'),
        collapseText: tr('show_less'),
        maxLines: 2,
        linkColor: Colors.blue,
        style: GoogleFonts.nunito(
            color: Colors.white,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _rainBowBrandWidget() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(
          Icons.watch_later_outlined,
          color: Colors.white,
          size: 16,
        ),
        SizedBox(width: 8.0),
        Container(
          width: 220,
          child: Text(
            QuickHelp.getTimeAgoForFeed(postModel.createdAt!),
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _userNameAndTimeUploadedWidget(BuildContext context) {
    // Verificar se postModel.getAuthor é nulo
    final author = postModel.getAuthor;
    if (author == null) {
      return SizedBox.shrink(); // Retorna um widget vazio se o autor for nulo
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          //onTap: () => controller.goToProfile(context),
          child: QuickActions.avatarWidget(
            author,
            width: 45,
            height: 45,
            margin: EdgeInsets.only(bottom: 0, top: 0, left: 0, right: 5),
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextWithTap(
              author.getFullName ?? "", // Use null coalescing para evitar erro
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(1.0),
              fontSize: 15,
              marginLeft: 3,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                SvgPicture.asset(
                  "assets/svg/ic_diamond.svg",
                  height: 20,
                ),
                TextWithTap(
                  "${author.getDiamondsTotal.toString()}",
                  color: Colors.white,
                  fontSize: 13,
                ),
                VerticalDivider(),
                SvgPicture.asset(
                  "assets/svg/ic_followers_active.svg",
                  height: 19,
                ),
                TextWithTap(
                  "${author.getFollowers?.length.toString() ?? "0"}", // Use null coalescing para evitar erro
                  color: Colors.white,
                  fontSize: 13,
                ),
              ],
            )
          ],
        ),
        Visibility(
          visible: currentUser != null &&
              author.objectId != null &&
              currentUser!.objectId != author.objectId,
          child: _followWidget(context),
        ),
      ],
    );
  }

  Widget _followWidget(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      margin: EdgeInsets.only(left: 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        mainAxisSize: MainAxisSize.max,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Obx(() => LikeButton(
              size: 37,
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.center,
              countPostion: CountPostion.top,
              circleColor:
              CircleColor(start: kPrimaryColor, end: kPrimaryColor),
              bubblesColor: BubblesColor(
                dotPrimaryColor: kPrimaryColor,
                dotSecondaryColor: kPrimaryColor,
              ),
              isLiked: controller.isFollowing.value,
              likeCountAnimationType: LikeCountAnimationType.none,
              likeBuilder: (bool isLiked) {
                return ContainerCorner(
                  colors: [
                    isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor,
                    isLiked ? Colors.black.withOpacity(0.4) : kPrimaryColor
                  ],
                  child: ContainerCorner(
                    color: kTransparentColor,
                    height: 30,
                    width: 30,
                    child: Icon(
                      isLiked ? Icons.done : Icons.add,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  borderRadius: 50,
                  height: 40,
                  width: 40,
                );
              },
              onTap: (isLiked) async {
                await controller.toggleFollow();
                return !isLiked;
              },
            )),
          ),
        ],
      ),
    );
  }
}
