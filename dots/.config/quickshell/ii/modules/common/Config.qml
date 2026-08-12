pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.modules.common.functions

Singleton {
    id: root
    property string filePath: Directories.shellConfigPath
    property alias options: configOptionsJsonAdapter
    property bool ready: false
    property int readWriteDelay: 75 // milliseconds
    property bool blockWrites: false

    function setNestedValue(nestedKey, value) {
        let keys = nestedKey.split(".");
        let obj = root.options;
        let parents = [obj];

        // Traverse and collect parent objects
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        // Convert value to correct type using JSON.parse when safe
        let convertedValue = value;
        if (typeof value === "string") {
            let trimmed = value.trim();
            if (trimmed === "true" || trimmed === "false" || !isNaN(Number(trimmed))) {
                try {
                    convertedValue = JSON.parse(trimmed);
                } catch (e) {
                    convertedValue = value;
                }
            }
        }

        obj[keys[keys.length - 1]] = convertedValue;
    }

    Timer {
        id: fileReloadTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.reload();
        }
    }

    Timer {
        id: fileWriteTimer
        interval: root.readWriteDelay
        repeat: false
        onTriggered: {
            configFileView.writeAdapter();
        }
    }

    FileView {
        id: configFileView
        path: root.filePath
        watchChanges: true
        blockWrites: root.blockWrites
        onFileChanged: fileReloadTimer.restart()
        onAdapterUpdated: fileWriteTimer.restart()
        onLoaded: root.ready = true
        onLoadFailed: error => {
            if (error == FileViewError.FileNotFound) {
                writeAdapter();
            }
        }

        JsonAdapter {
            id: configOptionsJsonAdapter

            property string panelFamily: "ii" // "ii", "waffle"

            property JsonObject policies: JsonObject {
                property int ai: 1 // 0: No | 1: Yes | 2: Local
                property int weeb: 0 // 0: No | 1: Open | 2: Closet
                property int wallpapers: 1 // 0: No | 1: Yes
                property int translator: 0 // 0: No | 1: Yes
            }

            property JsonObject extensions: JsonObject {
                property bool enable: true
            }

            property JsonObject localsend: JsonObject {
                property bool autoStart: true
                property string downloadPath: Directories.localSendDownloadPath.replace("file://", "")
                property bool showNotifications: true
            }

            property JsonObject ai: JsonObject {
                property string systemPrompt: "## Style\n- Use casual tone, don't be formal!\n- Always be brief and to the point, unless asked otherwise\n- Don't repeat the user's question\n- Be approachable: Avoid using overly complicated, domain-specific terms and provide analogies when asked to explain a concept\n\n## Context (ignore when irrelevant)\n- You are a helpful and inspiring sidebar assistant on a {DISTRO} Linux system\n- Desktop environment: {DE}\n- Current date & time: {DATETIME}\n- Focused app: {WINDOWCLASS}\n\n## Presentation\n- Use Markdown features in your response: \n  - **Bold** text to **highlight keywords** in your response\n  - **Split long information into small sections** with a relevant emoji at the start of it (for example `## 🐧 Linux`). Bullet points are preferred over long paragraphs, unless you're offering writing support or instructed otherwise by the user.\n- Asked to compare different options? You should firstly use a table to compare the main aspects, then elaborate or include relevant comments from online forums *after* the table. Make sure to provide a final recommendation for the user's use case!\n- Use LaTeX formatting for mathematical and scientific notations whenever appropriate. Enclose all LaTeX '$$' delimiters. NEVER generate LaTeX code in a latex block unless the user explicitly asks for it. DO NOT use LaTeX for regular documents (resumes, letters, essays, CVs, etc.).\n\nThanks!\n"
                property string tool: "functions" // search, functions, or none
                property list<var> models: [
                    {
                        "openrouter": [
                            {
                                title: "Gemini 2.5 Flash",
                                value: "gemini-2.5-flash",
                                modelProvider: "google"
                            },
                        ]
                    },
                    {
                        "google": []
                    }
                ]
                property list<var> otherModels: [
                    {
                        "name": "Mistral Medium",
                        "model": "mistral-medium-2505",
                        "icon": "mistral-symbolic",
                        "endpoint": "https://api.mistral.ai/v1/chat/completions",
                        "requires_key": true,
                        "key_id": "mistral",
                        "api_format": "mistral"
                    }
                ]
            }

            property JsonObject appearance: JsonObject {
                property bool extraBackgroundTint: true
                property int fakeScreenRounding: 2 // 0: None | 1: Always | 2: When not fullscreen | 3: Wrapped
                property int wrappedFrameThickness: 10
                property bool sharpMode: false
                property int defaultBorderRadius: 18
                property bool toggleWindowRounding: true
                property JsonObject fonts: JsonObject {
                    property bool enableCustom: false
                    property string main: "Google Sans Flex"
                    property string numbers: "Google Sans Flex"
                    property string title: "Google Sans Flex"
                    property string iconNerd: "JetBrains Mono NF"
                    property string monospace: "JetBrains Mono NF"
                    property string reading: "Readex Pro"
                    property string expressive: "Space Grotesk"
                }
                property JsonObject transparency: JsonObject {
                    property bool enable: false
                    property bool automatic: true
                    property real backgroundTransparency: 0.11
                    property real contentTransparency: 0.57
                }
                property JsonObject wallpaperTheming: JsonObject {
                    property bool enableAppsAndShell: true
                    property bool enableQtApps: true
                    property bool enableTerminal: true
                    property JsonObject terminalGenerationProps: JsonObject {
                        property real harmony: 0.6
                        property real harmonizeThreshold: 100
                        property real termFgBoost: 0.35
                        property bool forceDarkMode: false
                    }
                }
                property JsonObject palette: JsonObject {
                    property string type: "auto"
                    property string accentColor: ""
                }
                property list<string> customColorSchemes: []
            }

            property JsonObject audio: JsonObject {
                property JsonObject protection: JsonObject {
                    property bool enable: false
                    property real maxAllowedIncrease: 10
                    property real maxAllowed: 99
                }
            }

            property JsonObject apps: JsonObject {
                property string bluetooth: "kcmshell6 kcm_bluetooth"
                property string changePassword: "kitty -1 --hold=yes fish -i -c 'passwd'"
                property string network: "kcmshell6 kcm_networkmanagement"
                property string manageUser: "kcmshell6 kcm_users"
                property string networkEthernet: "kcmshell6 kcm_networkmanagement"
                property string taskManager: "plasma-systemmonitor --page-name Processes"
                property string terminal: "kitty -1"
                property string update: "kitty -1 --hold=yes fish -i -c 'pkexec pacman -Syu'"
                property string volumeMixer: `~/.config/hypr/hyprland/scripts/launch_first_available.sh "pavucontrol-qt" "pavucontrol"`
            }

            property JsonObject background: JsonObject {
                property bool enable: true
                property JsonObject widgets: JsonObject {
                    property JsonObject clock: JsonObject {
                        property bool enable: true
                        property bool showOnlyWhenLocked: false
                        property string placementStrategy: "leastBusy"
                        property real x: 100
                        property real y: 100
                        property string style: "cookie"
                        property string styleLocked: "cookie"
                        property JsonObject cookie: JsonObject {
                            property bool aiStyling: false
                            property string aiStylingModel: "gemini"
                            property int sides: 14
                            property string backgroundStyle: "cookie"
                            property string backgroundShape: "Arch"
                            property string dialNumberStyle: "full"
                            property string hourHandStyle: "fill"
                            property string minuteHandStyle: "medium"
                            property string secondHandStyle: "dot"
                            property string dateStyle: "bubble"
                            property bool timeIndicators: true
                            property bool hourMarks: false
                            property bool dateInClock: true
                            property bool constantlyRotate: false
                            property bool turnOffRotationOnTiledApps: false
                        }
                        property JsonObject digital: JsonObject {
                            property bool adaptiveAlignment: true
                            property bool showDate: true
                            property bool animateChange: true
                            property bool vertical: false
                            property bool colorful: false
                            property bool showColon: true
                            property JsonObject font: JsonObject {
                                property string family: "Google Sans Flex"
                                property real weight: 350
                                property real width: 100
                                property real size: 90
                                property real roundness: 0
                            }
                        }
                        property JsonObject quote: JsonObject {
                            property bool enable: false
                            property string text: ""
                        }
                    }
                    property JsonObject media: JsonObject {
                        property bool enable: true
                        property string placementStrategy: "free"
                        property real x: 800
                        property real y: 100
                        property bool useAlbumColors: true
                        property bool hideAllButtons: false
                        property bool showPreviousToggle: true
                        property bool tintArtCover: false
                        property string backgroundShape: "Circle"
                        property JsonObject glow: JsonObject {
                            property bool enable: true
                            property real brightness: 10
                        }
                        property JsonObject visualizer: JsonObject {
                            property bool enable: false
                            property real opacity: 0.15
                            property int smoothing: 2
                            property int blur: 1
                        }
                    }
                    property JsonObject weather: JsonObject {
                        property bool enable: false
                        property string placementStrategy: "free"
                        property real x: 400
                        property real y: 100
                    }
                }
                property bool animateWallpaperChanges: true
                property string transitionType: "radial"
                property int wipeAngle: 0
                property string wallpaperPath: ""
                property string thumbnailPath: ""
                property bool hideWhenFullscreen: true
                property JsonObject parallax: JsonObject {
                    property bool vertical: true
                    property bool autoVertical: false
                    property bool enableWorkspace: false
                    property real workspaceZoom: 1.07
                    property bool enableSidebar: false
                    property real widgetsFactor: 1.2
                }
                property JsonObject mediaMode: JsonObject {
                    property bool togglePerMonitor: false
                    property string backgroundShape: "Square"
                    property bool enableBackgroundAnimation: true
                    property bool changeShellColor: true
                    property int backgroundOpacity: 50
                    property int backgroundBlurRadius: 120
                    property JsonObject backgroundAnimation: JsonObject {
                        property bool enable: true
                        property int speedScale: 10
                    }
                    property JsonObject syllable: JsonObject {
                        property int textHighlightStyle: 0
                    }
                }
            }

            property JsonObject bar: JsonObject {
                property JsonObject activeWindow: JsonObject {
                    property bool fixedSize: false
                }
                property JsonObject autoHide: JsonObject {
                    property bool enable: false
                    property int hoverRegionWidth: 2
                    property bool pushWindows: false
                    property JsonObject showWhenPressingSuper: JsonObject {
                        property bool enable: true
                        property int delay: 140
                    }
                }
                property bool bottom: false
                property int cornerStyle: 0
                property bool floatStyleShadow: true
                property int barGroupStyle: 0
                property string topLeftIcon: "spark"
                property int barBackgroundStyle: 1
                property bool verbose: true
                property bool vertical: false
                property JsonObject mediaPlayer: JsonObject {
                    property bool useFixedSize: false
                    property int customSize: 250
                    property int maxSize: 400
                    property JsonObject artwork: JsonObject { property bool enable: false }
                    property JsonObject lyrics: JsonObject {
                        property bool enable: false
                        property int customSize: 400
                        property string style: "scroller"
                        property bool useGradientMask: true
                    }
                }
                property JsonObject resources: JsonObject {
                    property int memoryWarningThreshold: 95
                    property int swapWarningThreshold: 85
                    property int cpuWarningThreshold: 90
                }
                property list<string> screenList: []
                property JsonObject timers: JsonObject {
                    property bool showPomodoro: true
                    property bool showStopwatch: true
                }
                property JsonObject utilButtons: JsonObject {
                    property bool showScreenSnip: true
                    property bool showColorPicker: false
                    property bool showMicToggle: false
                    property bool showKeyboardToggle: true
                    property bool showDarkModeToggle: true
                    property bool showPerformanceProfileToggle: false
                    property bool showScreenRecord: false
                }
                property JsonObject workspaces: JsonObject {
                    property bool monochromeIcons: true
                    property int shown: 10
                    property bool showAppIcons: true
                    property bool alwaysShowNumbers: false
                    property int showNumberDelay: 300
                    property list<string> numberMap: ["1", "2"]
                    property bool useWorkspaceMap: true
                    property list<var> workspaceMap: [0, 10]
                    property int maxWindowCount: 1
                    property bool useNerdFont: false
                    property int activeIndicatorOpacity: 100
                    property bool dynamicWorkspaces: false
                }
                property JsonObject weather: JsonObject {
                    property bool enable: false
                    property bool enableGPS: true
                    property string city: ""
                    property bool useUSCS: false
                    property int fetchInterval: 10
                }
                property JsonObject indicators: JsonObject {
                    property JsonObject notifications: JsonObject {
                        property bool showUnreadCount: false
                    }
                }
            }
        }
    }
}
