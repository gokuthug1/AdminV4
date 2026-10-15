import math
import json
import os
import numpy as np

os.makedirs("Json2Schemas/3D", exist_ok=True)
os.makedirs("Json2Schemas/Anim", exist_ok=True)

# ==========================================
# 1. BUILD HALO.JSON (CONFIRMED PERFECT BY USER)
# ==========================================
def build_halo():
    R = 0.85
    Y = 1.35
    N = 24
    dtheta = 2 * math.pi / N
    thickness = 0.14
    sphere_diam = 0.16

    children = []

    # 24 Spherical joints at vertices
    for k in range(N):
        theta = k * dtheta
        vx = round(R * math.cos(theta), 4)
        vz = round(R * math.sin(theta), 4)
        part = {
            "ClassName": "Part",
            "Id": f"haloJoint{k+1}",
            "Name": f"Joint{k+1}",
            "Properties": {
                "Shape": "Ball",
                "Size": [sphere_diam, sphere_diam, sphere_diam],
                "CFrame": [vx, Y, vz],
                "Material": "Neon",
                "Color": "#FFD700",
                "Anchored": True,
                "CanCollide": False
            }
        }
        if k == 0:
            part["Children"] = [{
                "ClassName": "PointLight",
                "Id": "haloLight",
                "Name": "HaloGlow",
                "Properties": {
                    "Brightness": 2,
                    "Range": 6,
                    "Color": "#FFF275"
                }
            }]
        children.append(part)

    # 24 Tangent segments
    seg_len = round(2 * R * math.sin(dtheta / 2) + 0.04, 4)

    for k in range(N):
        theta1 = k * dtheta
        theta2 = (k + 1) * dtheta
        v1 = (R * math.cos(theta1), Y, R * math.sin(theta1))
        v2 = (R * math.cos(theta2), Y, R * math.sin(theta2))
        
        mid_x = round((v1[0] + v2[0]) / 2, 4)
        mid_z = round((v1[2] + v2[2]) / 2, 4)
        
        dx = v2[0] - v1[0]
        dz = v2[2] - v1[2]
        dist = math.hypot(dx, dz)
        ux = dx / dist
        uz = dz / dist
        
        matrix = [
            mid_x, Y, mid_z,
            round(uz, 5), 0, round(ux, 5),
            0, 1, 0,
            round(-ux, 5), 0, round(uz, 5)
        ]
        
        children.append({
            "ClassName": "Part",
            "Id": f"haloSeg{k+1}",
            "Name": f"Segment{k+1}",
            "Properties": {
                "Size": [thickness, thickness, seg_len],
                "CFrame": matrix,
                "Material": "Neon",
                "Color": "#FFD700",
                "Anchored": True,
                "CanCollide": False
            }
        })

    doc = {
        "ClassName": "Model",
        "Id": "haloModel",
        "Name": "Halo",
        "Properties": {
            "PrimaryPart": {
                "$ref": "haloJoint1"
            }
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/Halo.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print(f"Halo.json: {len(children)} parts generated (confirmed perfect).")


# ==========================================
# 2. BUILD WINGS.JSON (CASCADING MAJESTIC ARCHANGEL WINGS - STRICT BACK POSITIONING)
# ==========================================
def build_wings():
    # Helper functions for orthonormal rotation matrices
    def make_cframe_right(A, B, W_rough):
        A = np.array(A, dtype=float)
        B = np.array(B, dtype=float)
        L = float(np.linalg.norm(B - A))
        M = (A + B) / 2.0
        D = (B - A) / L
        T = np.cross(W_rough, D)
        T = T / np.linalg.norm(T)
        W = np.cross(D, T)
        W = W / np.linalg.norm(W)
        R = np.column_stack([T, W, D])
        return M, L, R

    def make_cframe_left(A, B, W_rough):
        A_l = np.array([-A[0], A[1], A[2]], dtype=float)
        B_l = np.array([-B[0], B[1], B[2]], dtype=float)
        L = float(np.linalg.norm(B_l - A_l))
        M = (A_l + B_l) / 2.0
        D = (B_l - A_l) / L
        W_rough_l = np.array([-W_rough[0], W_rough[1], W_rough[2]])
        T = np.cross(D, W_rough_l)
        T = T / np.linalg.norm(T)
        W = np.cross(D, T)
        W = W / np.linalg.norm(W)
        R = np.column_stack([T, W, D])
        return M, L, R

    W_rough = [0.15, 0.10, -0.98]
    children = []

    # 1. Central Diamond Spine Mount Bracket (Flush on the upper-mid back at Y = -0.15, Z = -0.48)
    children.append({
        "ClassName": "Part",
        "Id": "wingMount",
        "Name": "WingMount",
        "Properties": {
            "Size": [0.55, 0.70, 0.16],
            "CFrame": [0, -0.15, -0.48],
            "Material": "SmoothPlastic",
            "Color": "#1E293B",
            "Anchored": True,
            "CanCollide": False
        }
    })

    children.append({
        "ClassName": "Part",
        "Id": "wingCorePlate",
        "Name": "WingCorePlate",
        "Properties": {
            "Size": [0.42, 0.54, 0.08],
            "CFrame": [0, -0.15, -0.53],
            "Material": "SmoothPlastic",
            "Color": "#F8FAFC",
            "Anchored": True,
            "CanCollide": False
        }
    })

    children.append({
        "ClassName": "Part",
        "Id": "wingCoreGem",
        "Name": "WingCoreGem",
        "Properties": {
            "Shape": "Ball",
            "Size": [0.24, 0.24, 0.16],
            "CFrame": [0, -0.15, -0.58],
            "Material": "Neon",
            "Color": "#38BDF8",
            "Anchored": True,
            "CanCollide": False
        },
        "Children": [
            {
                "ClassName": "PointLight",
                "Id": "wingCoreLight",
                "Name": "CoreAura",
                "Properties": {
                    "Brightness": 1.5,
                    "Range": 7,
                    "Color": "#38BDF8"
                }
            }
        ]
    })

    # Wing framework definitions (Lowered and tightened against upper back)
    A0 = [0.22, -0.10, -0.50]   # Scapula root
    A1 = [0.72, 0.45, -0.56]    # Mid-shoulder rise
    A2 = [1.32, 1.05, -0.62]    # Elbow crest apex (arches just above shoulder)
    A3 = [2.20, 0.55, -0.72]    # Outer wingtip forearm

    # Tier 1: 8 Primary Flight Feathers (sweeping cascading arc downwards and backwards)
    primaries = [
        ([2.20, 0.55, -0.72], [2.85, -1.35, -0.90], 0.42, 0.07, "#BAE6FD", "Neon"),
        ([1.98, 0.68, -0.70], [2.55, -1.45, -0.86], 0.44, 0.07, "#93C5FD", "Neon"),
        ([1.76, 0.80, -0.67], [2.25, -1.55, -0.82], 0.44, 0.07, "#60A5FA", "Neon"),
        ([1.54, 0.92, -0.64], [1.95, -1.65, -0.78], 0.44, 0.07, "#38BDF8", "Neon"),
        ([1.32, 1.05, -0.62], [1.65, -1.75, -0.74], 0.42, 0.07, "#0EA5E9", "Neon"),
        ([1.12, 0.85, -0.60], [1.35, -1.80, -0.70], 0.40, 0.07, "#0284C7", "Neon"),
        ([0.92, 0.65, -0.58], [1.05, -1.85, -0.66], 0.38, 0.07, "#0369A1", "Neon"),
        ([0.72, 0.45, -0.56], [0.75, -1.90, -0.62], 0.36, 0.07, "#075985", "Neon")
    ]

    # Tier 2: 7 Secondary Covert Feathers (lush overlapping plumage over bone/bases)
    coverts = [
        ([2.05, 0.62, -0.64], [2.50, -0.45, -0.76], 0.36, 0.06, "#FFFFFF", "SmoothPlastic"),
        ([1.80, 0.74, -0.62], [2.20, -0.55, -0.72], 0.38, 0.06, "#F8FAFC", "SmoothPlastic"),
        ([1.55, 0.86, -0.60], [1.90, -0.65, -0.68], 0.40, 0.06, "#F1F5F9", "SmoothPlastic"),
        ([1.32, 0.98, -0.58], [1.60, -0.75, -0.64], 0.40, 0.06, "#E0F2FE", "SmoothPlastic"),
        ([1.10, 0.80, -0.56], [1.30, -0.85, -0.60], 0.38, 0.06, "#BAE6FD", "SmoothPlastic"),
        ([0.88, 0.60, -0.54], [1.00, -0.95, -0.56], 0.36, 0.06, "#7DD3FC", "SmoothPlastic"),
        ([0.68, 0.40, -0.52], [0.72, -1.05, -0.54], 0.34, 0.06, "#38BDF8", "SmoothPlastic")
    ]

    # Tier 3: 3 Tertiary Crest Feathers (high shoulder tips arching above head)
    crests = [
        ([1.10, 0.90, -0.58], [1.25, 1.55, -0.70], 0.32, 0.05, "#FFFFFF", "Neon"),
        ([1.32, 1.05, -0.60], [1.55, 1.75, -0.74], 0.34, 0.05, "#F0F9FF", "Neon"),
        ([1.55, 0.95, -0.62], [1.85, 1.50, -0.76], 0.30, 0.05, "#E0F2FE", "Neon")
    ]

    for side in ["Right", "Left"]:
        fn = make_cframe_right if side == "Right" else make_cframe_left
        sgn = 1 if side == "Right" else -1

        # 2. Bone Spar 1 (Scapula to Mid-Shoulder)
        M_s1, L_s1, R_s1 = fn(A0, A1, W_rough)
        children.append({
            "ClassName": "Part",
            "Id": f"boneSpar1_{side}",
            "Name": f"BoneSpar1_{side}",
            "Properties": {
                "Size": [0.18, 0.18, round(L_s1, 3)],
                "CFrame": [
                    round(float(M_s1[0]), 3), round(float(M_s1[1]), 3), round(float(M_s1[2]), 3),
                    round(float(R_s1[0,0]), 4), round(float(R_s1[0,1]), 4), round(float(R_s1[0,2]), 4),
                    round(float(R_s1[1,0]), 4), round(float(R_s1[1,1]), 4), round(float(R_s1[1,2]), 4),
                    round(float(R_s1[2,0]), 4), round(float(R_s1[2,1]), 4), round(float(R_s1[2,2]), 4)
                ],
                "Material": "SmoothPlastic",
                "Color": "#F8FAFC",
                "Anchored": True,
                "CanCollide": False
            }
        })

        # 3. Bone Spar 2 (Mid-Shoulder to High Elbow Apex)
        M_s2, L_s2, R_s2 = fn(A1, A2, W_rough)
        children.append({
            "ClassName": "Part",
            "Id": f"boneSpar2_{side}",
            "Name": f"BoneSpar2_{side}",
            "Properties": {
                "Size": [0.16, 0.16, round(L_s2, 3)],
                "CFrame": [
                    round(float(M_s2[0]), 3), round(float(M_s2[1]), 3), round(float(M_s2[2]), 3),
                    round(float(R_s2[0,0]), 4), round(float(R_s2[0,1]), 4), round(float(R_s2[0,2]), 4),
                    round(float(R_s2[1,0]), 4), round(float(R_s2[1,1]), 4), round(float(R_s2[1,2]), 4),
                    round(float(R_s2[2,0]), 4), round(float(R_s2[2,1]), 4), round(float(R_s2[2,2]), 4)
                ],
                "Material": "SmoothPlastic",
                "Color": "#F8FAFC",
                "Anchored": True,
                "CanCollide": False
            }
        })

        # 4. Elbow Apex Joint Gem
        children.append({
            "ClassName": "Part",
            "Id": f"elbowJoint_{side}",
            "Name": f"ElbowJoint_{side}",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.26, 0.26, 0.26],
                "CFrame": [round(sgn * A2[0], 3), A2[1], A2[2]],
                "Material": "Neon",
                "Color": "#BAE6FD",
                "Anchored": True,
                "CanCollide": False
            }
        })

        # 5. Bone Spar 3 (Elbow to Forearm Wingtip)
        M_s3, L_s3, R_s3 = fn(A2, A3, W_rough)
        children.append({
            "ClassName": "Part",
            "Id": f"boneSpar3_{side}",
            "Name": f"BoneSpar3_{side}",
            "Properties": {
                "Size": [0.15, 0.15, round(L_s3, 3)],
                "CFrame": [
                    round(float(M_s3[0]), 3), round(float(M_s3[1]), 3), round(float(M_s3[2]), 3),
                    round(float(R_s3[0,0]), 4), round(float(R_s3[0,1]), 4), round(float(R_s3[0,2]), 4),
                    round(float(R_s3[1,0]), 4), round(float(R_s3[1,1]), 4), round(float(R_s3[1,2]), 4),
                    round(float(R_s3[2,0]), 4), round(float(R_s3[2,1]), 4), round(float(R_s3[2,2]), 4)
                ],
                "Material": "SmoothPlastic",
                "Color": "#F1F5F9",
                "Anchored": True,
                "CanCollide": False
            }
        })

        # 6. Wingtip Joint Gem
        children.append({
            "ClassName": "Part",
            "Id": f"wingtipJoint_{side}",
            "Name": f"WingtipJoint_{side}",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.22, 0.22, 0.22],
                "CFrame": [round(sgn * A3[0], 3), A3[1], A3[2]],
                "Material": "Neon",
                "Color": "#7DD3FC",
                "Anchored": True,
                "CanCollide": False
            }
        })

        # 7. Tier 1: Primaries
        for idx, (root, tip, width, thk, col, mat) in enumerate(primaries):
            M_p, L_p, R_p = fn(root, tip, W_rough)
            children.append({
                "ClassName": "Part",
                "Id": f"primaryBlade{idx+1}_{side}",
                "Name": f"PrimaryBlade{idx+1}_{side}",
                "Properties": {
                    "Size": [width, thk, round(L_p, 3)],
                    "CFrame": [
                        round(float(M_p[0]), 3), round(float(M_p[1]), 3), round(float(M_p[2]), 3),
                        round(float(R_p[0,0]), 4), round(float(R_p[0,1]), 4), round(float(R_p[0,2]), 4),
                        round(float(R_p[1,0]), 4), round(float(R_p[1,1]), 4), round(float(R_p[1,2]), 4),
                        round(float(R_p[2,0]), 4), round(float(R_p[2,1]), 4), round(float(R_p[2,2]), 4)
                    ],
                    "Material": mat,
                    "Color": col,
                    "Anchored": True,
                    "CanCollide": False
                }
            })

        # 8. Tier 2: Coverts
        for idx, (root, tip, width, thk, col, mat) in enumerate(coverts):
            M_c, L_c, R_c = fn(root, tip, W_rough)
            children.append({
                "ClassName": "Part",
                "Id": f"covertFeather{idx+1}_{side}",
                "Name": f"CovertFeather{idx+1}_{side}",
                "Properties": {
                    "Size": [width, thk, round(L_c, 3)],
                    "CFrame": [
                        round(float(M_c[0]), 3), round(float(M_c[1]), 3), round(float(M_c[2]), 3),
                        round(float(R_c[0,0]), 4), round(float(R_c[0,1]), 4), round(float(R_c[0,2]), 4),
                        round(float(R_c[1,0]), 4), round(float(R_c[1,1]), 4), round(float(R_c[1,2]), 4),
                        round(float(R_c[2,0]), 4), round(float(R_c[2,1]), 4), round(float(R_c[2,2]), 4)
                    ],
                    "Material": mat,
                    "Color": col,
                    "Anchored": True,
                    "CanCollide": False
                }
            })

        # 9. Tier 3: Crests
        for idx, (root, tip, width, thk, col, mat) in enumerate(crests):
            M_cr, L_cr, R_cr = fn(root, tip, W_rough)
            children.append({
                "ClassName": "Part",
                "Id": f"crestFeather{idx+1}_{side}",
                "Name": f"CrestFeather{idx+1}_{side}",
                "Properties": {
                    "Size": [width, thk, round(L_cr, 3)],
                    "CFrame": [
                        round(float(M_cr[0]), 3), round(float(M_cr[1]), 3), round(float(M_cr[2]), 3),
                        round(float(R_cr[0,0]), 4), round(float(R_cr[0,1]), 4), round(float(R_cr[0,2]), 4),
                        round(float(R_cr[1,0]), 4), round(float(R_cr[1,1]), 4), round(float(R_cr[1,2]), 4),
                        round(float(R_cr[2,0]), 4), round(float(R_cr[2,1]), 4), round(float(R_cr[2,2]), 4)
                    ],
                    "Material": mat,
                    "Color": col,
                    "Anchored": True,
                    "CanCollide": False
                }
            })

    doc = {
        "ClassName": "Model",
        "Id": "wingsModel",
        "Name": "Wings",
        "Properties": {
            "PrimaryPart": {
                "$ref": "wingMount"
            }
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/Wings.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print(f"Wings.json: {len(children)} parts generated (Cascading Majestic Archangel Wings).")


# ==========================================
# 3. BUILD METALPIPE.JSON (HEAVY INDUSTRIAL CYLINDRICAL STEEL PIPE)
# ==========================================
def build_metal_pipe():
    # Direct CylinderMesh presentation for 100% natural tool alignment along Y axis
    children = [
        # Main Pipe Handle (Galvanized steel shaft with CylinderMesh)
        {
            "ClassName": "Part",
            "Id": "pipeHandle",
            "Name": "Handle",
            "Properties": {
                "Size": [0.45, 3.8, 0.45],
                "CFrame": [0, 0, 0],
                "Material": "Metal",
                "Color": "#8A9096",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "meshHandle",
                    "Name": "CylinderMesh"
                },
                {
                    "ClassName": "Sound",
                    "Id": "pipeClangSound",
                    "Name": "ClangSound",
                    "Properties": {
                        "SoundId": "rbxassetid://9114223180",
                        "Volume": 1.8,
                        "RollOffMaxDistance": 150
                    }
                },
                {
                    "ClassName": "Sound",
                    "Id": "pipeSwingSound",
                    "Name": "SwingSound",
                    "Properties": {
                        "SoundId": "rbxassetid://169445121",
                        "Volume": 0.9,
                        "Pitch": 0.95
                    }
                }
            ]
        },
        # Top Threaded Collar
        {
            "ClassName": "Part",
            "Id": "pipeTopCollar",
            "Name": "TopCollar",
            "Properties": {
                "Size": [0.56, 0.4, 0.56],
                "CFrame": [0, 1.7, 0],
                "Material": "Metal",
                "Color": "#71767C",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "meshTopCollar",
                    "Name": "CylinderMesh"
                }
            ]
        },
        # Bottom Threaded Collar
        {
            "ClassName": "Part",
            "Id": "pipeBottomCollar",
            "Name": "BottomCollar",
            "Properties": {
                "Size": [0.56, 0.4, 0.56],
                "CFrame": [0, -1.7, 0],
                "Material": "Metal",
                "Color": "#71767C",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "meshBottomCollar",
                    "Name": "CylinderMesh"
                }
            ]
        },
        # Textured Center Grip
        {
            "ClassName": "Part",
            "Id": "pipeGripWrap",
            "Name": "GripWrap",
            "Properties": {
                "Size": [0.48, 1.2, 0.48],
                "CFrame": [0, -0.3, 0],
                "Material": "Fabric",
                "Color": "#222326",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "meshGripWrap",
                    "Name": "CylinderMesh"
                }
            ]
        },
        # Weld Constraints connecting everything to Handle
        {
            "ClassName": "WeldConstraint",
            "Id": "weldTopCollar",
            "Name": "WeldTopCollar",
            "Properties": {
                "Part0": {"$ref": "pipeHandle"},
                "Part1": {"$ref": "pipeTopCollar"}
            }
        },
        {
            "ClassName": "WeldConstraint",
            "Id": "weldBottomCollar",
            "Name": "WeldBottomCollar",
            "Properties": {
                "Part0": {"$ref": "pipeHandle"},
                "Part1": {"$ref": "pipeBottomCollar"}
            }
        },
        {
            "ClassName": "WeldConstraint",
            "Id": "weldGripWrap",
            "Name": "WeldGripWrap",
            "Properties": {
                "Part0": {"$ref": "pipeHandle"},
                "Part1": {"$ref": "pipeGripWrap"}
            }
        }
    ]

    doc = {
        "ClassName": "Model",
        "Id": "metalPipeModel",
        "Name": "MetalPipe",
        "Properties": {
            "PrimaryPart": {
                "$ref": "pipeHandle"
            }
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminTools"
        },
        "Tags": ["JSON23D", "AdminTool"],
        "Children": children
    }

    with open("Json2Schemas/3D/MetalPipe.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("MetalPipe.json generated with CylinderMesh presentation.")


# ==========================================
# 4. BUILD ANIMATIONS (JSON2ANIM R15 & R6 - STRICT COMPLIANCE)
# ==========================================
def build_animations():
    r15_anim = {
        "ClassName": "KeyframeSequence",
        "Id": "pipeSwingR15",
        "Name": "MetalPipeSwing_R15",
        "Properties": {
            "Loop": False,
            "Priority": "Action"
        },
        "Children": [
            # 0.0s: Windup
            {
                "ClassName": "Keyframe",
                "Id": "r15_kf1",
                "Name": "Windup",
                "Properties": {"Time": 0.0},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "r15_w_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [5, -25, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r15_w_head",
                                "Name": "Head",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [0, 20, 0]}
                                }
                            },
                            {
                                "ClassName": "Pose",
                                "Id": "r15_w_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-60, 25, 55]},
                                    "EasingStyle": "Cubic",
                                    "EasingDirection": "Out"
                                },
                                "Children": [
                                    {
                                        "ClassName": "Pose",
                                        "Id": "r15_w_r_lower",
                                        "Name": "RightLowerArm",
                                        "Properties": {
                                            "CFrame": {"$type": "CFrame", "Orientation": [55, 0, 0]}
                                        },
                                        "Children": [
                                            {
                                                "ClassName": "Pose",
                                                "Id": "r15_w_r_hand",
                                                "Name": "RightHand",
                                                "Properties": {
                                                    "CFrame": {"$type": "CFrame", "Orientation": [-15, 0, 0]}
                                                }
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            # 0.16s: Strike / Impact
            {
                "ClassName": "Keyframe",
                "Id": "r15_kf2",
                "Name": "Impact",
                "Properties": {"Time": 0.16},
                "Children": [
                    {
                        "ClassName": "KeyframeMarker",
                        "Id": "r15_marker_hit",
                        "Name": "Hit",
                        "Properties": {"Value": "Impact"}
                    },
                    {
                        "ClassName": "Pose",
                        "Id": "r15_i_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [18, 20, -5]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r15_i_head",
                                "Name": "Head",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-10, -15, 0]}
                                }
                            },
                            {
                                "ClassName": "Pose",
                                "Id": "r15_i_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [70, -30, -20]},
                                    "EasingStyle": "Bounce",
                                    "EasingDirection": "Out"
                                },
                                "Children": [
                                    {
                                        "ClassName": "Pose",
                                        "Id": "r15_i_r_lower",
                                        "Name": "RightLowerArm",
                                        "Properties": {
                                            "CFrame": {"$type": "CFrame", "Orientation": [20, 0, 0]}
                                        },
                                        "Children": [
                                            {
                                                "ClassName": "Pose",
                                                "Id": "r15_i_r_hand",
                                                "Name": "RightHand",
                                                "Properties": {
                                                    "CFrame": {"$type": "CFrame", "Orientation": [30, 0, 0]}
                                                }
                                            }
                                        ]
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            # 0.40s: Recovery
            {
                "ClassName": "Keyframe",
                "Id": "r15_kf3",
                "Name": "Recovery",
                "Properties": {"Time": 0.40},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "r15_rec_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "InOut"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r15_rec_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]}
                                }
                            }
                        ]
                    }
                ]
            }
        ]
    }

    r6_anim = {
        "ClassName": "KeyframeSequence",
        "Id": "pipeSwingR6",
        "Name": "MetalPipeSwing_R6",
        "Properties": {
            "Loop": False,
            "Priority": "Action"
        },
        "Children": [
            # 0.0s: Windup
            {
                "ClassName": "Keyframe",
                "Id": "r6_kf1",
                "Name": "Windup",
                "Properties": {"Time": 0.0},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "r6_w_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [0, -20, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r6_w_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-80, 20, 45]},
                                    "EasingStyle": "Cubic",
                                    "EasingDirection": "Out"
                                }
                            }
                        ]
                    }
                ]
            },
            # 0.16s: Strike
            {
                "ClassName": "Keyframe",
                "Id": "r6_kf2",
                "Name": "Impact",
                "Properties": {"Time": 0.16},
                "Children": [
                    {
                        "ClassName": "KeyframeMarker",
                        "Id": "r6_marker_hit",
                        "Name": "Hit",
                        "Properties": {"Value": "Impact"}
                    },
                    {
                        "ClassName": "Pose",
                        "Id": "r6_i_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [15, 18, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r6_i_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [85, -20, -15]},
                                    "EasingStyle": "Bounce",
                                    "EasingDirection": "Out"
                                }
                            }
                        ]
                    }
                ]
            },
            # 0.40s: Return
            {
                "ClassName": "Keyframe",
                "Id": "r6_kf3",
                "Name": "Recovery",
                "Properties": {"Time": 0.40},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "r6_rec_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "InOut"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "r6_rec_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]}
                                }
                            }
                        ]
                    }
                ]
            }
        ]
    }

    # Ban Hammer animations
    hammer_r15 = {
        "ClassName": "KeyframeSequence",
        "Id": "hammerSwingR15",
        "Name": "BanHammerSwing_R15",
        "Properties": {"Loop": False, "Priority": "Action"},
        "Children": [
            {
                "ClassName": "Keyframe",
                "Id": "h_r15_kf1",
                "Name": "Windup",
                "Properties": {"Time": 0.0},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r15_w_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [15, -20, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r15_w_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-95, -15, 25]},
                                    "EasingStyle": "Cubic",
                                    "EasingDirection": "Out"
                                },
                                "Children": [
                                    {
                                        "ClassName": "Pose",
                                        "Id": "h_r15_w_r_lower",
                                        "Name": "RightLowerArm",
                                        "Properties": {
                                            "CFrame": {"$type": "CFrame", "Orientation": [-55, 0, 0]}
                                        }
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            {
                "ClassName": "Keyframe",
                "Id": "h_r15_kf2",
                "Name": "Slam",
                "Properties": {"Time": 0.22},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r15_s_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [-30, 15, 0]},
                            "EasingStyle": "Bounce",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r15_s_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-85, 20, -10]},
                                    "EasingStyle": "Bounce",
                                    "EasingDirection": "Out"
                                },
                                "Children": [
                                    {
                                        "ClassName": "Pose",
                                        "Id": "h_r15_s_r_lower",
                                        "Name": "RightLowerArm",
                                        "Properties": {
                                            "CFrame": {"$type": "CFrame", "Orientation": [-10, 0, 0]}
                                        }
                                    }
                                ]
                            }
                        ]
                    }
                ]
            },
            {
                "ClassName": "Keyframe",
                "Id": "h_r15_kf3",
                "Name": "Recovery",
                "Properties": {"Time": 0.50},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r15_rec_torso",
                        "Name": "UpperTorso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "InOut"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r15_rec_r_upper",
                                "Name": "RightUpperArm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]}
                                },
                                "Children": [
                                    {
                                        "ClassName": "Pose",
                                        "Id": "h_r15_rec_r_lower",
                                        "Name": "RightLowerArm",
                                        "Properties": {
                                            "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]}
                                        }
                                    }
                                ]
                            }
                        ]
                    }
                ]
            }
        ]
    }

    hammer_r6 = {
        "ClassName": "KeyframeSequence",
        "Id": "hammerSwingR6",
        "Name": "BanHammerSwing_R6",
        "Properties": {"Loop": False, "Priority": "Action"},
        "Children": [
            {
                "ClassName": "Keyframe",
                "Id": "h_r6_kf1",
                "Name": "Windup",
                "Properties": {"Time": 0.0},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r6_w_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [10, -15, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r6_w_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [105, 0, 20]}
                                }
                            }
                        ]
                    }
                ]
            },
            {
                "ClassName": "Keyframe",
                "Id": "h_r6_kf2",
                "Name": "Slam",
                "Properties": {"Time": 0.22},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r6_s_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [-25, 10, 0]},
                            "EasingStyle": "Bounce",
                            "EasingDirection": "Out"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r6_s_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [-115, 0, -15]}
                                }
                            }
                        ]
                    }
                ]
            },
            {
                "ClassName": "Keyframe",
                "Id": "h_r6_kf3",
                "Name": "Recovery",
                "Properties": {"Time": 0.50},
                "Children": [
                    {
                        "ClassName": "Pose",
                        "Id": "h_r6_rec_torso",
                        "Name": "Torso",
                        "Properties": {
                            "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]},
                            "EasingStyle": "Cubic",
                            "EasingDirection": "InOut"
                        },
                        "Children": [
                            {
                                "ClassName": "Pose",
                                "Id": "h_r6_rec_arm",
                                "Name": "Right Arm",
                                "Properties": {
                                    "CFrame": {"$type": "CFrame", "Orientation": [0, 0, 0]}
                                }
                            }
                        ]
                    }
                ]
            }
        ]
    }

    with open("Json2Schemas/Anim/MetalPipeSwing_R15.json", "w", encoding="utf-8") as f:
        json.dump(r15_anim, f, indent=2)
    with open("Json2Schemas/Anim/MetalPipeSwing_R6.json", "w", encoding="utf-8") as f:
        json.dump(r6_anim, f, indent=2)
    with open("Json2Schemas/Anim/BanHammerSwing_R15.json", "w", encoding="utf-8") as f:
        json.dump(hammer_r15, f, indent=2)
    with open("Json2Schemas/Anim/BanHammerSwing_R6.json", "w", encoding="utf-8") as f:
        json.dump(hammer_r6, f, indent=2)

    # Master bundle for animations (WITHOUT unsupported AssetPolicy field!)
    anim_bundle = {
        "Roots": [r15_anim, r6_anim, hammer_r15, hammer_r6],
        "Options": {
            "SelectGenerated": True,
            "GenerationLabel": "JSON2Anim: Generate Admin Animations"
        }
    }
    with open("Json2Schemas/AdminAnimations.json", "w", encoding="utf-8") as f:
        json.dump(anim_bundle, f, indent=2)

    print("Animations generated with strict JSON2Anim options.")


# ==========================================
# 5. BUILD BAN HAMMER (MASSIVE DWARVEN / TECH WARHAMMER)
# ==========================================
def build_ban_hammer():
    children = [
        {
            "ClassName": "Part",
            "Id": "hammerHandle",
            "Name": "Handle",
            "Properties": {
                "Size": [0.45, 4.2, 0.45],
                "CFrame": [0, 0, 0],
                "Material": "Metal",
                "Color": "#1E293B",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "hammerHandleMesh",
                    "Name": "HandleMesh"
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "hammerHead",
            "Name": "HammerHead",
            "Properties": {
                "Size": [1.8, 1.4, 2.6],
                "CFrame": [0, 1.8, 0],
                "Material": "DiamondPlate",
                "Color": "#0F172A",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "strikeFace1",
            "Name": "StrikeFaceFront",
            "Properties": {
                "Size": [1.6, 1.2, 0.2],
                "CFrame": [0, 1.8, 1.35],
                "Material": "Neon",
                "Color": "#EF4444",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "strikeFace2",
            "Name": "StrikeFaceBack",
            "Properties": {
                "Size": [1.6, 1.2, 0.2],
                "CFrame": [0, 1.8, -1.35],
                "Material": "Neon",
                "Color": "#EF4444",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "thunderGem",
            "Name": "ThunderGem",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.75, 0.75, 0.75],
                "CFrame": [0, 1.8, 0],
                "Material": "Neon",
                "Color": "#F59E0B",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "PointLight",
                    "Id": "hammerLight",
                    "Name": "ThunderAura",
                    "Properties": {
                        "Brightness": 3,
                        "Range": 14,
                        "Color": "#F59E0B"
                    }
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "hammerPommel",
            "Name": "Pommel",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.65, 0.65, 0.65],
                "CFrame": [0, -2.1, 0],
                "Material": "Metal",
                "Color": "#F59E0B",
                "Anchored": False,
                "CanCollide": False
            }
        }
    ]

    # Welds linking all parts to Handle
    for part in children[1:]:
        children.append({
            "ClassName": "WeldConstraint",
            "Id": f"weld_{part['Id']}",
            "Name": f"Weld_{part['Name']}",
            "Properties": {
                "Part0": {"$ref": "hammerHandle"},
                "Part1": {"$ref": part["Id"]}
            }
        })

    doc = {
        "ClassName": "Model",
        "Id": "banHammerModel",
        "Name": "BanHammer",
        "Properties": {
            "PrimaryPart": {"$ref": "hammerHandle"}
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/BanHammer.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("BanHammer.json generated successfully.")


# ==========================================
# 6. BUILD GRAVITY GUN (ZERO-POINT ENERGY MANIPULATOR)
# ==========================================
def build_gravity_gun():
    children = [
        {
            "ClassName": "Part",
            "Id": "gravHandle",
            "Name": "Handle",
            "Properties": {
                "Size": [0.65, 0.8, 2.4],
                "CFrame": [0, 0, 0],
                "Material": "Metal",
                "Color": "#334155",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "energyChamber",
            "Name": "EnergyChamber",
            "Properties": {
                "Size": [0.75, 0.75, 0.9],
                "CFrame": [0, 0.2, 0.2],
                "Material": "Glass",
                "Color": "#06B6D4",
                "Transparency": 0.35,
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "plasmaCore",
            "Name": "PlasmaCore",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.5, 0.5, 0.5],
                "CFrame": [0, 0.2, 0.2],
                "Material": "Neon",
                "Color": "#38BDF8",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "PointLight",
                    "Id": "gravLight",
                    "Name": "PlasmaLight",
                    "Properties": {
                        "Brightness": 3,
                        "Range": 12,
                        "Color": "#06B6D4"
                    }
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "muzzleRing",
            "Name": "MuzzleRing",
            "Properties": {
                "Size": [0.85, 0.85, 0.25],
                "CFrame": [0, 0.15, -1.3],
                "Material": "Metal",
                "Color": "#1E293B",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "clawTop",
            "Name": "ClawTop",
            "Properties": {
                "Size": [0.18, 0.35, 1.0],
                "CFrame": [0, 0.75, -1.8],
                "Material": "Metal",
                "Color": "#F59E0B",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "clawRight",
            "Name": "ClawRight",
            "Properties": {
                "Size": [0.18, 0.35, 1.0],
                "CFrame": [0.55, -0.35, -1.8],
                "Material": "Metal",
                "Color": "#F59E0B",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "clawLeft",
            "Name": "ClawLeft",
            "Properties": {
                "Size": [0.18, 0.35, 1.0],
                "CFrame": [-0.55, -0.35, -1.8],
                "Material": "Metal",
                "Color": "#F59E0B",
                "Anchored": False,
                "CanCollide": False
            }
        }
    ]

    for part in children[1:]:
        children.append({
            "ClassName": "WeldConstraint",
            "Id": f"weld_{part['Id']}",
            "Name": f"Weld_{part['Name']}",
            "Properties": {
                "Part0": {"$ref": "gravHandle"},
                "Part1": {"$ref": part["Id"]}
            }
        })

    doc = {
        "ClassName": "Model",
        "Id": "gravityGunModel",
        "Name": "GravityGun",
        "Properties": {
            "PrimaryPart": {"$ref": "gravHandle"}
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/GravityGun.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("GravityGun.json generated successfully.")


# ==========================================
# 7. BUILD FREEZE RAY (GLACIAL CRYO-WAND)
# ==========================================
def build_freeze_ray():
    children = [
        {
            "ClassName": "Part",
            "Id": "freezeHandle",
            "Name": "Handle",
            "Properties": {
                "Size": [0.4, 3.4, 0.4],
                "CFrame": [0, 0, 0],
                "Material": "Glass",
                "Color": "#E0F2FE",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "CylinderMesh",
                    "Id": "freezeHandleMesh",
                    "Name": "HandleMesh"
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "frostEmitter",
            "Name": "FrostEmitter",
            "Properties": {
                "Size": [1.1, 1.3, 1.1],
                "CFrame": [0, 1.8, 0],
                "Material": "Ice",
                "Color": "#38BDF8",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "glacialStar",
            "Name": "GlacialStar",
            "Properties": {
                "Shape": "Ball",
                "Size": [0.65, 0.65, 0.65],
                "CFrame": [0, 1.8, 0],
                "Material": "Neon",
                "Color": "#BAE6FD",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "PointLight",
                    "Id": "freezeLight",
                    "Name": "FrostLight",
                    "Properties": {
                        "Brightness": 2.5,
                        "Range": 12,
                        "Color": "#BAE6FD"
                    }
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "frostShard1",
            "Name": "FrostShard1",
            "Properties": {
                "Size": [0.25, 0.65, 0.25],
                "CFrame": [0.85, 1.8, 0],
                "Material": "Ice",
                "Color": "#E0F2FE",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "frostShard2",
            "Name": "FrostShard2",
            "Properties": {
                "Size": [0.25, 0.65, 0.25],
                "CFrame": [-0.85, 1.8, 0],
                "Material": "Ice",
                "Color": "#E0F2FE",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "frostShard3",
            "Name": "FrostShard3",
            "Properties": {
                "Size": [0.25, 0.65, 0.25],
                "CFrame": [0, 1.8, 0.85],
                "Material": "Ice",
                "Color": "#E0F2FE",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "frostShard4",
            "Name": "FrostShard4",
            "Properties": {
                "Size": [0.25, 0.65, 0.25],
                "CFrame": [0, 1.8, -0.85],
                "Material": "Ice",
                "Color": "#E0F2FE",
                "Anchored": False,
                "CanCollide": False
            }
        }
    ]

    for part in children[1:]:
        children.append({
            "ClassName": "WeldConstraint",
            "Id": f"weld_{part['Id']}",
            "Name": f"Weld_{part['Name']}",
            "Properties": {
                "Part0": {"$ref": "freezeHandle"},
                "Part1": {"$ref": part["Id"]}
            }
        })

    doc = {
        "ClassName": "Model",
        "Id": "freezeRayModel",
        "Name": "FreezeRay",
        "Properties": {
            "PrimaryPart": {"$ref": "freezeHandle"}
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/FreezeRay.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("FreezeRay.json generated successfully.")


# ==========================================
# 7B. BUILD BLACK HOLE / SINGULARITY CANNON (JSON23D)
# ==========================================
def build_black_hole_cannon():
    children = [
        {
            "ClassName": "Part",
            "Id": "bhHandle",
            "Name": "Handle",
            "Properties": {
                "Size": [0.65, 0.85, 2.2],
                "CFrame": [0, 0, 0],
                "Material": "Metal",
                "Color": "#1E1B4B",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhChassis",
            "Name": "Chassis",
            "Properties": {
                "Size": [1.1, 1.2, 3.2],
                "CFrame": [0, 0.35, -0.7],
                "Material": "DiamondPlate",
                "Color": "#0F172A",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhCoreSphere",
            "Name": "SingularityCore",
            "Properties": {
                "Shape": "Ball",
                "Size": [1.3, 1.3, 1.3],
                "CFrame": [0, 0.55, -0.7],
                "Material": "Neon",
                "Color": "#9333EA",
                "Anchored": False,
                "CanCollide": False
            },
            "Children": [
                {
                    "ClassName": "PointLight",
                    "Id": "bhCoreLight",
                    "Name": "SingularityLight",
                    "Properties": {
                        "Brightness": 4.5,
                        "Range": 15,
                        "Color": "#C084FC"
                    }
                }
            ]
        },
        {
            "ClassName": "Part",
            "Id": "bhRailLeft",
            "Name": "RailLeft",
            "Properties": {
                "Size": [0.22, 0.45, 3.6],
                "CFrame": [-0.68, 0.4, -1.8],
                "Material": "Neon",
                "Color": "#A855F7",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhRailRight",
            "Name": "RailRight",
            "Properties": {
                "Size": [0.22, 0.45, 3.6],
                "CFrame": [0.68, 0.4, -1.8],
                "Material": "Neon",
                "Color": "#A855F7",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhRing1",
            "Name": "ContainmentRing1",
            "Properties": {
                "Size": [1.5, 1.5, 0.25],
                "CFrame": [0, 0.4, -2.1],
                "Material": "Metal",
                "Color": "#3B0764",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhRing2",
            "Name": "ContainmentRing2",
            "Properties": {
                "Size": [1.7, 1.7, 0.25],
                "CFrame": [0, 0.4, -3.1],
                "Material": "Neon",
                "Color": "#7E22CE",
                "Anchored": False,
                "CanCollide": False
            }
        },
        {
            "ClassName": "Part",
            "Id": "bhMuzzle",
            "Name": "ApertureMuzzle",
            "Properties": {
                "Size": [0.85, 0.85, 0.5],
                "CFrame": [0, 0.4, -3.7],
                "Material": "Neon",
                "Color": "#581C87",
                "Anchored": False,
                "CanCollide": False
            }
        }
    ]

    for part in children[1:]:
        children.append({
            "ClassName": "WeldConstraint",
            "Id": f"weld_{part['Id']}",
            "Name": f"Weld_{part['Name']}",
            "Properties": {
                "Part0": {"$ref": "bhHandle"},
                "Part1": {"$ref": part["Id"]}
            }
        })

    doc = {
        "ClassName": "Model",
        "Id": "blackHoleCannonModel",
        "Name": "BlackHoleCannon",
        "Properties": {
            "PrimaryPart": {"$ref": "bhHandle"}
        },
        "Attributes": {
            "GeneratedBy": "JSON23D",
            "SchemaVersion": 1,
            "AssetCategory": "AdminV4"
        },
        "Tags": ["JSON23D", "AdminAsset"],
        "Children": children
    }

    with open("Json2Schemas/3D/BlackHoleCannon.json", "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2)
    print("BlackHoleCannon.json generated successfully.")


# ==========================================
# 8. REBUILD MASTER 3D BUNDLE (ADMIN3DASSETS.JSON)
# ==========================================
def rebuild_3d_bundle():
    schemas = [
        "Jail.json", "Halo.json", "Horns.json", "Wings.json", 
        "Bomb.json", "MetalPipe.json", "BanHammer.json", "GravityGun.json", "FreezeRay.json",
        "BlackHoleCannon.json"
    ]
    roots = []
    for s in schemas:
        p = os.path.join("Json2Schemas/3D", s)
        with open(p, "r", encoding="utf-8") as f:
            roots.append(json.load(f))

    bundle = {
        "Roots": roots,
        "Options": {
            "SelectGenerated": True,
            "AssetPolicy": "ReferenceOnly",
            "GenerationLabel": "JSON23D: Generate Admin Assets",
            "AllowExperimental": False
        }
    }
    with open("Json2Schemas/Admin3DAssets.json", "w", encoding="utf-8") as f:
        json.dump(bundle, f, indent=2)
    print(f"Admin3DAssets.json updated with {len(roots)} 3D models.")


if __name__ == "__main__":
    build_halo()
    build_wings()
    build_metal_pipe()
    build_ban_hammer()
    build_gravity_gun()
    build_freeze_ray()
    build_black_hole_cannon()
    build_animations()
    rebuild_3d_bundle()
    print("ALL ASSETS AND ANIMATIONS COMPILED SUCCESSFULLY!")
