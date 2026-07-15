# 视频转人物精灵流程

## 目标

使用固定镜头的 5 秒角色视频生成游戏动作，再转换为与现有角色一致的 `128 x 128` 透明 PNG 横向精灵条。运行时只加载 PNG，不直接播放 MP4。

## 动作范围

| 动作 | 方向 | 帧数 | 播放方式 | 当前状态 |
| --- | --- | ---: | --- | --- |
| 待机 | 正面 | 16 | 3.2 FPS 往返循环 | 已接入 |
| 行走 | 前、后、侧面镜像 | 6/方向 | 10 FPS 循环 | 已有精灵条，待视频版替换 |
| 普攻 | 正面、侧面镜像 | 8 | 单次播放 | 待生成 |
| 技能 | 正面、侧面镜像 | 8 | 单次播放 | 待生成 |
| 受击 | 正面、侧面镜像 | 6 | 单次播放 | 待生成 |
| 倒地 | 正面、侧面镜像 | 8 | 单次播放并停在末帧 | 待生成 |

四方向移动继续复用左右镜像。战斗动作优先正面和侧面，避免一次生成八方向却无法稳定保持角色造型。

## 视频约束

- 固定机位、固定缩放、完整全身，不能推进、环绕、摇移或变焦。
- 角色脚底位置固定，动作只在原地完成。
- 未来视频使用纯色绿幕，无地面、投影、烟雾、文字和水印。
- 首尾姿势一致；循环动作在最后一帧前回到初始姿势。
- 每个视频只包含一个动作，角色服装、发型、武器和朝向不变化。

## 本地处理

视频解码工具依赖 OpenCV，但依赖只安装在本机工具缓存，不进入游戏仓库：

```powershell
$python = "$env:USERPROFILE\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
$videoTools = "$env:USERPROFILE\.codex\tools\video-sprite-pipeline"
& $python -m pip install --target $videoTools opencv-python-headless
$env:PYTHONPATH = $videoTools
```

以正面待机为例：

```powershell
& $python tools/video_frame_sheet.py art/characters/player/video/player_idle_loop_5s_01.mp4 tmp/video_sprite/player_idle_raw.png --frames 16 --columns 4 --ping-pong
& $python "$env:USERPROFILE\.codex\skills\.system\imagegen\scripts\remove_chroma_key.py" --input tmp/video_sprite/player_idle_raw.png --out tmp/video_sprite/player_idle_keyed.png --auto-key border --soft-matte --transparent-threshold 12 --opaque-threshold 80 --force
& $python tools/sprite_pipeline.py tmp/video_sprite/player_idle_keyed.png art/characters/player/animation/idle_front_strip.png --columns 4 --rows 4 --target-size 128 --foot-y 112 --padding 8
```

接入前必须检查透明背景、人物轮廓、落脚点、首尾跳变和游戏内实际缩放。
