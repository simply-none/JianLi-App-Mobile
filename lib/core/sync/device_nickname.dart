// 本机随机昵称（#昵称）
//
// 格式：【形容词1】【形容词2】的【名词】，例如「软萌俏皮的樱桃」。
// 词库与 PC 端 transferModule.ts 同源（随即词库.md），三组各取其一拼接。
//
// 持久化：shared_preferences，默认留存 3 天；过期或缺失则重新随机。
// 同步获取：localNickname（缓存优先，未加载时回退 hostname）。
//   调用方应先 await ensureNickname()（幂等），main() 启动已预加载。
//
// 平台后缀规则：本机展示（首页顶部 / 我的设备卡片）只用基座 localNickname，
// 不带平台；只有在「发现设备 / 历史设备列表」等广播给对端时才追加「的App」，
// 见 localBroadcastName。PC 端对应追加「的PC」。
import 'dart:io';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

const List<String> _nickAdj1 = [
  '软萌', '圆滚', '糯软', '奶白', '粉糯', '蓬松', '软绵', '饱满', '奶胖', '粉嘟',
  '弹软', '粉润', '白胖', '软嫩', '圆溜', '软糯', '软绒', '奶乎', '粉圆', '甜软',
  '圆乎', '嫩白', '绒软', '粉软', '奶圆', '滑软', '圆胖', '软甜', '粉嫩', '蓬软',
  '奶润', '圆软', '糯白', '软粉', '胖乎', '奶嫩', '粉白', '圆嫩', '软滑', '润软',
  '绵密', '软润', '圆敦', '奶甜', '粉蓬', '软敦', '糯甜', '白软', '圆甜', '软胖',
];

const List<String> _nickAdj2 = [
  '俏皮', '撒娇', '憨萌', '奶凶', '粘人', '机灵', '呆萌', '淘气', '贪吃', '贪睡',
  '调皮', '乖巧', '害羞', '爱笑', '软怂', '暖心', '迷糊', '捣蛋', '娇憨', '闹腾',
  '安静', '懒懒', '爱玩', '胆小', '贴心', '会撩', '蠢萌', '傲娇', '元气', '治愈',
  '开朗', '腼腆', '活泼', '顽皮', '软乖', '憨憨', '傻气', '懂事', '黏人', '软娇',
  '萌趣', '逗趣', '喜人', '讨喜', '可爱', '温顺', '软怯', '蹦跳', '软嗲', '娇俏',
];

const List<String> _nickNoun = [
  '樱桃', '草莓', '葡萄', '蜜桃', '橙子', '柚子', '荔枝', '龙眼', '芒果', '蓝莓',
  '树莓', '枇杷', '杨梅', '李子', '杏子', '椰子', '菠萝', '香蕉', '柠檬', '金桔',
  '土豆', '南瓜', '玉米', '红薯', '紫薯', '芋圆', '豌豆', '毛豆', '番茄', '黄瓜',
  '萝卜', '山药', '藕片', '板栗', '花生', '麻薯', '年糕', '汤圆', '元宵', '粽子',
  '月饼', '泡芙', '蛋挞', '舒芙蕾', '马卡龙', '奶冻', '布丁', '果冻', '雪媚娘', '大福',
  '铜锣烧', '鲷鱼烧', '章鱼烧', '小丸子', '糯米糍', '奶猫', '奶狗', '兔子', '熊猫', '考拉',
  '水獭', '松鼠', '仓鼠', '企鹅', '海豹', '海獭', '刺猬', '小鹿', '小羊', '小猪',
  '小鸭', '小鸡', '柯基', '布偶', '橘猫', '桃花', '樱花', '雏菊', '多肉', '蘑菇',
  '蒲公英', '向日葵', '铃兰', '绣球', '茉莉', '云朵', '星星', '月亮', '泡泡', '雪球',
  '糖果', '纽扣', '铃铛', '纸船', '风筝', '气球', '弹珠', '积木', '玩偶', '抱枕',
];

const Duration _nickTtl = Duration(days: 3);

String? _nickCache;

String _randomNickname() {
  final r = Random();
  final a1 = _nickAdj1[r.nextInt(_nickAdj1.length)];
  final a2 = _nickAdj2[r.nextInt(_nickAdj2.length)];
  final n = _nickNoun[r.nextInt(_nickNoun.length)];
  return '$a1$a2的$n';
}

/// 确保昵称已加载（幂等）：过期/缺失则重新生成并持久化。
Future<void> ensureNickname() async {
  if (_nickCache != null) return;
  final sp = await SharedPreferences.getInstance();
  final name = sp.getString('device_nickname');
  final ts = sp.getInt('device_nickname_ts') ?? 0;
  final now = DateTime.now().millisecondsSinceEpoch;
  // 迁移：基座已不含平台后缀；旧格式（带「的渐离App/的App/的PC」等后缀）一律重生
  final hasOldSuffix = name != null &&
      (name.endsWith('的渐离App') ||
          name.endsWith('的App') ||
          name.endsWith('的PC') ||
          name.endsWith(' (App)') ||
          name.endsWith(' (PC)'));
  if (name != null &&
      name.isNotEmpty &&
      !hasOldSuffix &&
      now - ts < _nickTtl.inMilliseconds) {
    _nickCache = name;
  } else {
    final generated = _randomNickname();
    await sp.setString('device_nickname', generated);
    await sp.setInt('device_nickname_ts', now);
    _nickCache = generated;
  }
}

/// 当前本机昵称（同步；未加载时回退 hostname）
String get localNickname => _nickCache ?? Platform.localHostname;

/// 广播 / 对端可见名：基座昵称 + 平台后缀。
/// 仅用于「发现设备 / 历史设备列表」等需让对端区分平台的场景；本机展示请用 [localNickname]。
String get localBroadcastName => '$localNickname的App';
