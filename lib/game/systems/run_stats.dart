/// Everything measured during a single run. Objectives, stars, achievements
/// and the result screen are all computed from this.
class RunStats {
  int score = 0;
  int cuts = 0;
  int perfectCuts = 0;
  int chainCuts = 0;
  int bestChain = 0;
  int piecesCollected = 0;
  int shardsCollected = 0;
  int coinsCollected = 0;
  int combines = 0;
  int bestCombo = 0;
  int collisions = 0;
  int perfectDodges = 0;
  int perfectCollects = 0;
  int perfectGates = 0;
  int gatesPassed = 0;
  int gateFails = 0;
  int relicsSaved = 0;
  int relicsBroken = 0;
  int specialCuts = 0;
  int riskRoutes = 0;
  int powerUpsUsed = 0;
  double distance = 0;
  double time = 0;
  bool shieldAtEnd = false;
  int finalShards = 0;
}
