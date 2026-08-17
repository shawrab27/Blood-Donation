# BLOODPULSE MANDATORY AGENT RULES & PATTERN REGISTRY

Before executing any prompt or command, strictly enforce these mandatory BloodPulse UI alignment rules (which fix and override Stitch UI mistakes):

### 1. TOP HEADER PATTERN (TOP BAR RULE)
- **Top-Left**: Logo asset `assets/images/Blood Pulse logo.jpg` (height: 32px, circular clip) + `"BloodPulse"` title (Georgia font, deep red `#C30121`).
- **Top-Right**:
  1. Notification Bell icon (`Icons.notifications_outlined`) with active red unread badge (`#C30121`).
  2. 3-Dot vertical `PopupMenuButton` options: Learn more, Contact us, About us, Log out.

### 2. DOWN NAV BAR PATTERN (5 PERSISTENT TABS)
- Standard persistent bottom navigation bar across main app shell:
  1. 📰 **Feed**
  2. 🩸 **Blood Hub**
  3. 👥 **Communities**
  4. 🏥 **Health Hub**
  5. 👤 **Profile**

### 3. NOTIFICATION SCREEN TABS (NOTIFICATION EXCEPTION)
- Clicking the Notification Bell opens Notification Center with 4 items:
  1. 📰 **Feed**
  2. 🚨 **Request**
  3. 💬 **Messages**
  4. 👤 **Profile**

### 4. DESIGN TOKENS
- Primary `#C30121`, Secondary `#2B2B2B`, Tertiary `#0D68AA`, Surface `#FDF3F3` / `#FFF8F7`.
- Headlines in Georgia; Body/Inputs/Buttons in Inter.
- Full capsule / pill shape (`BorderRadius.circular(50)`) for buttons and input fields.
- Wrap all screens in `ResponsiveLayout`.

### 5. TARGET SCOPE & INSTITUTION
- Do NOT build for or reference BAUST (Bangladesh Army University of Science and Technology). All pilots, research documentation, consent forms, and data collection designs must remain general / campus-agnostic unless specifically instructed otherwise by the user.

