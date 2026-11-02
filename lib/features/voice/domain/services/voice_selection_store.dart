/// Where the chosen voice is remembered between launches.
abstract interface class VoiceSelectionStore {
  Future<String?> readSelection();
  Future<void> writeSelection(String value);
}
