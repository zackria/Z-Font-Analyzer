🌟 App Name Suggestion
Motion Font Analyzer (or something like: TemplateLens / FontScope)

🧭 High-Level Navigation (Tabs / Sections)
Use a top tab bar (like in Final Cut Pro or Xcode):

Tabs:
Dashboard

Fonts

Files

Results

Settings

🪄 Dashboard (Default Landing Tab)
Purpose:
Quick summary of all scanned content.

Layout:
Left: Circular file type distribution chart (.moti, .motn, etc.)

Right: Count summary panel (rounded cards with icons)

Bottom: Top 5 fonts used (with horizontal bars or mini line chart trends)

Widgets:
📁 Scanned Folder Path (with change button)

🔄 Files Processed (animated count-up)

📊 Total Fonts Found

🧾 Total Templates Detected

🔠 Fonts Tab
Purpose:
Show all fonts used, their counts, and file paths.

Layout:
Search bar (native macOS style with ⌘F)

Font List Table with sortable headers:

Font Name

File Type

Description

Count

Path (with expand/truncate toggle)

Optional: Side preview panel to show font rendering in real-time

📂 Files Tab
Purpose:
List of motion template files and their types.

Layout:
File Explorer-style table:

File Name

Type (.moti, .motn, etc.)

Font(s) Used

Path

Size

Last Modified

Filters for type or font

✅ Results Tab
Purpose:
Final summarized breakdown of fonts vs files

UI Features:
Heatmap or matrix of fonts vs file types

Export as CSV / JSON

Visual:

Fonts used by file type (bar chart)

Timeline showing scan activity (if applicable)

⚙️ Settings Tab
Features:
Default Scan Folder

File Types to Include/Ignore

Font Duplicate Merge Rules

Export Preferences

Dark Mode / Light Mode toggle (if not inherited)

🎨 Design System & Aesthetics
Dark Mode First (similar to Logic Pro / FCPX)

Rounded corners, minimal shadow for all containers

Use SF Symbols for icons

Fonts: System font (SF Pro Text), 14pt base size

Motion: Subtle animations for tab switch and counters

🧩 BONUS: UX Enhancements
Progress Indicator while scanning

Tooltips or popovers for data explanations

Drag & Drop Support to select directory

Breadcrumbs for folder paths

Copy Path and Reveal in Finder options per file/font
