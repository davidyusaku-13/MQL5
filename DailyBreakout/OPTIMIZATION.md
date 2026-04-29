# DailyBreakout Optimization

Use staged optimization. Do not optimize every input at once. Too many
combinations overfit fast.

Target: `XAUUSD` in MT5 Strategy Tester.

## Fixed Inputs

Do not optimize these first.

| Param          |              Value |
| -------------- | -----------------: |
| `magic_number` |              fixed |
| `autolot`      |            `false` |
| `base_balance` |              fixed |
| `lot`          | fixed, e.g. `0.01` |
| `min_lot`      |         broker min |
| `max_lot`      |         broker max |

## Phase 1: Core Edge

| Param              | Start | Step |   Stop |
| ------------------ | ----: | ---: | -----: |
| `range_start_time` |   `0` | `30` |  `600` |
| `range_duration`   |  `60` | `30` |  `480` |
| `stop_loss`        |  `40` | `10` |  `160` |
| `take_profit`      |   `0` | `25` |  `300` |
| `range_close_time` | `900` | `60` | `1380` |
| `breakout_mode`    |   `0` |  `1` |    `1` |

`breakout_mode`: `0 = BREAKOUT_ONE_PER_RANGE`, `1 = BREAKOUT_BOTH_DIRECTIONS`.

## Phase 2: Range Filter

Keep best Phase 1 values. Then optimize:

| Param            |  Start |  Step |   Stop |
| ---------------- | -----: | ----: | -----: |
| `min_range_size` |    `0` | `100` | `1200` |
| `max_range_size` | `1000` | `250` | `4000` |

Avoid `min_range_size > max_range_size`; EA rejects invalid combinations.

## Phase 3: Trailing

Keep best Phase 1 and Phase 2 values. Then optimize:

| Param            | Start |  Step |   Stop |
| ---------------- | ----: | ----: | -----: |
| `trailing_stop`  |   `0` | `100` | `1200` |
| `trailing_start` |   `0` | `100` | `2000` |

Prefer `trailing_start >= trailing_stop`. Smaller `trailing_start` than
`trailing_stop` often creates noisy results.

## Phase 4: Weekday Filters

Run all weekdays enabled first. Test weekday filtering last.

| Param                |   Start |   Step |   Stop |
| -------------------- | ------: | -----: | -----: |
| `range_on_monday`    | `false` | `true` | `true` |
| `range_on_tuesday`   | `false` | `true` | `true` |
| `range_on_wednesday` | `false` | `true` | `true` |
| `range_on_thursday`  | `false` | `true` | `true` |
| `range_on_friday`    | `false` | `true` | `true` |

Weekday filters overfit easily. Use only if out-of-sample remains stable.

## Selection Rules

Prefer robust clusters, not one lonely best result.

- Profit factor above `1.2`.
- Drawdown controlled.
- Trade count above `200`.
- Recovery factor high.
- Neighboring parameter sets stay decent.
