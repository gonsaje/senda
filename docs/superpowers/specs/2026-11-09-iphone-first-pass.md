# iPhone first refinement pass

The user approved the audit's first pass: tighten the workout screen, fix history and PR navigation, simplify Trends, and retain the current colors and notebook feel.

Use focused changes within the existing native SwiftUI screens. Preserve ivory #F7F3EB, terracotta #A94E32, charcoal #302720, Georgia headings, flat lists, 44-point essential targets, automatic saving, recoverable partial input and last valid values, grouped Drop entries, and Undo. Keep a prominent dedicated Type control and paired normal compact weight/reps. No decorative left borders. No new dependencies, storage formats, commits or pushes.

Workout: combine the plan target/completion into one concise line and bring the collapsed performance reference into that block. Reduce the header's combined height without reducing numeric sizes or hiding the current date, exercise, unit or plan. Use distinct previous-workout versus previous-set wording.

History: keep 8/12-week charts, but show all saved recorded days independently, including intentionally saved future dates. PR and logger references open the exact saved day/set read-only without selecting a different workout. Allow explicit Edit this workout, preserve the original day/exercise or week, and offer a persistent return control. Failed navigation must retain input and destination, retry exactly once, and be superseded by newer intent. Restore clears transient history context.

Trends: shorten the introduction before the first exercise comparison and tighten dated source-set presentation where it remains readable. Retain comparison semantics, exact dates/units, milestones, honest empty states, all-time records and Larger Text reflow.

Approach: refine existing screens and reuse current journal projections/navigation transactions. A theme replacement or new session system exceeds the approved pass. Older-day access is provided through all-date history rather than adding an unrelated calendar feature in this pass.

Acceptance: compact workout values and first Trends result move at least 44 logical points higher in matched previews; normal numeric sizes and touch targets remain. Read-only browsing never changes selected workout or records. Old non-PR sets remain reachable when recent charts are empty. Explicit editing has a reliable return path. Verify the semantic suite and native phone-size, compact, Larger Text, editing and failure renders. Mac previews do not establish iPhone keyboard or VoiceOver behavior.
