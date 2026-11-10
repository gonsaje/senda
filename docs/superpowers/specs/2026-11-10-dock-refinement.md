# Bottom bar refinement

Fix bottom-bar label wrapping at the largest text size while keeping Senda's ivory #F7F3EB, terracotta #A94E32, charcoal #302720, notebook styling, four destinations and persistent navigation. Preserve all page/numeric Dynamic Type behavior, selected traits, autosave, navigation state and minimum 44-point targets. No decorative left borders.

The current four equal columns allow caption text to grow without a cap and wrap vertically. Native iPhone 13 mini reproduction measures a 173-point bar at the largest text size. Keep the four columns and their positions. Cap only each bar label's Dynamic Type at xxxLarge, keep its full text on one line, retain the 54-point button minimum, existing spacing, ivory background and top rule. Align the existing 20-point symbols in 24-point slots. Mark selection with the existing filled symbol/emphasized text plus a small decorative checkmark, and keep the selected accessibility trait and explicit destination label.

On iOS add the system Large Content Viewer to every button, outside the capped text subtree. A press and hold shows the full destination label and symbol. This follows Apple's custom-tab-bar guidance: https://developer.apple.com/videos/play/wwdc2024/10074/ (12:10–13:35) and https://developer.apple.com/documentation/swiftui/view/accessibilityshowslargecontentviewer(). It is a navigation-specific size constraint; content and key values remain fully scalable.

A two-by-two bar would consume more persistent height and move destinations at accessibility sizes. Shrinking all app text would reduce readability beyond this bug. Keep the familiar single-row bar and supply the native large preview instead.

Verify all four full labels, one-row nonoverlap/alignment, selected state, 44-point targets and a bar no higher than 120 points including the bottom safe area on native ordinary/compact phones at the largest size. Inspect regular and all selected-state renders at 320/393-point widths. Verify the large viewer during a native hold and exercise navigation, unfinished input and failed-switch behavior through existing checks. Preserve unrelated work; do not commit or push.
