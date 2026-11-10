# Workout UX reset and grouped Drop sets

The user asked to remove the duplicate Regular/Working distinction, make Working set the default, improve Drop sets, and review the app because the current UI is poor. The user explicitly chose one grouped Drop entry with weight/reps stages.

Make the default Working and hide Regular from selectable choices while retaining its stored raw case as a compatibility alias. Rebuild the logging hierarchy around the sets: compact date controls, one exercise selector, paired narrow-screen weight/reps, contextual effort editing and quieter references. Keep Type separate and controls at least 44 points. Preserve visible units and number sizes; use full stacking for Larger Text.

Store explicit optional Drop group membership on existing flat rows, retaining their numeric editor, canonical weight and performed-set identity. Render one entry with Start and numbered drops. Count the group once in displayed set totals while preserving every stage in history and calculations based on actual values. Add/remove stages, repeat, whole-entry delete and Undo are atomic and retry-safe. Changing a multi-stage Drop group to another type preserves the values as separate sets, with clear explanatory wording. Legacy standalone rows are not silently joined.

Use local format 7 and backup version 4 for grouping and grouped Undo; read older versions without rewriting on read. CSV preserves grouping and stage order. Preserve automatic saving, incomplete-input recovery, metadata context guards and storage error handling. Drop workouts remain outside automatic load-increase comparisons.

Keep Learn back and Progress Back/Done outside their scrolling content. Remaining app-wide changes are documented in the audit and are not silently bundled into a broad redesign.
