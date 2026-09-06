// 文件互传纯函数单元测试（#28 边界用例补测）
//
// 覆盖 transfer_utils.dart 的无 IO 纯函数：文件名安全化、续传 .part 稳定名、
// 加密会话密钥 base64 往返。这些函数双端（PC/移动）需保持一致，故单测兜底。
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:jianli_mobile_app/features/file_transfer/models/transfer_utils.dart';

void main() {
  group('sanitizeFileName', () {
    test('仅取 basename，丢弃目录', () {
      expect(sanitizeFileName('/a/b/报告.pdf'), '报告.pdf');
      expect(sanitizeFileName('C:\\\\tmp\\\\x.png'), 'x.png');
    });

    test('过滤非法字符为下划线', () {
      expect(sanitizeFileName('a/b:c*?'), 'a_b_c__');
      expect(sanitizeFileName('foo"bar<baz>'), 'foo_bar_baz_');
    });

    test('空名回退未命名文件', () {
      expect(sanitizeFileName(''), '未命名文件');
      expect(sanitizeFileName('/'), '未命名文件');
    });
  });

  group('recvPartName', () {
    test('以 安全名 + 大小 生成稳定 .part 名（续传同键）', () {
      final a = recvPartName('大 文/件.txt', 1234);
      final b = recvPartName('大 文/件.txt', 1234);
      expect(a, b);
      expect(a, '.recv-大_文_件.txt-1234.part');
    });

    test('不同大小产生不同键（避免串扰）', () {
      final a = recvPartName('x.bin', 100);
      final b = recvPartName('x.bin', 200);
      expect(a, isNot(b));
    });
  });

  group('encSession base64 往返', () {
    test('key/iv 编解码往返无损', () {
      final key = List<int>.generate(32, (i) => i);
      final iv = List<int>.generate(16, (i) => 255 - i);
      final enc = encodeEncSession(key, iv);
      expect(enc['key'], isNotNull);
      expect(enc['iv'], isNotNull);
      final dec = decodeEncSession(enc['key']!, enc['iv']!);
      expect(dec['key'], key);
      expect(dec['iv'], iv);
    });

    test('解码 base64 与直接解码一致', () {
      final key = List<int>.generate(32, (i) => i * 3 % 256);
      final iv = List<int>.generate(16, (i) => i * 7 % 256);
      final enc = encodeEncSession(key, iv);
      expect(base64Decode(enc['key']!), key);
      expect(base64Decode(enc['iv']!), iv);
    });
  });
}
