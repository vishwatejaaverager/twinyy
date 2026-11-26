import 'dart:convert';
import 'dart:developer' as developer;
import 'package:firebase_ai/firebase_ai.dart';

class FirebaseAiService {
  static const String defaultModelName = 'gemini-2.5-flash';

  final String _modelName;

  FirebaseAiService({String modelName = defaultModelName})
      : _modelName = modelName;

  GenerativeModel _createModel({
    required String systemInstruction,
    String? responseMimeType,
    double temperature = 0.7,
  }) {
    return FirebaseAI.googleAI().generativeModel(
      model: _modelName,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: GenerationConfig(
        temperature: temperature,
        responseMimeType: responseMimeType,
      ),
    );
  }

  /// Stage 1 (The Architect): Generate 3-4 sharp discovery questions for Brain Sync.
  Future<List<String>?> generateDiscoveryQuestions(String contextData) async {
    try {
      final model = _createModel(
        systemInstruction:
            'You are "The Architect", an expert communication strategist for Twiny (an AI digital twin). '
            'The user will describe their current situation or goal for auto-replying to a contact. '
            'Generate 3 to 4 short, specific discovery questions to clarify tone, boundaries, '
            'availability, and what details should or should not be shared. '
            'Respond strictly as a JSON object with the shape: {"questions": ["...", "..."]}.',
        responseMimeType: 'application/json',
        temperature: 0.6,
      );

      final response = await model.generateContent([
        Content.text('User situation/intent:\n$contextData'),
      ]);

      final raw = response.text?.trim();
      if (raw == null || raw.isEmpty) return null;

      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic> && decoded['questions'] is List) {
        return List<String>.from(
          (decoded['questions'] as List)
              .map((q) => q.toString().trim())
              .where((q) => q.isNotEmpty),
        );
      }
      if (decoded is List) {
        return decoded
            .map((q) => q.toString().trim())
            .where((q) => q.isNotEmpty)
            .toList();
      }
      return null;
    } catch (e) {
      developer.log(
        'generateDiscoveryQuestions failed: $e',
        name: 'FirebaseAiService',
      );
      return null;
    }
  }

  /// Stage 2 (The Legislator): Generate a Markdown Brain State rulebook.
  Future<String?> generateRulebook({
    required String originalIntent,
    required String userAnswers,
  }) async {
    try {
      final model = _createModel(
        systemInstruction:
            'You are "The Legislator" for Twiny, an AI communication agent. '
            'Convert the user\'s original situation and discovery answers into a concise, actionable '
            'Markdown Brain State rulebook that the AI reply agent will strictly follow. '
            'Include sections: # Brain State, ## Current Context, ## Tone & Style, '
            '## Core Rules, ## Boundaries (Do / Don\'t), and ## Sample Replies. '
            'Keep it crisp and directly usable as instructions.',
        temperature: 0.5,
      );

      final prompt = '''
Original Intent:
$originalIntent

Discovery Q&A:
$userAnswers
''';

      final response = await model.generateContent([Content.text(prompt)]);
      final text = response.text?.trim();
      return (text != null && text.isNotEmpty) ? text : null;
    } catch (e) {
      developer.log(
        'generateRulebook failed: $e',
        name: 'FirebaseAiService',
      );
      return null;
    }
  }

  /// Stage 3 (The Operator): Generate a natural, in-character chat reply.
  Future<String?> generateReply({
    required String chatName,
    required String incomingMessage,
    List<Map<String, dynamic>> history = const [],
    String? brainState,
  }) async {
    try {
      final buffer = StringBuffer()
        ..writeln(
          'You are Twiny, acting as the user\'s digital twin replying to "$chatName" '
          'in a messaging app (WhatsApp / Microsoft Teams).',
        )
        ..writeln(
          'Mirror the user\'s natural texting style, length, and tone from the conversation history.',
        )
        ..writeln(
          'Keep your reply concise, natural, and human. Do NOT include quotes around the reply, '
          'do NOT prefix with "Me:" or your name, and do NOT mention that you are an AI '
          'unless explicitly instructed by the Brain State rulebook.',
        );

      if (brainState != null && brainState.trim().isNotEmpty) {
        buffer
          ..writeln('\n=== ACTIVE BRAIN STATE RULEBOOK (FOLLOW STRICTLY) ===')
          ..writeln(brainState.trim())
          ..writeln('=== END RULEBOOK ===');
      }

      final model = _createModel(
        systemInstruction: buffer.toString(),
        temperature: 0.7,
      );

      final promptBuffer = StringBuffer();
      if (history.isNotEmpty) {
        promptBuffer.writeln('Recent conversation history:');
        final recent = history.length > 20
            ? history.sublist(history.length - 20)
            : history;
        for (final msg in recent) {
          final sender = (msg['sender'] as String?) == 'me' ? 'Me' : chatName;
          final text = (msg['text'] as String?)?.trim() ?? '';
          if (text.isNotEmpty) {
            promptBuffer.writeln('$sender: $text');
          }
        }
        promptBuffer.writeln();
      }

      promptBuffer
        ..writeln('New incoming message from $chatName:')
        ..writeln(incomingMessage)
        ..writeln('\nReply as Me:');

      final response = await model.generateContent([
        Content.text(promptBuffer.toString()),
      ]);

      final reply = response.text?.trim();
      return (reply != null && reply.isNotEmpty) ? reply : null;
    } catch (e) {
      developer.log(
        'generateReply failed for [$chatName]: $e',
        name: 'FirebaseAiService',
      );
      return null;
    }
  }
}
