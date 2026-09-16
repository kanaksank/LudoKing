import 'package:flutter/services.dart';

/// Haptics and system sounds, both user-disableable. No audio assets needed.
class FeedbackService {
  bool haptics = true;
  bool sound = true;

  void diceRoll() {
    if (haptics) HapticFeedback.lightImpact();
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  void tokenStep() {
    if (haptics) HapticFeedback.selectionClick();
  }

  void select() {
    if (haptics) HapticFeedback.selectionClick();
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  void capture() {
    if (haptics) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 120), HapticFeedback.heavyImpact);
    }
    if (sound) SystemSound.play(SystemSoundType.alert);
  }

  void home() {
    if (haptics) HapticFeedback.mediumImpact();
    if (sound) SystemSound.play(SystemSoundType.click);
  }

  void button() {
    if (haptics) HapticFeedback.selectionClick();
  }

  void win() {
    if (haptics) {
      HapticFeedback.mediumImpact();
      Future.delayed(const Duration(milliseconds: 160), HapticFeedback.heavyImpact);
    }
  }
}
