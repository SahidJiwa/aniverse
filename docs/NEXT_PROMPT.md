# NEXT PROMPT

Read these files FIRST:

docs/AI_RULES.md
docs/PROJECT_STATE.md
docs/CURRENT_FILES.md
docs/CURRENT_TASK.md
docs/LAST_KNOWN_STATE.md
docs/ANIVERSE_HOME_REDESIGN.md

Do not ask questions already answered inside those files.

Current approved architecture:

Top Rail
Protagonist Zone
World Pulse
Progress Rail
Primary Action
Lobby Dock
Atmosphere Bar

Architecture Version:
V4 Approved

Current status:

- Research complete
- Widget inventory complete
- Zone mapping complete
- Wireframe V4 approved
- No coding started

Next task:

PHASE 1

Replace current Home Screen root architecture with:

Stack(
  Background,
  TopRail,
  ProtagonistZone,
  WorldPulse,
  ProgressRail,
  PrimaryAction,
  LobbyDock,
  AtmosphereBar,
)

Rules:

- No Community section
- No CustomScrollView
- No SliverToBoxAdapter
- No vertical dashboard sections
- No new features
- Keep recommendation engine untouched
- Keep continue watching logic untouched
- Keep anime fetching untouched

Before writing code:

1. Read all docs
2. Verify current home_screen.dart structure
3. Produce migration diff
4. Then implement Phase 1