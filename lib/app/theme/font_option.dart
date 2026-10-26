import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// 可选正文字体。艺术字体经 [google_fonts] 首次下载后缓存本机（非遥测）。
///
/// 仅用 TextStyle API，避免 google_fonts 9 与 Flutter TextTheme 类型冲突。
enum AppFontOption {
  system,
  notoSansSc,
  zcoolXiaoWei,
  zcoolQingKeHuangYou,
  maShanZheng,
  longCang,
  zhiMangXing,
  liuJianMaoCao;

  String get id => name;

  String get labelZh => switch (this) {
        AppFontOption.system => '系统默认',
        AppFontOption.notoSansSc => '思源黑体 · 清晰',
        AppFontOption.zcoolXiaoWei => '站酷小薇 · 清雅',
        AppFontOption.zcoolQingKeHuangYou => '站酷庆科黄油体 · 圆润',
        AppFontOption.maShanZheng => '马善政楷书 · 书法',
        AppFontOption.longCang => '龙藏体 · 手写',
        AppFontOption.zhiMangXing => '志莽行书 · 艺术',
        AppFontOption.liuJianMaoCao => '刘建毛草 · 狂草',
      };

  String get subtitleZh => switch (this) {
        AppFontOption.system => '跟随系统中文字体，无需下载',
        AppFontOption.notoSansSc => '现代无衬线，适合长文阅读',
        AppFontOption.zcoolXiaoWei => '圆润标题感，日记封面感强',
        AppFontOption.zcoolQingKeHuangYou => '黄油圆体，轻松活泼',
        AppFontOption.maShanZheng => '楷书笔意，偏文人笔记',
        AppFontOption.longCang => '手写感，适合短篇心情',
        AppFontOption.zhiMangXing => '行书风格，更有书写感',
        AppFontOption.liuJianMaoCao => '草书风格，艺术感最强（长文慎用）',
      };

  bool get needsDownload => this != AppFontOption.system;

  static AppFontOption fromId(String? id) {
    for (final v in AppFontOption.values) {
      if (v.id == id) return v;
    }
    return AppFontOption.system;
  }

  TextStyle _face({TextStyle? textStyle}) {
    switch (this) {
      case AppFontOption.system:
        return textStyle ?? const TextStyle();
      case AppFontOption.notoSansSc:
        return GoogleFonts.notoSansSc(textStyle: textStyle);
      case AppFontOption.zcoolXiaoWei:
        return GoogleFonts.zcoolXiaoWei(textStyle: textStyle);
      case AppFontOption.zcoolQingKeHuangYou:
        return GoogleFonts.zcoolQingKeHuangYou(textStyle: textStyle);
      case AppFontOption.maShanZheng:
        return GoogleFonts.maShanZheng(textStyle: textStyle);
      case AppFontOption.longCang:
        return GoogleFonts.longCang(textStyle: textStyle);
      case AppFontOption.zhiMangXing:
        return GoogleFonts.zhiMangXing(textStyle: textStyle);
      case AppFontOption.liuJianMaoCao:
        return GoogleFonts.liuJianMaoCao(textStyle: textStyle);
    }
  }

  TextTheme textTheme(TextTheme base) {
    if (this == AppFontOption.system) return base;
    TextStyle? map(TextStyle? s) => s == null ? null : _face(textStyle: s);
    return TextTheme(
      displayLarge: map(base.displayLarge),
      displayMedium: map(base.displayMedium),
      displaySmall: map(base.displaySmall),
      headlineLarge: map(base.headlineLarge),
      headlineMedium: map(base.headlineMedium),
      headlineSmall: map(base.headlineSmall),
      titleLarge: map(base.titleLarge),
      titleMedium: map(base.titleMedium),
      titleSmall: map(base.titleSmall),
      bodyLarge: map(base.bodyLarge),
      bodyMedium: map(base.bodyMedium),
      bodySmall: map(base.bodySmall),
      labelLarge: map(base.labelLarge),
      labelMedium: map(base.labelMedium),
      labelSmall: map(base.labelSmall),
    );
  }

  TextStyle previewStyle({double fontSize = 18}) {
    final base = TextStyle(fontSize: fontSize, height: 1.5);
    if (this == AppFontOption.system) return base;
    return _face(textStyle: base);
  }
}

enum AppColorMood {
  inkSea,
  duskPaper,
  mistBamboo;

  String get id => name;

  String get labelZh => switch (this) {
        AppColorMood.inkSea => '墨青',
        AppColorMood.duskPaper => '暮纸',
        AppColorMood.mistBamboo => '竹雾',
      };

  Color get seed => switch (this) {
        AppColorMood.inkSea => const Color(0xFF2F5D50),
        AppColorMood.duskPaper => const Color(0xFF8B6914),
        AppColorMood.mistBamboo => const Color(0xFF4A6741),
      };

  static AppColorMood fromId(String? id) {
    for (final v in AppColorMood.values) {
      if (v.id == id) return v;
    }
    return AppColorMood.inkSea;
  }
}
