import 'dart:io';
import 'dart:math';

import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// ======================================================
//                JOURNAL ENTRY MODEL
// ======================================================
class JournalEntry {
  final String id;
  final String title;            // ⭐ NEW FIELD
  final String content;
  final DateTime createdAt;
  final String emotion;    // ⭐ NEW FIELD
  final List<String> photos;
  final List<String> tags;
  final bool isFavorite;
  final bool isArchived;
  final int wordCount;
  final DateTime? futureOpenDate;

  JournalEntry({
    required this.id,
    required this.title,          // ⭐ NEW FIELD
    required this.content,
    required this.createdAt,
    required this.photos,
    required this.tags,
    required this.isFavorite,
    required this.isArchived,
    required this.wordCount,
    required this.futureOpenDate,
    required this.emotion,   // ⭐ NEW FIELD
  });

  Map<String, dynamic> toMap() {
    return {
      "title": title,            // ⭐ NEW FIELD
      "content": content,
      "createdAt": createdAt,
      "photos": photos,
      "tags": tags,
      "isFavorite": isFavorite,
      "isArchived": isArchived,
      "wordCount": wordCount,
      "futureOpenDate": futureOpenDate,
      "emotion": emotion,      // ⭐ NEW FIELD
    };
  }

  factory JournalEntry.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return JournalEntry(
      id: doc.id,
      title: data["title"] ?? "",                             // ⭐ NEW FIELD
      content: data["content"] ?? "",
      createdAt: (data["createdAt"] as Timestamp).toDate(),
      photos: List<String>.from(data["photos"] ?? []),
      emotion: data["emotion"] ?? "",   // ⭐ NEW FIELD
      tags: List<String>.from(data["tags"] ?? []),
      isFavorite: data["isFavorite"] ?? false,
      isArchived: data["isArchived"] ?? false,
      wordCount: data["wordCount"] ?? 0,
      futureOpenDate: data["futureOpenDate"] != null
          ? (data["futureOpenDate"] as Timestamp).toDate()
          : null,
    );
  }
}

// ======================================================
//                    PDF EXPORT
// ======================================================
class ExportPDF {
  static Future<String> generateJournalPDF(JournalEntry e) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        build: (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(e.title,
                style: pw.TextStyle(
                    fontSize: 26, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 12),
            pw.Text("Date: ${e.createdAt}"),
            pw.SizedBox(height: 20),
            pw.Text(e.content),
            pw.SizedBox(height: 20),
            pw.Text("Tags: ${e.tags.join(", ")}"),
            pw.Text("Word Count: ${e.wordCount}"),
          ],
        ),
      ),
    );

    final dir = await getApplicationDocumentsDirectory();
    final file = File("${dir.path}/journal_${e.id}.pdf");
    await file.writeAsBytes(await pdf.save());
    return file.path;
  }
}

// ======================================================
//                QUOTE OF THE DAY
// ======================================================
class QuoteOfTheDay {
  static final List<String> quotes = [
    "“Every day is a chance to grow.”",
    "“Be kind to yourself today.”",
    "“Your feelings are valid.”",
    "“Small progress is still progress.”",
    "“Keep going, you’re getting better.”",
  ];

  static String random() {
    final r = Random();
    return quotes[r.nextInt(quotes.length)];
  }
}

// ======================================================
//                    ANALYTICS
// ======================================================
class WordCountAnalytics {
  static int total(List<JournalEntry> entries) =>
      entries.fold(0, (sum, e) => sum + e.wordCount);

  static double average(List<JournalEntry> entries) =>
      entries.isEmpty ? 0 : total(entries) / entries.length;
}

class TagAnalytics {
  static Map<String, int> frequency(List<JournalEntry> entries) {
    final map = <String, int>{};
    for (var e in entries) {
      for (var t in e.tags) {
        map[t] = (map[t] ?? 0) + 1;
      }
    }
    return map;
  }
}

// ======================================================
//                     STREAK SERVICE
// ======================================================
class StreakService {
  static int calculate(List<JournalEntry> entries) {
    if (entries.isEmpty) return 0;

    int streak = 1;
    DateTime prev = entries.first.createdAt;

    for (int i = 1; i < entries.length; i++) {
      final diff = prev.difference(entries[i].createdAt).inDays;
      if (diff == 1) {
        streak++;
        prev = entries[i].createdAt;
      } else {
        break;
      }
    }

    return streak;
  }
}

// ======================================================
//                  TRENDS + CALENDAR
// ======================================================
class TrendsService {
  static Map<String, int> perDay(List<JournalEntry> entries) {
    final map = <String, int>{};
    for (var e in entries) {
      final key = "${e.createdAt.year}-${e.createdAt.month}-${e.createdAt.day}";
      map[key] = (map[key] ?? 0) + 1;
    }
    return map;
  }
}

class CalendarHelper {
  static Map<DateTime, List<JournalEntry>> groupByDay(
      List<JournalEntry> entries) {
    final map = <DateTime, List<JournalEntry>>{};
    for (var e in entries) {
      final date = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      map.putIfAbsent(date, () => []);
      map[date]!.add(e);
    }
    return map;
  }
}

// ======================================================
//                 TIMELINE SERVICE
// ======================================================
class TimelineService {
  static List<Map<String, dynamic>> generate(List<JournalEntry> entries) {
    return entries.map((e) {
      return {
        "date": e.createdAt,
        "title": e.title,
        "content": e.content,
        "tags": e.tags,
        "favorite": e.isFavorite,
      };
    }).toList();
  }
}

// ======================================================
//                 REMINDER SERVICE
// ======================================================
class ReminderService {
  static Future<void> sendDailyReminder() async {
    print("🔔 Daily reminder sent");
  }

  static Future<void> sendWeeklyReview() async {
    print("📅 Weekly review sent");
  }
}
