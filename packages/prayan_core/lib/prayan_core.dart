/// Prayan Trading Journal — domain engine.
///
/// Pure Dart: no Flutter, no Firebase, no IO. Everything authoritative the
/// product computes — money arithmetic, trade metrics, rule evaluation and the
/// discipline score — lives here so it can be unit tested on the VM, mirrored
/// by the Cloud Functions backend, and reused by a future web client without
/// touching the mobile UI (brief §29, §35).
library;

export 'src/calc/performance_metrics.dart';
export 'src/calc/trade_calculator.dart';
export 'src/coaching/coaching_facts.dart';
export 'src/coaching/insight_engine.dart';
export 'src/import/csv_import.dart';
export 'src/models/account.dart';
export 'src/models/enums.dart';
export 'src/models/rule.dart';
export 'src/models/trade.dart';
export 'src/money/currency.dart';
export 'src/money/dec.dart';
export 'src/money/money.dart';
export 'src/rules/rule_templates.dart';
export 'src/rules/rules_engine.dart';
export 'src/scoring/discipline_score.dart';
export 'src/scoring/streaks.dart';
export 'src/util/trading_day.dart';
