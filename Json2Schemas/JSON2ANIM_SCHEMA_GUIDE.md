# JSON2Anim Schema Guide

This document is the normative authoring reference for JSON2Anim schema version `1`, plugin version `1.0.0`.

- **Verification Date:** September 24, 2026
- **Verified Studio Build:** Roblox Studio `0.740.0.7400927`
- **Specification Status:** Stable / Normative
- **Engine Identity:** `Script:JSON2Anim`

The schema is deliberately strict. Unknown fields, unsupported classes, unsupported properties, unresolved references, unsafe asset strings, invalid parent relationships, NaN/Infinity numeric values, and out-of-range values fail before generated roots are attached to the target.

---

## 1. Document Principles

1. **Strict JSON Format:** Input must be standard JSON (RFC 8259). Luau table syntax, JSON5, JavaScript objects, trailing commas, single-quoted strings, unquoted keys, and NaN/Infinity numeric literals are strictly rejected.
2. **Explicit Double Quotes:** All object keys and string values must be enclosed in ASCII double quotes (`"`).
3. **Comment Fields:** Comments must use schema-defined `Comment` or `$comment` string fields. Inline comments (`//` or `/* */`) are rejected by the parser.
4. **Zero Null Tolerance:** JSON `null` is rejected everywhere in the document. Optional fields must be omitted entirely instead of assigned `null`.
5. **Dense Arrays:** All arrays (`Roots`, `Children`, `Tags`, numeric vectors, keypoint lists) must be dense with consecutive integer indices starting at 1.
6. **Case Sensitivity:** Class names, property names, enum item names, and `$type` descriptors require exact PascalCase Roblox capitalization unless explicit case-insensitivity is defined.
7. **Finite Numbers:** Every numeric value must be finite. `NaN`, `Infinity`, and `-Infinity` cause immediate parse or validation failures.
8. **Explicit Class & Property Allowlists:** A class is accepted only if present in the 9-class animation profile. A property is accepted only if explicitly allowlisted for that class.
9. **Automatic Keyframe Sorting:** Keyframe timestamps in `KeyframeSequence` are automatically sorted in strictly ascending chronological order off-tree, ensuring accurate native Roblox child order. Duplicate timestamps within the same sequence fail validation.
10. **Pose Naming Invariant:** Every `Pose` and `NumberPose` node requires a non-empty `Name` matching the target joint, FACS control channel, bone, or curve track. Duplicate joint names within a single keyframe fail validation.
11. **Off-Tree Preflight & Atomicity:** Before any instance is attached to the place DataModel, the complete hierarchy is instantiated off-tree, configured, cross-referenced, and validated in temporary memory. If any error occurs, all staged instances are destroyed, leaving the target parent untouched.
12. **Native Studio Authority:** Roblox Studio engine reflection and native Luau property assignment remain the final authority after schema and policy checks succeed.

---

## 2. Accepted Root Forms

JSON2Anim accepts exactly three document root forms.

### 2.1 Single Node Root

A solitary node object at the root of the JSON document:

```json
{
  "ClassName": "KeyframeSequence",
  "Name": "IdlePose",
  "Properties": {
    "Loop": true,
    "Priority": "Idle"
  },
  "Children": [
    {
      "ClassName": "Keyframe",
      "Properties": { "Time": 0 },
      "Children": [
        {
          "ClassName": "Pose",
          "Name": "Head",
          "Properties": {
            "CFrame": { "$type": "CFrame", "Orientation": [0, 10, 0] }
          }
        }
      ]
    }
  ]
}
```

The engine normalizes this internally as `Roots = [ <Node> ]`.

### 2.2 Dense Root Array

A dense JSON array containing one or more top-level node objects:

```json
[
  {
    "ClassName": "Folder",
    "Name": "LocomotionAnimations",
    "Children": [
      {
        "ClassName": "KeyframeSequence",
        "Name": "Walk"
      },
      {
        "ClassName": "KeyframeSequence",
        "Name": "Run"
      }
    ]
  },
  {
    "ClassName": "Configuration",
    "Name": "AnimationMetadata"
  }
]
```

The array must contain at least one node and cannot contain `null` items or sparse keys.

### 2.3 Document Wrapper With Options

A root object providing document-level configuration options and metadata alongside the `Roots` array:

```json
{
  "Roots": [
    {
      "ClassName": "KeyframeSequence",
      "Name": "WaveAnimation",
      "Properties": {
        "Loop": false,
        "Priority": "Action",
        "AuthoredHipHeight": 2.0
      },
      "Children": [
        {
          "ClassName": "Keyframe",
          "Properties": { "Time": 0 },
          "Children": [
            {
              "ClassName": "Pose",
              "Name": "RightUpperArm",
              "Properties": {
                "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 90] },
                "Weight": 1.0,
                "EasingStyle": "CubicV2",
                "EasingDirection": "InOut"
              }
            }
          ]
        }
      ]
    }
  ],
  "Options": {
    "SelectGenerated": true,
    "GenerationLabel": "JSON2Anim: Generate Wave Animation"
  },
  "Comment": "Authoring wrapper for character gesture animations",
  "$comment": "Alternate comment field"
}
```

#### Document Wrapper Fields

| Field | Required | Type | Limit | Description |
|---|:---:|---|---|---|
| `Roots` | **Yes** | dense array | $1 \le N \le 5,000$ | Non-empty array of root node objects. |
| `Options` | No | object | 4 fields | Document-level configuration options object. |
| `Comment` | No | string | $\le 10,000,000$ bytes | Optional documentation string (ignored by engine). |
| `$comment` | No | string | $\le 10,000,000$ bytes | Optional documentation string (ignored by engine). |

Unknown wrapper fields fail validation.

---

## 3. Document Options

When using the Document Wrapper, the `Options` dictionary accepts the following settings:

| Option | Type | Default | Permitted Values | Description |
|---|---|---|---|---|
| `SelectGenerated` | boolean | `true` | `true`, `false` | When `true`, automatically selects all attached root instances in Studio Explorer after successful generation. |
| `GenerationLabel` | string | `"JSON2Anim: Generate Animation"` | string ($\le 1,000$ bytes) | Human-readable label recorded in Roblox Studio undo history (`ChangeHistoryService`). |
| `StrictHierarchyChecking` | boolean | `false` | `true`, `false` | When `true`, `Animation` nodes must sit under an `Animator`, `AnimationController`, `Humanoid`, or container; any other parent fails closed with a path-rich message. |
| `ValidationWarningThreshold` | integer | `200` | integer ($10 \le n \le 500$) | Maximum allowed schema validation warnings before processing aborts. |

Unknown fields inside `Options` fail validation.

---

## 4. Node Object Contract

Every node object in `Roots` or `Children` follows this exact JSON structure:

```json
{
  "ClassName": "Pose",
  "Id": "armPose_01",
  "Name": "RightUpperArm",
  "Properties": {
    "CFrame": {
      "$type": "CFrame",
      "Orientation": [0, 0, 90]
    },
    "Weight": 1.0,
    "EasingStyle": "CubicV2",
    "EasingDirection": "InOut"
  },
  "Attributes": {
    "GeneratedBy": "JSON2Anim",
    "SchemaVersion": 1,
    "TrackIndex": 4
  },
  "Tags": [
    "JSON2Anim",
    "UpperBodyTrack"
  ],
  "Children": [],
  "Comment": "Right shoulder lift pose",
  "$comment": "Alternate comment key"
}
```

### Complete Node Fields Reference

| Field | Required | Type | Limits | Description |
|---|:---:|---|---|---|
| `ClassName` | **Yes** | string | 1–1,000 bytes | Exact name of the approved Roblox animation or container class. |
| `Id` | No | string | 1–1,000 bytes | Unique document-wide reference identifier (`[A-Za-z_][A-Za-z0-9_.-]*`). Must start with a letter or underscore. |
| `Name` | Conditional | string | 0–10,000 bytes | Assigned to `Instance.Name`. **Required for `Pose` and `NumberPose`**. Mutually exclusive with `Properties.Name`. |
| `Properties` | No | object | $\le 25,000$ properties | Allowlisted Roblox property assignments for this exact class. |
| `Attributes` | No | object | $\le 10,000$ attributes | Custom instance attributes applied via `Instance:SetAttribute`. |
| `Tags` | No | dense string array | $\le 1,000$ tags | CollectionService tags applied in order via `CollectionService:AddTag`. |
| `Children` | No | dense node array | $\le 1,000,000$ children | Child instance nodes parented under this instance. Max hierarchy depth is 1,000. |
| `Comment` | No | string | $\le 10,000,000$ bytes | Optional documentation string (ignored by engine). |
| `$comment` | No | string | $\le 10,000,000$ bytes | Optional documentation string (ignored by engine). |

Unknown node fields fail validation.

---

## 5. String, Identifier, And Name Constraints

### 5.1 Class and Property Names
- **Length:** 1 to 100 bytes.
- **Pattern:** `^[A-Za-z_][A-Za-z0-9_]*$`
- **Casing:** Exact PascalCase matching Roblox Studio reflection metadata (e.g., `KeyframeSequence`, `AuthoredHipHeight`, `EasingStyle`).

### 5.2 Node Reference Identifiers (`Id`)
- **Length:** 1 to 128 bytes.
- **Pattern:** `^[A-Za-z_][A-Za-z0-9_.-]*$` (must start with an ASCII letter or underscore).
- **Uniqueness:** Must be globally unique across all roots and descendants in the document.
- **Reserved Names:** `"@target"` is reserved and cannot be declared as a node `Id`.

#### Valid IDs:
```text
rootSequence
keyframe_01
pose.RightUpperArm
marker-footstep
anim_asset_2
```

#### Invalid IDs:
```text
1keyframe        (starts with digit)
pose right       (contains whitespace)
@target          (reserved identifier)
pose/sub         (invalid character /)
```

### 5.3 Instance Names (`Name`)
- **Length:** 0 to 1,000 bytes.
- **Character Set:** UTF-8 strings. Control characters (`[ -]`) are rejected.
- **Pose Requirement:** Both `Pose` and `NumberPose` require a non-empty `Name`. For `Pose`, it must match the motor/joint part name (e.g. `RightUpperArm`, `HumanoidRootPart`, `Torso`). For `NumberPose`, it must match the FACS facial slider, bone, or curve track (e.g. `JawDrop`, `EyesLookUp`, `MouthSmileLeft`).
- **Property Normalization:** If top-level `Name` is omitted but `"Properties": { "Name": "..." }` is defined, the engine automatically normalizes it to `node.Name`. A node cannot define both top-level `Name` and `Properties.Name`.

### 5.4 Attribute Names
- **Length:** 1 to 100 bytes.
- **Pattern:** `^[A-Za-z0-9_]+$`
- **Reserved Prefix:** Names starting with `RBX` or `rbx` (case-insensitive) are reserved by Roblox and rejected.
- Control characters are rejected.

### 5.5 CollectionService Tags
- **Length:** 1 to 100 bytes per tag.
- **Uniqueness:** Tags must be unique within a single node's `Tags` array.
- Control characters are rejected.

---

## 6. Cross-Node References & Pointer Architecture

References establish instance pointer relationships (`$ref`) within generated animation hierarchies.

### 6.1 Compact Reference
```json
{
  "$ref": "baseKeyframe"
}
```

### 6.2 Tagged Reference Object
```json
{
  "$type": "Reference",
  "Id": "baseKeyframe"
}
```
*Note: `"Value"` is accepted as an alias for `"Id"` in tagged reference objects (`{"$type": "Reference", "Value": "baseKeyframe"}`).*

### 6.3 Target References (`@target`)
Unlike spatial construction tools, animation instances (`KeyframeSequence`, `Keyframe`, `Pose`, `NumberPose`, `KeyframeMarker`) do not bind to target instances via pointer properties. As such, referencing `@target` inside properties is explicitly rejected in JSON2Anim:
```text
Roots[1].Properties.SomeProperty cannot reference @target; JSON2Anim supports no target references in this build.
```

---

## 7. Attributes

Attributes are applied via `Instance:SetAttribute(name, value)`.

### Rules:
- Maximum 256 attributes per node.
- Names are 1–100 alphanumeric/underscore bytes (`[A-Za-z0-9_]+`).
- Primitive JSON strings, numbers, and booleans are stored directly.
- Tables and structured values require an explicit `$type` tag.
- Roblox attributes cannot store `Instance` references (`$ref` or `$type: "Reference"` is rejected).

### Attribute Example:
```json
{
  "ClassName": "KeyframeSequence",
  "Name": "AttackCombo",
  "Attributes": {
    "AnimationCategory": "Combat",
    "ComboStep": 3,
    "DamageMultiplier": 1.45,
    "IsUncancellable": true,
    "RootMotionOffset": {
      "$type": "Vector3",
      "Value": [0, 0, -4.5]
    }
  }
}
```

---

## 8. CollectionService Tags

Tags are applied in sequence via `CollectionService:AddTag(instance, tag)`.

### Rules:
- Maximum 64 tags per node.
- `Tags` must be a dense array of unique, non-empty strings.
- Maximum 100 bytes per tag string.
- Control characters are rejected.

### Tags Example:
```json
{
  "ClassName": "KeyframeSequence",
  "Name": "SprintCycle",
  "Tags": [
    "JSON2Anim",
    "Locomotion",
    "HighPriorityTrack"
  ]
}
```

---

## 9. Exhaustive Datatype Specifications (19 Types)

For property assignments, JSON2Anim decodes datatypes through its built-in codec:
1. Resolve `$ref` or `$type: "Reference"`.
2. Decode explicit `$type` objects.
3. Read the property's default datatype on the freshly constructed Roblox instance.
4. Decode compact shorthand forms according to the expected datatype.
5. Apply the converted value via protected native assignment.

Tagged `$type` names are case-sensitive and must match one of the 19 supported types below.

---

### 9.1 CFrame (Core Animation Datatype)
Represents a 3D coordinate frame (position and orientation) applied to joint `Pose.CFrame`.

- **Orientation-Only in Degrees (Common for joint poses):**
  ```json
  {
    "$type": "CFrame",
    "Orientation": [0, 90, 0]
  }
  ```
- **3-Number Position Array `[x, y, z]`:**
  ```json
  [0, 2.5, 0]
  ```
- **6-Number Position + Euler Degrees `[x, y, z, rx, ry, rz]`:**
  ```json
  [0, 1.5, 0, 0, 45, 90]
  ```
- **12-Number Transformation Matrix:**
  ```json
  [0, 1.5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
  ```
- **Tagged Object with Position and Orientation (Degrees):**
  ```json
  {
    "$type": "CFrame",
    "Position": [0, 1.5, 0],
    "Orientation": [0, 45, 90]
  }
  ```
- **LookAt / Target Construction:**
  ```json
  {
    "$type": "CFrame",
    "Position": [0, 5, 10],
    "LookAt": [0, 0, 0]
  }
  ```
- **Allowed Tagged Fields:** `Position`, `Orientation`, `Rotation`, `Angles`, `LookAt`, `Target`, `Value`, `Components`, `X`, `Y`, `Z`.
- *Note: Euler angles in `Orientation`, `Rotation`, and `Angles` are always interpreted in **degrees**.*

---

### 9.2 Enum (Animation Priorities and Easing)
Represents Roblox engine enumerations (`AnimationPriority`, `PoseEasingStyle`, `PoseEasingDirection`).

- **Contextual Item Name String (Preferred Shorthand):**
  ```json
  "Action"
  ```
- **Full Enum Identifier String:**
  ```json
  "Enum.AnimationPriority.Action"
  ```
- **Tagged Enum Object:**
  ```json
  {
    "$type": "Enum",
    "EnumType": "PoseEasingStyle",
    "Name": "CubicV2"
  }
  ```
- **Allowed Tagged Fields:** `EnumType`, `Name`, `Value`. Case-insensitive item resolution is supported as a fallback.

---

### 9.3 Vector3
Represents a 3D vector.

- **Compact 3-Number Array `[x, y, z]`:**
  ```json
  [0, 2, 0]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "Vector3",
    "X": 0,
    "Y": 2,
    "Z": 0
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`, `Z`.

---

### 9.4 Vector2
Represents a 2D vector.

- **Compact 2-Number Array `[x, y]`:**
  ```json
  [128, 256]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "Vector2",
    "X": 128,
    "Y": 256
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`.

---

### 9.5 Color3
Represents an RGB color.

- **Hexadecimal String (`"#RGB"` or `"#RRGGBB"`):**
  ```json
  "#4FA3FF"
  ```
- **Packed 24-bit Integer (`0` to `16777215`):**
  ```json
  16753920
  ```
- **Compact 0–255 RGB Array:**
  ```json
  [79, 163, 255]
  ```
- **Tagged 0–255 RGB Object:**
  ```json
  {
    "$type": "Color3",
    "RGB": [79, 163, 255]
  }
  ```
- **Tagged 0.0–1.0 Unit Float Object:**
  ```json
  {
    "$type": "Color3",
    "Unit": [0.31, 0.64, 1.0]
  }
  ```
- **Tagged 0.0–1.0 HSV Object:**
  ```json
  {
    "$type": "Color3",
    "HSV": [0.58, 0.69, 1.0]
  }
  ```
- **Allowed Tagged Fields:** `Hex`, `HSV`, `Unit`, `RGB`, `Value`, `Components`, `R`, `G`, `B`.

---

### 9.6 NumberSequence
Represents a numeric curve over time ($[0.0, 1.0]$).

- **Constant Number:**
  ```json
  1.0
  ```
- **2-Number Start/End Shortcut:**
  ```json
  [0.0, 1.0]
  ```
- **Keypoint Objects List:**
  ```json
  {
    "$type": "NumberSequence",
    "Keypoints": [
      { "Time": 0.0, "Value": 0.0, "Envelope": 0.0 },
      { "Time": 0.5, "Value": 1.0, "Envelope": 0.0 },
      { "Time": 1.0, "Value": 0.0, "Envelope": 0.0 }
    ]
  }
  ```
- **Allowed Tagged Fields:** `Keypoints`, `Value`, `Components`.

---

### 9.7 ColorSequence
Represents a color progression over time ($[0.0, 1.0]$).

- **Constant Color:**
  ```json
  "#FF0000"
  ```
- **Keypoint Objects List:**
  ```json
  {
    "$type": "ColorSequence",
    "Keypoints": [
      { "Time": 0.0, "Value": "#FF0000" },
      { "Time": 1.0, "Value": "#00FF00" }
    ]
  }
  ```

---

### 9.8 NumberRange
Represents a closed numeric interval $[min, max]$.

- **Single Number:**
  ```json
  2.5
  ```
- **Compact 2-Number Array `[min, max]`:**
  ```json
  [1.0, 5.0]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "NumberRange",
    "Min": 1.0,
    "Max": 5.0
  }
  ```

---

### 9.9 UDim
Represents a 1D coordinate component.

- **Compact Array `[scale, offset]`:**
  ```json
  [0.5, 10]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "UDim",
    "Scale": 0.5,
    "Offset": 10
  }
  ```

---

### 9.10 UDim2
Represents a 2D coordinate for layout positioning.

- **Compact 4-Number Array `[xScale, xOffset, yScale, yOffset]`:**
  ```json
  [0.5, 0, 1.0, 0]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "UDim2",
    "XScale": 0.5,
    "XOffset": 0,
    "YScale": 1.0,
    "YOffset": 0
  }
  ```

---

### 9.11 Vector2int16
Represents a 2D signed 16-bit integer vector.

- **Tagged Object / Array:**
  ```json
  {
    "$type": "Vector2int16",
    "Value": [10, 20]
  }
  ```

---

### 9.12 Vector3int16
Represents a 3D signed 16-bit integer vector.

- **Tagged Object / Array:**
  ```json
  {
    "$type": "Vector3int16",
    "Value": [10, 20, 30]
  }
  ```

---

### 9.13 Rect
Represents a 2D bounding rectangle.

- **Compact 4-Number Array `[minX, minY, maxX, maxY]`:**
  ```json
  [0, 0, 512, 512]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "Rect",
    "Min": [0, 0],
    "Max": [512, 512]
  }
  ```

---

### 9.14 BrickColor
Represents standard palette BrickColors.

- **Name String:**
  ```json
  "Bright red"
  ```
- **Palette Integer Number:**
  ```json
  1004
  ```

---

### 9.15 Ray
Represents a 3D ray.

- **Tagged Object:**
  ```json
  {
    "$type": "Ray",
    "Origin": [0, 0, 0],
    "Direction": [0, 10, 0]
  }
  ```

---

### 9.16 PhysicalProperties
Represents custom physical simulation attributes.

- **Material Preset String:**
  ```json
  "Rubber"
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "PhysicalProperties",
    "Density": 1.0,
    "Friction": 0.7,
    "Elasticity": 0.5
  }
  ```

---

### 9.17 Axes
Represents a bitset of coordinate axes.

- **Tagged Object:**
  ```json
  {
    "$type": "Axes",
    "Values": ["X", "Y"]
  }
  ```

---

### 9.18 Faces
Represents a bitset of normal faces.

- **Tagged Object:**
  ```json
  {
    "$type": "Faces",
    "Values": ["Top", "Front"]
  }
  ```

---

### 9.19 Reference
Represents an explicit document instance reference.

- **Tagged Object:**
  ```json
  {
    "$type": "Reference",
    "Id": "targetNodeId"
  }
  ```
- Equivalent to `{"$ref": "targetNodeId"}`.

---

## 10. Supported Generation Targets (9 Targets)

The generation target must be an existing Instance attached to the currently open place DataModel. Clear the Studio selection to default to `Workspace`, or select exactly **one** of the following instances:

| Target Class | Allowed Child Roots | Special Target Rules |
|---|---|---|
| `Workspace` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | Direct generation requires a 2-step confirmation click within 10 seconds. |
| `Folder` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | General-purpose organizational container. |
| `Configuration` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | Metadata and settings container. |
| `Model` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | Assembly group container. |
| `ReplicatedStorage` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | Replicated animation asset storage. |
| `ServerStorage` | `Folder`, `Configuration`, `Model`, `KeyframeSequence`, `Animation` | Server-only animation asset storage. |
| `Animator` | `Animation` | Target for published `Animation` reference roots only. |
| `AnimationController` | `Animation` | Target for published `Animation` reference roots only. |
| `Humanoid` | `Animation` | Target for published `Animation` reference roots only. |

Selecting multiple instances or unapproved containers (e.g. `ScreenGui`, `Lighting`, `StarterPlayer`, `BasePart`) fails validation.

---

## 11. Supported Classes (9 Classes)

JSON2Anim supports exactly **9 classes** categorized into 2 functional groups:

```text
1. Containers (3)
   Folder, Configuration, Model

2. Animation Profile (6)
   KeyframeSequence, Keyframe, Pose, NumberPose, KeyframeMarker, Animation
```

### Class Descriptions

- **`KeyframeSequence`:** The root container representing a complete authored animation clip. Holds sequenced `Keyframe` children.
- **`Keyframe`:** A discrete point in time along the animation timeline. Holds `Pose`, `NumberPose`, and `KeyframeMarker` children.
- **`Pose`:** A 3D spatial transformation (`CFrame`) applied to a named joint (`BasePart` or `Bone`). Supports child sub-poses for skeletal chains.
- **`NumberPose`:** A scalar floating-point value applied to a named FACS control, bone channel, or scalar curve track. Supports child sub-poses.
- **`KeyframeMarker`:** A named event trigger placed at a specific keyframe, fired at playback time via `AnimationTrack:GetMarkerReachedSignal()`.
- **`Animation`:** An instance referencing an existing published Roblox animation asset ID (`AnimationId`).
- **`Folder`, `Configuration`, `Model`:** Organization containers for grouping animation sequences and metadata libraries.

---

## 12. Complete Property Allowlists

`Name` is allowlisted on every supported class. Engine-controlled properties (Section 13) are strictly rejected.

### 12.1 Container Classes
- **`Folder`:** `Name`
- **`Configuration`:** `Name`
- **`Model`:** `Name`, `LevelOfDetail`, `ModelStreamingMode`, `WorldPivot`

### 12.2 `KeyframeSequence`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | `"KeyframeSequence"` | Name of the animation clip instance. |
| `AuthoredHipHeight` | number | $\ge 0$ (Default `2.0`) | Hip height of the authored rig. Guards against NaN and negative values. |
| `Loop` | boolean | `false` | Whether the animation sequence loops during playback. |
| `Priority` | `Enum.AnimationPriority` | `"Action"` | Playback evaluation priority. |

### 12.3 `Keyframe`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | `"Keyframe"` | Name of the keyframe instance. |
| `Time` | number | $\ge 0$ (seconds) | Timestamp in seconds. Must be finite and non-negative. Unique within the sequence. |

### 12.4 `Pose`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | **Mandatory** | Name of the `BasePart` or `Bone` joint to animate. Cannot be empty. Unique within the keyframe. |
| `CFrame` | `CFrame` | Identity | Local transformation offset for the joint. |
| `Weight` | number | $[0.0, 1.0]$ (Default `1.0`) | Blend weight for this pose. NaN is strictly rejected. |
| `EasingStyle` | `Enum.PoseEasingStyle` | `"Linear"` | Interpolation curve (`Linear`, `Constant`, `Elastic`, `Cubic`, `Bounce`, `CubicV2`). |
| `EasingDirection` | `Enum.PoseEasingDirection` | `"In"` | Interpolation curve direction (`In`, `Out`, `InOut`). |

### 12.5 `NumberPose`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | **Mandatory** | Name of the FACS slider, bone channel, or curve track. Cannot be empty. Unique within the keyframe. |
| `Value` | number | Finite float (Default `0.0`) | Target scalar channel value. NaN and Infinity are strictly rejected. |
| `Weight` | number | $[0.0, 1.0]$ (Default `1.0`) | Blend weight for this pose. NaN is strictly rejected. |
| `EasingStyle` | `Enum.PoseEasingStyle` | `"Linear"` | Interpolation curve (`Linear`, `Constant`, `Elastic`, `Cubic`, `Bounce`, `CubicV2`). |
| `EasingDirection` | `Enum.PoseEasingDirection` | `"In"` | Interpolation curve direction (`In`, `Out`, `InOut`). |

### 12.6 `KeyframeMarker`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | `"KeyframeMarker"` | Event identifier matching `AnimationTrack:GetMarkerReachedSignal(name)`. |
| `Value` | string | `""` | String parameter payload delivered to signal listeners. |

### 12.7 `Animation`
| Property | Expected Type | Default / Range | Description |
|---|---|---|---|
| `Name` | string | `"Animation"` | Name of the animation reference instance. |
| `AnimationId` | string / number | **Mandatory** | Published asset identifier (`rbxassetid://<id>` or numeric id). |

---

## 13. Controlled, Blocked, And Deprecated Properties

### 13.1 Controlled Properties
These properties are managed exclusively by the engine and are strictly forbidden inside `Properties`:

```text
Parent                  (Managed by hierarchy tree nesting and target attachment)
ClassName               (Managed by node ClassName field)
Source                  (Blocked: executable script source)
LinkedSource            (Blocked: executable script source)
RunContext              (Blocked: script execution context)
ScriptGuid              (Blocked: internal engine identifier)
SourceAssetId           (Blocked: internal asset pointer)
RobloxLocked            (Blocked: internal engine protection)
Archivable              (Blocked: internal replication state)
Sandboxed               (Blocked: internal execution mode)
Capabilities            (Blocked: security capabilities)
DefinesCapabilities     (Blocked: security capabilities)
UniqueId                (Blocked: internal identity GUID)
HistoryId               (Blocked: internal history tracker)
Attributes              (Managed by node Attributes object)
AttributesReplicate     (Blocked: internal serialization)
AttributesSerialize     (Blocked: internal serialization)
Tags                    (Managed by node Tags array)
Length                  (Computed automatically from the last Keyframe timestamp)
Guid                    (Generated internally by Roblox Studio)
GuidBinaryString        (Generated internally by Roblox Studio)
```

### 13.2 Deprecated Property Messages
- `Pose.MaskWeight`: `"Pose.MaskWeight is deprecated; use Pose.Weight instead."`
- `NumberPose.MaskWeight`: `"NumberPose.MaskWeight is deprecated; use NumberPose.Weight instead."`
- `KeyframeSequence.Length`: `"KeyframeSequence.Length is computed from its last Keyframe and cannot be assigned."`
- `KeyframeSequence.Guid`: `"KeyframeSequence.Guid is generated by Studio and cannot be assigned."`
- `Animation.Guid`: `"Animation.Guid is generated by Studio and cannot be assigned."`

### 13.3 EasingStyle Deprecation Warning
- `PoseEasingStyle.Cubic`: Authoring `"EasingStyle": "Cubic"` produces a diagnostic warning recommending `"CubicV2"`, due to a known direction-reversal defect in the legacy Roblox `Cubic` easing solver.

---

## 14. Parenting Rules Matrix

| Child Class | Permitted Parent Classes | Violation Diagnostic |
|---|---|---|
| `Folder`, `Configuration`, `Model` | Container (`Folder`, `Configuration`, `Model`), `Workspace`, `ReplicatedStorage`, `ServerStorage` | `... must be parented under a Folder, Configuration, Model, Workspace, ReplicatedStorage, or ServerStorage.` |
| `KeyframeSequence` | Container (`Folder`, `Configuration`, `Model`), `Workspace`, `ReplicatedStorage`, `ServerStorage` | `... must be parented under a Folder, Configuration, Model, Workspace, ReplicatedStorage, or ServerStorage.` |
| `Keyframe` | `KeyframeSequence` | `Keyframe must be parented to a KeyframeSequence.` |
| `Pose` | `Keyframe`, `Pose` (sub-pose), `NumberPose` (sub-pose) | `Pose must be parented to a Keyframe, or to another Pose/NumberPose as a sub-pose.` |
| `NumberPose` | `Keyframe`, `Pose` (sub-pose), `NumberPose` (sub-pose) | `NumberPose must be parented to a Keyframe, or to another Pose/NumberPose as a sub-pose.` |
| `KeyframeMarker` | `Keyframe` | `KeyframeMarker must be parented to a Keyframe.` |
| `Animation` | `Animator`, `AnimationController`, `Humanoid`, Container, `Workspace`, `ReplicatedStorage`, `ServerStorage` | `Animation must be parented to an Animator, AnimationController, Humanoid, container, Workspace, ReplicatedStorage, or ServerStorage.` |

---

## 15. Asset Policy

Properties requiring approved Roblox asset references:
- `Animation.AnimationId`

### Approved URI Schemes:
1. **Roblox Asset ID Scheme:**
   ```text
   rbxassetid://123456789
   ```
2. **Numeric String / Integer Shorthand (Normalized to `rbxassetid://`):**
   ```text
   "123456789"
   123456789
   ```

### URI Constraints:
- Maximum length: 512 bytes.
- No whitespace or control characters (`[ - ]`).
- Directory traversal (`..`) is strictly rejected.
- External schemes (`http://`, `https://`, `file://`), disk paths, and UNC shares are rejected.

---

## 16. Architectural Limits (21 Boundaries)

| Parameter | Limit | Failure Diagnostic |
|---|---:|---|
| Maximum JSON input length | 100,000,000 bytes | `JSON exceeds 100000000-byte input limit.` |
| Maximum persisted editor text | 20,000,000 bytes | Session-only warning; editor does not save across restart. |
| Maximum nodes per document | 1,000,000 nodes | `Document exceeds maximum of 1000000 nodes.` |
| Maximum hierarchy depth | 1,000 levels | `... exceeds maximum hierarchy depth of 1000.` |
| Direct children per node | 1,000,000 children | `... exceeds limit of 1000000 children.` |
| Properties per node | 25,000 properties | `... exceeds limit of 25000 entries.` |
| Attributes per node | 10,000 attributes | `... exceeds limit of 10000 entries.` |
| Tags per node | 1,000 tags | `... exceeds limit of 1000 tags.` |
| Maximum ID string length | 1,000 bytes | `...Id must be between 1 and 1000 bytes.` |
| Maximum Name string length | 10,000 bytes | `...Name exceeds 10000 bytes.` |
| Maximum Key or Class length | 1,000 bytes | `... exceeds limit of 1000 bytes.` |
| Maximum Comment string length | 10,000,000 bytes | `... exceeds 10000000 bytes.` |
| Maximum GenerationLabel length | 1,000 bytes | `Options.GenerationLabel exceeds 1000 bytes.` |
| Maximum KeyframeSequences per operation | 100,000 instances | `Document exceeds maximum of 100000 KeyframeSequences.` |
| Maximum Keyframes per operation | 1,000,000 instances | `Document exceeds maximum of 1000000 Keyframes.` |
| Maximum Poses per operation | 1,000,000 instances | `Document exceeds maximum of 1000000 Poses.` |
| Maximum NumberPoses per operation | 1,000,000 instances | `Document exceeds maximum of 1000000 NumberPoses.` |
| Maximum KeyframeMarkers per operation | 500,000 instances | `Document exceeds maximum of 500000 KeyframeMarkers.` |
| Maximum Animations per operation | 100,000 instances | `Document exceeds maximum of 100000 Animation references.` |
| Maximum Asset URI string length | 1,024 bytes | `... must be between 1 and 1024 bytes.` |
| Maximum retained warnings | 500 warnings | Warnings list capped at 500 entries (or `ValidationWarningThreshold`). |

---

## 17. Complete Production-Grade Examples

### 17.1 R15 Multi-Keyframe Wave Animation with Sub-Poses & Markers

```json
{
  "Roots": [
    {
      "ClassName": "KeyframeSequence",
      "Name": "WaveAnimation",
      "Properties": {
        "Loop": true,
        "Priority": "Action",
        "AuthoredHipHeight": 2.0
      },
      "Attributes": {
        "GeneratedBy": "JSON2Anim",
        "SchemaVersion": 1
      },
      "Tags": [
        "JSON2Anim",
        "EmoteAnimation"
      ],
      "Children": [
        {
          "ClassName": "Keyframe",
          "Properties": { "Time": 0.0 },
          "Children": [
            {
              "ClassName": "Pose",
              "Name": "RightUpperArm",
              "Properties": {
                "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 90] },
                "Weight": 1.0,
                "EasingStyle": "CubicV2",
                "EasingDirection": "InOut"
              },
              "Children": [
                {
                  "ClassName": "Pose",
                  "Name": "RightLowerArm",
                  "Properties": {
                    "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 15] },
                    "Weight": 1.0,
                    "EasingStyle": "CubicV2",
                    "EasingDirection": "Out"
                  }
                }
              ]
            },
            {
              "ClassName": "KeyframeMarker",
              "Name": "WaveStart",
              "Properties": {
                "Value": "raise_arm"
              }
            }
          ]
        },
        {
          "ClassName": "Keyframe",
          "Properties": { "Time": 0.5 },
          "Children": [
            {
              "ClassName": "Pose",
              "Name": "RightUpperArm",
              "Properties": {
                "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 150] },
                "Weight": 1.0,
                "EasingStyle": "CubicV2",
                "EasingDirection": "InOut"
              },
              "Children": [
                {
                  "ClassName": "Pose",
                  "Name": "RightLowerArm",
                  "Properties": {
                    "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 45] },
                    "Weight": 1.0,
                    "EasingStyle": "CubicV2",
                    "EasingDirection": "InOut"
                  }
                }
              ]
            }
          ]
        },
        {
          "ClassName": "Keyframe",
          "Properties": { "Time": 1.0 },
          "Children": [
            {
              "ClassName": "Pose",
              "Name": "RightUpperArm",
              "Properties": {
                "CFrame": { "$type": "CFrame", "Orientation": [0, 0, 90] },
                "Weight": 1.0,
                "EasingStyle": "CubicV2",
                "EasingDirection": "In"
              }
            },
            {
              "ClassName": "KeyframeMarker",
              "Name": "WaveComplete",
              "Properties": {
                "Value": "lower_arm"
              }
            }
          ]
        }
      ]
    }
  ],
  "Options": {
    "SelectGenerated": true,
    "GenerationLabel": "JSON2Anim: Generate Wave Sequence"
  }
}
```

---

### 17.2 Dynamic Head & Facial Animation with NumberPose (FACS Sliders)

```json
{
  "ClassName": "KeyframeSequence",
  "Name": "ExpressiveFacialReaction",
  "Properties": {
    "Loop": false,
    "Priority": "Action4"
  },
  "Children": [
    {
      "ClassName": "Keyframe",
      "Properties": { "Time": 0.0 },
      "Children": [
        {
          "ClassName": "NumberPose",
          "Name": "JawDrop",
          "Properties": {
            "Value": 0.0,
            "Weight": 1.0,
            "EasingStyle": "CubicV2",
            "EasingDirection": "InOut"
          }
        },
        {
          "ClassName": "NumberPose",
          "Name": "MouthSmileLeft",
          "Properties": { "Value": 0.0 }
        },
        {
          "ClassName": "NumberPose",
          "Name": "MouthSmileRight",
          "Properties": { "Value": 0.0 }
        }
      ]
    },
    {
      "ClassName": "Keyframe",
      "Properties": { "Time": 0.35 },
      "Children": [
        {
          "ClassName": "NumberPose",
          "Name": "JawDrop",
          "Properties": {
            "Value": 0.85,
            "Weight": 1.0,
            "EasingStyle": "CubicV2",
            "EasingDirection": "Out"
          }
        },
        {
          "ClassName": "NumberPose",
          "Name": "EyesLookUp",
          "Properties": {
            "Value": 0.6,
            "Weight": 1.0
          }
        }
      ]
    },
    {
      "ClassName": "Keyframe",
      "Properties": { "Time": 0.75 },
      "Children": [
        {
          "ClassName": "NumberPose",
          "Name": "JawDrop",
          "Properties": { "Value": 0.1 }
        },
        {
          "ClassName": "NumberPose",
          "Name": "MouthSmileLeft",
          "Properties": { "Value": 0.95 }
        },
        {
          "ClassName": "NumberPose",
          "Name": "MouthSmileRight",
          "Properties": { "Value": 0.95 }
        }
      ]
    }
  ]
}
```

---

### 17.3 Animation Asset Library with Published Animation References

```json
{
  "Roots": [
    {
      "ClassName": "Folder",
      "Name": "CharacterAnimations",
      "Children": [
        {
          "ClassName": "Animation",
          "Name": "MeleeSlash",
          "Properties": {
            "AnimationId": "rbxassetid://507771019"
          }
        },
        {
          "ClassName": "Animation",
          "Name": "DodgeRoll",
          "Properties": {
            "AnimationId": 507772025
          }
        },
        {
          "ClassName": "Configuration",
          "Name": "CombatTags",
          "Attributes": {
            "Version": "1.0.0",
            "RigType": "R15"
          }
        }
      ]
    }
  ],
  "Options": {
    "SelectGenerated": true,
    "GenerationLabel": "JSON2Anim: Generate Animation Library"
  }
}
```

---

## 18. Validation & Atomic Staging Lifecycle

Every operation in JSON2Anim follows strict transactional boundaries:

1. **Syntax Parsing:** Decode JSON and assert zero `null` occurrences outside string literals.
2. **Schema Normalization:** Verify document boundaries, string lengths, ID uniqueness, and valid `$type` tags. Automatically normalizes `Properties.Name` to `node.Name` if root `Name` is omitted.
3. **Policy Evaluation:** Confirm the selected target is valid, classes belong to the 9-class profile, properties match allowlists, parent-child hierarchies comply with engine topology, keyframe timestamps are unique per sequence, and pose names are unique per keyframe.
4. **Off-Tree Native Preflight:**
   - Temporarily instantiates every node off-tree using `Instance.new`.
   - Sorts keyframes chronologically by detaching and re-parenting in ascending `Time` order.
   - Applies names, properties, attributes, and tags off-tree.
   - Validates that native Luau assignments succeed without throwing errors.
   - Destroys the disposable hierarchy completely.
   - Returns itemized counts and warnings without modifying the place DataModel.
5. **Committed Staging & History Hook:**
   - Opens undo recording with `ChangeHistoryService`.
   - Reconstructs the hierarchy off-tree and reapplies all assignments.
   - Attaches root instances to the target parent only after all stages succeed.
   - If any step fails during construction or attachment, all generated instances from that session are destroyed immediately, and the history recording is cancelled.

---

## 19. Troubleshooting & Diagnostic Error Matrix

| Error Message Fragment | Root Cause | Exact Resolution |
|---|---|---|
| `JSON null is not supported at byte X` | `null` token found in JSON | Remove `"key": null` and omit optional fields entirely. |
| `contains unsupported field 'X'` | Unrecognized node or wrapper key | Move Roblox properties inside `Properties` dictionary. |
| `cannot assign controlled property 'Parent'` | `Parent` assigned directly in `Properties` | Remove `Parent`; hierarchy is derived from `Children` nesting. |
| `uses blocked class 'Script'` | Executable or networking class used | Replace with approved animation or container classes. |
| `Pose requires a Name matching the BasePart or Bone it animates` | `Pose.Name` is missing | Provide joint name in `Name` or `Properties.Name`. |
| `NumberPose requires a Name matching the FACS control...` | `NumberPose.Name` is missing | Provide FACS/bone channel name in `Name` or `Properties.Name`. |
| `duplicates pose name 'X' with another pose in...` | Duplicate joint/curve names in keyframe | Ensure each joint or FACS channel appears at most once per `Keyframe`. |
| `duplicates Time X with another Keyframe in...` | Multiple keyframes share identical `Time` | Ensure each `Keyframe.Properties.Time` is strictly unique within the sequence. |
| `Keyframe must be parented to a KeyframeSequence` | Invalid parent for `Keyframe` | Ensure `Keyframe` is placed directly under a `KeyframeSequence.Children`. |
| `Pose must be parented to a Keyframe, or to another Pose...` | Invalid parent for `Pose` | Parent `Pose` under `Keyframe` or another `Pose`/`NumberPose` (sub-pose). |
| `Properties.Weight must be between 0 and 1` | Weight $< 0$, $> 1$, or `NaN` | Provide a valid finite float between `0.0` and `1.0`. |
| `Properties.Time must be a finite, non-negative number` | Negative time, Infinity, or `NaN` | Set `Time` to a finite number $\ge 0.0$. |
| `cannot reference @target; JSON2Anim supports no target references...` | `@target` used in animation property | Remove `@target`; animation nodes do not use target instance references. |
| `uses unsupported URI scheme 'http'` | External web URL assigned | Use `rbxassetid://<id>` or numeric id shorthand. |
| `AnimationId is required for an Animation reference` | `AnimationId` omitted | Provide `AnimationId` in `Animation.Properties`. |
| `Target unavailable: Select exactly one target parent` | Multiple or invalid instances selected | Select exactly one supported container or clear selection for `Workspace`. |

---

## 20. Explicit Blocked Scope & Security Invariants

The following classes are explicitly and permanently blocked from creation:

```text
Script, LocalScript, ModuleScript, CoreScript, Actor,
RemoteEvent, RemoteFunction, UnreliableRemoteEvent,
BindableEvent, BindableFunction,
Humanoid, Animator, AnimationController, AnimationTrack,
DataModel, Workspace, ReplicatedStorage, ServerStorage,
ServerScriptService, StarterGui, StarterPlayer, Lighting,
SoundService, Teams, Chat, Players,
Part, MeshPart, Attachment, Bone, Camera,
Light, PointLight, SpotLight, SurfaceLight,
ParticleEmitter, Trail, Beam, Highlight,
Decal, Texture, Sound
```

*Note: While `Workspace`, `ReplicatedStorage`, `ServerStorage`, `Humanoid`, `Animator`, and `AnimationController` can be selected as generation targets in Studio, they cannot be created as generated nodes.*

---

## 21. Version Boundary

This specification is normative for **JSON2Anim `v1.0.0`** verified on Roblox Studio build **`0.740.0.7400927`**.
