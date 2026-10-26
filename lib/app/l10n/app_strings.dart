/// 应用内中文文案（当前仅简体中文）。
abstract final class S {
  static const appName = '私密日记';
  static const brandEnglish = 'PrivateNote';

  // 锁
  static const lockSetupHint = '设置 PIN，保护你的日记';
  static const lockEnterHint = '请输入 PIN';
  static const lockNewPin = '新 PIN（4–8 位数字）';
  static const lockPin = 'PIN';
  static const lockConfirmPin = '确认 PIN';
  static const lockSavePin = '保存 PIN';
  static const lockUnlock = '解锁';
  static const lockUseBiometrics = '使用生物识别';
  static const lockPinMismatch = '两次 PIN 不一致';
  static const lockInvalidPin = 'PIN 无效';
  static String lockWaitSeconds(int s) => '请等待 $s 秒';
  static const lockIncorrectPin = 'PIN 不正确';
  static String lockIncorrectBackoff(int s) => 'PIN 不正确。已锁定 ${s}s';
  static const lockTooManyAttempts = '尝试次数过多，请稍后再试';
  static const lockPinLength = 'PIN 须为 4–8 位数字';
  static const lockPinNumeric = 'PIN 只能包含数字';

  // 时间线
  static const timelineTitle = '日记';
  static const timelineEmptyTitle = '还没有日记';
  static const timelineEmptyBody = '写下第一篇吧。内容仅加密保存在本机。';
  static const timelineUntitled = '（无标题）';
  static const timelineNew = '写新日记';
  static const timelineSyncSettings = '同步与外观';
  static const timelineConflicts = '解决同步冲突';
  static const deleteEntryTitle = '删除这篇日记？';
  static const deleteEntryBody = '删除后无法从本机恢复（若已同步，请自行清理 WebDAV）。';
  static const cancel = '取消';
  static const delete = '删除';
  static const close = '关闭';
  static const keepLocal = '保留本地';
  static const keepRemote = '保留远程';
  static const syncConflictsTitle = '同步冲突';
  static const syncConflictSubtitle = '本地与远程均有改动，请选择保留哪一侧。';
  static const selectOrCreate = '选择一篇日记，或点击右下角新建';

  // 编辑
  static const editorNew = '新日记';
  static const editorEdit = '编辑';
  static const editorTitleHint = '标题';
  static const editorBodyHint = '随便写点什么…';
  static const editorSave = '保存';
  static const editorNotFound = '找不到这篇日记';
  static const unsavedTitle = '有未保存的更改';
  static const unsavedBody = '离开前要保存吗？';
  static const discard = '丢弃';
  static const save = '保存';

  // 设置
  static const settingsTitle = '设置';
  static const settingsAppearance = '外观与字体';
  static const settingsSync = 'WebDAV 同步';
  static const appearanceTitle = '外观与字体';
  static const appearanceFontSection = '正文字体';
  static const appearanceFontHint =
      '艺术字体首次选用时会从字体源下载到本机缓存（仅字体文件，不含日记）。之后可离线使用。系统字体不下载。';
  static const appearancePreview = '预览：春风又绿江南岸，明月何时照我还。';
  static const appearanceThemeSection = '色调';

  // 同步
  static const syncTitle = '同步设置';
  static const syncIntro =
      '上传前会在本机用 AES-256-GCM 加密。你的 WebDAV 服务器只保存密文，开发者无法读取日记内容。';
  static const syncUrl = 'WebDAV 地址';
  static const syncUsername = '用户名';
  static const syncPassword = '密码 / 令牌';
  static const syncRemoteFolder = '远程目录';
  static const syncSaveCreds = '保存凭证';
  static const syncNow = '立即同步';
  static const syncSaved = '已保存（密码在系统安全存储中）';
  static String syncSaveFailed(Object e) => '保存失败：$e';
  static const syncing = '正在同步…';
  static String syncError(Object e) => '同步错误：$e';
  static String syncConflicts(int n) => '同步完成，有 $n 处冲突。请在时间线中选择保留项。';
  static String syncOk(int pushed, int pulled) =>
      '同步成功 — 上传 $pushed，下载 $pulled';
  static String syncFailed(Object e) => '同步失败：$e';
}
