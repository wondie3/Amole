import 'package:flutter/material.dart';

class AiPromptAssistantSheet extends StatefulWidget {
  const AiPromptAssistantSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AiPromptAssistantSheet(),
    );
  }

  @override
  State<AiPromptAssistantSheet> createState() => _AiPromptAssistantSheetState();
}

class _AiPromptAssistantSheetState extends State<AiPromptAssistantSheet> {
  final TextEditingController _promptController = TextEditingController();
  bool _isThinking = false;
  _AiRecommendation? _result;

  final List<String> _samplePrompts = const [
    'Spicy traditional feast for 2 under 800 ETB',
    'Vegan fasting (Tsom) lunch with high protein',
    'Mild comforting dish + traditional drink pairing',
    'Quick street-food style snack in Addis Ababa',
  ];

  void _runAiPrompt(String rawPrompt) async {
    final prompt = rawPrompt.trim();
    if (prompt.isEmpty) return;

    setState(() {
      _promptController.text = prompt;
      _isThinking = true;
    });

    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;

    final lower = prompt.toLowerCase();
    _AiRecommendation recommendation;

    if (lower.contains('vegan') ||
        lower.contains('fasting') ||
        lower.contains('tsom') ||
        lower.contains('beyaynetu') ||
        lower.contains('shiro')) {
      recommendation = const _AiRecommendation(
        intentSummary: 'Plant-Based / Fasting (Tsom) • High Fiber & Protein',
        dishName: 'Yetsom Beyaynetu & Tegabino Shiro Combo',
        restaurant: 'Habesha Heritage Kitchen',
        estimatedPrice: '340 ETB',
        reasoning:
            'Matched your fasting/plant-based intent with chickpea-rich Tegabino Shiro and assorted spiced lentils (Misir Wot, Kik Alicha) on fresh 100% Teff Injera.',
        pairingTip: 'Pair with freshly roasted Ethiopian Buna or Spiced Ginger Tea.',
      );
    } else if (lower.contains('mild') ||
        lower.contains('comfort') ||
        lower.contains('non-spicy') ||
        lower.contains('alicha')) {
      recommendation = const _AiRecommendation(
        intentSummary: 'Mild Spice Profile • Comforting Traditional Meal',
        dishName: 'Yebeg Alicha & Gomen Besiga',
        restaurant: 'Addis Spice & Grill',
        estimatedPrice: '480 ETB',
        reasoning:
            'Filtered out Berbere-heavy dishes to match your mild preference. Slow-simmered turmeric lamb stew balances rich flavor without intense heat.',
        pairingTip: 'Pair with homemade Honey Wine (Tej) or fresh Avocado Juice.',
      );
    } else if (lower.contains('quick') ||
        lower.contains('snack') ||
        lower.contains('street') ||
        lower.contains('lunch')) {
      recommendation = const _AiRecommendation(
        intentSummary: 'Fast Prep (< 20 mins) • Light & Savory',
        dishName: 'Chechebsa with Honey & Spiced Sambusa Trio',
        restaurant: 'Bole Express Bites',
        estimatedPrice: '260 ETB',
        reasoning:
            'Prioritized rapid preparation time and portable street-food favorites crisp-fried with Niter Kibbeh and organic honey.',
        pairingTip: 'Pair with Macchiato or Fresh Mango-Papaya Spris.',
      );
    } else {
      recommendation = const _AiRecommendation(
        intentSummary: 'Authentic Spicy Feast • Signature Ethiopian Experience',
        dishName: 'Special Doro Wot & Kitfo Royal Platter',
        restaurant: 'Enkutatash Traditional Dining',
        estimatedPrice: '690 ETB',
        reasoning:
            'Selected Ethiopia’s flagship Berbere-spiced chicken stew with Ayib (fresh cottage cheese) and Mitmita-seasoned Kitfo for bold flavor.',
        pairingTip: 'Pair with cool Ayib cheese to balance the Berbere heat and Tej.',
      );
    }

    setState(() {
      _isThinking = false;
      _result = recommendation;
    });
  }

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  'Amole AI Meal Prompt Assistant',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Describe your craving, budget, spice level, or dietary preference in natural language.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _promptController,
              textInputAction: TextInputAction.send,
              onSubmitted: _runAiPrompt,
              decoration: InputDecoration(
                hintText: 'e.g., Spicy fasting meal under 350 ETB...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.send_rounded),
                  onPressed: () => _runAiPrompt(_promptController.text),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _samplePrompts.map((prompt) {
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 12)),
                  onPressed: () => _runAiPrompt(prompt),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),
            if (_isThinking)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_result != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'DETECTED INTENT: ${_result!.intentSummary}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _result!.dishName,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Text(
                          _result!.estimatedPrice,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      _result!.restaurant,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _result!.reasoning,
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '✨ AI Pairing Tip: ${_result!.pairingTip}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AiRecommendation {
  final String intentSummary;
  final String dishName;
  final String restaurant;
  final String estimatedPrice;
  final String reasoning;
  final String pairingTip;

  const _AiRecommendation({
    required this.intentSummary,
    required this.dishName,
    required this.restaurant,
    required this.estimatedPrice,
    required this.reasoning,
    required this.pairingTip,
  });
}
