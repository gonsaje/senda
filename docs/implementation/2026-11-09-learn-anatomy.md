# Learn anatomy metadata

`ExerciseMuscleMap` adds offline anatomical regions for all 20 preset exercises. It uses exercise IDs and the variations already described by `ExerciseFormGuide`. Custom and unknown IDs return `nil`; names and saved muscle groups never produce inferred guidance.

`MuscleRegion` supplies readable and anatomical names for 15 illustration regions. The model is independent of persisted `MuscleGroup`, exercise classification, workout history, backup formats and storage schemas.

## Role definitions

- **Primary:** the main movement or training emphasis of the guided variation.
- **Supporting:** regions that assist the movement.
- **Stabilizing:** regions that maintain posture or grip. Trunk bracing is listed separately from the muscles moving the load.

These categories are qualitative teaching labels. They do not measure activation, predict growth, rank exercises or assign percentages. Sources sometimes use different definitions of “primary”; a muscle can be essential to a lift while appearing here as supporting or stabilizing. Arrays are ordered for readable labels, without a strength or activation ranking.

The diagram is selective. It omits deep muscles and some smaller movers, including the rotator cuff, serratus anterior, teres major and hip adductors. A highlighted region can contain muscles with different roles; the anatomical name describes the region and does not claim equal involvement of every muscle within it. For example, the upper-back region groups trapezius and rhomboids; the calf region groups gastrocnemius and soleus. Neither is a claim about a particular muscle head's activation.

## Source audit

Primary sources were checked on November 9, 2026. The entries below record the anatomical basis and the exact guided variation. No source prose or illustrations were copied into the metadata.

| Preset | Guided variation and anatomical basis | Sources |
| --- | --- | --- |
| `bench` | Flat barbell press: pectoralis major, with anterior deltoid and triceps assistance. | [ACE barbell chest press](https://www.acefitness.org/resources/everyone/exercise-library/5/chest-press/), [NASM barbell bench press](https://www.nasm.org/resource-center/exercise-library/barbell-bench-press) |
| `deadlift` | Conventional barbell lift: hip and knee extension involve glutes, quadriceps and hamstrings. Back and grip roles are kept separate. | [NASM barbell deadlift](https://www.nasm.org/resource-center/exercise-library/barbell-deadlift) |
| `squat` | Barbell back squat: quadriceps and gluteal emphasis; hamstrings assist. Abdominals and spinal erectors maintain the trunk. | [NASM squat biomechanics](https://www.nasm.org/resource-center/blog/training/biomechanics-of-the-squat) |
| `row` | Overhand bent-over barbell row: lats and scapular retractors, with posterior deltoids and elbow flexors assisting. | [ACE bent-over row](https://www.acefitness.org/resources/everyone/exercise-library/12/bent-over-row/), [NSCA technique anatomy, Module 3.2](https://www.nsca.com/contentassets/24f7e187e9aa4a588439c9612231c7fd/tsac-module-3.0--3.3.pdf) |
| `overhead-press` | Standing barbell press: anterior and middle deltoids, assisted by triceps and scapular muscles. Standing trunk control is separate. | [ACE standing shoulder press](https://www.acefitness.org/resources/everyone/exercise-library/71/standing-shoulder-press/), [NSCA shoulder-press anatomy](https://www.nsca.com/contentassets/24f7e187e9aa4a588439c9612231c7fd/tsac-module-3.0--3.3.pdf) |
| `lat-pulldown` | Seated cable pulldown in front of the head: lats, with elbow flexors, posterior deltoids and scapular muscles assisting. | [NASM pulldown biomechanics](https://www.nasm.org/resource-center/blog/training/the-biomechanics-of-the-lat-pulldown-muscles-grip-and-form), [ACE seated pulldown](https://www.acefitness.org/resources/everyone/exercise-library/158/seated-lat-pulldown/) |
| `romanian-deadlift` | Barbell hip hinge from standing: hamstrings and glutes; the trunk and grip hold position. | [NASM barbell RDL](https://www.nasm.org/resource-center/exercise-library/romanian-deadlift-barbell), [ACE RDL anatomy](https://www.acefitness.org/continuing-education/certified/may-2025/8865/the-ace-do-it-better-series-the-romanian-deadlift/) |
| `dumbbell-bench` | Flat dumbbell press: pectoral emphasis with shoulder and triceps assistance. | [ACE dumbbell chest press](https://www.acefitness.org/resources/everyone/exercise-library/19/chest-press/) |
| `pull-up` | Overhand bodyweight pull-up: lats, assisted by scapular muscles, biceps and posterior deltoids; core and grip provide stability. | [NASM pull-up](https://www.nasm.org/resource-center/exercise-library/pull-up) |
| `leg-press` | Seated machine press: quadriceps and glutes with hamstring assistance. | [NASM leg press](https://www.nasm.org/resource-center/exercise-library/leg-press) |
| `leg-curl` | Lying machine knee curl: hamstrings, with gastrocnemius assistance represented by the calf region. | [NASM lying leg curl](https://www.nasm.org/resource-center/exercise-library/lying-leg-curl) |
| `leg-extension` | Seated machine knee extension: quadriceps. | [ACE leg-extension explanation](https://www.acefitness.org/continuing-education/prosource/september-2014/4975/best-exercises-for-great-legs-and-pain-free-knees/) |
| `lunge` | Forward lunge holding dumbbells: knee and hip extensors with trunk and grip control. | [ACE dumbbell forward lunge](https://www.acefitness.org/resources/everyone/exercise-library/363/lunge/), [NSCA lunge](https://www.nsca.com/education/articles/ptq/the-undervalued-lunge/), [NSCA lower-body anatomy](https://www.nsca.com/contentassets/24f7e187e9aa4a588439c9612231c7fd/tsac-module-3.0--3.3.pdf) |
| `biceps-curl` | Seated dumbbell curl, palms forward: biceps and brachialis; brachioradialis assistance is represented by the forearm region. | [ACE seated curl](https://www.acefitness.org/resources/everyone/exercise-library/44/seated-biceps-curl/), [NSCA elbow-flexor anatomy, Module 3.0](https://www.nsca.com/contentassets/24f7e187e9aa4a588439c9612231c7fd/tsac-module-3.0--3.3.pdf) |
| `triceps-extension` | Standing cable rope pressdown, as specified in the existing guide; elbow extension emphasizes triceps. | [ACE rope pressdown](https://www.acefitness.org/resources/everyone/exercise-library/3/triceps-pressdown/), [NSCA triceps action](https://www.nsca.com/contentassets/24f7e187e9aa4a588439c9612231c7fd/tsac-module-3.0--3.3.pdf) |
| `lateral-raise` | Standing dumbbell raise: middle deltoid emphasis with scapular assistance. | [ACE lateral raise](https://www.acefitness.org/resources/everyone/exercise-library/26/lateral-raise/), [ACE shoulder mechanics](https://www.acefitness.org/continuing-education/certified/september-2025/8951/a-pro-s-guide-to-muscle-mechanics-the-shoulders/) |
| `calf-raise` | Seated foot-press machine with legs supported in front, matching the guide. This is not a bent-knee seated calf machine or a claim of soleus isolation. | [ACE foot-press calf raise](https://www.acefitness.org/resources/everyone/exercise-library/294/calf-raise/) |
| `hip-thrust` | Barbell across the hips, shoulders supported on a bench: gluteal emphasis with hamstrings assisting. | [ACE barbell hip thrust](https://www.acefitness.org/continuing-education/certified/november-2019/7403/understanding-the-barbell-hip-thrust/) |
| `cable-row` | Seated low cable row to the abdomen: lats and scapular retractors; elbow flexors and posterior deltoids assist. | [ACE seated cable row](https://www.acefitness.org/resources/everyone/exercise-library/48/seated-row/), [NASM close-grip row anatomy](https://www.nasm.org/resource-center/exercise-library/seated-machine-row-close-grip) |
| `push-up` | Floor push-up with legs extended: chest, with anterior shoulder and triceps assistance; the trunk remains aligned. | [NASM push-up](https://www.nasm.org/resource-center/exercise-library/push-up) |

The split between movement assistance and static stabilization is an implementation interpretation of the sources' joint actions, grip and posture cues. In particular, spinal erectors in a neutral-spine hinge, abdominal bracing and sustained gripping are recorded as stabilizing. Quadriceps in the hip thrust hold the bent-knee position rather than being presented as a knee-extension target. The source descriptions do not supply measurements for these categories.

## Verification

`ExerciseMuscleMapTests` covers preset coverage, unknown/custom fallback, distinct role sets, movement-specific differences and the ambiguous guide variations. The same muscle region never appears twice or under two roles within a map.

The focused command is:

```sh
bash scripts/test.sh --scratch-path /private/tmp/senda-learn-domain-build --cache-path /private/tmp/senda-learn-domain-cache --config-path /private/tmp/senda-learn-domain-config --security-path /private/tmp/senda-learn-domain-security --disable-sandbox --filter ExerciseMuscleMapTests
```

The domain model and tests compiled in the focused run. Final test execution is covered by the integrated Learn verification after all concurrent view and illustration changes are present.
