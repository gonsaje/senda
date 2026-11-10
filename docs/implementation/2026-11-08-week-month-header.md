# Week month header

User selected the left-aligned layout with a month heading and Today plus grouped arrows on the right. Arrows and horizontal swipes still move one week; Today returns to the current calendar week and keeps the week view open, without creating a workout.

Single-month weeks use the full month name. Overlapping months show both names, with abbreviated labels when space is limited. Other years are identified explicitly. Larger accessibility text moves the controls below the month, still right-aligned. Screen readers retain the exact week range as the heading value. All three controls have at least 44-point tap targets.

Today uses the existing atomic finalization/persistence path. Failed writes retain the original context; the same control can be retried. Week errors direct the user to repeat the action instead of offering a generic retry that cannot replay a navigation request.

Verification: 179 local tests pass, including current-week persistence/failure/year-boundary checks and month-label boundaries. Native pointer probes at393/320 points verify three unique controls, right alignment, arrows, Today and month/year boundary layouts. Normal and compact renders inspected; iPhone flows now exercise Today and grouped-control alignment, including large text. Full iPhone checks run automatically on push.
