import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  // TODO: Replace with your actual Gemini API Key
  // Ideally, store this securely (e.g., --dart-define, .env)
  static const String _apiKey = 'YOUR_GEMINI_API_KEY'; 

  static Future<String> draftMessage(String className, String instructorName, String topic) async {
    try {
      if (_apiKey == 'YOUR_GEMINI_API_KEY') {
        return "Error: Gemini API Key not configured.";
      }
      final model = GenerativeModel(
        model: 'gemini-1.5-flash', // Updated to a standard model name available in the SDK
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.7,
        ),
      );

      final prompt = 'Draft a professional yet friendly class announcement for the course "$className" taught by $instructorName. The announcement is about: $topic. Keep it concise and suitable for a student group chat.';
      
      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? "No response generated.";
    } catch (e) {
      // print("Gemini Error: $e");
      return "Error drafting message. Please try again.";
    }
  }

  static Future<String> summarizeMaterial(String fileName, String category) async {
    try {
       if (_apiKey == 'YOUR_GEMINI_API_KEY') {
        return "Error: Gemini API Key not configured.";
      }
      final model = GenerativeModel(
        model: 'gemini-1.5-flash',
        apiKey: _apiKey,
        generationConfig: GenerationConfig(
          temperature: 0.5,
        ),
      );

      final prompt = 'Provide a short, 2-sentence summary of what a document named "$fileName" in the "$category" category might contain for a college student. Be helpful and professional.';

      final content = [Content.text(prompt)];
      final response = await model.generateContent(content);

      return response.text ?? "No summary generated.";
    } catch (e) {
      // print("Gemini Error: $e");
      return "Error summarizing material.";
    }
  }
}
