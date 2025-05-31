import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:yurufuwa_diary/widgets/network_image_preview.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ImageGridView extends StatelessWidget {
  final List<String> imageUrls;
  final int maxDisplayCount;

  const ImageGridView({
    Key? key,
    required this.imageUrls,
    this.maxDisplayCount = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // 表示する画像の数を制限
    final displayCount = imageUrls.length > maxDisplayCount ? maxDisplayCount : imageUrls.length;
    final hasMore = imageUrls.length > maxDisplayCount;
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemCount: displayCount,
      itemBuilder: (context, index) {
        // 最後の画像で、かつ表示しきれない画像がある場合
        if (index == maxDisplayCount - 1 && hasMore) {
          return GestureDetector(
            onTap: () => _showAllImages(context),
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 画像
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CachedNetworkImage(
                    imageUrl: imageUrls[index],
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: Colors.grey[200],
                      child: const Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                    errorWidget: (context, url, error) => Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.error),
                    ),
                  ),
                ),
                
                // オーバーレイ
                Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '+${imageUrls.length - maxDisplayCount + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        
        // 通常の画像
        return GestureDetector(
          onTap: () => _showImagePreview(context, index),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: CachedNetworkImage(
              imageUrl: imageUrls[index],
              fit: BoxFit.cover,
              placeholder: (context, url) => Container(
                color: Colors.grey[200],
                child: const Center(
                  child: CircularProgressIndicator(),
                ),
              ),
              errorWidget: (context, url, error) => Container(
                color: Colors.grey[200],
                child: const Icon(Icons.error),
              ),
            ),
          ),
        );
      },
    );
  }

  // 画像プレビューを表示
  void _showImagePreview(BuildContext context, int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkImagePreviewScreen(
          imageUrls: imageUrls,
          initialIndex: index,
        ),
      ),
    );
  }

  // すべての画像を表示
  void _showAllImages(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NetworkImagePreviewScreen(
          imageUrls: imageUrls,
          initialIndex: maxDisplayCount - 1,
        ),
      ),
    );
  }
}
