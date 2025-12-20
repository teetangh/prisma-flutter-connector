# Domain & Subdomain Strategy

## Primary Domain Recommendations

Based on your project (Dart/Flutter ORM with Prisma schema), here are the top domain choices ranked by priority:

### Tier 1: Best Choices (Get These First)

| Rank | Domain | Why |
|------|--------|-----|
| 1 | **prism.dev** | Developer-focused TLD, short, memorable |
| 2 | **getprism.dev** | If prism.dev taken, "get" prefix works well |
| 3 | **prism.io** | Tech-friendly, established credibility |
| 4 | **dartisan.dev** | Unique, Dart-focused branding |
| 5 | **typeforge.dev** | Technical, implies code generation |

### Tier 2: Alternatives

| Domain | Notes |
|--------|-------|
| prism.so | Short, modern |
| prism.app | App-focused |
| useprism.dev | Action-oriented |
| prismdb.dev | Database-focused |
| prismorm.dev | ORM-specific |

---

## Subdomain Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     SUBDOMAIN STRUCTURE                             │
│                                                                     │
│  prism.dev (or your chosen domain)                                 │
│  │                                                                  │
│  ├── www.prism.dev          → Marketing site / Landing page        │
│  ├── docs.prism.dev         → Documentation                        │
│  ├── api.prism.dev          → API reference                        │
│  ├── app.prism.dev          → Web dashboard / Studio               │
│  ├── status.prism.dev       → Service status page                  │
│  ├── blog.prism.dev         → Blog / Updates                       │
│  ├── community.prism.dev    → Forum / Discord landing              │
│  └── enterprise.prism.dev   → Enterprise sales                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Industry-Specific Subdomains/Landing Pages

### Group 1: Tech Industry

```
┌─────────────────────────────────────────────────────────────────────┐
│  TECH / SOFTWARE DEVELOPMENT                                        │
│  Target: Developers, CTOs, Tech Leads                               │
│                                                                     │
│  Subdomains:                                                        │
│  ├── flutter.prism.dev      → Flutter-specific landing             │
│  ├── mobile.prism.dev       → Mobile app development               │
│  ├── backend.prism.dev      → Dart backend (Dart Frog, Shelf)      │
│  ├── supabase.prism.dev     → Supabase integration guide           │
│  ├── postgres.prism.dev     → PostgreSQL users                     │
│  ├── sqlite.prism.dev       → Offline-first / SQLite               │
│  ├── startup.prism.dev      → Startup-focused (speed, MVP)         │
│  └── agency.prism.dev       → Development agencies                 │
│                                                                     │
│  Priority: ★★★★★ (Core audience)                                   │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 2: Finance / FinTech

```
┌─────────────────────────────────────────────────────────────────────┐
│  FINANCE / FINTECH                                                  │
│  Target: Banks, Trading platforms, Payment apps                     │
│                                                                     │
│  Subdomains:                                                        │
│  ├── fintech.prism.dev      → FinTech landing page                 │
│  ├── banking.prism.dev      → Banking app solutions                │
│  ├── trading.prism.dev      → Trading platform backends            │
│  ├── payments.prism.dev     → Payment processing apps              │
│  └── compliance.prism.dev   → Compliance/audit trail features      │
│                                                                     │
│  Key selling points:                                                │
│  - Type-safe queries (reduce bugs in financial calculations)       │
│  - Transaction support (ACID compliance)                           │
│  - Audit logging capabilities                                       │
│  - Offline-first for POS systems                                   │
│                                                                     │
│  Priority: ★★★★☆ (High-value customers)                            │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 3: Healthcare / Medical

```
┌─────────────────────────────────────────────────────────────────────┐
│  HEALTHCARE / MEDICAL                                               │
│  Target: Health apps, Hospital systems, Telemedicine               │
│                                                                     │
│  Subdomains:                                                        │
│  ├── health.prism.dev       → Healthcare landing page              │
│  ├── medical.prism.dev      → Medical record systems               │
│  ├── telehealth.prism.dev   → Telemedicine apps                    │
│  ├── hipaa.prism.dev        → HIPAA compliance features            │
│  └── clinical.prism.dev     → Clinical trial data management       │
│                                                                     │
│  Key selling points:                                                │
│  - Offline-first (rural/low connectivity areas)                    │
│  - Type-safe patient data handling                                 │
│  - SQLite for local data (HIPAA: data stays on device)            │
│  - Audit trails for compliance                                     │
│                                                                     │
│  Priority: ★★★★☆ (Growing market, compliance-heavy)                │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 4: Legal

```
┌─────────────────────────────────────────────────────────────────────┐
│  LEGAL                                                              │
│  Target: Law firms, Legal tech, Document management                │
│                                                                     │
│  Subdomains:                                                        │
│  ├── legal.prism.dev        → Legal tech landing page              │
│  ├── lawfirm.prism.dev      → Law firm management apps             │
│  ├── contracts.prism.dev    → Contract management systems          │
│  └── ediscovery.prism.dev   → E-discovery solutions                │
│                                                                     │
│  Key selling points:                                                │
│  - Document relationship modeling                                   │
│  - Complex query capabilities (case research)                      │
│  - Offline access to case files                                    │
│  - Audit trails for billing                                        │
│                                                                     │
│  Priority: ★★★☆☆ (Niche but high-value)                            │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 5: Management / Enterprise

```
┌─────────────────────────────────────────────────────────────────────┐
│  MANAGEMENT / ENTERPRISE                                            │
│  Target: Project management, HR, CRM, ERP                          │
│                                                                     │
│  Subdomains:                                                        │
│  ├── enterprise.prism.dev   → Enterprise sales landing             │
│  ├── crm.prism.dev          → CRM solutions                        │
│  ├── erp.prism.dev          → ERP systems                          │
│  ├── hr.prism.dev           → HR management apps                   │
│  ├── inventory.prism.dev    → Inventory management                 │
│  └── field.prism.dev        → Field service apps (offline)         │
│                                                                     │
│  Key selling points:                                                │
│  - Complex data relationships                                       │
│  - Aggregations and reporting                                       │
│  - Multi-tenant architecture support                               │
│  - Offline field workers                                           │
│                                                                     │
│  Priority: ★★★★☆ (Large market)                                    │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 6: E-Commerce / Retail

```
┌─────────────────────────────────────────────────────────────────────┐
│  E-COMMERCE / RETAIL                                                │
│  Target: Online stores, POS systems, Marketplaces                  │
│                                                                     │
│  Subdomains:                                                        │
│  ├── ecommerce.prism.dev    → E-commerce landing                   │
│  ├── retail.prism.dev       → Retail solutions                     │
│  ├── pos.prism.dev          → Point of sale (offline-first)        │
│  ├── marketplace.prism.dev  → Marketplace platforms                │
│  └── catalog.prism.dev      → Product catalog management           │
│                                                                     │
│  Key selling points:                                                │
│  - Offline POS capability                                          │
│  - Product/variant/inventory modeling                              │
│  - Order management                                                 │
│  - Real-time sync with Supabase                                    │
│                                                                     │
│  Priority: ★★★★☆ (High volume)                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Group 7: Education

```
┌─────────────────────────────────────────────────────────────────────┐
│  EDUCATION                                                          │
│  Target: EdTech, Schools, LMS platforms                            │
│                                                                     │
│  Subdomains:                                                        │
│  ├── education.prism.dev    → Education landing                    │
│  ├── lms.prism.dev          → Learning management systems          │
│  ├── school.prism.dev       → School management                    │
│  └── learn.prism.dev        → Tutorials (also marketing)           │
│                                                                     │
│  Key selling points:                                                │
│  - Offline learning content                                        │
│  - Student/course/grade relationships                              │
│  - Progress tracking                                                │
│                                                                     │
│  Priority: ★★★☆☆ (Growing market)                                  │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Recommended Domain Purchase Strategy

### Phase 1: Core (Now - MVP)
**Budget: ~$100-200/year**

```
Must have:
├── prism.dev (or primary choice)       ~$15/year
├── prism.io (backup/redirect)          ~$40/year
└── getprism.dev (if prism.dev taken)   ~$15/year

Subdomains (free, just DNS):
├── docs.prism.dev
├── api.prism.dev
└── app.prism.dev
```

### Phase 2: Growth (1,000-10,000 users)
**Budget: ~$300-500/year**

```
Add:
├── prism.app                           ~$15/year
├── prism.co                            ~$30/year
├── prismdb.com                         ~$15/year
└── Industry subdomains (free)
    ├── flutter.prism.dev
    ├── mobile.prism.dev
    ├── startup.prism.dev
    └── enterprise.prism.dev
```

### Phase 3: Scale (10,000-100,000 users)
**Budget: ~$1,000-2,000/year**

```
Add:
├── prism.com (if available/affordable)
├── Regional domains
│   ├── prism.eu
│   ├── prism.in
│   └── prism.asia
└── All industry subdomains
    ├── fintech.prism.dev
    ├── health.prism.dev
    ├── legal.prism.dev
    ├── enterprise.prism.dev
    └── (all others)
```

---

## Priority Matrix

```
                        HIGH VALUE
                            │
    ┌───────────────────────┼───────────────────────┐
    │                       │                       │
    │   FINTECH             │   ENTERPRISE          │
    │   HEALTHCARE          │   TECH/DEVELOPERS     │
    │                       │                       │
    │   (Fewer customers,   │   (Core audience,     │
    │    higher revenue)    │    high volume)       │
    │                       │                       │
NICHE ──────────────────────┼─────────────────────── BROAD
    │                       │                       │
    │   LEGAL               │   E-COMMERCE          │
    │   CLINICAL            │   EDUCATION           │
    │                       │   RETAIL              │
    │   (Specialized,       │                       │
    │    compliance-heavy)  │   (Volume play)       │
    │                       │                       │
    └───────────────────────┼───────────────────────┘
                            │
                        LOW VALUE
```

---

## Recommended Go-To-Market Strategy

### Stage 1: Developer-First (0-10,000 users)

```
Focus: Tech / Developers
─────────────────────────────────────────────
Primary: prism.dev
Active subdomains:
  ├── docs.prism.dev      (documentation)
  ├── flutter.prism.dev   (Flutter landing)
  ├── supabase.prism.dev  (integration page)
  └── startup.prism.dev   (quick MVP pitch)

Why: Developers adopt tools, then bring them to enterprises
```

### Stage 2: Vertical Expansion (10,000-50,000 users)

```
Focus: Add FinTech + Healthcare
─────────────────────────────────────────────
Add subdomains:
  ├── fintech.prism.dev   (compliance, transactions)
  ├── health.prism.dev    (HIPAA, offline)
  ├── enterprise.prism.dev (sales team landing)
  └── agency.prism.dev    (dev agency partners)

Why: High-value verticals with specific needs you solve
```

### Stage 3: Full Market (50,000-100,000+ users)

```
Focus: All Verticals
─────────────────────────────────────────────
Add all remaining:
  ├── legal.prism.dev
  ├── ecommerce.prism.dev
  ├── education.prism.dev
  ├── crm.prism.dev
  └── (industry-specific pages)

Regional expansion:
  ├── prism.eu (GDPR focused)
  ├── prism.in (India market)
  └── prism.asia
```

---

## Complete Subdomain List (Ranked)

### Tier 1: Essential (Launch with these)

| Subdomain | Purpose | Priority |
|-----------|---------|----------|
| docs.prism.dev | Documentation | ★★★★★ |
| api.prism.dev | API Reference | ★★★★★ |
| app.prism.dev | Dashboard/Studio | ★★★★☆ |
| status.prism.dev | Status page | ★★★★☆ |

### Tier 2: Growth (Add at 1,000+ users)

| Subdomain | Purpose | Priority |
|-----------|---------|----------|
| flutter.prism.dev | Flutter developers | ★★★★★ |
| supabase.prism.dev | Supabase integration | ★★★★☆ |
| startup.prism.dev | Startup landing | ★★★★☆ |
| mobile.prism.dev | Mobile dev focus | ★★★★☆ |
| backend.prism.dev | Dart backend focus | ★★★☆☆ |
| blog.prism.dev | Blog/Updates | ★★★☆☆ |
| community.prism.dev | Community/Forum | ★★★☆☆ |

### Tier 3: Verticals (Add at 10,000+ users)

| Subdomain | Purpose | Priority |
|-----------|---------|----------|
| enterprise.prism.dev | Enterprise sales | ★★★★★ |
| fintech.prism.dev | FinTech vertical | ★★★★☆ |
| health.prism.dev | Healthcare vertical | ★★★★☆ |
| agency.prism.dev | Dev agencies | ★★★☆☆ |
| ecommerce.prism.dev | E-commerce | ★★★☆☆ |
| legal.prism.dev | Legal tech | ★★★☆☆ |

### Tier 4: Expansion (Add at 50,000+ users)

| Subdomain | Purpose | Priority |
|-----------|---------|----------|
| banking.prism.dev | Banking specific | ★★★☆☆ |
| trading.prism.dev | Trading platforms | ★★★☆☆ |
| telehealth.prism.dev | Telemedicine | ★★★☆☆ |
| pos.prism.dev | Point of sale | ★★★☆☆ |
| lms.prism.dev | Learning management | ★★☆☆☆ |
| crm.prism.dev | CRM systems | ★★☆☆☆ |
| erp.prism.dev | ERP systems | ★★☆☆☆ |
| hr.prism.dev | HR management | ★★☆☆☆ |
| inventory.prism.dev | Inventory | ★★☆☆☆ |
| field.prism.dev | Field service | ★★☆☆☆ |
| hipaa.prism.dev | HIPAA compliance | ★★☆☆☆ |
| compliance.prism.dev | Compliance focus | ★★☆☆☆ |

---

## Summary: What to Buy Now

```
┌─────────────────────────────────────────────────────────────────────┐
│  IMMEDIATE PURCHASE LIST                                            │
│                                                                     │
│  Primary Domain (pick one):                                        │
│  ├── prism.dev           ($15/year) ← RECOMMENDED                  │
│  ├── dartisan.dev        ($15/year)                                │
│  └── typeforge.dev       ($15/year)                                │
│                                                                     │
│  Backup Domains:                                                    │
│  ├── prism.io            ($40/year)                                │
│  └── getprism.dev        ($15/year)                                │
│                                                                     │
│  Total: ~$70-85/year                                               │
│                                                                     │
│  Subdomains are FREE (just DNS records)                            │
│  Set up: docs, api, app, status                                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```
