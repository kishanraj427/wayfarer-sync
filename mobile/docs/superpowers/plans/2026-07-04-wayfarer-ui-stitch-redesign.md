# Wire — Stitch UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reskin the Wire the Stitch design language (token-driven, light + dark), add a bottom-nav shell with a new Profile tab and Trips search, and give users a real first/last name (small backend change) for name-based avatars.

**Architecture:** All visual change flows from the central theme token layer (`core/theme/`), so screens/widgets never hardcode colors. A `StatefulShellRoute` adds a 2-tab shell (Trips · Profile). Two shared utils — a name monogram and a no-emoji input formatter — are consumed across screens. A separate backend PR adds `firstName`/`lastName` to the `User` model and signup.

**Tech Stack:** Flutter, Riverpod 3, go_router, flutter_map, google_fonts (Plus Jakarta Sans + JetBrains Mono), shared_preferences. Backend: Bun, Express, Prisma (custom client at `src/generated/prisma`), Zod v4, `bun:test`.

**Design source of truth:** `wayfarer-sync/mobile/docs/superpowers/specs/2026-07-04-wayfarer-ui-stitch-redesign-design.md`.

## Global Constraints

- **DO NOT COMMIT.** Standing user instruction. Every task ends with a **Checkpoint** that runs verification and leaves changes in the working tree. The `git commit` step of normal TDD is replaced by the Checkpoint. Do not run `git commit` or `git push`.
- **No hardcoded UI.** No raw hex, `Color(0x…)`, or inline `style`/color literals in screens/widgets. Only `core/theme/appTokens.dart` holds literal colors. Everything else uses `ColorScheme`, `context.semantic.*`, `Theme.of(context).textTheme` / `monoData`, `AppSpace`, `AppRadius`.
- **Light + dark.** Every token has a light and dark value.
- **File naming.** New files `snake_case`; existing `camelCase` files keep their names (no bulk rename).
- **One package per change set.** Backend (Phase 0) is its own PR; mobile is the rest.
- **No emoji in any input** (mobile formatter + backend Zod refine). **No profile pictures** (monogram only).
- **Zod v4:** `z.uuid()` is strict RFC 4122 — test fixtures use valid v4 UUIDs (version nibble `4`, variant nibble `8/9/a/b`), e.g. `11111111-1111-4111-8111-111111111111`.
- **Never edit** `**/generated/**` or `*.g.dart` by hand.
- **Verification split:** Backend (Phase 0) is verifiable in this environment (`bun test`). Mobile has no Flutter here — mobile `flutter analyze` / `flutter test` are run by the user; the plan still writes tests and records expected outcomes.

---

## Phase 0 — Backend: user first/last name (separate PR)

### Task 1: Add `firstName` / `lastName` to the User schema

**Files:**
- Modify: `wayfarer-sync/backend/prisma/user.prisma`
- Modify: `wayfarer-sync/backend/schema/user.ts`
- Modify: `wayfarer-sync/backend/schema/auth.ts`

**Interfaces:**
- Produces: `safeNameSchema` (Zod), `signupInputSchema` now `{ email, password, firstName, lastName }`, `userSchema` now includes nullable `firstName`/`lastName`.

- [ ] **Step 1: Add the Prisma columns**

In `prisma/user.prisma`, add two nullable fields to `model User` (nullable so existing rows need no migration):

```prisma
model User {
  id          String       @id @default(uuid()) @db.Uuid
  email       String       @unique
  password    String // hashed
  firstName   String?
  lastName    String?
  lastLoginAt DateTime?
  createdAt   DateTime     @default(now())
  updatedAt   DateTime     @updatedAt
  deletedAt   DateTime?
  trips       TripMember[]
  pathPoints  PathPoint[]
}
```

- [ ] **Step 2: Push schema + regenerate client**

Run: `cd wayfarer-sync/backend && bunx prisma db push`
Expected: "Your database is now in sync with your Prisma schema." and the client regenerates under `src/generated/prisma` (do not hand-edit it).

- [ ] **Step 3: Add the shared name validator + extend signup schema**

In `schema/auth.ts`, add an emoji-rejecting name schema and wire it into signup:

```ts
import { z } from "zod";
import { userSchema } from "./user";

// Covers the common emoji / pictograph / regional-indicator / ZWJ ranges so a
// non-mobile client cannot push characters that crash the DB/BE.
const EMOJI_REGEX =
  /[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}\u{20E3}]/u;

export const safeNameSchema = z
  .string()
  .trim()
  .min(1)
  .max(50)
  .refine((value) => !EMOJI_REGEX.test(value), {
    message: "Name must not contain emoji.",
  });

export const signupInputSchema = z.object({
  email: z.email(),
  password: z.string().min(6),
  firstName: safeNameSchema,
  lastName: safeNameSchema,
});

export const loginInputSchema = z.object({
  email: z.email(),
  password: z.string(),
});

export const authResponseSchema = z.object({
  token: z.string(),
  user: userSchema,
});

export type SignupInput = z.infer<typeof signupInputSchema>;
export type LoginInput = z.infer<typeof loginInputSchema>;
export type AuthResponse = z.infer<typeof authResponseSchema>;
```

- [ ] **Step 4: Extend the read model**

In `schema/user.ts`, add the nullable names so they round-trip through `userSchema.parse(...)` in the auth responses:

```ts
import { z } from "zod";
import { baseSchema } from "./base";

export const userSchema = baseSchema.extend({
  email: z.email(),
  firstName: z.string().nullable(),
  lastName: z.string().nullable(),
  lastLoginAt: z.iso.datetime().optional().readonly(),
});

export type User = z.infer<typeof userSchema>;
```

- [ ] **Step 5: Typecheck**

Run: `cd wayfarer-sync/backend && bunx tsc --noEmit`
Expected: no errors in `schema/*.ts`.

- [ ] **Step 6: Checkpoint (DO NOT COMMIT)**

Leave changes in the working tree. Verify `git status` shows modified `prisma/user.prisma`, `schema/user.ts`, `schema/auth.ts` and the regenerated client.

---

### Task 2: Persist names in signup + service, with tests

**Files:**
- Modify: `wayfarer-sync/backend/src/services/auth.service.ts`
- Modify: `wayfarer-sync/backend/src/controllers/auth.controller.ts`
- Create: `wayfarer-sync/backend/src/tests/auth.test.ts`
- Modify: `wayfarer-sync/backend/README.md`

**Interfaces:**
- Consumes: `signupInputSchema`, `safeNameSchema` (Task 1).
- Produces: `createUser(email, password, firstName, lastName)`; `signup` validates the body and returns `{ token, user: { …, firstName, lastName }, success }`.

- [ ] **Step 1: Write the failing test**

Create `src/tests/auth.test.ts` (mirrors the `joinTrip.test.ts` mock pattern):

```ts
import { test, expect, mock, describe, beforeEach } from "bun:test";

const mockUserFindUnique = mock((_args: any) => Promise.resolve<any>(null));
const mockUserCreate = mock((_args: any) => Promise.resolve<any>(null));

mock.module("../prisma", () => ({
  default: {
    user: { findUnique: mockUserFindUnique, create: mockUserCreate },
  },
}));

// Avoid a real bcrypt hash / jwt secret dependency in the controller path.
mock.module("bcryptjs", () => ({
  default: { hash: (value: string) => Promise.resolve(`hashed:${value}`) },
}));
mock.module("jsonwebtoken", () => ({
  default: { sign: () => "test-token" },
}));

import { signup } from "../controllers/auth.controller";

const USER_ID = "22222222-2222-4222-8222-222222222222";

const makeReq = (body: any) => ({ body }) as any;
const makeRes = () => {
  const res: any = { statusCode: 200, body: undefined };
  res.status = (code: number) => ((res.statusCode = code), res);
  res.json = (body: any) => ((res.body = body), res);
  return res;
};

const validBody = {
  email: "kunal@essentia.dev",
  password: "secret123",
  firstName: "Kunal",
  lastName: "Sharma",
};

describe("signup", () => {
  beforeEach(() => {
    mockUserFindUnique.mockReset();
    mockUserCreate.mockReset();
    mockUserFindUnique.mockResolvedValue(null);
    mockUserCreate.mockImplementation((args: any) =>
      Promise.resolve({
        id: USER_ID,
        email: args.data.email,
        firstName: args.data.firstName,
        lastName: args.data.lastName,
        lastLoginAt: new Date().toISOString(),
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
        deletedAt: null,
      }),
    );
  });

  test("stores and echoes first/last name", async () => {
    const res = makeRes();
    await signup(makeReq(validBody), res);
    expect(res.statusCode).toBe(201);
    expect(mockUserCreate.mock.calls[0][0].data.firstName).toBe("Kunal");
    expect(res.body.user.firstName).toBe("Kunal");
    expect(res.body.user.lastName).toBe("Sharma");
  });

  test("rejects a blank name with 400", async () => {
    const res = makeRes();
    await signup(makeReq({ ...validBody, firstName: "   " }), res);
    expect(res.statusCode).toBe(400);
  });

  test("rejects an emoji name with 400", async () => {
    const res = makeRes();
    await signup(makeReq({ ...validBody, lastName: "Sharma😀" }), res);
    expect(res.statusCode).toBe(400);
  });
});
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd wayfarer-sync/backend && bun test src/tests/auth.test.ts`
Expected: FAIL — signup doesn't validate names / `createUser` ignores names.

- [ ] **Step 3: Update the service**

In `src/services/auth.service.ts`, extend `createUser`:

```ts
export const createUser = async (
  email: string,
  password: string,
  firstName: string,
  lastName: string,
) => {
  const hashed = await bcrypt.hash(password, 10);
  return prisma.user.create({
    data: { email, password: hashed, firstName, lastName, lastLoginAt: new Date() },
  });
};
```

- [ ] **Step 4: Validate + pass names in the controller**

In `src/controllers/auth.controller.ts`, validate the body with `signupInputSchema` and forward the names:

```ts
import { Request, Response } from "express";
import { AuthRequest } from "../middleware/auth.middleware";
import { userSchema } from "../../schema";
import { signupInputSchema } from "../../schema/auth";
import * as authService from "../services/auth.service";
import { toJSON } from "@/utils/converter";

export const signup = async (req: Request, res: Response) => {
  const parsed = signupInputSchema.safeParse(req.body);
  if (!parsed.success) {
    res.status(400).json({ error: parsed.error.issues[0]?.message ?? "Invalid input", success: false });
    return;
  }
  const { email, password, firstName, lastName } = parsed.data;

  const existing = await authService.findUserByEmail(email);
  if (existing) {
    res.status(409).json({ error: "Email already exists" });
    return;
  }

  const user = await authService.createUser(email, password, firstName, lastName);
  const token = authService.generateToken(user.id);

  res.status(201).json({ token, user: userSchema.parse(toJSON(user)), success: true });
};
```

Leave `login` and `getMe` unchanged (they already return `userSchema.parse(...)`, which now includes the names).

> If `src/routes/auth.route.ts` already runs a validation middleware for signup, the controller `safeParse` is still correct and harmless; keep it so the 400 behavior is guaranteed by the test.

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd wayfarer-sync/backend && bun test src/tests/auth.test.ts`
Expected: PASS (3 tests). Then `bun test` — the 3 pre-existing WebSocket integration tests may time out; all other suites pass.

- [ ] **Step 6: Update the backend README**

In `wayfarer-sync/backend/README.md`, update the signup docs: request body now `{ email, password, firstName, lastName }` (names required, 1–50 chars, no emoji → 400); the `user` object in every auth response (`signup`/`login`/`me`) now includes `firstName` and `lastName` (nullable for legacy accounts).

- [ ] **Step 7: Checkpoint (DO NOT COMMIT)**

Leave changes in the working tree. This completes the backend PR.

---

## Phase 1 — Mobile foundation (token remap + shared utils)

### Task 3: Remap the palette (`AppPalette`)

**Files:**
- Modify: `wayfarer-sync/mobile/lib/core/theme/appTokens.dart`

**Interfaces:**
- Produces: `AppPalette` static colors used only by `appTheme.dart` and `appSemanticColors.dart`. `AppSpace`/`AppRadius` unchanged (add `AppRadius.xl`).

- [ ] **Step 1: Replace the palette with the Stitch values**

Rewrite the `AppPalette` class (keep `AppSpace` as-is; add `AppRadius.xl`). Values from spec §3.1:

```dart
import 'package:flutter/material.dart';

/// Raw palette. The ONLY place literal colors live; consumed exclusively by the
/// theme builders and the semantic color extension.
abstract final class AppPalette {
  // Light
  static const accent = Color(0xFFFF5722);
  static const onAccent = Color(0xFFFFFFFF);
  static const rust = Color(0xFFB02F00);
  static const background = Color(0xFFF8F9FA);
  static const surface = Color(0xFFFFFFFF);
  static const onSurface = Color(0xFF191C1D);
  static const onSurfaceVariant = Color(0xFF5B4039);
  static const hairline = Color(0xFFE4BEB4);
  static const green = Color(0xFF1B6D24);
  static const greenContainer = Color(0xFFA0F399);
  static const onGreenContainer = Color(0xFF217128);
  static const blue = Color(0xFF005CAB);
  static const blueContainer = Color(0xFF1775D1);
  static const error = Color(0xFFBA1A1A);
  static const errorContainer = Color(0xFFFFDAD6);
  static const endedContainer = Color(0xFFE1E3E4);
  static const glassFillLight = Color(0xCCFFFFFF);
  static const contourLight = Color(0x14191C1D);
  static const accentSubtleLight = Color(0x1AFF5722);

  // Dark (derived from the same roles)
  static const accentDark = Color(0xFFFF8A65);
  static const onAccentDark = Color(0xFF591C00);
  static const rustDark = Color(0xFFFFB5A0);
  static const backgroundDark = Color(0xFF1A1110);
  static const surfaceDark = Color(0xFF241A18);
  static const onSurfaceDark = Color(0xFFF0E0DB);
  static const onSurfaceVariantDark = Color(0xFFD8C2BA);
  static const hairlineDark = Color(0xFF3A2C28);
  static const greenDark = Color(0xFF88D982);
  static const greenContainerDark = Color(0xFF005312);
  static const onGreenContainerDark = Color(0xFFA3F69C);
  static const blueDark = Color(0xFFA5C8FF);
  static const blueContainerDark = Color(0xFF004786);
  static const errorDark = Color(0xFFFFB4AB);
  static const errorContainerDark = Color(0xFF93000A);
  static const endedContainerDark = Color(0xFF3A2C28);
  static const glassFillDark = Color(0xCC241A18);
  static const contourDark = Color(0x1AF0E0DB);
  static const accentSubtleDark = Color(0x24FF8A65);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

abstract final class AppRadius {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 20.0;
}
```

- [ ] **Step 2: Checkpoint (DO NOT COMMIT)**

This file will not compile against `appTheme.dart`/`appSemanticColors.dart` until Tasks 4–5 update those references. Do them before running `flutter analyze`.

---

### Task 4: Rewire the semantic colors (`AppSemanticColors`)

**Files:**
- Modify: `wayfarer-sync/mobile/lib/core/theme/appSemanticColors.dart`

**Interfaces:**
- Consumes: `AppPalette` (Task 3).
- Produces: `AppSemanticColors` with existing fields repointed + new fields `activeContainer`, `onActiveContainer`, `endedContainer`, `statValue`. Accessor `context.semantic.*` unchanged.

- [ ] **Step 1: Add fields + repoint light/dark**

Add four fields to the class, constructor, `light`, `dark`, `copyWith`, and `lerp`. Repoint existing fields to the new palette:

```dart
// New fields on the class:
final Color activeContainer;
final Color onActiveContainer;
final Color endedContainer;
final Color statValue;
```

`light` values:

```dart
static const light = AppSemanticColors(
  route: AppPalette.accent,
  routeSubtle: AppPalette.accentSubtleLight,
  onRoute: AppPalette.onAccent,
  signalOnline: AppPalette.green,
  signalPending: AppPalette.blue,
  hairline: AppPalette.hairline,
  glassFill: AppPalette.glassFillLight,
  glassStroke: AppPalette.hairline,
  contour: AppPalette.contourLight,
  selfMarker: AppPalette.accent,
  destinationPin: AppPalette.accent,
  peerFallback: AppPalette.blue,
  onMarker: AppPalette.onAccent,
  activeContainer: AppPalette.greenContainer,
  onActiveContainer: AppPalette.onGreenContainer,
  endedContainer: AppPalette.endedContainer,
  statValue: AppPalette.rust,
);
```

`dark` values:

```dart
static const dark = AppSemanticColors(
  route: AppPalette.accentDark,
  routeSubtle: AppPalette.accentSubtleDark,
  onRoute: AppPalette.onAccentDark,
  signalOnline: AppPalette.greenDark,
  signalPending: AppPalette.blueDark,
  hairline: AppPalette.hairlineDark,
  glassFill: AppPalette.glassFillDark,
  glassStroke: AppPalette.hairlineDark,
  contour: AppPalette.contourDark,
  selfMarker: AppPalette.accentDark,
  destinationPin: AppPalette.accentDark,
  peerFallback: AppPalette.blueDark,
  onMarker: AppPalette.onAccentDark,
  activeContainer: AppPalette.greenContainerDark,
  onActiveContainer: AppPalette.onGreenContainerDark,
  endedContainer: AppPalette.endedContainerDark,
  statValue: AppPalette.rustDark,
);
```

Add the four fields to `copyWith` (param + `?? this.`) and `lerp` (`Color.lerp(...)!`) following the existing pattern for every other field.

- [ ] **Step 2: Checkpoint (DO NOT COMMIT)** — completes with Task 5.

---

### Task 5: Update the theme builder (`appTheme.dart`)

**Files:**
- Modify: `wayfarer-sync/mobile/lib/core/theme/appTheme.dart`

**Interfaces:**
- Consumes: `AppPalette`, `AppSemanticColors` (Tasks 3–4).
- Produces: `buildLightTheme()`, `buildDarkTheme()`, `monoData(...)` (unchanged signature).

- [ ] **Step 1: Repoint surfaces/text, switch display font, set explicit scheme colors**

In `_buildTheme`, replace the `background`/`surface`/`textHi`/`textLo` locals and the `colorScheme` with palette-driven values, switch `display(...)` to Plus Jakarta Sans, and align the type scale to the mockup:

```dart
final background = isDark ? AppPalette.backgroundDark : AppPalette.background;
final surface = isDark ? AppPalette.surfaceDark : AppPalette.surface;
final textHi = isDark ? AppPalette.onSurfaceDark : AppPalette.onSurface;
final textLo = isDark ? AppPalette.onSurfaceVariantDark : AppPalette.onSurfaceVariant;

final colorScheme = ColorScheme.fromSeed(
  seedColor: semantic.route,
  brightness: brightness,
).copyWith(
  surface: surface,
  onSurface: textHi,
  onSurfaceVariant: textLo,
  primary: semantic.route,
  onPrimary: semantic.onRoute,
  secondary: semantic.signalOnline,
  secondaryContainer: semantic.activeContainer,
  onSecondaryContainer: semantic.onActiveContainer,
  tertiary: semantic.peerFallback,
  error: isDark ? AppPalette.errorDark : AppPalette.error,
  errorContainer: isDark ? AppPalette.errorContainerDark : AppPalette.errorContainer,
  outline: semantic.hairline,
);

TextStyle display(double size, FontWeight weight) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: textHi);
TextStyle body(double size, FontWeight weight, Color color) =>
    GoogleFonts.plusJakartaSans(fontSize: size, fontWeight: weight, color: color);

final textTheme = TextTheme(
  displaySmall: display(24, FontWeight.w700),
  headlineSmall: display(22, FontWeight.w700),
  titleLarge: display(18, FontWeight.w600),
  titleMedium: body(16, FontWeight.w600, textHi),
  bodyLarge: body(14, FontWeight.w400, textHi),
  bodyMedium: body(14, FontWeight.w400, textLo),
  labelLarge: body(12, FontWeight.w600, textHi),
);
```

Keep `monoData(...)` as `GoogleFonts.jetBrainsMono`. Leave the `appBarTheme`/`cardTheme`/`inputDecorationTheme`/`elevatedButtonTheme`/etc. bodies as-is — they already reference `semantic.*` and the `textTheme`, so they inherit the new palette. Update `appBarTheme.titleTextStyle` to `display(22, FontWeight.w700)`.

- [ ] **Step 2: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors from `core/theme/**`. The whole app now renders in the Stitch palette.

- [ ] **Step 3: Checkpoint (DO NOT COMMIT)**

---

### Task 6: Name monogram util

**Files:**
- Create: `wayfarer-sync/mobile/lib/core/util/name_monogram.dart`
- Create: `wayfarer-sync/mobile/test/name_monogram_test.dart`

**Interfaces:**
- Produces: `String nameMonogram({String? firstName, String? lastName, required String email})`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/util/name_monogram.dart';

void main() {
  test('uses first + last initials', () {
    expect(nameMonogram(firstName: 'Kunal', lastName: 'Sharma', email: 'k@x.com'), 'KS');
  });
  test('single name falls back to its initial', () {
    expect(nameMonogram(firstName: 'Kunal', lastName: '', email: 'k@x.com'), 'K');
  });
  test('no name falls back to email first+middle', () {
    expect(nameMonogram(firstName: null, lastName: null, email: 'kunal@essentia.dev'), 'KN');
  });
  test('empty local part yields ?', () {
    expect(nameMonogram(firstName: '', lastName: '', email: '@x.com'), '?');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd wayfarer-sync/mobile && flutter test test/name_monogram_test.dart`
Expected: FAIL — `name_monogram.dart` doesn't exist.

- [ ] **Step 3: Implement**

```dart
/// Derives a 1–2 char avatar label. The backend stores no profile picture, so
/// avatars are always a monogram: first + last initials, with an email fallback
/// for legacy accounts created before names existed.
String nameMonogram({String? firstName, String? lastName, required String email}) {
  final first = (firstName ?? '').trim();
  final last = (lastName ?? '').trim();
  if (first.isNotEmpty && last.isNotEmpty) {
    return (first[0] + last[0]).toUpperCase();
  }
  if (first.isNotEmpty) return first[0].toUpperCase();
  if (last.isNotEmpty) return last[0].toUpperCase();
  return _emailMonogram(email);
}

String _emailMonogram(String email) {
  final local = email.split('@').first.replaceAll(RegExp(r'[^A-Za-z0-9]'), '');
  if (local.isEmpty) return '?';
  if (local.length == 1) return local.toUpperCase();
  return (local[0] + local[local.length ~/ 2]).toUpperCase();
}
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd wayfarer-sync/mobile && flutter test test/name_monogram_test.dart`
Expected: PASS (4 tests).

- [ ] **Step 5: Checkpoint (DO NOT COMMIT)**

---

### Task 7: No-emoji input formatter util

**Files:**
- Create: `wayfarer-sync/mobile/lib/core/util/text_input_rules.dart`
- Create: `wayfarer-sync/mobile/test/text_input_rules_test.dart`

**Interfaces:**
- Produces: `const noEmojiFormatter` (a `TextInputFormatter`), and `List<TextInputFormatter> inputRules([List<TextInputFormatter>? extra])` for screens to spread into `TextField(inputFormatters: …)`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/core/util/text_input_rules.dart';

TextEditingValue _apply(String text) => noEmojiFormatter.formatEditUpdate(
      const TextEditingValue(text: ''),
      TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length)),
    );

void main() {
  test('strips emoji, keeps letters/digits/punctuation', () {
    expect(_apply('Kunal😀 Sharma!').text, 'Kunal Sharma!');
  });
  test('leaves plain text untouched', () {
    expect(_apply('alex.w@x.com').text, 'alex.w@x.com');
  });
  test('inputRules includes the no-emoji formatter', () {
    expect(inputRules().contains(noEmojiFormatter), isTrue);
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd wayfarer-sync/mobile && flutter test test/text_input_rules_test.dart`
Expected: FAIL — file missing.

- [ ] **Step 3: Implement**

```dart
import 'package:flutter/services.dart';

// Emoji / pictograph / regional-indicator / ZWJ / variation-selector ranges.
// Named (not inline) per the no-hardcode rule; lowerCamel to satisfy the Dart
// `constant_identifier_names` lint.
final RegExp _emojiRegExp = RegExp(
  r'[\u{1F000}-\u{1FAFF}\u{2600}-\u{27BF}\u{2190}-\u{21FF}\u{2B00}-\u{2BFF}'
  r'\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}\u{20E3}\u{2122}\u{2139}]',
  unicode: true,
);

class _NoEmojiFormatter extends TextInputFormatter {
  const _NoEmojiFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    if (!_emojiRegExp.hasMatch(newValue.text)) return newValue;
    final cleaned = newValue.text.replaceAll(_emojiRegExp, '');
    return TextEditingValue(
      text: cleaned,
      selection: TextSelection.collapsed(offset: cleaned.length),
    );
  }
}

/// Blocks emoji so nothing that can crash the backend/DB reaches a request body.
const TextInputFormatter noEmojiFormatter = _NoEmojiFormatter();

/// Baseline formatters every text input opts into, plus any screen-specific extras.
List<TextInputFormatter> inputRules([List<TextInputFormatter>? extra]) =>
    [noEmojiFormatter, ...?extra];
```

- [ ] **Step 4: Run to verify it passes**

Run: `cd wayfarer-sync/mobile && flutter test test/text_input_rules_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Checkpoint (DO NOT COMMIT)**

---

## Phase 2 — Nav shell + Profile scaffold

### Task 8: Bottom-nav shell + Profile route

**Files:**
- Create: `wayfarer-sync/mobile/lib/core/widgets/app_scaffold_shell.dart`
- Create: `wayfarer-sync/mobile/lib/features/profile/screens/profile_screen.dart` (scaffold only)
- Modify: `wayfarer-sync/mobile/lib/core/network/router.dart`

**Interfaces:**
- Consumes: theme (Tasks 3–5).
- Produces: `AppScaffoldShell(navigationShell)` widget; `/trips` + `/profile` live inside a `StatefulShellRoute.indexedStack`.

- [ ] **Step 1: Create the shell widget**

```dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/appSemanticColors.dart';

class AppScaffoldShell extends StatelessWidget {
  final StatefulNavigationShell navigationShell;
  const AppScaffoldShell({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          initialLocation: index == navigationShell.currentIndex,
        ),
        indicatorColor: context.semantic.activeContainer,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.flight_takeoff_outlined),
            selectedIcon: Icon(Icons.flight_takeoff),
            label: 'Trips',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Create the Profile scaffold (filled in Task 15)**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(child: Text('Profile')),
    );
  }
}
```

- [ ] **Step 3: Wrap `/trips` + `/profile` in a shell route**

In `router.dart`, add imports for `AppScaffoldShell` and `ProfileScreen`, and replace the standalone `/trips` `GoRoute` with a `StatefulShellRoute.indexedStack`. Leave `/login`, `/signup`, `/create-trip`, `/trip/:tripId/map/:userId` as top-level routes (full-screen, no bottom bar).

```dart
StatefulShellRoute.indexedStack(
  builder: (context, state, navigationShell) => AppScaffoldShell(navigationShell: navigationShell),
  branches: [
    StatefulShellBranch(routes: [
      GoRoute(path: '/trips', builder: (context, state) => const TripsScreen()),
    ]),
    StatefulShellBranch(routes: [
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
    ]),
  ],
),
```

Keep the existing `redirect` logic and the other `GoRoute`s. (Shell branch routes use `builder`, not the shared-axis `pageBuilder`, so the bottom bar stays put while tabs switch.)

- [ ] **Step 4: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors. App shows a 2-tab bottom bar; Profile tab shows the placeholder.

- [ ] **Step 5: Checkpoint (DO NOT COMMIT)**

---

## Phase 3 — Trips tab

### Task 9: Restyle `TripDashboardCard`

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/trip/widgets/trip_dashboard_card.dart`

**Interfaces:**
- Consumes: `Trip` model, `StatusPill`, `MemberAvatarCluster`, theme.
- Produces: unchanged constructor `TripDashboardCard({trip, onOpen, onShare, onEnd})`.

- [ ] **Step 1: Rework the layout to the mockup**

Match `Trips.html` card: title + destination sub-line on the left, `⋮` overflow on the right; a bottom row with the avatar cluster + "N members" on the left and the `StatusPill` on the right; a date line with a `calendar_today` icon + `monoData` date. Keep the existing `_memberColor`, `onOpen`/`onShare`/`onEnd` callbacks, and the ended-card opacity. Remove the duplicate `SizedBox(height: AppSpace.sm)` (there are currently two in a row). Add the "N members" label next to the cluster and a calendar row:

```dart
// inside build(), replacing the current bottom Row:
Row(
  crossAxisAlignment: CrossAxisAlignment.end,
  children: [
    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              MemberAvatarCluster(colors: memberColors, total: trip.memberCount),
              const SizedBox(width: AppSpace.sm),
              Text(
                trip.memberCount == 1 ? '1 member' : '${trip.memberCount} members',
                style: textTheme.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.sm),
          if (startText.isNotEmpty)
            Row(
              children: [
                Icon(Icons.calendar_today, size: 16, color: context.semantic.hairline),
                const SizedBox(width: AppSpace.xs),
                Text(startText, style: monoData(context, size: 11)),
              ],
            ),
        ],
      ),
    ),
    StatusPill(isActive: trip.isActive),
  ],
),
```

Move the date out of the title row (delete the inline `startText` `Text` next to the title) so it only appears in the calendar row. Keep the `PopupMenuButton` (Share always; End trip only when `trip.isActive`).

- [ ] **Step 2: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors; no unused `startText`/imports.

- [ ] **Step 3: Checkpoint (DO NOT COMMIT)**

---

### Task 10: Trips tab — active-only + stat row + search

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/trip/screens/tripsScreen.dart`

**Interfaces:**
- Consumes: `tripsProvider`, `TripDashboardCard`, `StatTile`, `SectionHeader`, `inputRules` (Task 7).
- Produces: `TripsScreen` (now `ConsumerStatefulWidget` to hold search state).

- [ ] **Step 1: Convert to stateful + add search state**

Change `TripsScreen` to `ConsumerStatefulWidget`. Hold `bool _searching = false;` and `String _query = '';` plus a `TextEditingController`. The app bar shows the title + a search `IconButton`; when `_searching`, the app bar `title` becomes a `TextField` (with `inputFormatters: inputRules()`), and a close `IconButton` resets `_searching`/`_query`. Remove the logout action (it moves to Profile in Task 15).

```dart
appBar: AppBar(
  title: _searching
      ? TextField(
          controller: _searchController,
          autofocus: true,
          inputFormatters: inputRules(),
          decoration: const InputDecoration(hintText: 'Search trips', border: InputBorder.none),
          onChanged: (value) => setState(() => _query = value),
        )
      : const Text('My trips'),
  actions: [
    IconButton(
      icon: Icon(_searching ? Icons.close : Icons.search),
      tooltip: _searching ? 'Close search' : 'Search',
      onPressed: () => setState(() {
        _searching = !_searching;
        if (!_searching) { _query = ''; _searchController.clear(); }
      }),
    ),
  ],
),
```

- [ ] **Step 2: Filter to active + query in `_Dashboard`**

In the `data:` branch, compute the active + filtered list and pass `_query` down. `_Dashboard` filters `trips.where((trip) => trip.isActive)` then, if `query` is non-empty, `.where((trip) => trip.title.toLowerCase().contains(q) || (trip.primaryDestination?.name.toLowerCase().contains(q) ?? false))`. Stat tiles compute from the **active** list (Active count, Travelers = sum of `memberCount`, Destinations = sum of `destinations.length`). Remove the "Ended" section entirely. Section header becomes `SectionHeader(label: 'Active Trips')`.

```dart
data: (trips) {
  final active = trips.where((trip) => trip.isActive).toList();
  final query = _query.trim().toLowerCase();
  final visible = query.isEmpty
      ? active
      : active.where((trip) =>
          trip.title.toLowerCase().contains(query) ||
          (trip.primaryDestination?.name.toLowerCase().contains(query) ?? false)).toList();
  if (active.isEmpty) return _EmptyView(onCreate: () => context.push('/create-trip'));
  if (visible.isEmpty) return _NoMatchView(query: _query);
  return _Dashboard(trips: active, visible: visible, userId: userId, ref: ref);
},
```

- [ ] **Step 3: Add the no-match empty state**

Add a small `_NoMatchView` stateless widget: centered text "No trips match '<query>'." using `textTheme.bodyMedium` and an `Icons.search_off` icon (`color: context.semantic.route`). Update `_Dashboard` to take `visible` for the card list while still using `trips` (active) for the stat row.

- [ ] **Step 4: Restyle the join dialog trigger unchanged**

Leave `_showJoinDialog` / `_joinTrip` behavior as-is (dialog restyle is Task 12). Ensure the `TextEditingController` is disposed in `dispose()`.

- [ ] **Step 5: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze && flutter test`
Expected: no errors; existing `trip_model_test.dart` still passes.

- [ ] **Step 6: Checkpoint (DO NOT COMMIT)**

---

## Phase 4 — Create + Join

### Task 11: Restyle Create Trip + apply emoji rule

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/trip/screens/createTripScreen.dart`

**Interfaces:**
- Consumes: `inputRules` (Task 7), theme, `tripRepositoryProvider`, `tripsProvider`.

- [ ] **Step 1: Apply the no-emoji rule to both text fields**

Add `inputFormatters: inputRules()` to the trip-name `TextField` and the destination-search `TextField`. (The pin marker already uses `context.semantic.route`; the button already uses `PrimaryButton`.)

- [ ] **Step 2: Restyle the "Trip created" dialog**

Replace the plain `AlertDialog` content with the new-system layout: a circular `Icons.check_circle` badge (`color: context.semantic.signalOnline`), "Trip created" heading (`textTheme.titleLarge`), the trip id in `monoData(context)`, and the existing Copy / Share / Open Live Map actions unchanged. No hardcoded colors.

- [ ] **Step 3: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors.

- [ ] **Step 4: Checkpoint (DO NOT COMMIT)**

---

### Task 12: Restyle the Join dialog + emoji rule

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/trip/screens/tripsScreen.dart` (`_JoinTripDialog`)

**Interfaces:**
- Consumes: `inputRules` (Task 7), theme.

- [ ] **Step 1: Rework `_JoinTripDialog` to the mockup**

Match `join trip.html`: a circular `group_add` icon badge (`context.semantic.route` fill, `onRoute` icon), "Join a Trip" title, helper text "Enter the Trip ID your group leader shared.", a `key`-prefixed input **labeled "Trip ID"** with `inputFormatters: inputRules()`, and "Join trip" (primary) + "Cancel" (secondary) buttons. Keep the behavior: non-empty → `Navigator.pop()` then `widget.onJoin(tripId)`.

```dart
content: Column(
  mainAxisSize: MainAxisSize.min,
  children: [
    CircleAvatar(
      radius: 24,
      backgroundColor: context.semantic.route,
      child: Icon(Icons.group_add, color: context.semantic.onRoute),
    ),
    const SizedBox(height: AppSpace.md),
    Text('Join a Trip', style: Theme.of(context).textTheme.titleLarge),
    const SizedBox(height: AppSpace.xs),
    Text('Enter the Trip ID your group leader shared.',
        style: Theme.of(context).textTheme.bodyMedium, textAlign: TextAlign.center),
    const SizedBox(height: AppSpace.md),
    TextField(
      controller: _controller,
      inputFormatters: inputRules(),
      decoration: const InputDecoration(
        labelText: 'Trip ID',
        prefixIcon: Icon(Icons.key),
      ),
    ),
  ],
),
```

- [ ] **Step 2: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors.

- [ ] **Step 3: Checkpoint (DO NOT COMMIT)**

---

## Phase 5 — Map overlays (visual only)

### Task 13: Restyle Trip Map overlays

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/tracking/screens/tripMapScreen.dart`

**Interfaces:**
- Consumes: theme, existing map/tracking state.
- **Do not touch** GPS, `_trailColorForUser`, `_zoomBy`, OSRM `_refreshRoutes`/`_routesToDestination`, sync, or lifecycle logic.

- [ ] **Step 1: Restyle the zoom/recenter controls**

Ensure the recenter, `+`, and `−` buttons are circular themed buttons: `color: Theme.of(context).colorScheme.surface`, icon `onSurface`, subtle border `context.semantic.hairline`. Reuse the existing `_zoomBy` and recenter callbacks — visual only.

- [ ] **Step 2: Restyle the member chips row**

Give each member chip the pill look: rounded surface background, colored avatar circle (member color), name in `textTheme.labelLarge`; the selected chip uses `context.semantic.activeContainer` / `onActiveContainer`. Keep the tap-to-center behavior and the destination chip (orange flag).

- [ ] **Step 3: Restyle the bottom info panel**

Wrap the bottom "Trip ID / Syncing" panel in the existing `GlassPanel` (or a themed container using `context.semantic.glassFill` + `glassStroke`). Show a "TRIP ID" label (`textTheme.labelLarge`, `onSurfaceVariant`), the id via `monoData(context)`, and a "Syncing…" row driven by the existing connectivity/sync state (a green dot `context.semantic.signalOnline`). No new state.

- [ ] **Step 4: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze`
Expected: no errors; trail colors and zoom still behave (manual smoke test on device).

- [ ] **Step 5: Checkpoint (DO NOT COMMIT)**

---

## Phase 6 — Profile content + Auth

### Task 14: Current-user model + provider (persisted, `/me` fallback)

**Files:**
- Create: `wayfarer-sync/mobile/lib/features/auth/models/current_user.dart`
- Create: `wayfarer-sync/mobile/lib/features/auth/providers/current_user_provider.dart`
- Create: `wayfarer-sync/mobile/test/current_user_test.dart`
- Modify: login + signup screens to persist the returned `user` (wired in Task 16)

**Interfaces:**
- Produces: `CurrentUser` (`id`, `email`, `firstName?`, `lastName?`, `displayName`, `fromJson`); `currentUserProvider` (a `FutureProvider<CurrentUser?>` or `AsyncNotifier`) reading persisted JSON, `/me` fallback; `persistCurrentUser(ref, json)` helper.

- [ ] **Step 1: Write the failing model test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:wayfarer_sync_mobile/features/auth/models/current_user.dart';

void main() {
  test('parses user json with names', () {
    final user = CurrentUser.fromJson({
      'id': 'u1', 'email': 'kunal@essentia.dev', 'firstName': 'Kunal', 'lastName': 'Sharma',
    });
    expect(user.displayName, 'Kunal Sharma');
  });
  test('falls back to email when names are null', () {
    final user = CurrentUser.fromJson({'id': 'u1', 'email': 'kunal@essentia.dev'});
    expect(user.displayName, 'kunal@essentia.dev');
  });
}
```

- [ ] **Step 2: Run to verify it fails**

Run: `cd wayfarer-sync/mobile && flutter test test/current_user_test.dart`
Expected: FAIL — model missing.

- [ ] **Step 3: Implement the model**

```dart
class CurrentUser {
  final String id;
  final String email;
  final String? firstName;
  final String? lastName;

  const CurrentUser({required this.id, required this.email, this.firstName, this.lastName});

  String get displayName {
    final full = [firstName, lastName].where((part) => (part ?? '').trim().isNotEmpty).join(' ').trim();
    return full.isEmpty ? email : full;
  }

  factory CurrentUser.fromJson(Map<String, dynamic> json) => CurrentUser(
        id: json['id'] as String,
        email: json['email'] as String,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'firstName': firstName, 'lastName': lastName};
}
```

- [ ] **Step 4: Implement the provider**

Create `current_user_provider.dart`: a `FutureProvider<CurrentUser?>` that (a) reads `current_user` JSON from `shared_preferences` and returns `CurrentUser.fromJson(...)` if present; (b) else, if a token exists, calls `GET /me` via the existing `apiClient`, caches the JSON, and returns it; (c) else returns `null`. Add `Future<void> persistCurrentUser(WidgetRef ref, Map<String, dynamic> userJson)` that writes the JSON to prefs and invalidates `currentUserProvider`. Use the same `SharedPreferences` access pattern as `authTokenProvider`/`storageProviders`.

- [ ] **Step 5: Run to verify model test passes**

Run: `cd wayfarer-sync/mobile && flutter test test/current_user_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 6: Checkpoint (DO NOT COMMIT)**

---

### Task 15: Profile content (identity, stats, history, account)

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/profile/screens/profile_screen.dart`
- Create: `wayfarer-sync/mobile/lib/features/profile/widgets/history_row.dart`
- Create: `wayfarer-sync/mobile/lib/features/profile/widgets/setting_row.dart`

**Interfaces:**
- Consumes: `currentUserProvider` (Task 14), `tripsProvider`, `themeModeProvider`, `authTokenProvider`, `nameMonogram` (Task 6), `StatTile`, `SectionHeader`.

- [ ] **Step 1: Build the Profile body**

Replace the placeholder body with sections:
1. **Identity** — a circular avatar (diameter via `AppSpace`, `context.semantic.route` fill, `onRoute` text) showing `nameMonogram(firstName: user.firstName, lastName: user.lastName, email: user.email)`, `user.displayName` as `textTheme.headlineSmall`, `user.email` as `textTheme.bodyMedium`. Render from `currentUserProvider.when(...)` with a `SkeletonBox` while loading.
2. **Travel Summary** — `SectionHeader(label: 'Travel Summary')` + a `Row` of three `StatTile`s: total trips, active trips, destinations (computed from `tripsProvider` data; guard the `AsyncValue`).
3. **Trip History** — `SectionHeader(label: 'Trip History')` + ended trips (`trips.where((trip) => !trip.isActive)`) as `HistoryRow`s; tapping pushes `/trip/${trip.id}/map/$userId`. Empty → "No past trips yet." (`textTheme.bodyMedium`).
4. **Account** — `SectionHeader(label: 'Account')` + a `SettingRow` with a theme light/dark `Switch` bound to `themeModeProvider`, and a `SettingRow` "Log out" (`context.semantic` error styling via `colorScheme.error`) calling `ref.read(authTokenProvider.notifier).clearToken()`.

- [ ] **Step 2: Implement `HistoryRow`**

A stateless row: leading rounded icon tile (`Icons.flight_takeoff`, `context.semantic.activeContainer` bg), title (`textTheme.titleMedium`), subtitle relative date via `intl` (`textTheme.bodyMedium`), trailing `Icons.chevron_right`. Constructor `HistoryRow({required this.title, required this.subtitle, required this.onTap})`.

- [ ] **Step 3: Implement `SettingRow`**

A stateless row: leading icon, label (`textTheme.titleMedium`), trailing `Widget? trailing` (e.g. a `Switch`) OR `onTap` for action rows. Constructor `SettingRow({required this.icon, required this.label, this.trailing, this.onTap, this.isDestructive = false})`; destructive uses `colorScheme.error` for icon+label.

- [ ] **Step 4: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze && flutter test`
Expected: no errors; monogram/current-user tests pass.

- [ ] **Step 5: Checkpoint (DO NOT COMMIT)**

---

### Task 16: Auth restyle — Signup names + confirm password + emoji rule + persist user

**Files:**
- Modify: `wayfarer-sync/mobile/lib/features/auth/screens/signupScreen.dart`
- Modify: `wayfarer-sync/mobile/lib/features/auth/screens/loginScreen.dart`

**Interfaces:**
- Consumes: `inputRules` (Task 7), `persistCurrentUser` (Task 14), theme, existing `apiClient`/`authTokenProvider`.

- [ ] **Step 1: Add First/Last name + Confirm password to Signup**

Add `_firstNameController`, `_lastNameController`, `_confirmController` (dispose all). Render four themed inputs (first name, last name, email, password, confirm password); every text field gets `inputFormatters: inputRules()`. Validation before the request:

```dart
if (_firstNameController.text.trim().isEmpty || _lastNameController.text.trim().isEmpty ||
    _emailController.text.trim().isEmpty || _passwordController.text.isEmpty) {
  setState(() => _errorMessage = 'All fields are required.');
  return;
}
if (_passwordController.text != _confirmController.text) {
  setState(() => _errorMessage = "Passwords don't match.");
  return;
}
```

Include `firstName`/`lastName` in the signup request body. On success, `await persistCurrentUser(ref, response.user)` before navigating (so Profile has the name immediately). Keep the existing token-store + redirect flow.

- [ ] **Step 2: Persist user on Login too**

In `loginScreen.dart`, after a successful login, `await persistCurrentUser(ref, response.user)` alongside storing the token. Add `inputFormatters: inputRules()` to the email + password fields. Restyle both screens to the new system (Jakarta heading via `textTheme`, `PrimaryButton` CTA, themed inputs, `InlineErrorBanner`) — no hardcoded colors.

- [ ] **Step 3: Verify (user machine)**

Run: `cd wayfarer-sync/mobile && flutter analyze && flutter test`
Expected: no errors.

- [ ] **Step 4: Checkpoint (DO NOT COMMIT)**

---

### Task 17: README + no-hardcode / emoji-rule sweep

**Files:**
- Modify: `wayfarer-sync/mobile/README.md`

- [ ] **Step 1: Update the README**

Document: the bottom-nav shell (Trips · Profile), the new Profile tab (identity monogram, real stat tiles, Trip History, theme toggle, logout), active-only Trips + client-side search, the Stitch palette/font remap, the name monogram + no-emoji input rule, and the `features/auth/{models,providers}` + `features/profile/` + `core/util/` additions in the directory tree. Note the companion backend change (user first/last name).

- [ ] **Step 2: Sweep for hardcoded UI + un-ruled inputs**

Run and confirm empty (token layer excepted):

```bash
cd wayfarer-sync/mobile
grep -rnE "Color\(0x|#[0-9a-fA-F]{6}" lib/features lib/core/widgets | grep -v generated
grep -rn "TextField(" lib | grep -v inputFormatters   # every hit must be checked to use inputRules()
```

Expected: the first grep returns nothing; every `TextField` either shows `inputFormatters` on an adjacent line or is intentionally read-only.

- [ ] **Step 3: Full static verification (user machine)**

Run: `cd wayfarer-sync/mobile && flutter pub get && flutter analyze && flutter test`
Expected: analyzer clean; all unit tests pass.

- [ ] **Step 4: Checkpoint (DO NOT COMMIT)**

---

## Self-Review notes (coverage)

- Spec §3 (token remap) → Tasks 3–5. §4 (nav shell) → Task 8. §5.1 (auth + signup names/confirm) → Tasks 14, 16. §5.2 (Trips active-only + search) → Tasks 9–10. §5.3 (create) → Task 11. §5.4 (map overlays) → Task 13. §5.5 (join dialog) → Task 12. §5.6 (card) → Task 9. §5.7 (Profile) → Tasks 8, 14–15. §6.1 (monogram) → Task 6. §6.2 (no-emoji) → Task 7 (+ applied in Tasks 10–12, 16). §7 (currentUserProvider) → Task 14. §9 (verification) → Tasks end-of-phase + Task 17. §10 phasing → task order. §11 (backend) → Tasks 1–2.
- No placeholders; every code step shows code. Symbol names consistent (`nameMonogram`, `noEmojiFormatter`/`inputRules`, `currentUserProvider`, `persistCurrentUser`, `AppScaffoldShell`, `CurrentUser.displayName`) across producing/consuming tasks.
