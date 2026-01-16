import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:translator/translator.dart';
import '../utils/app_localizations.dart'; // [NEW]
import '../services/language_service.dart'; // [NEW]

class TranslatableText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final int? maxLines;
  final TextOverflow? overflow;
  final Color? buttonColor; // [NEW]
  final Function(String)? onMentionTap; // [NEW]

  const TranslatableText(
    this.text, {
    super.key,
    this.style,
    this.maxLines,
    this.overflow,
    this.buttonColor, // [NEW]
    this.onMentionTap, // [NEW]
  });

  @override
  State<TranslatableText> createState() => _TranslatableTextState();
}

class _TranslatableTextState extends State<TranslatableText> {
  bool _isTranslated = false;
  String? _translatedText;
  String? _targetLanguage;
  bool _isLoading = false;
  final GoogleTranslator _translator = GoogleTranslator();

  String _t(String key) {
    return AppLocalizations.get(key, LanguageService().currentLanguage);
  }

  @override
  void initState() {
    super.initState();
    LanguageService().languageNotifier.addListener(_onLanguageChanged);
    _checkAutoTranslate();
  }

  @override
  void dispose() {
    LanguageService().languageNotifier.removeListener(_onLanguageChanged);
    super.dispose();
  }

  void _onLanguageChanged() {
    _checkAutoTranslate();
  }

  void _checkAutoTranslate() {
    final currentLang = LanguageService().currentLanguage;
    
    // If not translated yet, or language changed, we might want to auto-translate
    // But usually we just let user click translate unless it's the specific "Auto-translate to English" case found previously.
    // However, the user request says: "if app language is TR, translate EN->TR; if EN, TR->EN".
    // This implies we should try to translate whenever the app language changes if translation was active.
    
    if (_isTranslated) {
       // Re-translate to new language
       _translate();
    } else {
       // Optional: Auto-translate on init if desired? 
       // For now, let's keep the original "Auto translate if English" logic but adapted
       if (currentLang == 'en') {
         _translate(); 
       }
    }
  }

  Future<void> _translate() async {
    if (_translatedText != null && _targetLanguage == LanguageService().currentLanguage) {
      if (mounted) {
        setState(() {
          _isTranslated = true;
        });
      }
      return;
    }
    
    if (_isLoading) return;

    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final targetLang = LanguageService().currentLanguage;
      final translation = await _translator.translate(widget.text, to: targetLang);
      if (mounted) {
        setState(() {
          _translatedText = translation.text;
          _targetLanguage = targetLang;
          _isTranslated = true;
        });
      }
    } catch (e) {
      debugPrint("Translation error: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleTranslation() async {
    if (_isTranslated) {
      // Revert to original
      setState(() {
        _isTranslated = false;
      });
      return;
    }
    await _translate();
  }

  // Helper to build rich text with clickable mentions
  List<InlineSpan> _buildTextSpans(String content) {
    final effectiveStyle = DefaultTextStyle.of(context).style.merge(widget.style);

    if (widget.onMentionTap == null) {
      return [TextSpan(text: content, style: effectiveStyle)];
    }

    List<InlineSpan> spans = [];
    final mentionRegex = RegExp(r'(@\w+)');
    final matches = mentionRegex.allMatches(content);

    int lastMatchEnd = 0;
    for (final match in matches) {
      // Add text before the mention
      if (match.start > lastMatchEnd) {
        spans.add(TextSpan(
          text: content.substring(lastMatchEnd, match.start),
          style: effectiveStyle,
        ));
      }

      // Add the mention text
      final mentionText = match.group(0)!;
      final username = mentionText.substring(1); // remove @

      spans.add(TextSpan(
        text: mentionText,
        style: effectiveStyle.copyWith(
          color: Colors.blue[800],
          fontWeight: FontWeight.bold,
        ),
        recognizer: TapGestureRecognizer()
          ..onTap = () => widget.onMentionTap!(username),
      ));

      lastMatchEnd = match.end;
    }

    // Add remaining text
    if (lastMatchEnd < content.length) {
      spans.add(TextSpan(
        text: content.substring(lastMatchEnd),
        style: effectiveStyle,
      ));
    }

    if (spans.isEmpty) {
        return [TextSpan(text: content, style: effectiveStyle)];
    }

    return spans;
  }

  @override
  Widget build(BuildContext context) {
    final textToShow = _isTranslated ? (_translatedText ?? "") : widget.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            children: _buildTextSpans(textToShow),
            style: DefaultTextStyle.of(context).style.merge(widget.style),
          ),
          maxLines: widget.maxLines,
          overflow: widget.overflow ?? TextOverflow.visible,
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: _isLoading ? null : _toggleTranslation,
          child: _isLoading
              ? const SizedBox(
                  width: 12, 
                  height: 12, 
                  child: CircularProgressIndicator(strokeWidth: 2)
                )
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.translate, 
                      size: 14, 
                      color: widget.buttonColor ?? Colors.blue[700]
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isTranslated ? _t('show_original_label') : _t('translate_label'),
                      style: TextStyle(
                        color: widget.buttonColor ?? Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}
