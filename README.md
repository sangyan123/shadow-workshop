# 影子修理铺：Godot 原型

这是《影子修理铺》的第一个可运行灰盒原型，当前只实现 **L01 最小闭环**：

1. 看到目标影子轮廓；
2. 拖动桌面的三角物件；
3. 影子实时变化；
4. 点击「检查影子」；
5. 系统用 Precision / Recall 判断是否通过。

## 如何打开

1. 安装 Godot 4.x，建议使用设计基线中的 Godot 4.7.2 Stable。
2. 打开 Godot。
3. 选择「导入」。
4. 选择本目录中的 `project.godot`。
5. 打开项目后按 `F5` 运行。

## 当前玩法

- L01 只开放拖动；
- 灯位固定；
- 旋转按钮会自动隐藏；
- 物件拖动后会计入步数；
- 目标判定使用固定采样，而不是像素级精确拖动；
- 达到 Precision / Recall 阈值后显示通过。

## 当前结构

```text
shadow-workshop/
├── project.godot
├── scenes/
│   ├── Main.tscn
│   └── Level.tscn
├── scripts/
│   ├── Main.gd
│   └── Level.gd
├── data/
│   └── levels/
│       └── L01.json
├── assets/
│   └── targets/
└── docs/
```

## 怎么玩通 L01

把桌面上的浅色三角形拖到桌面左下方。让投影板上的深色影子尽量盖住浅色目标三角形，然后点击右下角「检查影子」。

判定标准来自 `L01.json`：

```json
{
  "precision": 0.90,
  "recall": 0.92
}
```

## 下一阶段任务

1. 在 Godot 里运行 L01，验证拖动手感；
2. 如果判定太严，调整 `win_threshold`；
3. 加入 L02：开放 30° 旋转；
4. 加入 L03：两个物件拼合；
5. 加入简单关卡选择；
6. 之后再做存档、音效和 Android 导出。
