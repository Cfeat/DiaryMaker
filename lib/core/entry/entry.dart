/// Domain model for a diary entry (`DATA_MODEL.md`).
class Entry {
  const Entry({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
    this.mood,
    this.tags = const [],
    this.attachments = const [],
  });

  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? mood;
  final List<String> tags;
  final List<EntryAttachment> attachments;

  Entry copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? mood,
    bool clearMood = false,
    List<String>? tags,
    List<EntryAttachment>? attachments,
  }) {
    return Entry(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mood: clearMood ? null : (mood ?? this.mood),
      tags: tags ?? this.tags,
      attachments: attachments ?? this.attachments,
    );
  }
}

class EntryAttachment {
  const EntryAttachment({
    required this.id,
    required this.localRelativePath,
    this.mimeType,
    this.byteSize,
  });

  final String id;
  final String localRelativePath;
  final String? mimeType;
  final int? byteSize;

  Map<String, Object?> toJson() => {
        'id': id,
        'local_relative_path': localRelativePath,
        'mime_type': mimeType,
        'byte_size': byteSize,
      };

  factory EntryAttachment.fromJson(Map<String, Object?> json) {
    return EntryAttachment(
      id: json['id']! as String,
      localRelativePath: json['local_relative_path']! as String,
      mimeType: json['mime_type'] as String?,
      byteSize: json['byte_size'] as int?,
    );
  }
}
