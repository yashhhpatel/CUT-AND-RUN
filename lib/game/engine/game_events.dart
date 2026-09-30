/// Side-effect notifications emitted by the pure gameplay world. The screen
/// controller turns them into audio, haptics and HUD feedback, keeping the
/// simulation free of Flutter/UI dependencies.
enum GameEventType {
  cut,
  crack,
  deflect,
  tooSlow,
  perfectCut,
  chain,
  collect,
  coin,
  combine,
  perfectCollect,
  perfectDodge,
  perfectGate,
  gatePass,
  gateFail,
  powerUp,
  shieldBreak,
  relicSaved,
  relicBroken,
  comboUp,
  land,
  crash,
  complete,
}

class GameEvent {
  const GameEvent(this.type, [this.value = 0]);
  final GameEventType type;
  final int value;
}
