# JSON23D Schema Guide

This document is the normative authoring reference for JSON23D schema version `1`, plugin version `1.2.0`.

- **Verification Date:** September 24, 2026
- **Verified Studio Build:** Roblox Studio `0.740.0.7400927`
- **Specification Status:** Stable / Normative
- **Engine Identity:** `Script:JSON23D`

The schema is deliberately strict. Unknown fields, unsupported classes, unsupported properties, unresolved references, unsafe asset strings, invalid parent relationships, and out-of-range values fail before generated roots are attached to the target.

---

## 1. Document Principles

1. **Strict JSON Format:** Input must be standard JSON (RFC 8259). Luau table syntax, JSON5, JavaScript objects, trailing commas, single-quoted strings, unquoted keys, and NaN/Infinity numeric literals are strictly rejected.
2. **Explicit Double Quotes:** All object keys and string values must be enclosed in ASCII double quotes (`"`).
3. **Comment Fields:** Comments must use schema-defined `Comment` or `$comment` string fields. Inline comments (`//` or `/* */`) are rejected by the parser.
4. **Zero Null Tolerance:** JSON `null` is rejected everywhere in the document. Optional fields must be omitted entirely instead of assigned `null`.
5. **Dense Arrays:** All arrays (`Roots`, `Children`, `Tags`, numeric vectors, keypoint lists) must be dense with consecutive integer indices starting at 1.
6. **Case Sensitivity:** Class names, property names, enum item names, and `$type` descriptors require exact PascalCase Roblox capitalization unless explicit case-insensitivity is defined.
7. **Finite Numbers:** Every numeric value must be finite. `NaN`, `Infinity`, and `-Infinity` cause immediate parse or validation failures.
8. **Explicit Class & Property Allowlists:** A class is accepted only if present in the 66-class profile. A property is accepted only if explicitly allowlisted for that class.
9. **Off-Tree Preflight & Atomicity:** Before any instance is attached to the place DataModel, the complete hierarchy is instantiated off-tree, configured, cross-referenced, and validated in temporary memory. If any error occurs, all staged instances are destroyed, leaving the target parent untouched.
10. **Native Studio Authority:** Roblox Studio engine reflection and native Luau property assignment remain the final authority after schema and policy checks succeed.

---

## 2. Accepted Root Forms

JSON23D accepts exactly three document root forms.

### 2.1 Single Node Root

A solitary node object at the root of the JSON document:

```json
{
  "ClassName": "Part",
  "Name": "MainBlock",
  "Properties": {
    "Anchored": true,
    "Size": [4, 2, 4],
    "CFrame": [0, 1, 0],
    "Color": "#4FA3FF",
    "Material": "Concrete"
  }
}
```

The engine normalizes this internally as `Roots = [ <Node> ]`.

### 2.2 Dense Root Array

A dense JSON array containing one or more top-level node objects:

```json
[
  {
    "ClassName": "Model",
    "Name": "BuildingStructure",
    "Children": [
      {
        "ClassName": "Part",
        "Name": "Floor",
        "Properties": {
          "Size": [20, 1, 20],
          "CFrame": [0, 0.5, 0],
          "Anchored": true
        }
      }
    ]
  },
  {
    "ClassName": "Folder",
    "Name": "BuildingMetadata",
    "Children": [
      {
        "ClassName": "Configuration",
        "Name": "Config"
      }
    ]
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
      "ClassName": "Model",
      "Id": "mainHouse",
      "Name": "GeneratedHouse",
      "Properties": {
        "PrimaryPart": {
          "$ref": "foundationBlock"
        }
      },
      "Children": [
        {
          "ClassName": "Part",
          "Id": "foundationBlock",
          "Name": "Foundation",
          "Properties": {
            "Size": [14, 1, 12],
            "CFrame": [0, 0.5, 0],
            "Anchored": true,
            "Color": "#8A8F98",
            "Material": "Concrete"
          }
        }
      ]
    }
  ],
  "Options": {
    "SelectGenerated": true,
    "AssetPolicy": "ReferenceOnly",
    "GenerationLabel": "JSON23D: Generate House Assembly",
    "AllowExperimental": false
  },
  "Comment": "Production environment asset wrapper",
  "$comment": "Alternate comment field"
}
```

#### Document Wrapper Fields

| Field | Required | Type | Limit | Description |
|---|:---:|---|---|---|
| `Roots` | **Yes** | dense array | $1 \le N \le 5000$ | Non-empty array of root node objects. |
| `Options` | No | object | 4 fields | Document-level configuration options object. |
| `Comment` | No | string | $\le 10,000$ bytes | Optional documentation string (ignored by engine). |
| `$comment` | No | string | $\le 10,000$ bytes | Optional documentation string (ignored by engine). |

Unknown wrapper fields fail validation.

---

## 3. Document Options

When using the Document Wrapper, the `Options` dictionary accepts the following settings:

| Option | Type | Default | Permitted Values | Description |
|---|---|---|---|---|
| `SelectGenerated` | boolean | `true` | `true`, `false` | When `true`, automatically selects all attached root instances in Studio Explorer after successful generation. |
| `AssetPolicy` | string | `"ReferenceOnly"` | `"ReferenceOnly"` | Enforces local and asset-id referencing only. External network downloads are strictly disabled. |
| `GenerationLabel` | string | `"JSON23D: Generate 3D"` | string, 1–1,000 bytes | Human-readable label recorded in Roblox Studio undo history (`ChangeHistoryService`). |
| `AllowExperimental` | boolean | `false` | `false` | Must remain `false`; experimental unverified classes are disabled. |
| `ZFightGuard` | boolean | `false` | `true`, `false` | Enables the Z-Fight Guard pass for this document. The toolbar toggle overrides it for the current session. |
| `ZFightTolerance` | number | `0.005` | 0.001 – 0.1 studs | Distance within which two surfaces are treated as coincident. |
| `ZFightStrategy` | string | `"Nudge"` | `"Nudge"`, `"Grow"` | `Nudge` translates the later part; `Grow` inflates it along the conflict axis. |
| `StrictHierarchyChecking` | boolean | `false` | `true`, `false` | When `true`, class nesting is checked against an explicit parent table before the native preflight pass, and unlisted combinations fail closed. |
| `ValidationWarningThreshold` | integer | `200` | 10 – 500 | Maximum retained warning stack. Exceeding it is a hard failure rather than a silent truncation. |

Unknown fields inside `Options` fail validation.

### 3.1 Z-Fight Guard

When `ZFightGuard` is `true` (or the toolbar toggle is on), the engine computes every
coincident-surface conflict in the document, resolves each one deterministically, and
reports every change as `path.Property: from -> to`. The earlier part in document order
always wins; only the later part is adjusted, never more than eight times, across at most
eight passes. Unresolved residue fails the whole operation with the target untouched.

| Geometry | Analysis |
|---|---|
| `Part` with `Shape = Block`, `Seat`, `VehicleSeat`, `SpawnLocation` | Exact oriented-box faces with true polygon intersection area. |
| `WedgePart` | Exact five-face triangular prism. |
| `Part` with `Shape = Ball` | Exact sphere coincidence. |
| `Part` with `Shape = Cylinder` | Exact lateral-surface and end-cap coincidence. |
| `MeshPart`, mesh-bearing `Part`, `CornerWedgePart`, `TrussPart`, unknown shapes | Oriented bounding-box proxy, reported per instance. |

Parts that overlap in volume without sharing a surface plane are not z-fighting and are
left unchanged. Terrain, CSG interiors and mesh interiors are never claimed to be exact.

---

## 4. Node Object Contract

Every node object in `Roots` or `Children` follows this exact JSON structure:

```json
{
  "ClassName": "Part",
  "Id": "pillar_01",
  "Name": "SupportPillar",
  "Properties": {
    "Size": [2, 10, 2],
    "CFrame": {
      "$type": "CFrame",
      "Position": [5, 5, 0],
      "Orientation": [0, 45, 0]
    },
    "Anchored": true,
    "Material": "Concrete",
    "Color": "#8A8F98"
  },
  "Attributes": {
    "GeneratedBy": "JSON23D",
    "SchemaVersion": 1,
    "StructuralLoad": 1500.5,
    "Offset": {
      "$type": "Vector3",
      "Value": [0, 5, 0]
    }
  },
  "Tags": [
    "JSON23D",
    "Generated3D",
    "Structural"
  ],
  "Children": [],
  "Comment": "Front-right support column",
  "$comment": "Alternate comment key"
}
```

### Complete Node Fields Reference

| Field | Required | Type | Limits | Description |
|---|:---:|---|---|---|
| `ClassName` | **Yes** | string | 1–100 bytes | Exact name of the approved Roblox class (e.g. `"Part"`, `"Model"`, `"Attachment"`). |
| `Id` | No | string | 1–1,000 bytes | Unique document-wide reference identifier (`[A-Za-z_][A-Za-z0-9_.-]*`). Cannot be `"@target"`. |
| `Name` | No | string | 0–10,000 bytes | Assigned to `Instance.Name`. No control characters. Mutually exclusive with `Properties.Name`. |
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
- **Casing:** Exact PascalCase matching Roblox Studio reflection metadata (e.g., `PointLight`, `AssemblyLinearVelocity`, `TextureID`).

### 5.2 Node Reference Identifiers (`Id`)
- **Length:** 1 to 128 bytes.
- **Pattern:** `^[A-Za-z_][A-Za-z0-9_.-]*$`
- **Uniqueness:** Must be globally unique across all roots and descendants in the document.
- **Reserved Names:** `"@target"` is reserved for pointing to the selected Studio target instance and cannot be declared as a node `Id`.

#### Valid IDs:
```text
main
_rootNode
left_wing
column.01
bracket-A
```

#### Invalid IDs:
```text
1stColumn        (starts with digit)
wing left        (contains whitespace)
@target          (reserved identifier)
part/sub         (invalid character /)
```

### 5.3 Instance Names (`Name`)
- **Length:** 0 to 1,000 bytes.
- **Character Set:** UTF-8 strings. Control characters (`[\x00-\x1F\x7F]`) are rejected.
- If top-level `Name` is omitted, the instance retains its default native Roblox name unless `Properties.Name` is defined. A node cannot define both `Name` and `Properties.Name`.

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

References establish instance pointer properties (`Adornee`, `Part0`, `Part1`, `Attachment0`, `Attachment1`, `PrimaryPart`, `Value`) between generated nodes or to the active target.

### 6.1 Compact Reference
```json
{
  "$ref": "anchorPart"
}
```

### 6.2 Tagged Reference Object
```json
{
  "$type": "Reference",
  "Id": "anchorPart"
}
```
*Note: `"Value"` is accepted as an alias for `"Id"` in tagged reference objects (`{"$type": "Reference", "Value": "anchorPart"}`).*

### 6.3 Reserved Target Pointer (`@target`)
The special reference `"@target"` resolves to the active parent instance selected in Studio. It is permitted exclusively on:
- `Highlight.Adornee`
- `SelectionBox.Adornee`
- `SelectionSphere.Adornee`
- `ObjectValue.Value`

```json
{
  "ClassName": "Highlight",
  "Name": "SelectionGlow",
  "Properties": {
    "Adornee": {
      "$ref": "@target"
    },
    "FillColor": "#00FF88",
    "FillTransparency": 0.5,
    "OutlineColor": "#FFFFFF",
    "OutlineTransparency": 0
  }
}
```

`@target` cannot be used on structural properties like `Model.PrimaryPart` or physics joints like `Weld.Part0`.

### 6.4 Comprehensive Reference Requirements Table

| Class / Property | Required Reference Property | Mandatory / Optional | Target Class Requirement |
|---|---|:---:|---|
| `Beam` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `Trail` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `WeldConstraint` | `Part0`, `Part1` | **Mandatory** | `BasePart` |
| `NoCollisionConstraint` | `Part0`, `Part1` | **Mandatory** | `BasePart` |
| `RigidConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `Weld` | `Part0`, `Part1` | **Mandatory** | `BasePart` |
| `ManualWeld` | `Part0`, `Part1` | **Mandatory** | `BasePart` |
| `Motor6D` | `Part0`, `Part1` | **Mandatory** | `BasePart` |
| `RopeConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `RodConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `SpringConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `BallSocketConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `HingeConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `PrismaticConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `CylindricalConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `UniversalConstraint` | `Attachment0`, `Attachment1` | **Mandatory** | `Attachment` |
| `AlignPosition` | `Attachment0`<br>`Attachment1` | **Mandatory**<br>Optional | `Attachment`<br>`Attachment` |
| `AlignOrientation` | `Attachment0`<br>`Attachment1` | **Mandatory**<br>Optional | `Attachment`<br>`Attachment` |
| `LinearVelocity` | `Attachment0` | **Mandatory** | `Attachment` |
| `AngularVelocity` | `Attachment0` | **Mandatory** | `Attachment` |
| `VectorForce` | `Attachment0` | **Mandatory** | `Attachment` |
| `Torque` | `Attachment0` | **Mandatory** | `Attachment` |
| `Highlight` | `Adornee` | **Mandatory** | Any `Instance` or `"@target"` |
| `SelectionBox` | `Adornee` | **Mandatory** | Any `Instance` or `"@target"` |
| `SelectionSphere` | `Adornee` | **Mandatory** | Any `PVInstance` (`BasePart` or `Model`) or `"@target"` (if `PVInstance`) |
| `Model.PrimaryPart` | `PrimaryPart` | Optional | A generated descendant `BasePart` within that exact Model |
| `Sound.SoundGroup` | `SoundGroup` | Optional | `SoundGroup` |
| `ObjectValue.Value` | `Value` | Optional | Any `Instance` or `"@target"` |

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
  "ClassName": "Part",
  "Attributes": {
    "ItemName": "ObsidianShard",
    "ItemCount": 10,
    "IsEquippable": true,
    "DropRate": 0.05,
    "SpawnCoordinate": {
      "$type": "Vector3",
      "Value": [10.5, 2.0, -40.0]
    },
    "TintColor": {
      "$type": "Color3",
      "Hex": "#9933FF"
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
  "ClassName": "Model",
  "Tags": [
    "JSON23D",
    "Generated3D",
    "Destructible",
    "InteractiveZone"
  ]
}
```

---

## 9. Exhaustive Datatype Specifications (19 Types)

For property assignments, JSON23D resolves values in this exact sequence:
1. Resolve `$ref` or `$type: "Reference"`.
2. Decode explicit `$type` objects.
3. Read the property's default datatype on the freshly constructed Roblox instance.
4. Decode compact shorthand forms according to the expected datatype.
5. Apply the converted value via protected native assignment.

Tagged `$type` names are case-sensitive and must match one of the 19 supported types below.

---

### 9.1 UDim
Represents a 1D coordinate component with relative scale and pixel offset.

- **Compact 2-Number Array `[scale, offset]`:**
  ```json
  [0.5, 12]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "UDim",
    "Scale": 0.5,
    "Offset": 12
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `Scale`, `Offset`.

---

### 9.2 UDim2
Represents a 2D coordinate for UI positioning and sizing.

- **Compact 4-Number Array `[xScale, xOffset, yScale, yOffset]`:**
  ```json
  [0.5, -10, 1.0, -20]
  ```
- **Compact 2-Number Offset Array `[xOffset, yOffset]`:**
  ```json
  [100, 200]
  ```
- **Nested UDim Object:**
  ```json
  {
    "$type": "UDim2",
    "X": [0.5, -10],
    "Y": [1.0, -20]
  }
  ```
- **Explicit Component Fields:**
  ```json
  {
    "$type": "UDim2",
    "XScale": 0.5,
    "XOffset": -10,
    "YScale": 1.0,
    "YOffset": -20
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`, `Scale`, `Offset`, `XScale`, `XOffset`, `YScale`, `YOffset`.

---

### 9.3 Vector2
Represents a 2D vector in studs, angles, or texture coordinates.

- **Compact 2-Number Array `[x, y]`:**
  ```json
  [45, 45]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "Vector2",
    "X": 45,
    "Y": 45
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`.

---

### 9.4 Vector3
Represents a 3D point, size, force, or velocity in studs.

- **Compact 3-Number Array `[x, y, z]`:**
  ```json
  [4, 2, 8]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "Vector3",
    "X": 4,
    "Y": 2,
    "Z": 8
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`, `Z`.

---

### 9.5 Vector2int16
Represents a 2D integer vector with signed 16-bit integers (`-32768` to `32767`).

- **Tagged Object / Array:**
  ```json
  {
    "$type": "Vector2int16",
    "Value": [32767, -32768]
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`. Non-integer or out-of-range values are rejected.

---

### 9.6 Vector3int16
Represents a 3D integer vector with signed 16-bit integers (`-32768` to `32767`).

- **Tagged Object / Array:**
  ```json
  {
    "$type": "Vector3int16",
    "Value": [10, -5, 20]
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Components`, `X`, `Y`, `Z`. Non-integer or out-of-range values are rejected.

---

### 9.7 Color3
Represents RGB color.

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

### 9.8 ColorSequence
Represents a gradient color progression over time ($[0.0, 1.0]$).

- **Constant Color String / Array (converted to uniform sequence):**
  ```json
  "#40A9FF"
  ```
- **2-Color Start/End Shortcut:**
  ```json
  ["#FF0000", "#0000FF"]
  ```
- **Keypoint Objects List:**
  ```json
  {
    "$type": "ColorSequence",
    "Keypoints": [
      { "Time": 0.0, "Value": "#FF0000" },
      { "Time": 0.5, "Value": "#00FF00" },
      { "Time": 1.0, "Value": "#0000FF" }
    ]
  }
  ```
- **Compact Array Keypoints `[time, color]`:**
  ```json
  {
    "$type": "ColorSequence",
    "Keypoints": [
      [0.0, "#FF0000"],
      [1.0, "#0000FF"]
    ]
  }
  ```
- **Validation Rules:** Keypoint times must start at `0.0`, end at `1.0`, and increase strictly monotonically.

---

### 9.9 NumberSequence
Represents a numeric curve over time ($[0.0, 1.0]$) with optional envelope tolerance.

- **Constant Number:**
  ```json
  0.5
  ```
- **2-Number Start/End Shortcut:**
  ```json
  [0.0, 1.0]
  ```
- **Keypoint Objects List with Envelope:**
  ```json
  {
    "$type": "NumberSequence",
    "Keypoints": [
      { "Time": 0.0, "Value": 0.0, "Envelope": 0.0 },
      { "Time": 0.5, "Value": 0.8, "Envelope": 0.1 },
      { "Time": 1.0, "Value": 1.0, "Envelope": 0.0 }
    ]
  }
  ```
- **Compact Array Keypoints `[time, value, envelope?]`:**
  ```json
  {
    "$type": "NumberSequence",
    "Keypoints": [
      [0.0, 0.0],
      [0.5, 0.8, 0.1],
      [1.0, 1.0]
    ]
  }
  ```
- **Validation Rules:** Times must start at `0.0`, end at `1.0`, and increase strictly. Envelope must be $\ge 0$.

---

### 9.10 Rect
Represents a 2D pixel or UV bounding rectangle.

- **Compact 4-Number Array `[minX, minY, maxX, maxY]`:**
  ```json
  [0, 0, 512, 512]
  ```
- **Structured Min/Max Object:**
  ```json
  {
    "$type": "Rect",
    "Min": [0, 0],
    "Max": [512, 512]
  }
  ```
- **Allowed Tagged Fields:** `Min`, `Max`, `Value`, `Components`.

---

### 9.11 CFrame
Represents a 3D spatial coordinate frame (position and orientation).

- **3-Number Position Array `[x, y, z]`:**
  ```json
  [0, 5, 0]
  ```
- **6-Number Position + Euler Degrees `[x, y, z, rx, ry, rz]`:**
  ```json
  [0, 5, 0, 0, 90, 0]
  ```
- **12-Number Transformation Matrix:**
  ```json
  [0, 5, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1]
  ```
- **Tagged Object with Position and Orientation (Degrees):**
  ```json
  {
    "$type": "CFrame",
    "Position": [0, 5, 0],
    "Orientation": [0, 45, 0]
  }
  ```
- **Orientation-Only (Position defaults to `[0, 0, 0]`):**
  ```json
  {
    "$type": "CFrame",
    "Orientation": [0, 90, 0]
  }
  ```
- **LookAt / Target Construction:**
  ```json
  {
    "$type": "CFrame",
    "Position": [0, 10, 20],
    "LookAt": [0, 0, 0]
  }
  ```
- **Allowed Tagged Fields:** `Position`, `Orientation`, `Rotation`, `Angles`, `LookAt`, `Target`, `Value`, `Components`, `X`, `Y`, `Z`.
- *Note: Euler angles in `Orientation`, `Rotation`, and `Angles` are always interpreted in **degrees**.*

---

### 9.12 NumberRange
Represents a closed numeric interval $[min, max]$.

- **Single Number (uniform interval):**
  ```json
  5
  ```
- **Compact 2-Number Array `[min, max]`:**
  ```json
  [1, 5]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "NumberRange",
    "Min": 1,
    "Max": 5
  }
  ```
- **Allowed Tagged Fields:** `Min`, `Max`, `Value`, `Components`. Minimum cannot exceed maximum.

---

### 9.13 BrickColor
Represents standard palette BrickColors.

- **Name String:**
  ```json
  "Bright red"
  ```
- **Palette Integer Number:**
  ```json
  1004
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "BrickColor",
    "Name": "Medium stone grey"
  }
  ```
- **Allowed Tagged Fields:** `Value`, `Name`, `Number`.

---

### 9.14 Enum
Represents Roblox engine enumerations.

- **Contextual Item Name String:**
  ```json
  "Concrete"
  ```
- **Full Enum Identifier String:**
  ```json
  "Enum.Material.Concrete"
  ```
- **Tagged Enum Object:**
  ```json
  {
    "$type": "Enum",
    "EnumType": "Material",
    "Name": "Concrete"
  }
  ```
- **Allowed Tagged Fields:** `EnumType`, `Name`, `Value`. Case-insensitive item resolution is supported as a fallback.

---

### 9.15 Ray
Represents a 3D ray with origin point and direction vector.

- **Tagged Ray Object:**
  ```json
  {
    "$type": "Ray",
    "Origin": [0, 0, 0],
    "Direction": [0, -50, 0]
  }
  ```
- **Allowed Tagged Fields:** `Origin`, `Direction`.

---

### 9.16 PhysicalProperties
Represents physical simulation attributes (density, friction, elasticity, and weights).

- **Material Preset Name String:**
  ```json
  "Concrete"
  ```
- **3-Parameter Array `[density, friction, elasticity]`:**
  ```json
  [1.2, 0.6, 0.3]
  ```
- **5-Parameter Full Matrix `[density, friction, elasticity, frictionWeight, elasticityWeight]`:**
  ```json
  [1.2, 0.6, 0.3, 1.0, 1.0]
  ```
- **Tagged Object:**
  ```json
  {
    "$type": "PhysicalProperties",
    "Density": 1.2,
    "Friction": 0.6,
    "Elasticity": 0.3,
    "FrictionWeight": 1.0,
    "ElasticityWeight": 1.0
  }
  ```
- **Tagged Material Preset:**
  ```json
  {
    "$type": "PhysicalProperties",
    "Material": "Concrete"
  }
  ```
- **Allowed Tagged Fields:** `Material`, `Density`, `Friction`, `Elasticity`, `FrictionWeight`, `ElasticityWeight`, `Value`, `Components`.

---

### 9.17 Axes
Represents a bitset of coordinate axes (`X`, `Y`, `Z`).

- **Tagged Object:**
  ```json
  {
    "$type": "Axes",
    "Values": ["X", "Z"]
  }
  ```
- **Allowed Tagged Fields:** `Values`, `Value`. At least one valid `Enum.Axis` item is required.

---

### 9.18 Faces
Represents a bitset of normal faces (`Top`, `Bottom`, `Left`, `Right`, `Front`, `Back`).

- **Tagged Object:**
  ```json
  {
    "$type": "Faces",
    "Values": ["Top", "Front"]
  }
  ```
- **Allowed Tagged Fields:** `Values`, `Value`. At least one valid `Enum.NormalId` item is required.

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

## 10. Supported Generation Targets (12 Targets)

The generation target must be an existing Instance attached to the currently open place DataModel. Clear the Studio selection to default to `Workspace`, or select exactly **one** of the following instances:

| Target Class | Allowed Child Roots | Special Target Rules |
|---|---|---|
| `Workspace` | Any container, BasePart, spatial, light, effect, sound, constraint, value | Direct generation requires a 2-step confirmation click within 10 seconds. |
| `Folder` | Any container, BasePart, spatial, light, effect, sound, constraint, value | General-purpose organizational container. |
| `Configuration` | Any container, BasePart, spatial, light, effect, sound, constraint, value | Metadata and setting container. |
| `Model` | Any container, BasePart, spatial, light, effect, sound, constraint, value | Assembly group container. |
| `WorldModel` | Any BasePart, spatial, light, effect, sound, constraint, value | 3D physical world container. |
| `BasePart` | Mesh presentation, Surface content, Attachments, Bones, Lights, Effects, Sounds, Constraints, Values | BaseParts and containers cannot be parented beneath a BasePart target. |
| `Attachment` | Attachments, Lights, ParticleEmitters, Smoke, Fire, Sparkles, Beams, Trails, Constraints, Sounds | Rigid spatial anchor. BaseParts cannot be parented beneath an Attachment. |
| `Bone` | Bones, Attachments, Lights, ParticleEmitters, Sounds, Constraints | Deformable mesh bone. |
| `ViewportFrame` | `WorldModel` | **Strict Rule:** Only a `WorldModel` may be generated directly under a ViewportFrame. |
| `ReplicatedStorage` | Folders, Models, Configurations, Sounds, Values, Constraints | Replicated data and asset storage. |
| `ServerStorage` | Folders, Models, Configurations, Sounds, Values, Constraints | Server-only assets and prefabs. |
| `SoundService` | `Sound` | Dedicated global sound container. |

Selecting multiple instances or unapproved containers (e.g. `ScreenGui`, `Lighting`, `StarterPlayer`) fails validation.

---

## 11. Supported Classes (64 Classes)

JSON23D supports exactly **64 classes** categorized into 10 groups:

```text
1. Containers (4)
   Folder, Configuration, Model, WorldModel

2. Primitive BaseParts (8)
   Part, WedgePart, CornerWedgePart, TrussPart, SpawnLocation, Seat, VehicleSeat, MeshPart

3. Mesh Presentation (4)
   SpecialMesh, BlockMesh, CylinderMesh, SurfaceAppearance

4. Spatial Nodes (3)
   Attachment, Bone, Camera

5. Lights (3)
   PointLight, SpotLight, SurfaceLight

6. Effects & Adornments (9)
   ParticleEmitter, Trail, Beam, Smoke, Fire, Sparkles, Highlight, SelectionBox, SelectionSphere

7. Audio (1)
   Sound

8. Constraints, Joints, Motors & Actuators (20)
   WeldConstraint, RigidConstraint, Weld, ManualWeld, Motor6D, NoCollisionConstraint,
   RopeConstraint, RodConstraint, SpringConstraint, BallSocketConstraint,
   HingeConstraint, PrismaticConstraint, CylindricalConstraint, UniversalConstraint,
   AlignPosition, AlignOrientation, LinearVelocity, AngularVelocity, VectorForce, Torque

9. Value Objects (10)
   StringValue, BoolValue, IntValue, NumberValue, Color3Value, Vector3Value,
   CFrameValue, BrickColorValue, RayValue, ObjectValue

10. Surface Content (2)
    Decal, Texture
```

---

## 12. Complete Property Allowlists

`Name` is allowlisted on every supported class. Engine-controlled properties (Section 13) are strictly rejected.

### 12.1 Shared BasePart Properties
Allowed on all 8 BasePart classes (`Part`, `WedgePart`, `CornerWedgePart`, `TrussPart`, `SpawnLocation`, `Seat`, `VehicleSeat`, `MeshPart`):

```text
Anchored                  (boolean)
AssemblyAngularVelocity   (Vector3)
AssemblyLinearVelocity    (Vector3)
AudioCanCollide           (boolean)
BackSurface               (Enum.SurfaceType)
BottomSurface             (Enum.SurfaceType)
BrickColor                (BrickColor)
CFrame                    (CFrame)
CanCollide                (boolean)
CanQuery                  (boolean)
CanTouch                  (boolean)
CastShadow                (boolean)
CollisionGroup            (string)
Color                     (Color3)
CustomPhysicalProperties  (PhysicalProperties)
EnableFluidForces         (boolean)
FrontSurface              (Enum.SurfaceType)
LeftSurface               (Enum.SurfaceType)
Locked                    (boolean)
Massless                  (boolean)
Material                  (Enum.Material)
MaterialVariant           (string)
Orientation               (Vector3)
PivotOffset               (CFrame)
Position                  (Vector3)
Reflectance               (number, [0, 1])
RightSurface              (Enum.SurfaceType)
RootPriority              (number)
Rotation                  (Vector3)
Size                      (Vector3, all components > 0)
TopSurface                (Enum.SurfaceType)
Transparency              (number, [0, 1])
```

#### Class-Specific BasePart Properties:
- `Part`: `Shape` (`Enum.PartType`)
- `TrussPart`: `Style` (`Enum.Style`)
- `SpawnLocation`: `AllowTeamChangeOnTouch`, `Duration`, `Enabled`, `Neutral`, `TeamColor`
- `Seat`: `Disabled`
- `VehicleSeat`: `Disabled`, `HeadsUpDisplay`, `MaxSpeed`, `SteerFloat`, `ThrottleFloat`, `Torque`, `TurnSpeed`
- `MeshPart`: `CollisionFidelity`, `DoubleSided`, `RenderFidelity`, `TextureID` *(Note: `MeshId` is read-only in Studio and rejected).*

---

### 12.2 Container Properties
- `Folder`, `Configuration`: `Name`
- `Model`: `LevelOfDetail`, `ModelStreamingMode`, `PrimaryPart` (`$ref` to descendant BasePart), `WorldPivot`
- `WorldModel`: `UseWorkspaceCollisionGroups`

---

### 12.3 Mesh Presentation Properties
- `SpecialMesh`: `MeshType` (`Enum.MeshType`), `MeshId` (Asset URI), `TextureId` (Asset URI), `Offset` (Vector3), `Scale` (Vector3), `VertexColor` (Vector3)
- `BlockMesh`, `CylinderMesh`: `Offset` (Vector3), `Scale` (Vector3), `VertexColor` (Vector3)
- `SurfaceAppearance`: `AlphaMode`, `Color`, `ColorMap`, `EmissiveMask`, `EmissiveStrength`, `EmissiveTint`, `MetalnessMap`, `NormalMap`, `ResampleMode`, `RoughnessMap`

---

### 12.4 Spatial Properties
- `Attachment`: `Axis`, `CFrame`, `Orientation`, `Position`, `SecondaryAxis`, `Visible`
- `Bone`: `Axis`, `CFrame`, `Orientation`, `Position`, `SecondaryAxis`, `Transform`, `Visible`
- `Camera`: `CFrame`, `CameraType`, `FieldOfView`, `FieldOfViewMode`, `Focus`, `HeadLocked`, `HeadScale`, `VRTiltAndRollEnabled`

---

### 12.5 Light Properties
- `PointLight`: `Brightness`, `Color`, `Enabled`, `Range`, `Shadows`
- `SpotLight`: `Angle`, `Brightness`, `Color`, `Enabled`, `Face`, `Range`, `Shadows`
- `SurfaceLight`: `Angle`, `Brightness`, `Color`, `Enabled`, `Face`, `Range`, `Shadows`

---

### 12.6 Effects & Adornments Properties
- `ParticleEmitter`: `Acceleration`, `Brightness`, `Color` (ColorSequence), `Drag`, `EmissionDirection`, `Enabled`, `FlipbookBlendFrames`, `FlipbookFramerate`, `FlipbookLayout`, `FlipbookMode`, `FlipbookStartRandom`, `Lifetime` (NumberRange), `LightEmission` ([0, 1]), `LightInfluence` ([0, 1]), `LockedToPart`, `Orientation`, `Rate`, `RotSpeed` (NumberRange), `Rotation` (NumberRange), `Shape`, `ShapeInOut`, `ShapePartial` ([0, 1]), `ShapeStyle`, `Size` (NumberSequence), `Speed` (NumberRange), `SpreadAngle` (Vector2), `Squash` (NumberSequence), `Texture` (Asset URI), `TimeScale`, `Transparency` (NumberSequence), `VelocityInheritance` ([0, 1]), `WindAffectsDrag`, `ZOffset`
- `Beam`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Brightness`, `Color` (ColorSequence), `CurveSize0`, `CurveSize1`, `Enabled`, `FaceCamera`, `LightEmission` ([0, 1]), `LightInfluence` ([0, 1]), `Segments`, `Texture` (Asset URI), `TextureLength`, `TextureMode`, `TextureSpeed`, `Transparency` (NumberSequence), `Width0`, `Width1`, `ZOffset`
- `Trail`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Brightness`, `Color` (ColorSequence), `Enabled`, `FaceCamera`, `Lifetime`, `LightEmission` ([0, 1]), `LightInfluence` ([0, 1]), `MaxLength`, `MinLength`, `Texture` (Asset URI), `TextureLength`, `TextureMode`, `Transparency` (NumberSequence), `WidthScale` (NumberSequence)
- `Smoke`: `Color`, `Enabled`, `Opacity` ([0, 1]), `RiseVelocity`, `Size`, `TimeScale`
- `Fire`: `Color`, `Enabled`, `Heat`, `SecondaryColor`, `Size`, `TimeScale`
- `Sparkles`: `Enabled`, `SparkleColor`, `TimeScale`
- `Highlight`: `Adornee` (`$ref` or `"@target"`), `DepthMode`, `Enabled`, `FillColor`, `FillTransparency` ([0, 1]), `OutlineColor`, `OutlineTransparency` ([0, 1])
- `SelectionBox`: `Adornee` (`$ref` or `"@target"`), `AlwaysOnTop`, `Color3`, `LineThickness`, `SurfaceColor3`, `SurfaceTransparency` ([0, 1]), `Visible`, `ZIndex`
- `SelectionSphere`: `Adornee` (`$ref` or `"@target"`), `AlwaysOnTop`, `Color3`, `SurfaceColor3`, `SurfaceTransparency` ([0, 1]), `Visible`, `ZIndex`

---

### 12.7 Audio Properties
- `Sound`: `Looped` (boolean), `PlaybackSpeed` (number), `Pitch` (number), `Playing` (boolean), `RollOffMaxDistance` (number), `RollOffMinDistance` (number), `RollOffMode` (`Enum.RollOffMode`), `SoundGroup` (`$ref`), `SoundId` (Asset URI), `TimePosition` (number), `Volume` (number)

---

### 12.8 Constraints, Joints, Motors & Actuators
- `WeldConstraint`: `Part0` (`$ref`), `Part1` (`$ref`), `Enabled`
- `NoCollisionConstraint`: `Part0` (`$ref`), `Part1` (`$ref`), `Enabled`
- `RigidConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Enabled`
- `Weld`: `Part0` (`$ref`), `Part1` (`$ref`), `C0` (CFrame), `C1` (CFrame), `Enabled`
- `ManualWeld`: `Part0` (`$ref`), `Part1` (`$ref`), `C0` (CFrame), `C1` (CFrame), `Enabled`
- `Motor6D`: `Part0` (`$ref`), `Part1` (`$ref`), `C0` (CFrame), `C1` (CFrame), `Transform` (CFrame), `CurrentAngle`, `DesiredAngle`, `MaxVelocity`, `Enabled`
- `RopeConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `Length`, `Restitution`, `Thickness`, `WinchEnabled`, `WinchForce`, `WinchResponsiveness`, `WinchSpeed`, `WinchTarget`
- `RodConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `Length`, `LimitAngle0`, `LimitAngle1`, `LimitsEnabled`, `Thickness`
- `SpringConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `Coils`, `Damping`, `FreeLength`, `LimitsEnabled`, `MaxForce`, `MaxLength`, `MinLength`, `Radius`, `Stiffness`, `Thickness`
- `BallSocketConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `LimitsEnabled`, `MaxFrictionTorque`, `Radius`, `Restitution`, `TwistLimitsEnabled`, `TwistLowerAngle`, `TwistUpperAngle`, `UpperAngle`
- `HingeConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `ActuatorType`, `AngularResponsiveness`, `AngularSpeed`, `AngularVelocity`, `LimitsEnabled`, `LowerAngle`, `MotorMaxAcceleration`, `MotorMaxTorque`, `Radius`, `Restitution`, `ServoMaxTorque`, `TargetAngle`, `UpperAngle`
- `PrismaticConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `ActuatorType`, `LinearResponsiveness`, `LineDirection`, `LinearVelocity`, `LimitsEnabled`, `LowerLimit`, `MotorMaxAcceleration`, `MotorMaxForce`, `Restitution`, `ServoMaxForce`, `Size`, `Speed`, `TargetPosition`, `UpperLimit`, `Velocity`
- `CylindricalConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `ActuatorType`, `AngularActuatorType`, `AngularLimitsEnabled`, `AngularResponsiveness`, `AngularRestitution`, `AngularSpeed`, `AngularVelocity`, `InclinationAngle`, `LinearResponsiveness`, `LinearVelocity`, `LimitsEnabled`, `LowerAngle`, `LowerLimit`, `MotorMaxAcceleration`, `MotorMaxAngularAcceleration`, `MotorMaxForce`, `MotorMaxTorque`, `Restitution`, `ServoMaxForce`, `ServoMaxTorque`, `Speed`, `TargetAngle`, `TargetPosition`, `UpperAngle`, `UpperLimit`, `Velocity`
- `UniversalConstraint`: `Attachment0` (`$ref`), `Attachment1` (`$ref`), `Color`, `Enabled`, `Visible`, `LimitsEnabled`, `MaxAngle`, `Radius`, `Restitution`
- `AlignPosition`: `Attachment0` (`$ref`), `Attachment1` (`$ref` optional), `Color`, `Enabled`, `Visible`, `ApplyAtCenterOfMass`, `ForceLimitMode`, `ForceRelativeTo`, `MaxAxesForce`, `MaxForce`, `MaxVelocity`, `Mode`, `Position`, `ReactionForceEnabled`, `Responsiveness`, `RigidityEnabled`
- `AlignOrientation`: `Attachment0` (`$ref`), `Attachment1` (`$ref` optional), `Color`, `Enabled`, `Visible`, `AlignType`, `CFrame`, `LookAtPosition`, `MaxAngularVelocity`, `MaxTorque`, `Mode`, `PrimaryAxis`, `PrimaryAxisOnly`, `ReactionTorqueEnabled`, `Responsiveness`, `RigidityEnabled`, `SecondaryAxis`
- `LinearVelocity`: `Attachment0` (`$ref`), `Color`, `Enabled`, `Visible`, `ForceLimitMode`, `ForceLimitsEnabled`, `LineDirection`, `LineVelocity`, `MaxAxesForce`, `MaxForce`, `MaxPlanarAxesForce`, `PlaneVelocity`, `PrimaryTangentAxis`, `ReactionForceEnabled`, `RelativeTo`, `SecondaryTangentAxis`, `VectorVelocity`, `VelocityConstraintMode`
- `AngularVelocity`: `Attachment0` (`$ref`), `Color`, `Enabled`, `Visible`, `AngularVelocity`, `MaxTorque`, `ReactionTorqueEnabled`, `RelativeTo`
- `VectorForce`: `Attachment0` (`$ref`), `Color`, `Enabled`, `Visible`, `ApplyAtCenterOfMass`, `Force`, `RelativeTo`
- `Torque`: `Attachment0` (`$ref`), `Color`, `Enabled`, `Visible`, `RelativeTo`, `Torque`

---

### 12.9 Value Objects & Surface Content
- `StringValue`: `Value` (string)
- `BoolValue`: `Value` (boolean)
- `IntValue`: `Value` (integer)
- `NumberValue`: `Value` (number)
- `Color3Value`: `Value` (Color3)
- `Vector3Value`: `Value` (Vector3)
- `CFrameValue`: `Value` (CFrame)
- `BrickColorValue`: `Value` (BrickColor)
- `RayValue`: `Value` (Ray)
- `ObjectValue`: `Value` (`$ref` or `"@target"`)
- `Decal`: `AutoLocalize`, `Color3`, `ColorMap`, `Face`, `Rotation`, `Texture` (Asset URI), `Transparency`, `UVOffset`, `UVScale`, `ZIndex`
- `Texture`: `AutoLocalize`, `Color3`, `ColorMap`, `Face`, `OffsetStudsU`, `OffsetStudsV`, `Rotation`, `StudsPerTileU`, `StudsPerTileV`, `Texture` (Asset URI), `Transparency`, `UVOffset`, `UVScale`, `ZIndex`

---

## 13. Controlled Properties

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
```

### Mutually Exclusive Property Rules
1. Do not combine `CFrame` with `Position`, `Orientation`, or `Rotation` on the same node.
2. Do not combine `Orientation` with `Rotation` on the same node.
3. Do not combine `Color` with `BrickColor` on the same node.

---

## 14. Asset Policy

Properties requiring approved Roblox asset references:
- `MeshPart.TextureID`
- `SpecialMesh.MeshId`, `SpecialMesh.TextureId`
- `SurfaceAppearance.ColorMap`, `SurfaceAppearance.MetalnessMap`, `SurfaceAppearance.NormalMap`, `SurfaceAppearance.RoughnessMap`, `SurfaceAppearance.EmissiveMask`
- `ParticleEmitter.Texture`
- `Beam.Texture`
- `Trail.Texture`
- `Decal.ColorMap`, `Decal.Texture`
- `Texture.ColorMap`, `Texture.Texture`
- `Sound.SoundId`

### Approved URI Schemes:
1. **Roblox Asset ID:**
   ```text
   rbxassetid://123456789
   ```
2. **Numeric ID string shorthand:**
   ```text
   "123456789"
   ```
3. **Internal Built-in Textures:**
   ```text
   rbxasset://textures/StudioSharedUI/scripts.png
   rbxasset://textures/particles/sparkles_main.dds
   ```
4. **Internal Built-in Sounds:**
   ```text
   rbxasset://sounds/electronic_beep.wav
   ```

### URI Constraints:
- Maximum length: 1,024 bytes.
- No whitespace or control characters (`[\x00-\x20]`).
- Directory traversal (`..`) is strictly rejected.
- HTTP, HTTPS, local disk paths (`file://`, `C:\`), and UNC shares are rejected.

---

## 15. Architectural Limits (20 Boundaries)

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
| Maximum Key, Class, Attribute, or Tag length | 1,000 bytes | `... exceeds limit of 1000 bytes.` |
| Maximum Comment string length | 10,000,000 bytes | `... exceeds 10000000 bytes.` |
| Maximum GenerationLabel length | 1,000 bytes | `Options.GenerationLabel exceeds 1000 bytes.` |
| Maximum BaseParts per operation | 1,000,000 instances | `Document exceeds maximum of 1000000 BaseParts.` |
| Maximum MeshParts per operation | 100,000 instances | `Document exceeds maximum of 100000 MeshParts.` |
| Maximum Constraints per operation | 100,000 instances | `Document exceeds maximum of 100000 constraints.` |
| Maximum Effects & Lights per operation | 100,000 instances | `Document exceeds maximum of 100000 effects and lights.` |
| Maximum Sounds per operation | 100,000 instances | `Document exceeds maximum of 100000 sounds.` |
| Maximum Asset URI string length | 1,024 bytes | `... must be between 1 and 1024 bytes.` |
| Maximum retained warnings | 200 warnings | Warnings list capped at 200 entries. |

---

## 16. Complete Production-Grade Examples

### 16.1 Anchored Architectural Building with Materials & Lighting

```json
{
  "Roots": [
    {
      "ClassName": "Model",
      "Id": "estateModel",
      "Name": "ModernVilla",
      "Properties": {
        "PrimaryPart": {
          "$ref": "foundation"
        }
      },
      "Attributes": {
        "GeneratedBy": "JSON23D",
        "SchemaVersion": 1,
        "Architect": "StudioAI"
      },
      "Tags": [
        "JSON23D",
        "Architecture",
        "StaticStructure"
      ],
      "Children": [
        {
          "ClassName": "Part",
          "Id": "foundation",
          "Name": "FoundationSlab",
          "Properties": {
            "Size": [24, 1.5, 20],
            "CFrame": [0, 0.75, 0],
            "Anchored": true,
            "Color": "#7A8088",
            "Material": "Concrete",
            "CustomPhysicalProperties": "Concrete"
          }
        },
        {
          "ClassName": "Part",
          "Name": "WallBack",
          "Properties": {
            "Size": [24, 10, 0.8],
            "CFrame": {
              "$type": "CFrame",
              "Position": [0, 6.5, -9.6]
            },
            "Anchored": true,
            "Color": "#E8E2D8",
            "Material": "Brick"
          }
        },
        {
          "ClassName": "Part",
          "Name": "GlassFacade",
          "Properties": {
            "Size": [10, 10, 0.5],
            "CFrame": {
              "$type": "CFrame",
              "Position": [-6, 6.5, 9.6]
            },
            "Anchored": true,
            "Color": "#A0D0FF",
            "Material": "Glass",
            "Transparency": 0.4,
            "Reflectance": 0.2
          }
        },
        {
          "ClassName": "Part",
          "Name": "CeilingLightFixture",
          "Properties": {
            "Size": [2, 0.4, 2],
            "CFrame": {
              "$type": "CFrame",
              "Position": [0, 11.2, 0]
            },
            "Anchored": true,
            "Color": "#303236",
            "Material": "Metal"
          },
          "Children": [
            {
              "ClassName": "PointLight",
              "Properties": {
                "Brightness": 3.0,
                "Color": "#FFE6B0",
                "Range": 24,
                "Shadows": true
              }
            }
          ]
        }
      ]
    }
  ],
  "Options": {
    "SelectGenerated": true,
    "AssetPolicy": "ReferenceOnly",
    "GenerationLabel": "JSON23D: Generate Modern Villa",
    "AllowExperimental": false
  }
}
```

---

### 16.2 Rigged Robotic Arm with Motor6D Joints

```json
{
  "ClassName": "Model",
  "Id": "robotModel",
  "Name": "ArticulatedRobotArm",
  "Properties": {
    "PrimaryPart": {
      "$ref": "baseMount"
    }
  },
  "Children": [
    {
      "ClassName": "Part",
      "Id": "baseMount",
      "Name": "BaseMount",
      "Properties": {
        "Size": [4, 1, 4],
        "CFrame": [0, 0.5, 0],
        "Anchored": true,
        "Color": "#2A2D32",
        "Material": "Metal"
      }
    },
    {
      "ClassName": "Part",
      "Id": "lowerArm",
      "Name": "LowerArmSegment",
      "Properties": {
        "Size": [1.2, 6, 1.2],
        "CFrame": [0, 4, 0],
        "Anchored": false,
        "Color": "#E65100",
        "Material": "SmoothPlastic"
      }
    },
    {
      "ClassName": "Motor6D",
      "Name": "BaseShoulderJoint",
      "Properties": {
        "Part0": {
          "$ref": "baseMount"
        },
        "Part1": {
          "$ref": "lowerArm"
        },
        "C0": [0, 0.5, 0],
        "C1": [0, -3, 0],
        "MaxVelocity": 0.1,
        "DesiredAngle": 0.785
      }
    },
    {
      "ClassName": "Part",
      "Id": "upperArm",
      "Name": "UpperArmSegment",
      "Properties": {
        "Size": [1, 5, 1],
        "CFrame": [0, 9.5, 0],
        "Anchored": false,
        "Color": "#37474F",
        "Material": "SmoothPlastic"
      }
    },
    {
      "ClassName": "Motor6D",
      "Name": "ElbowJoint",
      "Properties": {
        "Part0": {
          "$ref": "lowerArm"
        },
        "Part1": {
          "$ref": "upperArm"
        },
        "C0": [0, 3, 0],
        "C1": [0, -2.5, 0],
        "MaxVelocity": 0.15,
        "DesiredAngle": -0.523
      }
    }
  ]
}
```

---

### 16.3 Positional 3D Audio Beacon

```json
{
  "ClassName": "Part",
  "Name": "AudioBeaconPillar",
  "Properties": {
    "Size": [2, 6, 2],
    "CFrame": [0, 3, 0],
    "Anchored": true,
    "Color": "#1E2228",
    "Material": "Metal"
  },
  "Children": [
    {
      "ClassName": "Sound",
      "Name": "ReactorAmbience",
      "Properties": {
        "SoundId": "rbxassetid://9114223175",
        "Volume": 0.75,
        "Pitch": 1.1,
        "Looped": true,
        "Playing": true,
        "RollOffMode": "InverseTapered",
        "RollOffMinDistance": 6,
        "RollOffMaxDistance": 60
      }
    },
    {
      "ClassName": "PointLight",
      "Properties": {
        "Brightness": 2.5,
        "Color": "#40C4FF",
        "Range": 16
      }
    }
  ]
}
```

---

### 16.4 PBR Mesh Container with SurfaceAppearance

```json
{
  "ClassName": "MeshPart",
  "Name": "PBRColumn",
  "Properties": {
    "Size": [4, 10, 4],
    "CFrame": [0, 5, 0],
    "Anchored": true,
    "TextureID": "rbxassetid://1",
    "RenderFidelity": "Automatic",
    "CollisionFidelity": "PreciseConvexDecomposition"
  },
  "Children": [
    {
      "ClassName": "SurfaceAppearance",
      "Properties": {
        "ColorMap": "rbxassetid://12345678",
        "NormalMap": "rbxassetid://12345679",
        "MetalnessMap": "rbxassetid://12345680",
        "RoughnessMap": "rbxassetid://12345681",
        "EmissiveMask": "rbxassetid://12345682",
        "EmissiveStrength": 1.8,
        "AlphaMode": "Overlay"
      }
    }
  ]
}
```

---

### 16.5 Lasers & Particle FX with Beams and Attachments

```json
{
  "ClassName": "Model",
  "Name": "LaserBeamEmitter",
  "Children": [
    {
      "ClassName": "Part",
      "Name": "SourcePylon",
      "Properties": {
        "Size": [1, 4, 1],
        "CFrame": [-10, 2, 0],
        "Anchored": true
      },
      "Children": [
        {
          "ClassName": "Attachment",
          "Id": "sourceAtt",
          "Properties": {
            "Position": [0, 1.8, 0]
          }
        },
        {
          "ClassName": "ParticleEmitter",
          "Properties": {
            "Texture": "rbxassetid://12345678",
            "Rate": 25,
            "Lifetime": [0.5, 1.2],
            "Speed": [1, 4],
            "Color": ["#FF1744", "#FF8A80"],
            "Transparency": [0, 1]
          }
        }
      ]
    },
    {
      "ClassName": "Part",
      "Name": "TargetPylon",
      "Properties": {
        "Size": [1, 4, 1],
        "CFrame": [10, 2, 0],
        "Anchored": true
      },
      "Children": [
        {
          "ClassName": "Attachment",
          "Id": "targetAtt",
          "Properties": {
            "Position": [0, 1.8, 0]
          }
        }
      ]
    },
    {
      "ClassName": "Beam",
      "Properties": {
        "Attachment0": {
          "$ref": "sourceAtt"
        },
        "Attachment1": {
          "$ref": "targetAtt"
        },
        "Width0": 0.2,
        "Width1": 0.2,
        "Color": "#FF1744",
        "FaceCamera": true,
        "LightEmission": 1.0
      }
    }
  ]
}
```

---

### 16.6 UI 3D Preview in ViewportFrame + WorldModel + Camera

```json
{
  "ClassName": "WorldModel",
  "Name": "PreviewScene",
  "Children": [
    {
      "ClassName": "Camera",
      "Name": "PreviewCamera",
      "Properties": {
        "CFrame": [0, 3, 8, -12, 0, 0],
        "FieldOfView": 60
      }
    },
    {
      "ClassName": "Part",
      "Name": "RotatingShowcasePedestal",
      "Properties": {
        "Size": [3, 0.5, 3],
        "CFrame": [0, 0, 0],
        "Anchored": true,
        "Color": "#455A64",
        "Material": "SmoothPlastic"
      },
      "Children": [
        {
          "ClassName": "PointLight",
          "Properties": {
            "Brightness": 2.0,
            "Color": "#ECEFF1",
            "Range": 12
          }
        }
      ]
    }
  ]
}
```

---

## 17. Validation & Atomic Staging Lifecycle

Every operation in JSON23D follows strict transactional boundaries:

1. **Syntax Parsing:** Decode JSON and assert zero `null` occurrences outside string literals.
2. **Schema Normalization:** Verify document boundaries, string lengths, ID uniqueness, and valid `$type` tags.
3. **Policy Evaluation:** Confirm the selected target is valid, classes belong to the 64-profile, properties match allowlists, and parent-child hierarchies comply with engine topology.
4. **Off-Tree Native Preflight:**
   - Temporarily instantiates every node using `Instance.new`.
   - Applies names, properties, attributes, and tags off-tree.
   - Evaluates reference connections and validates joints/constraints.
   - Destroys the disposable hierarchy completely.
   - Returns itemized counts and warnings without touching the place.
5. **Committed Staging & History Hook:**
   - Opens undo recording with `ChangeHistoryService`.
   - Reconstructs the instances off-tree and reapplies all assignments.
   - Attaches root instances to the target parent only after all assignments succeed.
   - If any step fails during construction or attachment, all generated instances from that session are destroyed immediately, and the history recording is cancelled.

---

## 18. Troubleshooting & Diagnostic Error Matrix

| Error Message Fragment | Root Cause | Exact Resolution |
|---|---|---|
| `JSON null is not supported at byte X` | `null` token found in JSON | Remove `"key": null` and omit optional fields entirely. |
| `contains unsupported field 'X'` | Unrecognized node or wrapper key | Move Roblox properties inside `Properties` dictionary. |
| `cannot assign controlled property 'Parent'` | `Parent` assigned directly in `Properties` | Remove `Parent`; hierarchy is derived from `Children` nesting. |
| `uses blocked class 'Script'` | Executable or networking class used | Replace with approved static 3D presentation classes. |
| `MeshPart.MeshId is not writable...` | `MeshId` assigned to `MeshPart` | Use `Part` with child `SpecialMesh` and assign `SpecialMesh.MeshId`. |
| `references 'X', which resolves to Part, but Attachment is required` | Property reference points to wrong class | Update `$ref` to target an `Attachment` node. |
| `PrimaryPart must reference a descendant of the generated Model` | `PrimaryPart` points to external part | Make sure the target part is a child/descendant within that same `Model`. |
| `cannot reference @target in the supported profile` | `@target` used on unsupported property | Restrict `@target` to `Highlight.Adornee`, `SelectionBox.Adornee`, `SelectionSphere.Adornee`, or `ObjectValue.Value`. |
| `uses unsupported URI scheme 'http'` | External web URL assigned | Use `rbxassetid://<id>` or internal `rbxasset://` paths. |
| `BasePart.Size components must be finite and greater than zero` | Size contains $0$ or negative numbers | Provide positive numbers ($> 0$) for all X, Y, Z dimensions. |
| `keypoint times must start at time 0 and end at time 1` | Keypoints miss 0.0 or 1.0 bounds | Set first keypoint `Time: 0.0` and last keypoint `Time: 1.0`. |
| `keypoint times must be strictly increasing` | Keypoint timestamps duplicate or decrease | Ensure each keypoint `Time` is strictly greater than the previous. |
| `Table in attributes requires an explicit $type` | Untagged table in `Attributes` | Add `$type` descriptor (e.g. `{"$type": "Vector3", "Value": [0,0,0]}`). |
| `Roblox attributes cannot store Instance references` | `$ref` used in `Attributes` | Remove instance reference; store string IDs or use `ObjectValue` nodes instead. |
| `Target unavailable: Select exactly one target parent` | Multiple or invalid instances selected | Select exactly one supported container in Explorer or clear selection for `Workspace`. |

---

## 19. Explicit Blocked Scope & Security Invariants

The following classes are explicitly and permanently blocked:

```text
Script, LocalScript, ModuleScript, CoreScript, Actor,
RemoteEvent, RemoteFunction, UnreliableRemoteEvent,
BindableEvent, BindableFunction,
DataModel, Workspace, ReplicatedStorage, ServerStorage,
ServerScriptService, StarterGui, StarterPlayer, Lighting,
SoundService, Teams, Chat, Players,
Terrain, EditableMesh, EditableImage,
UnionOperation, NegateOperation, PartOperation,
PackageLink, Package, Drafts,
ProximityPrompt, ClickDetector,
Humanoid, HumanoidDescription, BodyColors,
Shirt, Pants, ShirtGraphic
```

*Note: While `Workspace`, `ReplicatedStorage`, `ServerStorage`, and `SoundService` are supported generation targets, they cannot be created as nodes.*

---

## 20. Version Boundary

This specification is normative for **JSON23D `v1.2.0`** verified on Roblox Studio build **`0.740.0.7400927`**.