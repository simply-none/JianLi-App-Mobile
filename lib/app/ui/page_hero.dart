// 共享元素 Hero 包装（UI 现代化 Phase 1）
//
// 列表 → 详情共享元素过渡用。极薄封装，保持 tag 唯一即可。
import 'package:flutter/widgets.dart';

/// 共享元素容器
class PageHero extends StatelessWidget {
  const PageHero({
    super.key,
    required this.tag,
    required this.child,
  });

  final Object tag;
  final Widget child;

  @override
  Widget build(BuildContext context) => Hero(tag: tag, child: child);
}
