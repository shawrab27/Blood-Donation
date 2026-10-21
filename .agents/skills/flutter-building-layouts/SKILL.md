---
name: flutter-building-layouts
description: Build responsive Flutter layouts, fix RenderFlex overflow errors, resolve cut-off buttons (e.g. Create Poster), and adapt to different screen sizes and keyboard states. Use when building or modifying Flutter UI widgets, screens, responsive layouts, or debugging layout overflows.
metadata:
  version: "1.0.0"
---

# Flutter Building Layouts & Overflow Remediation

Comprehensive guide for designing responsive Flutter UI, resolving `RenderFlex overflowed by N pixels` errors, and preventing cut-off action buttons in BloodPulse.

## When to Activate

- Creating or updating any Flutter screen, card, or modal dialog.
- Debugging `RenderFlex overflowed by X pixels` yellow-and-black stripes.
- Fixing cut-off floating/bottom action buttons (e.g., "Create Poster", "Submit Request").
- Handling on-screen keyboard appearance without breaking forms.
- Adapting layouts across various mobile screen aspect ratios and tablets.

---

## 1. Core Principles of Responsive Layouts

### A. Wrapping in `ResponsiveLayout`
Every full screen in BloodPulse must be wrapped in `ResponsiveLayout` to enforce max-width constraints on wide screens/tablets and maintain ergonomic mobile padding:

```dart
import 'package:flutter/material.dart';

class BloodRequestScreen extends StatelessWidget {
  const BloodRequestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BloodPulseTopBar(),
      body: ResponsiveLayout(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Screen content
            ],
          ),
        ),
      ),
    );
  }
}
```

### B. Dynamic Screen Sizing with `MediaQuery` & `LayoutBuilder`

- **Use `MediaQuery.sizeOf(context)`**: Instead of `MediaQuery.of(context).size` to avoid unnecessary rebuilds when non-size media query data changes.
- **Use `LayoutBuilder`**: Whenever a component's internal layout depends on its parent's incoming box constraints (not the entire screen size).

```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 600) {
      return _buildTwoColumnLayout();
    }
    return _buildSingleColumnLayout();
  },
)
```

---

## 2. Fixing the "Cut-off Button" Issue (e.g. Create Poster)

### Cause:
Placing a button at the bottom of a `Column` inside a unconstrained screen or non-scrollable container causes the button to get pushed below the visible viewport or cut off by the system navigation bar/bottom nav.

### Solution 1: Scroll View with Sticky Bottom Button using `CustomScrollView`

```dart
Scaffold(
  body: SafeArea(
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Form fields, poster preview, inputs
              ],
            ),
          ),
        ),
        // Sticky Bottom Action Bar with capsule button
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFC30121),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(50),
                ),
              ),
              onPressed: () => _handleCreatePoster(),
              child: const Text(
                'Create Poster',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
  ),
);
```

### Solution 2: Bottom Navigation Bar Slot for Action Button

```dart
Scaffold(
  body: const SingleChildScrollView(
    padding: EdgeInsets.all(16),
    child: PosterFormContent(),
  ),
  bottomNavigationBar: SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFC30121),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(50),
          ),
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: _submit,
        child: const Text('Create Poster'),
      ),
    ),
  ),
);
```

---

## 3. Resolving `RenderFlex Overflow` Anti-Patterns

### Anti-Pattern 1: Unbounded Text in a Row
**Problem**: A long hospital name or address causes right overflow.
```dart
// BAD:
Row(
  children: [
    Icon(Icons.location_on),
    Text('Dhaka Medical College & Hospital, Secretariate Road, Dhaka'), // OVERFLOW
  ],
)

// GOOD:
Row(
  children: [
    const Icon(Icons.location_on, color: Color(0xFFC30121)),
    const SizedBox(width: 8),
    Expanded(
      child: Text(
        'Dhaka Medical College & Hospital, Secretariate Road, Dhaka',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontFamily: 'Inter'),
      ),
    ),
  ],
)
```

### Anti-Pattern 2: Column inside Column without Expanded/Flexible
**Problem**: Vertical viewport was given unbounded height.
```dart
// BAD:
Column(
  children: [
    Text('Header'),
    ListView.builder(...), // CRASH: Vertical viewport was given unbounded height
  ],
)

// GOOD:
Column(
  children: [
    const Text('Header'),
    Expanded(
      child: ListView.builder(
        itemCount: items.length,
        itemBuilder: (context, index) => ItemTile(items[index]),
      ),
    ),
  ],
)
// OR if the entire page scrolls:
SingleChildScrollView(
  child: Column(
    children: [
      const Text('Header'),
      ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: items.length,
        itemBuilder: (context, index) => ItemTile(items[index]),
      ),
    ],
  ),
)
```

### Anti-Pattern 3: Keyboard Overlay Overflow
**Problem**: When the keyboard opens, bottom elements overflow by 150+ pixels.
```dart
// Check in Scaffold:
Scaffold(
  resizeToAvoidBottomInset: true,
  body: SafeArea(
    child: LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                children: [
                  // Form inputs
                  const Spacer(),
                  // Submit button
                ],
              ),
            ),
          ),
        );
      },
    ),
  ),
)
```

---

## 4. Layout Diagnostic Checklist

- [ ] Is the screen wrapped in `ResponsiveLayout`?
- [ ] Are all rows containing dynamic text or badges wrapped in `Expanded` or `Flexible`?
- [ ] Does the page scroll gracefully when the soft keyboard appears?
- [ ] Is the primary action button (e.g. "Create Poster", "Send Request") always visible or explicitly sticky?
- [ ] Are buttons using the mandatory `BorderRadius.circular(50)` pill shape?
