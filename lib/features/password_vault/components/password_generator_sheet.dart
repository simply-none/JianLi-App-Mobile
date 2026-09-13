// 密码生成器抽屉（md 档）—— 对齐 PC PasswordGenerator 双模式
//
// 随机密码模式：长度 8-64 滑条 + 大写/小写/数字/符号开关 + 排除易混淆字符（Il1O0）；
// 口令短语模式：词数 3-8 + 分隔符选择。随机源 Random.secure。
// 「使用」返回生成的密码（Navigator.pop 值），表单侧回填密码框。
import 'dart:math';

import 'package:forui/forui.dart';
import 'package:material_ui/material_ui.dart';

import '../../../app/theme/app_theme.dart';
import '../../../app/ui/gradient_button.dart';
import '../../../app/ui/sheet_form.dart';
import '../../../app/ui/sheet_surface.dart';

/// 打开密码生成器；返回选中的密码（取消/关闭返回 null）
Future<String?> showPasswordGeneratorSheet(BuildContext context) {
  return showFSheet<String>(
    context: context,
    side: FLayout.btt,
    // md 档（50%，扣键盘）
    mainAxisMaxRatio: AppTokens.sheetHeightLg,
    resizeToAvoidBottomInset: false,
    builder: (c) => const _GeneratorSheet(),
  );
}

/// 口令短语词表（短小好记；配合分隔符与大小写习惯足够抗碰撞）
const List<String> kPassphraseWords = [
  'apple', 'amber', 'anchor', 'aurora', 'basil', 'beacon', 'birch', 'breeze',
  'cactus', 'canyon', 'cedar', 'chalk', 'cherry', 'cinder', 'citrus', 'clover',
  'comet', 'coral', 'cosmos', 'crater', 'crimson', 'daisy', 'delta', 'dune',
  'ember', 'fable', 'falcon', 'fern', 'fjord', 'flint', 'forest', 'galaxy',
  'garnet', 'glacier', 'granite', 'grove', 'harbor', 'hazel', 'helix', 'hollow',
  'indigo', 'ivory', 'jade', 'jasmine', 'juniper', 'kelp', 'lagoon', 'lantern',
  'lichen', 'lotus', 'lumen', 'lunar', 'mango', 'maple', 'marble', 'meadow',
  'mesa', 'mint', 'mirage', 'moss', 'nectar', 'nimbus', 'nova', 'oak',
  'obsidian', 'ocean', 'olive', 'onyx', 'opal', 'orbit', 'otter', 'palm',
  'pebble', 'pepper', 'petal', 'pierce', 'pillar', 'pine', 'plasma', 'prairie',
  'quartz', 'quill', 'rain', 'raven', 'reef', 'ridge', 'river', 'rose',
  'saffron', 'sage', 'salmon', 'sand', 'sapphire', 'shadow', 'slate', 'solstice',
  'spruce', 'stellar', 'storm', 'summit', 'sunset', 'thistle', 'thunder', 'tide',
  'timber', 'topaz', 'tulip', 'tundra', 'valley', 'velvet', 'vertex', 'violet',
  'willow', 'winter', 'wombat', 'zenith', 'zephyr', 'zinc', 'zodiac', 'copper',
];

class _GeneratorSheet extends StatefulWidget {
  const _GeneratorSheet();

  @override
  State<_GeneratorSheet> createState() => _GeneratorSheetState();
}

class _GeneratorSheetState extends State<_GeneratorSheet> {
  bool _phraseMode = false;

  // 随机模式参数
  double _length = 16;
  bool _upper = true;
  bool _lower = true;
  bool _digits = true;
  bool _symbols = true;
  bool _excludeAmbiguous = true;

  // 口令短语参数
  double _wordCount = 4;
  String _separator = '-';

  String _generated = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _regenerate());
  }

  void _regenerate() {
    setState(() => _generated = _phraseMode ? _genPhrase() : _genRandom());
  }

  String _genRandom() {
    const upperChars = 'ABCDEFGHJKLMNPQRSTUVWXYZ';
    const lowerChars = 'abcdefghijkmnopqrstuvwxyz';
    const digitChars = '23456789';
    const symbolChars = '!@#\$%^&*-_=+?';
    const ambiguous = 'Il1O0o';
    final rng = Random.secure();
    String pool() {
      final buf = StringBuffer();
      if (_upper) buf.write(upperChars);
      if (_lower) buf.write(lowerChars);
      if (_digits) buf.write(digitChars);
      if (_symbols) buf.write(symbolChars);
      var s = buf.toString();
      if (_excludeAmbiguous) {
        s = s.split('').where((c) => !ambiguous.contains(c)).join();
      }
      return s;
    }

    final chars = pool();
    if (chars.isEmpty) return '';
    final codeUnits = [
      for (var i = 0; i < _length.round(); i++) chars.codeUnitAt(rng.nextInt(chars.length)),
    ];
    return String.fromCharCodes(codeUnits);
  }

  String _genPhrase() {
    final rng = Random.secure();
    final words = [
      for (var i = 0; i < _wordCount.round(); i++)
        kPassphraseWords[rng.nextInt(kPassphraseWords.length)],
    ];
    // 词首字母大写提高可读性，再按分隔符拼接
    final cased = [
      for (final w in words)
        '${w[0].toUpperCase()}${w.substring(1)}',
    ];
    return cased.join(_separator);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.theme;
    return SheetScaffold(
      title: '密码生成器',
      size: SheetSize.md,
      body: StatefulBuilder(
        builder: (context, setInner) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: 14,
          children: [
            // 结果预览（等宽 + 可复制）
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: t.colors.card,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.colors.border),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      _generated.isEmpty ? '—' : _generated,
                      style: t.typography.body.md.copyWith(
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      _regenerate();
                      setInner(() {});
                    },
                    behavior: HitTestBehavior.opaque,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(
                        FLucideIcons.refreshCw,
                        size: 16,
                        color: t.colors.mutedForeground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // 模式切换
            Wrap(
              spacing: 8,
              children: [
                SheetChoiceChip(
                  label: '随机密码',
                  selected: !_phraseMode,
                  onTap: () {
                    setInner(() => _phraseMode = false);
                    setState(() => _generated = _genRandom());
                  },
                ),
                SheetChoiceChip(
                  label: '口令短语',
                  selected: _phraseMode,
                  onTap: () {
                    setInner(() => _phraseMode = true);
                    setState(() => _generated = _genPhrase());
                  },
                ),
              ],
            ),
            if (!_phraseMode) ...[
              // label↔控件间距只由 SheetFieldLabel 自带 bottom:6 提供
              //（包进无间距 Column，外层 spacing:14 只作组间）
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetFieldLabel('长度 · ${_length.round()}'),
                  Slider(
                    value: _length,
                    min: 8,
                    max: 64,
                    divisions: 56,
                    label: '${_length.round()}',
                    onChanged: (v) {
                      setState(() => _length = v);
                      setInner(() {});
                    },
                    onChangeEnd: (_) =>
                        setState(() => _generated = _genRandom()),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (label, key) in const [
                    ('大写 A-Z', 'upper'),
                    ('小写 a-z', 'lower'),
                    ('数字 0-9', 'digits'),
                    ('符号', 'symbols'),
                  ])
                    SheetChoiceChip(
                      label: label,
                      selected: key == 'upper'
                          ? _upper
                          : key == 'lower'
                              ? _lower
                              : key == 'digits'
                                  ? _digits
                                  : _symbols,
                      onTap: () {
                        setState(() {
                          if (key == 'upper') _upper = !_upper;
                          if (key == 'lower') _lower = !_lower;
                          if (key == 'digits') _digits = !_digits;
                          if (key == 'symbols') _symbols = !_symbols;
                        });
                        setInner(() {});
                        _regenerate();
                      },
                    ),
                  SheetChoiceChip(
                    label: '排除易混淆（Il1O0）',
                    selected: _excludeAmbiguous,
                    onTap: () {
                      setState(() => _excludeAmbiguous = !_excludeAmbiguous);
                      setInner(() {});
                      _regenerate();
                    },
                  ),
                ],
              ),
            ] else ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetFieldLabel('词数 · ${_wordCount.round()}'),
                  Slider(
                    value: _wordCount,
                    min: 3,
                    max: 8,
                    divisions: 5,
                    label: '${_wordCount.round()}',
                    onChanged: (v) {
                      setState(() => _wordCount = v);
                      setInner(() {});
                    },
                    onChangeEnd: (_) =>
                        setState(() => _generated = _genPhrase()),
                  ),
                ],
              ),
              Wrap(
                spacing: 8,
                children: [
                  for (final sep in const ['-', '.', '_', ' '])
                    SheetChoiceChip(
                      label: sep == ' ' ? '空格' : sep,
                      selected: _separator == sep,
                      onTap: () {
                        setState(() => _separator = sep);
                        setInner(() {});
                        _regenerate();
                      },
                    ),
                ],
              ),
            ],
          ],
        ),
      ),
      bottomBar: [
        Expanded(
          child: FButton(
            variant: FButtonVariant.outline,
            onPress: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
        ),
        Expanded(
          child: GradientButton(
            label: '使用',
            icon: FLucideIcons.check,
            onPress: _generated.isEmpty
                ? null
                : () => Navigator.pop(context, _generated),
          ),
        ),
      ],
    );
  }
}
