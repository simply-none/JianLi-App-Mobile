// 文件互传模型与协议常量（双端同构；桌面端 transferModule.ts 同套定义）
import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

/// 传输方向
enum TransferDirection { send, receive }

/// 传输状态
enum TransferStatus { done, failed, canceled }

/// 接收端自动接收开关默认开启（v1 默认自动接收，页面可关）
const bool kDefaultAutoAccept = true;

/// 重名策略默认：rename=追加 (n)（#9）
const String kDefaultRename = 'rename'; // 'rename' | 'overwrite'

/// 传输加密默认关（#14，跨端细节未充分验证，默认不安全优先）
const bool kDefaultEnc = false;

/// 文件互传专用接收目录名（沙盒 Documents 下）
const String kTransferDirName = '渐离App文件互传';

/// 批量发送时单文件逐字节进度的回调载荷
class TransferProgress {
  const TransferProgress({
    required this.tid,
    required this.fid,
    required this.name,
    required this.total,
    required this.sent,
    required this.phase,
  });

  final String tid;
  final String fid;
  final String name;
  final int total;
  final int sent;

  /// 'data' 传输中 | 'end' 收尾 | 'done' 完成 | 'failed' 失败 | 'canceled' 取消
  final String phase;

  double get ratio => total <= 0 ? 0 : (sent / total).clamp(0.0, 1.0);
}

/// 发送端单文件任务描述
class TransferFileTask {
  const TransferFileTask({
    required this.fid,
    required this.file,
    required this.name,
    required this.size,
    this.mime,
  });

  final String fid;
  final File file;
  final String name;
  final int size;
  final String? mime;
}

/// 文件名安全化：仅取 basename、过滤非法字符；重名由调用方追加 ` (n)`。
String safeFileName(String raw) {
  final base = p.basename(raw);
  const illegal = r'<>:"/\|?*';
  var cleaned = base;
  for (final ch in illegal.split('')) {
    cleaned = cleaned.replaceAll(ch, '_');
  }
  return cleaned.isEmpty ? '未命名文件' : cleaned;
}

/// 取路径扩展名（含点，如 '.png'），无则空串
String fileExt(String path) => p.extension(path);

/// 节流辅助：每 ~100ms 触发一次回调
class _Throttle {
  _Throttle(this.interval);
  final Duration interval;
  DateTime _last = DateTime.fromMillisecondsSinceEpoch(0);
  void call(void Function() fn) {
    final now = DateTime.now();
    if (now.difference(_last) >= interval) {
      _last = now;
      fn();
    }
  }
}

/// 构造一个包装流：转发字节并累计计数，按节流回调 [onByte]。
/// [initial] 用于断点续传（#13）：已收字节作为进度起点。
Stream<List<int>> countingStream(
  Stream<List<int>> source,
  void Function(int totalBytes) onByte, {
  int initial = 0,
}) {
  final throttle = _Throttle(const Duration(milliseconds: 100));
  var total = initial;
  return source.map((chunk) {
    total += chunk.length;
    throttle(() => onByte(total));
    return chunk;
  });
}

/// 文件互传设置（单一事实源：服务端读取 autoAccept/rename/enc，页面切换写入并持久化）
class TransferSettings {
  TransferSettings({
    this.autoAccept = kDefaultAutoAccept,
    this.renameStrategy = kDefaultRename,
    this.enc = kDefaultEnc,
  });

  bool autoAccept;
  String renameStrategy; // 'rename' | 'overwrite'
  bool enc;

  /// 从 shared_preferences 载入到本实例（页面 init 时调用，服务端持有同一实例即生效）
  Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    autoAccept = sp.getBool('transfer_auto_accept') ?? kDefaultAutoAccept;
    renameStrategy = sp.getString('transfer_rename') ?? kDefaultRename;
    enc = sp.getBool('transfer_enc') ?? kDefaultEnc;
  }

  /// 持久化（切换开关时调用）
  Future<void> persist() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool('transfer_auto_accept', autoAccept);
    await sp.setString('transfer_rename', renameStrategy);
    await sp.setBool('transfer_enc', enc);
  }
}
