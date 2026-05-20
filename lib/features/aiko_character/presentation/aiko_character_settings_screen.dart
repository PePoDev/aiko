import 'package:flutter/material.dart';

import '../../../shared/widgets/finance_card.dart';
import '../../../theme/aiko_colors.dart';
import '../domain/aiko_character_profile.dart';

class AikoCharacterSettingsScreen extends StatefulWidget {
  const AikoCharacterSettingsScreen({super.key});

  @override
  State<AikoCharacterSettingsScreen> createState() =>
      _AikoCharacterSettingsScreenState();
}

class _AikoCharacterSettingsScreenState
    extends State<AikoCharacterSettingsScreen> {
  AikoCharacterVisibility _visibility = AikoCharacterVisibility.full;
  bool _reduceMotion = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Aiko Character')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 112),
        children: [
          FinanceCard(
            title: 'Character visibility',
            icon: Icons.face_3_outlined,
            accentColor: AikoColors.premiumPurple,
            child: SegmentedButton<AikoCharacterVisibility>(
              segments: const [
                ButtonSegment(
                  value: AikoCharacterVisibility.full,
                  icon: Icon(Icons.face_3_outlined),
                  label: Text('Full'),
                ),
                ButtonSegment(
                  value: AikoCharacterVisibility.reduced,
                  icon: Icon(Icons.visibility_outlined),
                  label: Text('Reduced'),
                ),
                ButtonSegment(
                  value: AikoCharacterVisibility.hidden,
                  icon: Icon(Icons.visibility_off_outlined),
                  label: Text('Hidden'),
                ),
              ],
              selected: {_visibility},
              onSelectionChanged: (selection) {
                setState(() => _visibility = selection.single);
              },
            ),
          ),
          const SizedBox(height: 16),
          FinanceCard(
            title: 'Motion and placement',
            icon: Icons.tune_outlined,
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _reduceMotion,
                  onChanged: (value) => setState(() => _reduceMotion = value),
                  title: const Text('Reduce animation'),
                ),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.privacy_tip_outlined),
                  title: Text('Data first'),
                  subtitle: Text(
                    'Aiko appears only when she helps explain or guide financial data.',
                  ),
                ),
                const Divider(),
                const ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.warning_amber_outlined),
                  title: Text('Serious warnings stay professional'),
                  subtitle: Text(
                    'Warnings avoid shame and focus on clear next steps.',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
