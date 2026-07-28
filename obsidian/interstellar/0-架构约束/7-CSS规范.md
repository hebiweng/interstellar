---
AIGC:
  ContentProducer: '001191110102MAD55U9H0F10002'
  ContentPropagator: '001191110102MAD55U9H0F10002'
  Label: '1'
  ProduceID: '786c69c6-9512-4287-9ec9-82db69e433e2'
  PropagateID: '786c69c6-9512-4287-9ec9-82db69e433e2'
  ReservedCode1: '84cd5f03-f779-462c-9409-4e7969880ae8'
  ReservedCode2: '84cd5f03-f779-462c-9409-4e7969880ae8'
---

# CSS 规范

> 样式按盘型隔离，设计变量集中管理，响应式断点统一。

---

## 文件组织

| 文件 | 内容 | 规则 |
|---|---|---|
| `styles/tokens.css` | 设计变量/令牌 | 所有颜色、字号、间距、圆角、阴影统一定义在此 |
| `styles/shared.css` | 通用布局 | 四区布局、面板通用结构、响应式断点 |
| `styles/xxx.css` | 盘型专用样式 | 只包含该盘型特有的样式 |

`globals.css` 仅保留 Next.js 全局重置和 `@import` 引入上述文件。

## 设计变量/令牌

### 必须定义为 CSS 变量的属性

```css
:root {
  /* 颜色 */
  --violet: #b9a8ff;
  --blue: #57aaf0;
  --gold: #e8b458;
  --success: #69d1b0;
  --danger: #ef8c90;

  /* 面板颜色 */
  --panel: #0c1a2b;
  --panel-2: #0f2137;
  --text: #e4e9f0;
  --muted: #8b99ae;
  --faint: #5a6a80;
  --line-soft: rgba(185, 168, 255, .12);

  /* 代码 */
  --code-bg: #0d1b2a;
  --mono: 'JetBrains Mono', monospace;

  /* 间距 */
  --gap-sm: 8px;
  --gap-md: 16px;
  --gap-lg: 24px;

  /* 圆角 */
  --radius-sm: 7px;
  --radius-md: 13px;

  /* 阴影 */
  --shadow: rgba(0, 0, 0, .35);
}
```

**规则**：
- 禁止在 CSS 中硬编码颜色值（如 `color: #b9a8ff`），必须使用变量（`color: var(--violet)`）
- 新增颜色/间距/圆角时，先在 tokens.css 中定义变量，再引用

## 响应式断点

| 断点 | 宽度 | 布局变化 |
|---|---|---|
| 桌面宽屏 | > 1500px | 三列：参数 + 轮盘 + 右侧面板 |
| 桌面标准 | 1181—1500px | 三列，参数和右侧面板变窄 |
| 平板 | 901—1180px | 两列：参数 + 轮盘，右侧面板移到底部全宽 |
| 手机 | ≤ 900px | 单列，三个区域垂直堆叠 |

**规则**：
- 只使用上述 4 个断点，不自定义中间断点
- 盘型专用样式如需微调断点行为，在盘型 CSS 文件中覆盖，不修改 shared.css 的断点定义
- 手机端（≤ 900px）一律取消 sticky 定位和固定高度，改为自然流布局

## 盘型专用样式规则

1. **选择器前缀**：盘型专用样式必须以 `.secondary-progressions-workspace`（或对应盘型 workspace class）开头，避免污染其他盘型。

2. **卡片样式**：右侧面板的卡片样式在 shared.css 中定义通用结构，盘型 CSS 只覆盖差异部分。

3. **轮盘尺寸**：轮盘面板的高度统一使用 `calc(100vh - 142px)`，在 shared.css 中定义。盘型 CSS 不覆盖此值。

4. **面板高度**：左右面板高度跟轮盘一致，超出内容用 `overflow-y: auto`。在 shared.css 中定义。

## 检查清单

- [ ] 新增 CSS 是否使用了硬编码颜色（应改用变量）
- [ ] 新增样式是否放在了正确的文件（盘型专用 vs 通用）
- [ ] 盘型专用选择器是否加了 workspace class 前缀
- [ ] 响应式断点是否只用了 4 个标准断点
- [ ] globals.css 中是否新增了盘型专用样式（应移到盘型 CSS 文件）
- [ ] 新增的设计变量是否在 tokens.css 中定义

> AI生成