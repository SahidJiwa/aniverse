# AniVerse Home Redesign

## Goal

Transform Home from:

- Anime dashboard

Into:

- Living Anime Universe Lobby

---

## Core Rules

- Single viewport
- No vertical scrolling
- No CustomScrollView
- No SingleChildScrollView
- No Slivers
- Home must fit inside one screen

If screen is small:

- Reduce typography
- Reduce artwork height
- Compress world state
- Never introduce scrolling

---

## Design Philosophy

User should feel:

"I entered an anime universe."

Not:

"I opened an anime application."

---

## Categories

### Identity

- Avatar
- Username
- Title
- Level
- XP
- Current Journey

### World State

- Active rooms
- Friends online
- Voice activity
- Global activity

### Action

- Notifications
- Continue watching
- Join room
- Create room

### Progress

- XP
- Missions

### Atmosphere

- Nebula
- Sakura particles
- Bloom
- Gradients
- Wordmark

---

## Final Home Structure

Top Rail

↓

Protagonist Field

↓

World Pulse

↓

Lobby Dock

↓

Atmosphere Bar

---

## Important Decisions

- Community does not belong on Home
- Missions are embedded into Identity
- Current Journey appears only once
- World Pulse is not a section
- Home is a Lobby