# Project Name Suggestions

## Top Recommendations

### #1: Prism

```
┌─────────────────────────────────────────────────────────────────────┐
│  Prism                                                              │
│                                                                     │
│  - Sounds like "Prisma" (familiar to users)                        │
│  - Short and memorable                                              │
│  - Light/refraction theme (like Prisma)                            │
│                                                                     │
│  Usage:                                                             │
│    import 'package:prism/prism.dart';                              │
│    final db = PrismClient(adapter: ...);                           │
│                                                                     │
│  CLI:                                                               │
│    dart run prism:generate                                         │
└─────────────────────────────────────────────────────────────────────┘
```

### #2: Dartisan

```
┌─────────────────────────────────────────────────────────────────────┐
│  Dartisan                                                           │
│                                                                     │
│  - "Dart" + "Artisan" (craftsman)                                  │
│  - Unique and searchable                                            │
│  - Implies "crafted queries"                                        │
│  - Laravel has "Artisan" (nice parallel)                           │
│                                                                     │
│  Usage:                                                             │
│    import 'package:dartisan/dartisan.dart';                        │
│    final db = DartisanClient(adapter: ...);                        │
│                                                                     │
│  CLI:                                                               │
│    dart run dartisan:generate                                      │
└─────────────────────────────────────────────────────────────────────┘
```

### #3: TypeForge

```
┌─────────────────────────────────────────────────────────────────────┐
│  TypeForge                                                          │
│                                                                     │
│  - Emphasizes type-safety + code generation                        │
│  - "Forge" = crafting/building                                     │
│  - Unique and memorable                                             │
│                                                                     │
│  Usage:                                                             │
│    import 'package:typeforge/typeforge.dart';                      │
│    final db = ForgeClient(adapter: ...);                           │
│                                                                     │
│  CLI:                                                               │
│    dart run typeforge:generate                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## All Name Suggestions

### Light/Crystal Theme (Similar to Prisma)

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Prism** | Light refraction | `PrismClient` |
| **Spectra** | Spectrum of light | `SpectraClient` |
| **Lumina** | Light/illumination | `LuminaClient` |
| **Facet** | Surface of a crystal | `FacetClient` |
| **Crystel** | Crystal + Model | `CrystelClient` |
| **Refract** | Light bending | `RefractClient` |

### Crafting/Building Theme

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Forge** | Where things are crafted | `ForgeClient` |
| **Anvil** | Blacksmith's tool | `AnvilClient` |
| **TypeForge** | Type-safe + crafting | `ForgeClient` |
| **Dartisan** | Dart + Artisan | `DartisanClient` |
| **Catalyst** | Triggers/enables things | `CatalystClient` |

### Database/Query Theme

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Queryant** | Query + Elegant | `QueryantClient` |
| **Schemix** | Schema + Mix | `SchemixClient` |
| **TypeQuery** | Type-safe queries | `TypeQueryClient` |
| **SchemaORM** | Schema-first ORM | `SchemaClient` |

### Dart-Specific Theme

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Dartisan** | Dart + Artisan | `DartisanClient` |
| **DartBase** | Dart + Database | `DartBaseClient` |
| **Dartify** | Dart + -ify | `DartifyClient` |
| **FlutterDB** | Flutter + Database | `FlutterDBClient` |

### Strong/Solid Theme

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Basalt** | Solid volcanic rock | `BasaltClient` |
| **Granite** | Strong rock | `GraniteClient` |
| **Bedrock** | Foundation | `BedrockClient` |
| **Foundation** | Base/support | `FoundationClient` |

### Unique/Creative Names

| Name | Meaning | Usage Example |
|------|---------|---------------|
| **Meridian** | Line connecting points | `MeridianClient` |
| **Nexus** | Connection/link | `NexusClient` |
| **Vertex** | Point where lines meet | `VertexClient` |
| **Conduit** | Channel for data | `ConduitClient` |
| **Lattice** | Structured framework | `LatticeClient` |
| **Matrix** | Structured arrangement | `MatrixClient` |

---

## Name Evaluation Criteria

```
┌─────────────────────────────────────────────────────────────────────┐
│  What makes a good name?                                            │
│                                                                     │
│  ✓ Short (1-2 syllables ideal)                                     │
│  ✓ Memorable                                                        │
│  ✓ Easy to spell                                                    │
│  ✓ Easy to pronounce                                                │
│  ✓ Unique/searchable on Google                                      │
│  ✓ Available on pub.dev                                             │
│  ✓ Hints at what it does                                           │
│  ✓ Works well as class prefix (e.g., PrismClient)                  │
│  ✓ Works well as CLI command (e.g., dart run prism:generate)       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Quick Reference

| Vibe | Best Pick |
|------|-----------|
| Familiar (Prisma-like) | **Prism** |
| Unique/Creative | **Dartisan** |
| Technical | **TypeForge** |
| Strong/Solid | **Basalt** |
| Elegant | **Lumina** |
| Database-focused | **Schemix** |

---

## Package Name Examples

```dart
// If named "Prism"
import 'package:prism/prism.dart';

final prisma = PrismClient(adapter: PostgresAdapter(connection));
final users = await prisma.user.findMany();
```

```dart
// If named "Dartisan"
import 'package:dartisan/dartisan.dart';

final db = DartisanClient(adapter: PostgresAdapter(connection));
final users = await db.user.findMany();
```

```dart
// If named "TypeForge"
import 'package:typeforge/typeforge.dart';

final forge = ForgeClient(adapter: PostgresAdapter(connection));
final users = await forge.user.findMany();
```
