import json
import os

def corner(radius=10):
    return {"ClassName": "UICorner", "Name": "C", "Properties": {"CornerRadius": [0, radius]}}

def stroke(color="#1E293B", thickness=1):
    return {"ClassName": "UIStroke", "Name": "S", "Properties": {"Color": color, "Thickness": thickness}}

def list_layout(direction="Horizontal", padding=8):
    return {"ClassName": "UIListLayout", "Name": "Layout", "Properties": {"FillDirection": direction, "Padding": [0, padding]}}

def padding(top=8, bottom=8, left=8, right=8):
    return {
        "ClassName": "UIPadding",
        "Name": "Pad",
        "Properties": {
            "PaddingTop": [0, top],
            "PaddingBottom": [0, bottom],
            "PaddingLeft": [0, left],
            "PaddingRight": [0, right]
        }
    }

# Build Remastered Admin Dashboard GUI
dashboard_gui = {
    "ClassName": "ScreenGui",
    "Name": "AdminDashboard",
    "Properties": {
        "ResetOnSpawn": False,
        "ZIndexBehavior": "Sibling",
        "DisplayOrder": 110,
        "Enabled": False
    },
    "Children": [
        {
            "ClassName": "Frame",
            "Name": "MainContainer",
            "Properties": {
                "AnchorPoint": [0.5, 0.5],
                "Position": [0.5, 0, 0.5, 0],
                "Size": [0, 840, 0, 540],
                "BackgroundColor3": "#090D16",
                "BorderSizePixel": 0
            },
            "Children": [
                corner(16),
                stroke("#38BDF8", 2),
                
                # Top Header Bar
                {
                    "ClassName": "Frame",
                    "Name": "Header",
                    "Properties": {
                        "Size": [1, 0, 0, 56],
                        "BackgroundColor3": "#0F172A",
                        "BorderSizePixel": 0
                    },
                    "Children": [
                        corner(16),
                        stroke("#1E293B", 1),
                        {
                            "ClassName": "TextLabel",
                            "Name": "GlowIcon",
                            "Properties": {
                                "Position": [0, 16, 0.5, 0],
                                "AnchorPoint": [0, 0.5],
                                "Size": [0, 32, 0, 32],
                                "BackgroundTransparency": 1,
                                "Font": "GothamBold",
                                "Text": "🛡️",
                                "TextSize": 22
                            }
                        },
                        {
                            "ClassName": "TextLabel",
                            "Name": "TitleLabel",
                            "Properties": {
                                "Position": [0, 54, 0, 10],
                                "Size": [0, 320, 0, 20],
                                "BackgroundTransparency": 1,
                                "Font": "GothamBold",
                                "Text": "ADMIN V4 EXECUTIVE COMMAND SUITE",
                                "TextColor3": "#FFFFFF",
                                "TextSize": 14,
                                "TextXAlignment": "Left"
                            }
                        },
                        {
                            "ClassName": "TextLabel",
                            "Name": "SubtitleLabel",
                            "Properties": {
                                "Position": [0, 54, 0, 30],
                                "Size": [0, 320, 0, 16],
                                "BackgroundTransparency": 1,
                                "Font": "GothamMedium",
                                "Text": "REAL-TIME MODERATION & SERVER ORCHESTRATION",
                                "TextColor3": "#38BDF8",
                                "TextSize": 10,
                                "TextXAlignment": "Left"
                            }
                        },
                        # Target Pill
                        {
                            "ClassName": "TextLabel",
                            "Name": "TargetPill",
                            "Properties": {
                                "AnchorPoint": [1, 0.5],
                                "Position": [1, -260, 0.5, 0],
                                "Size": [0, 160, 0, 28],
                                "BackgroundColor3": "#1E293B",
                                "Font": "GothamBold",
                                "Text": "🎯 None Selected",
                                "TextColor3": "#F59E0B",
                                "TextSize": 11
                            },
                            "Children": [corner(6), stroke("#D97706", 1)]
                        },
                        # FPS Pill
                        {
                            "ClassName": "TextLabel",
                            "Name": "FpsPill",
                            "Properties": {
                                "AnchorPoint": [1, 0.5],
                                "Position": [1, -165, 0.5, 0],
                                "Size": [0, 85, 0, 28],
                                "BackgroundColor3": "#0F291E",
                                "Font": "GothamBold",
                                "Text": "⚡ 60 FPS",
                                "TextColor3": "#10B981",
                                "TextSize": 11
                            },
                            "Children": [corner(6), stroke("#059669", 1)]
                        },
                        # Ping Pill
                        {
                            "ClassName": "TextLabel",
                            "Name": "PingPill",
                            "Properties": {
                                "AnchorPoint": [1, 0.5],
                                "Position": [1, -70, 0.5, 0],
                                "Size": [0, 85, 0, 28],
                                "BackgroundColor3": "#0C2B40",
                                "Font": "GothamBold",
                                "Text": "📶 32ms",
                                "TextColor3": "#38BDF8",
                                "TextSize": 11
                            },
                            "Children": [corner(6), stroke("#0284C7", 1)]
                        },
                        # Close Button
                        {
                            "ClassName": "TextButton",
                            "Name": "CloseBtn",
                            "Properties": {
                                "AnchorPoint": [1, 0.5],
                                "Position": [1, -16, 0.5, 0],
                                "Size": [0, 32, 0, 32],
                                "BackgroundColor3": "#EF4444",
                                "Font": "GothamBold",
                                "Text": "✕",
                                "TextColor3": "#FFFFFF",
                                "TextSize": 14
                            },
                            "Children": [corner(8)]
                        }
                    ]
                },

                # Tab Navigation Buttons
                {
                    "ClassName": "Frame",
                    "Name": "TabBar",
                    "Properties": {
                        "Position": [0, 16, 0, 68],
                        "Size": [1, -32, 0, 38],
                        "BackgroundTransparency": 1
                    },
                    "Children": [
                        list_layout("Horizontal", 10),
                        {
                            "ClassName": "TextButton",
                            "Name": "PlayerTabBtn",
                            "Properties": {
                                "Size": [0, 180, 1, 0],
                                "BackgroundColor3": "#2563EB",
                                "Font": "GothamBold",
                                "Text": "👥 Player Moderation",
                                "TextColor3": "#FFFFFF",
                                "TextSize": 12
                            },
                            "Children": [corner(8), stroke("#60A5FA", 1)]
                        },
                        {
                            "ClassName": "TextButton",
                            "Name": "HealthTabBtn",
                            "Properties": {
                                "Size": [0, 180, 1, 0],
                                "BackgroundColor3": "#111827",
                                "Font": "GothamBold",
                                "Text": "📊 Server Telemetry",
                                "TextColor3": "#94A3B8",
                                "TextSize": 12
                            },
                            "Children": [corner(8), stroke("#1E293B", 1)]
                        },
                        {
                            "ClassName": "TextButton",
                            "Name": "WorldTabBtn",
                            "Properties": {
                                "Size": [0, 180, 1, 0],
                                "BackgroundColor3": "#111827",
                                "Font": "GothamBold",
                                "Text": "🌐 World & Environment",
                                "TextColor3": "#94A3B8",
                                "TextSize": 12
                            },
                            "Children": [corner(8), stroke("#1E293B", 1)]
                        }
                    ]
                },

                # Content Area 1: Player Management
                {
                    "ClassName": "Frame",
                    "Name": "PlayerTab",
                    "Properties": {
                        "Position": [0, 16, 0, 116],
                        "Size": [1, -32, 1, -132],
                        "BackgroundTransparency": 1,
                        "Visible": True
                    },
                    "Children": [
                        # Left: Player Selection Panel
                        {
                            "ClassName": "Frame",
                            "Name": "PlayerListPanel",
                            "Properties": {
                                "Position": [0, 0, 0, 0],
                                "Size": [0, 250, 1, 0],
                                "BackgroundColor3": "#0F172A",
                                "BorderSizePixel": 0
                            },
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "PanelTitle",
                                    "Properties": {
                                        "Position": [0, 12, 0, 10],
                                        "Size": [1, -24, 0, 18],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "ONLINE PLAYERS (SELECT TARGET)",
                                        "TextColor3": "#94A3B8",
                                        "TextSize": 10,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextBox",
                                    "Name": "PlayerSearchBox",
                                    "Properties": {
                                        "Position": [0, 10, 0, 32],
                                        "Size": [1, -20, 0, 32],
                                        "BackgroundColor3": "#1E293B",
                                        "Font": "GothamMedium",
                                        "PlaceholderText": "🔍 Filter players...",
                                        "PlaceholderColor3": "#64748B",
                                        "Text": "",
                                        "TextColor3": "#FFFFFF",
                                        "TextSize": 11,
                                        "ClearTextOnFocus": False
                                    },
                                    "Children": [corner(6), stroke("#334155", 1)]
                                },
                                {
                                    "ClassName": "ScrollingFrame",
                                    "Name": "PlayerListFrame",
                                    "Properties": {
                                        "Position": [0, 10, 0, 72],
                                        "Size": [1, -20, 1, -82],
                                        "BackgroundColor3": "#0B1120",
                                        "BorderSizePixel": 0,
                                        "ScrollBarThickness": 4,
                                        "ScrollBarImageColor3": "#334155"
                                    },
                                    "Children": [
                                        corner(8),
                                        list_layout("Vertical", 6),
                                        padding(6, 6, 6, 6),
                                        # Template Button for player rows
                                        {
                                            "ClassName": "TextButton",
                                            "Name": "Template",
                                            "Properties": {
                                                "Size": [1, 0, 0, 38],
                                                "BackgroundColor3": "#1E293B",
                                                "Font": "GothamSemibold",
                                                "Text": "",
                                                "TextColor3": "#F8FAFC",
                                                "TextSize": 12,
                                                "Visible": False,
                                                "AutoButtonColor": True
                                            },
                                            "Children": [
                                                corner(6),
                                                stroke("#334155", 1),
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "PlayerName",
                                                    "Properties": {
                                                        "Position": [0, 10, 0, 0],
                                                        "Size": [1, -30, 1, 0],
                                                        "BackgroundTransparency": 1,
                                                        "Font": "GothamMedium",
                                                        "Text": "PlayerName (@User)",
                                                        "TextColor3": "#F8FAFC",
                                                        "TextSize": 11,
                                                        "TextXAlignment": "Left"
                                                    }
                                                },
                                                {
                                                    "ClassName": "Frame",
                                                    "Name": "OnlineDot",
                                                    "Properties": {
                                                        "AnchorPoint": [0.5, 0.5],
                                                        "Position": [1, -16, 0.5, 0],
                                                        "Size": [0, 8, 0, 8],
                                                        "BackgroundColor3": "#10B981",
                                                        "BorderSizePixel": 0
                                                    },
                                                    "Children": [corner(4)]
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },

                        # Right: Target Hub & Action Panel
                        {
                            "ClassName": "Frame",
                            "Name": "ActionPanel",
                            "Properties": {
                                "Position": [0, 262, 0, 0],
                                "Size": [1, -262, 1, 0],
                                "BackgroundColor3": "#0F172A",
                                "BorderSizePixel": 0
                            },
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),

                                # Target Header with Live Status Badges
                                {
                                    "ClassName": "Frame",
                                    "Name": "TargetHeader",
                                    "Properties": {
                                        "Position": [0, 14, 0, 10],
                                        "Size": [1, -28, 0, 42],
                                        "BackgroundColor3": "#1E293B",
                                        "BorderSizePixel": 0
                                    },
                                    "Children": [
                                        corner(8),
                                        stroke("#334155", 1),
                                        {
                                            "ClassName": "TextLabel",
                                            "Name": "SelectedTargetLabel",
                                            "Properties": {
                                                "Position": [0, 12, 0, 0],
                                                "Size": [0, 220, 1, 0],
                                                "BackgroundTransparency": 1,
                                                "Font": "GothamBold",
                                                "Text": "Target: [Select a Player]",
                                                "TextColor3": "#38BDF8",
                                                "TextSize": 13,
                                                "TextXAlignment": "Left"
                                            }
                                        },
                                        # Badges Row for Active Statuses
                                        {
                                            "ClassName": "Frame",
                                            "Name": "BadgesRow",
                                            "Properties": {
                                                "AnchorPoint": [1, 0.5],
                                                "Position": [1, -10, 0.5, 0],
                                                "Size": [0, 280, 0, 24],
                                                "BackgroundTransparency": 1
                                            },
                                            "Children": [
                                                list_layout("Horizontal", 6),
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "FreezeBadge",
                                                    "Properties": {
                                                        "Size": [0, 56, 1, 0],
                                                        "BackgroundColor3": "#0284C7",
                                                        "Font": "GothamBold",
                                                        "Text": "FROZEN",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 9,
                                                        "Visible": False
                                                    },
                                                    "Children": [corner(4)]
                                                },
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "JailBadge",
                                                    "Properties": {
                                                        "Size": [0, 52, 1, 0],
                                                        "BackgroundColor3": "#D97706",
                                                        "Font": "GothamBold",
                                                        "Text": "JAILED",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 9,
                                                        "Visible": False
                                                    },
                                                    "Children": [corner(4)]
                                                },
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "MuteBadge",
                                                    "Properties": {
                                                        "Size": [0, 52, 1, 0],
                                                        "BackgroundColor3": "#DC2626",
                                                        "Font": "GothamBold",
                                                        "Text": "MUTED",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 9,
                                                        "Visible": False
                                                    },
                                                    "Children": [corner(4)]
                                                },
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "BlindBadge",
                                                    "Properties": {
                                                        "Size": [0, 52, 1, 0],
                                                        "BackgroundColor3": "#7C3AED",
                                                        "Font": "GothamBold",
                                                        "Text": "BLIND",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 9,
                                                        "Visible": False
                                                    },
                                                    "Children": [corner(4)]
                                                },
                                                {
                                                    "ClassName": "TextLabel",
                                                    "Name": "GodBadge",
                                                    "Properties": {
                                                        "Size": [0, 44, 1, 0],
                                                        "BackgroundColor3": "#059669",
                                                        "Font": "GothamBold",
                                                        "Text": "GOD",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 9,
                                                        "Visible": False
                                                    },
                                                    "Children": [corner(4)]
                                                }
                                            ]
                                        }
                                    ]
                                },

                                # Card 1: Interactive Moderation Toggles (Undo-Ready)
                                {
                                    "ClassName": "Frame",
                                    "Name": "TogglesCard",
                                    "Properties": {
                                        "Position": [0, 14, 0, 58],
                                        "Size": [1, -28, 0, 142],
                                        "BackgroundColor3": "#0B1120",
                                        "BorderSizePixel": 0
                                    },
                                    "Children": [
                                        corner(10),
                                        stroke("#1E293B", 1),
                                        {
                                            "ClassName": "TextLabel",
                                            "Name": "Title",
                                            "Properties": {
                                                "Position": [0, 12, 0, 8],
                                                "Size": [1, -24, 0, 16],
                                                "BackgroundTransparency": 1,
                                                "Font": "GothamBold",
                                                "Text": "MODERATION TOGGLES (CLICK TO TOGGLE ON / UNDO OFF)",
                                                "TextColor3": "#94A3B8",
                                                "TextSize": 10,
                                                "TextXAlignment": "Left"
                                            }
                                        },
                                        {
                                            "ClassName": "Frame",
                                            "Name": "TogglesGrid",
                                            "Properties": {
                                                "Position": [0, 12, 0, 28],
                                                "Size": [1, -24, 0, 104],
                                                "BackgroundTransparency": 1
                                            },
                                            "Children": [
                                                {
                                                    "ClassName": "UIGridLayout",
                                                    "Name": "Grid",
                                                    "Properties": {
                                                        "CellSize": [0, 160, 0, 46],
                                                        "CellPadding": [0, 8, 0, 8]
                                                    }
                                                },
                                                # Toggle 1: Freeze
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "FreezeToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "🧊 Freeze: OFF",
                                                        "TextColor3": "#38BDF8",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#0284C7", 1)]
                                                },
                                                # Toggle 2: Jail
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "JailToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "⛓️ Jail: OFF",
                                                        "TextColor3": "#F59E0B",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#D97706", 1)]
                                                },
                                                # Toggle 3: Mute
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "MuteToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "🔇 Mute: OFF",
                                                        "TextColor3": "#EF4444",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#DC2626", 1)]
                                                },
                                                # Toggle 4: Blind
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "BlindToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "🙈 Blind: OFF",
                                                        "TextColor3": "#C084FC",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#7C3AED", 1)]
                                                },
                                                # Toggle 5: Godmode
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GodToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "🛡️ Godmode: OFF",
                                                        "TextColor3": "#34D399",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#059669", 1)]
                                                },
                                                # Toggle 6: Spectate
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "SpectateToggleBtn",
                                                    "Properties": {
                                                        "BackgroundColor3": "#1E293B",
                                                        "Font": "GothamBold",
                                                        "Text": "🎥 Spectate: OFF",
                                                        "TextColor3": "#06B6D4",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6), stroke("#0891B2", 1)]
                                                }
                                            ]
                                        }
                                    ]
                                },

                                # Card 2: Dispatch & Teleport Actions
                                {
                                    "ClassName": "Frame",
                                    "Name": "ActionsCard",
                                    "Properties": {
                                        "Position": [0, 14, 0, 208],
                                        "Size": [1, -28, 0, 78],
                                        "BackgroundColor3": "#0B1120",
                                        "BorderSizePixel": 0
                                    },
                                    "Children": [
                                        corner(10),
                                        stroke("#1E293B", 1),
                                        {
                                            "ClassName": "TextLabel",
                                            "Name": "Title",
                                            "Properties": {
                                                "Position": [0, 12, 0, 8],
                                                "Size": [1, -24, 0, 16],
                                                "BackgroundTransparency": 1,
                                                "Font": "GothamBold",
                                                "Text": "PUNISHMENT & TELEPORTATION CONTROLS",
                                                "TextColor3": "#94A3B8",
                                                "TextSize": 10,
                                                "TextXAlignment": "Left"
                                            }
                                        },
                                        {
                                            "ClassName": "Frame",
                                            "Name": "BtnRow",
                                            "Properties": {
                                                "Position": [0, 12, 0, 30],
                                                "Size": [1, -24, 0, 36],
                                                "BackgroundTransparency": 1
                                            },
                                            "Children": [
                                                list_layout("Horizontal", 8),
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "KickBtn",
                                                    "Properties": {
                                                        "Size": [0, 120, 1, 0],
                                                        "BackgroundColor3": "#DC2626",
                                                        "Font": "GothamBold",
                                                        "Text": "👢 Kick Player",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "BanToggleBtn",
                                                    "Properties": {
                                                        "Size": [0, 120, 1, 0],
                                                        "BackgroundColor3": "#991B1B",
                                                        "Font": "GothamBold",
                                                        "Text": "🔨 Ban: OFF",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "TpToBtn",
                                                    "Properties": {
                                                        "Size": [0, 120, 1, 0],
                                                        "BackgroundColor3": "#2563EB",
                                                        "Font": "GothamBold",
                                                        "Text": "📍 Teleport To",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "BringBtn",
                                                    "Properties": {
                                                        "Size": [0, 120, 1, 0],
                                                        "BackgroundColor3": "#2563EB",
                                                        "Font": "GothamBold",
                                                        "Text": "🧲 Bring Player",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 11
                                                    },
                                                    "Children": [corner(6)]
                                                }
                                            ]
                                        }
                                    ]
                                },

                                # Card 3: Weapons Arsenal Distribution
                                {
                                    "ClassName": "Frame",
                                    "Name": "WeaponsCard",
                                    "Properties": {
                                        "Position": [0, 14, 0, 294],
                                        "Size": [1, -28, 0, 78],
                                        "BackgroundColor3": "#0B1120",
                                        "BorderSizePixel": 0
                                    },
                                    "Children": [
                                        corner(10),
                                        stroke("#1E293B", 1),
                                        {
                                            "ClassName": "TextLabel",
                                            "Name": "Title",
                                            "Properties": {
                                                "Position": [0, 12, 0, 8],
                                                "Size": [1, -24, 0, 16],
                                                "BackgroundTransparency": 1,
                                                "Font": "GothamBold",
                                                "Text": "SIGNATURE WEAPONS ARSENAL DISPATCH",
                                                "TextColor3": "#94A3B8",
                                                "TextSize": 10,
                                                "TextXAlignment": "Left"
                                            }
                                        },
                                        {
                                            "ClassName": "Frame",
                                            "Name": "BtnRow",
                                            "Properties": {
                                                "Position": [0, 12, 0, 30],
                                                "Size": [1, -24, 0, 36],
                                                "BackgroundTransparency": 1
                                            },
                                            "Children": [
                                                list_layout("Horizontal", 8),
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GiveHammerBtn",
                                                    "Properties": {
                                                        "Size": [0, 92, 1, 0],
                                                        "BackgroundColor3": "#EA580C",
                                                        "Font": "GothamBold",
                                                        "Text": "⚡ Hammer",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 10
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GiveGravBtn",
                                                    "Properties": {
                                                        "Size": [0, 92, 1, 0],
                                                        "BackgroundColor3": "#0284C7",
                                                        "Font": "GothamBold",
                                                        "Text": "🌀 GravGun",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 10
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GiveFreezeBtn",
                                                    "Properties": {
                                                        "Size": [0, 92, 1, 0],
                                                        "BackgroundColor3": "#0EA5E9",
                                                        "Font": "GothamBold",
                                                        "Text": "❄️ FreezeRay",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 10
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GivePipeBtn",
                                                    "Properties": {
                                                        "Size": [0, 92, 1, 0],
                                                        "BackgroundColor3": "#0D9488",
                                                        "Font": "GothamBold",
                                                        "Text": "🔩 MetalPipe",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 10
                                                    },
                                                    "Children": [corner(6)]
                                                },
                                                {
                                                    "ClassName": "TextButton",
                                                    "Name": "GiveBlackHoleBtn",
                                                    "Properties": {
                                                        "Size": [0, 92, 1, 0],
                                                        "BackgroundColor3": "#7E22CE",
                                                        "Font": "GothamBold",
                                                        "Text": "🕳️ Singularity",
                                                        "TextColor3": "#FFF",
                                                        "TextSize": 10
                                                    },
                                                    "Children": [corner(6)]
                                                }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        }
                    ]
                },

                # Content Area 2: Server Telemetry
                {
                    "ClassName": "Frame",
                    "Name": "HealthTab",
                    "Properties": {
                        "Position": [0, 16, 0, 116],
                        "Size": [1, -32, 1, -132],
                        "BackgroundTransparency": 1,
                        "Visible": False
                    },
                    "Children": [
                        {
                            "ClassName": "UIGridLayout",
                            "Name": "HealthGrid",
                            "Properties": {
                                "CellSize": [0, 395, 0, 175],
                                "CellPadding": [0, 18, 0, 18]
                            }
                        },
                        # Card 1: FPS
                        {
                            "ClassName": "Frame",
                            "Name": "FpsCard",
                            "Properties": {"BackgroundColor3": "#0F172A", "BorderSizePixel": 0},
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "Frame",
                                    "Name": "AccentBar",
                                    "Properties": {"Size": [1, 0, 0, 4], "BackgroundColor3": "#10B981", "BorderSizePixel": 0},
                                    "Children": [corner(4)]
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 16],
                                        "Size": [1, -32, 0, 20],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "SERVER / CLIENT FRAMERATE",
                                        "TextColor3": "#94A3B8",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "FpsVal",
                                    "Properties": {
                                        "Position": [0, 16, 0, 48],
                                        "Size": [1, -32, 0, 52],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "60.0 FPS",
                                        "TextColor3": "#10B981",
                                        "TextSize": 36,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Desc",
                                    "Properties": {
                                        "Position": [0, 16, 0, 118],
                                        "Size": [1, -32, 0, 24],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamMedium",
                                        "Text": "Status: Optimal (Engine ticking at nominal 60 Hz)",
                                        "TextColor3": "#64748B",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                }
                            ]
                        },
                        # Card 2: Ping
                        {
                            "ClassName": "Frame",
                            "Name": "PingCard",
                            "Properties": {"BackgroundColor3": "#0F172A", "BorderSizePixel": 0},
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "Frame",
                                    "Name": "AccentBar",
                                    "Properties": {"Size": [1, 0, 0, 4], "BackgroundColor3": "#06B6D4", "BorderSizePixel": 0},
                                    "Children": [corner(4)]
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 16],
                                        "Size": [1, -32, 0, 20],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "NETWORK ROUND-TRIP LATENCY",
                                        "TextColor3": "#94A3B8",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "PingVal",
                                    "Properties": {
                                        "Position": [0, 16, 0, 48],
                                        "Size": [1, -32, 0, 52],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "32 ms",
                                        "TextColor3": "#06B6D4",
                                        "TextSize": 36,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Desc",
                                    "Properties": {
                                        "Position": [0, 16, 0, 118],
                                        "Size": [1, -32, 0, 24],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamMedium",
                                        "Text": "Status: Ultra-responsive packet routing",
                                        "TextColor3": "#64748B",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                }
                            ]
                        },
                        # Card 3: Memory
                        {
                            "ClassName": "Frame",
                            "Name": "MemCard",
                            "Properties": {"BackgroundColor3": "#0F172A", "BorderSizePixel": 0},
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "Frame",
                                    "Name": "AccentBar",
                                    "Properties": {"Size": [1, 0, 0, 4], "BackgroundColor3": "#F59E0B", "BorderSizePixel": 0},
                                    "Children": [corner(4)]
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 16],
                                        "Size": [1, -32, 0, 20],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "LUA VIRTUAL MACHINE MEMORY",
                                        "TextColor3": "#94A3B8",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "MemVal",
                                    "Properties": {
                                        "Position": [0, 16, 0, 48],
                                        "Size": [1, -32, 0, 52],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "135 MB",
                                        "TextColor3": "#F59E0B",
                                        "TextSize": 36,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Desc",
                                    "Properties": {
                                        "Position": [0, 16, 0, 118],
                                        "Size": [1, -32, 0, 24],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamMedium",
                                        "Text": "Status: Dynamic heap & GC healthy",
                                        "TextColor3": "#64748B",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                }
                            ]
                        },
                        # Card 4: Instances
                        {
                            "ClassName": "Frame",
                            "Name": "InstCard",
                            "Properties": {"BackgroundColor3": "#0F172A", "BorderSizePixel": 0},
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "Frame",
                                    "Name": "AccentBar",
                                    "Properties": {"Size": [1, 0, 0, 4], "BackgroundColor3": "#A855F7", "BorderSizePixel": 0},
                                    "Children": [corner(4)]
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 16],
                                        "Size": [1, -32, 0, 20],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "PHYSICS SIMULATION INSTANCES",
                                        "TextColor3": "#94A3B8",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "InstVal",
                                    "Properties": {
                                        "Position": [0, 16, 0, 48],
                                        "Size": [1, -32, 0, 52],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "2,150",
                                        "TextColor3": "#A855F7",
                                        "TextSize": 36,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Desc",
                                    "Properties": {
                                        "Position": [0, 16, 0, 118],
                                        "Size": [1, -32, 0, 24],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamMedium",
                                        "Text": "Status: Workspace rendering pipeline nominal",
                                        "TextColor3": "#64748B",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                }
                            ]
                        }
                    ]
                },

                # Content Area 3: World & Environment
                {
                    "ClassName": "Frame",
                    "Name": "WorldTab",
                    "Properties": {
                        "Position": [0, 16, 0, 116],
                        "Size": [1, -32, 1, -132],
                        "BackgroundTransparency": 1,
                        "Visible": False
                    },
                    "Children": [
                        list_layout("Vertical", 14),
                        # Time of Day Box
                        {
                            "ClassName": "Frame",
                            "Name": "TimeBox",
                            "Properties": {
                                "Size": [1, 0, 0, 84],
                                "BackgroundColor3": "#0F172A",
                                "BorderSizePixel": 0
                            },
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 10],
                                        "Size": [1, -32, 0, 18],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "LIGHTING & TIME OF DAY PRESETS",
                                        "TextColor3": "#F8FAFC",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "Frame",
                                    "Name": "BtnRow",
                                    "Properties": {
                                        "Position": [0, 16, 0, 36],
                                        "Size": [1, -32, 0, 36],
                                        "BackgroundTransparency": 1
                                    },
                                    "Children": [
                                        list_layout("Horizontal", 10),
                                        {"ClassName": "TextButton", "Name": "NoonBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "☀️ Noon (14:00)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "SunsetBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🌇 Sunset (18:00)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "MidnightBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🌙 Midnight (00:00)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "SunriseBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🌅 Sunrise (06:00)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]}
                                    ]
                                }
                            ]
                        },
                        # Gravity Box
                        {
                            "ClassName": "Frame",
                            "Name": "GravBox",
                            "Properties": {
                                "Size": [1, 0, 0, 84],
                                "BackgroundColor3": "#0F172A",
                                "BorderSizePixel": 0
                            },
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 10],
                                        "Size": [1, -32, 0, 18],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "PHYSICS GRAVITATIONAL CONSTANTS",
                                        "TextColor3": "#F8FAFC",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "Frame",
                                    "Name": "BtnRow",
                                    "Properties": {
                                        "Position": [0, 16, 0, 36],
                                        "Size": [1, -32, 0, 36],
                                        "BackgroundTransparency": 1
                                    },
                                    "Children": [
                                        list_layout("Horizontal", 10),
                                        {"ClassName": "TextButton", "Name": "NormalGravBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🌍 Earth (196.2)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "LowGravBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🌕 Moon (50.0)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "ZeroGravBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🚀 Zero-G (0.0)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "HeavyGravBtn", "Properties": {"Size": [0, 180, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "⚓ Heavy (400.0)", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]}
                                    ]
                                }
                            ]
                        },
                        # Action Box
                        {
                            "ClassName": "Frame",
                            "Name": "ActionBox",
                            "Properties": {
                                "Size": [1, 0, 0, 84],
                                "BackgroundColor3": "#0F172A",
                                "BorderSizePixel": 0
                            },
                            "Children": [
                                corner(12),
                                stroke("#1E293B", 1),
                                {
                                    "ClassName": "TextLabel",
                                    "Name": "Title",
                                    "Properties": {
                                        "Position": [0, 16, 0, 10],
                                        "Size": [1, -32, 0, 18],
                                        "BackgroundTransparency": 1,
                                        "Font": "GothamBold",
                                        "Text": "SERVER SECURITY & CLEANING ACTIONS",
                                        "TextColor3": "#F8FAFC",
                                        "TextSize": 11,
                                        "TextXAlignment": "Left"
                                    }
                                },
                                {
                                    "ClassName": "Frame",
                                    "Name": "BtnRow",
                                    "Properties": {
                                        "Position": [0, 16, 0, 36],
                                        "Size": [1, -32, 0, 36],
                                        "BackgroundTransparency": 1
                                    },
                                    "Children": [
                                        list_layout("Horizontal", 10),
                                        {"ClassName": "TextButton", "Name": "LockServerToggleBtn", "Properties": {"Size": [0, 240, 1, 0], "BackgroundColor3": "#1E293B", "Font": "GothamBold", "Text": "🔒 Server Lock: OFF", "TextColor3": "#EF4444", "TextSize": 12}, "Children": [corner(6), stroke("#DC2626", 1)]},
                                        {"ClassName": "TextButton", "Name": "ClearDebrisBtn", "Properties": {"Size": [0, 240, 1, 0], "BackgroundColor3": "#0D9488", "Font": "GothamBold", "Text": "🧹 Clear Debris & Drops", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]},
                                        {"ClassName": "TextButton", "Name": "ReloadMapBtn", "Properties": {"Size": [0, 240, 1, 0], "BackgroundColor3": "#D97706", "Font": "GothamBold", "Text": "🔄 Reload Initial Map", "TextColor3": "#F8FAFC", "TextSize": 12}, "Children": [corner(6)]}
                                    ]
                                }
                            ]
                        }
                    ]
                }
            ]
        }
    ]
}

# Write Json2Schemas/UI/AdminDashboard.json
doc = {
    "Options": {
        "SelectGenerated": False,
        "GenerationLabel": "Json2GUI: Generate Remastered AdminDashboard"
    },
    "Roots": [dashboard_gui]
}
with open("Json2Schemas/UI/AdminDashboard.json", "w", encoding="utf-8") as f:
    json.dump(doc, f, indent=2)

print("Remastered AdminDashboard.json created successfully.")

# Update Json2Schemas/AdminUiAssets.json
with open("Json2Schemas/AdminUiAssets.json", "r", encoding="utf-8") as f:
    master_ui = json.load(f)

roots = [r for r in master_ui["Roots"] if r.get("Name") != "AdminDashboard"]
roots.append(dashboard_gui)
master_ui["Roots"] = roots

with open("Json2Schemas/AdminUiAssets.json", "w", encoding="utf-8") as f:
    json.dump(master_ui, f, indent=2)

print(f"AdminUiAssets.json updated with {len(roots)} UI roots.")
