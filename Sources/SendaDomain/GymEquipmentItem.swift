/// Inventory choices keep stable identifiers when their display labels change.
public enum GymEquipmentItem: String, CaseIterable, Codable, Hashable, Sendable {
    case dumbbells, kettlebells, barbell, weightPlates, bumperPlates, ezBar, trapBar, safetySquatBar
    case landmine, weightVest, weightedBackpack
    case flatBench, adjustableBench, inclineBench, uprightBench, declineBench, rack, powerRack
    case preacherBench, anchoredBench, sealRowBench, box, step, pullingBlocks, heelWedge, calfBlock
    case cableMachine, dualCableMachine, cableRope, cableBar, ankleCuff, rowHandle, wideRowBar
    case latPulldown, cableRow, dipBelt
    case resistanceBand, miniBand, bandAnchor, overheadAnchor, pullUpBar, multiGripBar, dipBars
    case parallettes, pushUpHandles, rings, suspensionTrainer, verticalKneeRaise, ankleAnchor, partner
    case chair, fixedSupport, wall, doorframe
    case smithMachine, assistedDips, assistedPullUps, chestPress, inclineChestPress, pecDeck
    case reverseFly, shoulderPress, lateralRaise, chestSupportedRow, tBarRow, highRow, pullover, shrug
    case preacherCurl, seatedDipPress, tricepsMachine, inclineLegPress, horizontalLegPress
    case verticalLegPress, hackSquat, pendulumSquat, beltSquat, leverSquat, legExtension, seatedLegCurl
    case lyingLegCurl, standingLegCurl, hipAbduction, hipAdduction, hipThrust, gluteKickback
    case standingCalfRaise, seatedCalfRaise, donkeyCalfRaise, gluteHamDeveloper, backExtensionBench
    case backExtension, reverseHyper, abCrunch, torsoRotation
    case treadmill, inclineTreadmill, curvedTreadmill, uprightBike, indoorBike, recumbentBike, airBike
    case bikeErg, rower, skiErg, elliptical, recumbentCrossTrainer, armErgometer, stairmill
    case stairStepper, verticalClimber, jumpRope, miniTrampoline, battleRope, heavyBag, boxingGloves
    case speedBag, pool, flotationBelt, stairs, hill
    case medicineBall, slamBall, wallBall, wallTarget, stabilityBall, abWheel, abMat, sliders
    case stretchStrap, dowel, foamRoller, balancePad, balanceBoard, cones, agilityLadder, hurdles
    case pilatesReformer, handGripper, wristRoller, tibBar
    case sled, dragStraps, pullingRope, towingHarness, sandbag, throwingSandbag, throwingKeg
    case strongmanCrossbar, heightStandard, atlasStone, loadingPlatform, husafellStone, axleBar
    case strongmanLog, circusDumbbell, farmersHandles, carryFrame, duckWalkHandle, yoke, conansWheel
    case powerStairs, herculesHold, hingedPole, tractorTire, vehicle, climbingRope, pegboard

    public var label: String {
        switch self {
        case .dumbbells: "Dumbbells"
        case .kettlebells: "Kettlebells"
        case .barbell: "Barbell"
        case .weightPlates: "Weight plates"
        case .bumperPlates: "Bumper plates"
        case .ezBar: "EZ curl bar"
        case .trapBar: "Trap bar"
        case .safetySquatBar: "Safety squat bar"
        case .landmine: "Landmine attachment"
        case .weightVest: "Weight vest"
        case .weightedBackpack: "Weighted backpack"
        case .flatBench: "Flat bench"
        case .adjustableBench: "Adjustable bench"
        case .inclineBench: "Fixed incline bench"
        case .uprightBench: "Upright bench"
        case .declineBench: "Decline bench"
        case .rack: "Squat rack"
        case .powerRack: "Power rack with safeties"
        case .preacherBench: "Preacher curl bench"
        case .anchoredBench: "Anchored bench"
        case .sealRowBench: "Seal row bench"
        case .box: "Plyometric box"
        case .step: "Exercise step"
        case .pullingBlocks: "Pulling blocks"
        case .heelWedge: "Heel wedge"
        case .calfBlock: "Calf block"
        case .cableMachine: "Cable machine with handles"
        case .dualCableMachine: "Dual cable machine with handles"
        case .cableRope: "Rope attachment"
        case .cableBar: "Straight cable bar"
        case .ankleCuff: "Cable ankle cuff"
        case .rowHandle: "Close-grip row handle"
        case .wideRowBar: "Wide row bar"
        case .latPulldown: "Lat pulldown station with bar"
        case .cableRow: "Seated cable row station with handle"
        case .dipBelt: "Dip belt"
        case .resistanceBand: "Long resistance band"
        case .miniBand: "Mini loop band"
        case .bandAnchor: "Fixed band anchor"
        case .overheadAnchor: "Overhead anchor"
        case .pullUpBar: "Pull-up bar"
        case .multiGripBar: "Multi-grip pull-up bar"
        case .dipBars: "Parallel dip bars"
        case .parallettes: "Parallettes"
        case .pushUpHandles: "Push-up handles"
        case .rings: "Gymnastic rings"
        case .suspensionTrainer: "Suspension trainer"
        case .verticalKneeRaise: "Vertical knee raise station"
        case .ankleAnchor: "Ankle anchor for Nordic curls"
        case .partner: "Workout partner"
        case .chair: "Sturdy chair"
        case .fixedSupport: "Fixed support or counter"
        case .wall: "Wall"
        case .doorframe: "Doorframe"
        case .smithMachine: "Smith machine"
        case .assistedDips: "Assisted dip machine"
        case .assistedPullUps: "Assisted pull-up machine"
        case .chestPress: "Chest press machine"
        case .inclineChestPress: "Plate-loaded incline chest press"
        case .pecDeck: "Pec deck machine"
        case .reverseFly: "Reverse fly machine"
        case .shoulderPress: "Shoulder press machine"
        case .lateralRaise: "Lateral raise machine"
        case .chestSupportedRow: "Chest-supported row machine"
        case .tBarRow: "Chest-supported T-bar row machine"
        case .highRow: "Plate-loaded high row machine"
        case .pullover: "Pullover machine"
        case .shrug: "Shrug machine"
        case .preacherCurl: "Preacher curl machine"
        case .seatedDipPress: "Seated dip press machine"
        case .tricepsMachine: "Triceps extension machine"
        case .inclineLegPress: "Incline leg press"
        case .horizontalLegPress: "Horizontal leg press"
        case .verticalLegPress: "Vertical leg press"
        case .hackSquat: "Hack squat machine"
        case .pendulumSquat: "Pendulum squat machine"
        case .beltSquat: "Belt squat machine with belt"
        case .leverSquat: "Lever squat machine"
        case .legExtension: "Leg extension machine"
        case .seatedLegCurl: "Seated leg curl machine"
        case .lyingLegCurl: "Lying leg curl machine"
        case .standingLegCurl: "Standing leg curl machine"
        case .hipAbduction: "Hip abduction machine"
        case .hipAdduction: "Hip adduction machine"
        case .hipThrust: "Hip thrust machine"
        case .gluteKickback: "Glute kickback machine"
        case .standingCalfRaise: "Standing calf raise machine"
        case .seatedCalfRaise: "Seated calf raise machine"
        case .donkeyCalfRaise: "Donkey calf raise machine"
        case .gluteHamDeveloper: "Glute-ham developer"
        case .backExtensionBench: "45-degree back extension bench"
        case .backExtension: "Back extension machine"
        case .reverseHyper: "Reverse hyperextension machine"
        case .abCrunch: "Abdominal crunch machine"
        case .torsoRotation: "Torso rotation machine"
        case .treadmill: "Treadmill"
        case .inclineTreadmill: "Incline treadmill"
        case .curvedTreadmill: "Curved manual treadmill"
        case .uprightBike: "Upright exercise bike"
        case .indoorBike: "Indoor cycling bike"
        case .recumbentBike: "Recumbent exercise bike"
        case .airBike: "Air bike"
        case .bikeErg: "BikeErg"
        case .rower: "Rowing machine"
        case .skiErg: "Ski ergometer"
        case .elliptical: "Elliptical trainer"
        case .recumbentCrossTrainer: "Recumbent cross-trainer"
        case .armErgometer: "Arm ergometer"
        case .stairmill: "Rotating stair machine"
        case .stairStepper: "Pedal stair stepper"
        case .verticalClimber: "Vertical climbing machine"
        case .jumpRope: "Jump rope"
        case .miniTrampoline: "Mini trampoline"
        case .battleRope: "Battle rope with anchor"
        case .heavyBag: "Mounted heavy bag"
        case .boxingGloves: "Boxing gloves"
        case .speedBag: "Speed bag with platform"
        case .pool: "Pool"
        case .flotationBelt: "Flotation belt"
        case .stairs: "Stairs"
        case .hill: "Hill"
        case .medicineBall: "Medicine ball"
        case .slamBall: "Slam ball"
        case .wallBall: "Wall ball"
        case .wallTarget: "Wall ball target"
        case .stabilityBall: "Stability ball"
        case .abWheel: "Ab wheel"
        case .abMat: "AbMat"
        case .sliders: "Exercise sliders"
        case .stretchStrap: "Stretch strap"
        case .dowel: "PVC pipe or dowel"
        case .foamRoller: "Foam roller"
        case .balancePad: "Balance pad"
        case .balanceBoard: "Balance board"
        case .cones: "Cones or markers"
        case .agilityLadder: "Agility ladder"
        case .hurdles: "Training hurdles"
        case .pilatesReformer: "Pilates reformer"
        case .handGripper: "Hand gripper"
        case .wristRoller: "Wrist roller"
        case .tibBar: "Tib bar"
        case .sled: "Weight sled"
        case .dragStraps: "Sled drag straps"
        case .pullingRope: "Pulling rope"
        case .towingHarness: "Towing harness"
        case .sandbag: "Sandbag"
        case .throwingSandbag: "Throwing sandbag"
        case .throwingKeg: "Throwing keg"
        case .strongmanCrossbar: "Strongman crossbar"
        case .heightStandard: "Height standard"
        case .atlasStone: "Atlas stone"
        case .loadingPlatform: "Stone loading platform"
        case .husafellStone: "Húsafell stone"
        case .axleBar: "Axle bar"
        case .strongmanLog: "Strongman log"
        case .circusDumbbell: "Circus dumbbell"
        case .farmersHandles: "Farmer’s walk handles"
        case .carryFrame: "Carry frame"
        case .duckWalkHandle: "Duck walk handle"
        case .yoke: "Yoke"
        case .conansWheel: "Conan’s wheel"
        case .powerStairs: "Power stairs with loading implement"
        case .herculesHold: "Hercules hold apparatus"
        case .hingedPole: "Hinged strongman pole"
        case .tractorTire: "Tractor tire"
        case .vehicle: "Towing vehicle"
        case .climbingRope: "Climbing rope"
        case .pegboard: "Climbing pegboard with pegs"
        }
    }

    public var section: String {
        switch self {
        case .dumbbells, .kettlebells, .barbell, .weightPlates, .bumperPlates, .ezBar, .trapBar,
             .safetySquatBar, .landmine, .weightVest, .weightedBackpack:
            "Free weights"
        case .flatBench, .adjustableBench, .inclineBench, .uprightBench, .declineBench, .rack, .powerRack,
             .preacherBench, .anchoredBench, .sealRowBench, .box, .step, .pullingBlocks, .heelWedge, .calfBlock:
            "Benches, racks and steps"
        case .cableMachine, .dualCableMachine, .cableRope, .cableBar, .ankleCuff, .rowHandle, .wideRowBar,
             .latPulldown, .cableRow, .dipBelt:
            "Cables and attachments"
        case .resistanceBand, .miniBand, .bandAnchor, .overheadAnchor, .pullUpBar, .multiGripBar, .dipBars,
             .parallettes, .pushUpHandles, .rings, .suspensionTrainer, .verticalKneeRaise, .ankleAnchor,
             .partner, .chair, .fixedSupport, .wall, .doorframe:
            "Bands and bodyweight equipment"
        case .smithMachine, .assistedDips, .assistedPullUps, .chestPress, .inclineChestPress, .pecDeck,
             .reverseFly, .shoulderPress, .lateralRaise, .chestSupportedRow, .tBarRow, .highRow, .pullover,
             .shrug, .preacherCurl, .seatedDipPress, .tricepsMachine, .inclineLegPress, .horizontalLegPress,
             .verticalLegPress, .hackSquat, .pendulumSquat, .beltSquat, .leverSquat, .legExtension,
             .seatedLegCurl, .lyingLegCurl, .standingLegCurl, .hipAbduction, .hipAdduction, .hipThrust,
             .gluteKickback, .standingCalfRaise, .seatedCalfRaise, .donkeyCalfRaise, .gluteHamDeveloper,
             .backExtensionBench, .backExtension, .reverseHyper, .abCrunch, .torsoRotation:
            "Strength machines"
        case .treadmill, .inclineTreadmill, .curvedTreadmill, .uprightBike, .indoorBike, .recumbentBike,
             .airBike, .bikeErg, .rower, .skiErg, .elliptical, .recumbentCrossTrainer, .armErgometer,
             .stairmill, .stairStepper, .verticalClimber, .jumpRope, .miniTrampoline, .battleRope, .heavyBag,
             .boxingGloves, .speedBag, .pool, .flotationBelt, .stairs, .hill:
            "Cardio and conditioning"
        case .medicineBall, .slamBall, .wallBall, .wallTarget, .stabilityBall, .abWheel, .abMat, .sliders,
             .stretchStrap, .dowel, .foamRoller, .balancePad, .balanceBoard, .cones, .agilityLadder, .hurdles,
             .pilatesReformer, .handGripper, .wristRoller, .tibBar:
            "Training accessories"
        case .sled, .dragStraps, .pullingRope, .towingHarness, .sandbag, .throwingSandbag, .throwingKeg,
             .strongmanCrossbar, .heightStandard, .atlasStone, .loadingPlatform, .husafellStone, .axleBar,
             .strongmanLog, .circusDumbbell, .farmersHandles, .carryFrame, .duckWalkHandle, .yoke,
             .conansWheel, .powerStairs, .herculesHold, .hingedPole, .tractorTire, .vehicle, .climbingRope,
             .pegboard:
            "Strongman, sleds and climbing"
        }
    }

    public func matchesSearch(key: String) -> Bool {
        key.isEmpty || ([label] + searchTerms).contains { ExerciseLibrary.matchingKey($0).contains(key) }
    }

    public var searchTerms: [String] {
        switch self {
        case .dumbbells: ["DB", "hand weights"]
        case .kettlebells: ["KB"]
        case .barbell: ["Olympic bar", "straight bar"]
        case .weightPlates: ["discs", "disks"]
        case .bumperPlates: ["Olympic plates"]
        case .ezBar: ["EZ-bar", "EZ bar"]
        case .trapBar: ["hex bar"]
        case .safetySquatBar: ["SSB"]
        case .weightVest: ["weighted vest"]
        case .weightedBackpack: ["ruck", "rucksack"]
        case .flatBench: ["weight bench"]
        case .adjustableBench: ["incline bench", "upright bench", "weight bench"]
        case .uprightBench: ["seated press bench"]
        case .rack: ["stands", "bench rack"]
        case .powerRack: ["cage", "safety pins", "safety bars", "squat rack"]
        case .preacherBench: ["Scott bench"]
        case .anchoredBench: ["fixed bench", "bolted bench"]
        case .box: ["plyo box", "jump box"]
        case .step: ["step platform", "stepper platform"]
        case .pullingBlocks: ["lifting blocks", "jerk blocks"]
        case .heelWedge: ["squat wedge", "squat ramp"]
        case .cableMachine: ["cable station", "adjustable pulley", "functional trainer"]
        case .dualCableMachine: ["cable crossover", "functional trainer", "two pulleys"]
        case .cableRope: ["cable rope", "triceps rope"]
        case .cableBar: ["pushdown bar", "straight bar attachment"]
        case .ankleCuff: ["ankle strap"]
        case .rowHandle: ["V-bar", "V handle", "neutral grip handle"]
        case .latPulldown: ["lat bar", "lat machine", "lat pull-down"]
        case .cableRow: ["low row", "pulley row"]
        case .dipBelt: ["weighted pull-up belt"]
        case .resistanceBand: ["exercise band", "pull-up band", "tube band"]
        case .miniBand: ["mini-band", "booty band"]
        case .bandAnchor: ["door anchor", "band anchor"]
        case .overheadAnchor: ["ceiling mount", "hanging point"]
        case .pullUpBar: ["chin-up bar", "pullup bar"]
        case .multiGripBar: ["neutral grip", "parallel grip", "chin-up bar"]
        case .dipBars: ["dipping station"]
        case .parallettes: ["mini parallel bars"]
        case .pushUpHandles: ["pushup bars"]
        case .rings: ["gymnastics rings"]
        case .suspensionTrainer: ["TRX", "suspension straps"]
        case .verticalKneeRaise: ["captain’s chair", "power tower"]
        case .ankleAnchor: ["Nordic strap", "foot anchor"]
        case .chair: ["seat", "chair with backrest"]
        case .fixedSupport: ["countertop", "rail"]
        case .doorframe: ["doorway"]
        case .assistedDips: ["assisted pull-up and dip station"]
        case .assistedPullUps: ["assisted pull-up and dip station", "gravitron"]
        case .pecDeck: ["chest fly machine"]
        case .reverseFly: ["reverse pec deck"]
        case .inclineLegPress: ["45-degree leg press", "sled leg press"]
        case .horizontalLegPress: ["seated leg press"]
        case .legExtension: ["knee extension"]
        case .seatedLegCurl: ["hamstring curl"]
        case .lyingLegCurl: ["hamstring curl"]
        case .standingLegCurl: ["hamstring curl"]
        case .hipThrust: ["glute drive"]
        case .gluteHamDeveloper: ["GHD"]
        case .backExtensionBench: ["Roman chair", "hyperextension bench"]
        case .reverseHyper: ["reverse hyper"]
        case .abCrunch: ["ab crunch"]
        case .torsoRotation: ["rotary torso"]
        case .uprightBike: ["stationary bike"]
        case .indoorBike: ["spin bike", "spinning"]
        case .airBike: ["assault bike", "fan bike"]
        case .bikeErg: ["Concept2"]
        case .rower: ["rower", "rowing ergometer"]
        case .skiErg: ["SkiErg"]
        case .elliptical: ["cross trainer"]
        case .armErgometer: ["arm bike", "UBE"]
        case .stairmill: ["stairmill", "StairMaster"]
        case .verticalClimber: ["VersaClimber"]
        case .jumpRope: ["skipping rope"]
        case .miniTrampoline: ["rebounder"]
        case .heavyBag: ["punching bag"]
        case .flotationBelt: ["aqua jogging belt"]
        case .medicineBall: ["med ball"]
        case .stabilityBall: ["Swiss ball", "exercise ball"]
        case .abWheel: ["ab roller"]
        case .abMat: ["sit-up mat"]
        case .sliders: ["gliding discs", "slide discs"]
        case .stretchStrap: ["yoga strap"]
        case .dowel: ["broomstick"]
        case .balancePad: ["foam pad"]
        case .balanceBoard: ["wobble board"]
        case .cones: ["agility cones"]
        case .agilityLadder: ["speed ladder"]
        case .hurdles: ["agility hurdles"]
        case .handGripper: ["grip trainer"]
        case .tibBar: ["tibialis bar"]
        case .sled: ["prowler", "push sled"]
        case .pullingRope: ["sled rope"]
        case .towingHarness: ["sled harness"]
        case .throwingSandbag: ["throw bag"]
        case .heightStandard: ["toss bar"]
        case .axleBar: ["thick bar"]
        case .strongmanLog: ["log bar"]
        case .farmersHandles: ["farmer carry"]
        case .hingedPole: ["Fingal’s fingers"]
        case .tractorTire: ["tyre"]
        case .vehicle: ["truck pull"]
        default: []
        }
    }
}
