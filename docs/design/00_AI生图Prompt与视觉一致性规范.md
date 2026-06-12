# 毛伙伴 Design 00号文档：AI 生图 Prompt 与视觉一致性规范

- 文档版本：v0.1
- 更新时间：2026-06-13
- 适用阶段：UI 设计稿生成、Logo / 图标生成、IP 形象探索、默认头像与运营视觉生成
- 关联文档：
  - `docs/html/maohuoban-ui-design.html`
  - `docs/product/prd/00_V1_PRD_产品总纲与核心流程.md`
  - `docs/product/strategy/01_主页与底部Tab产品方向.md`

---

## 1. 文档目的

这份文档提供毛伙伴所有 AI 生图任务的统一基准。

适用对象包括：

| 资产类型 | 用途 |
|---|---|
| UI 设计稿 | 首页、宠物世界、同城、消息、我的、宠物档案、发布流程 |
| Logo | App Logo、品牌符号、启动页标识 |
| 图标 | Tab 图标、功能图标、状态图标、服务图标 |
| IP 形象 | 毛伙伴品牌陪伴形象、引导页形象、空状态形象 |
| 默认头像 | 宠物默认头像、商家默认头像、医院默认头像、用户默认头像 |
| 运营视觉 | 封面图、活动图、说明图、功能概念图 |

所有生图任务优先使用本文档的母 Prompt，再根据具体资产类型追加场景模板。

---

## 2. 核心视觉方向

| 维度 | 规范 |
|---|---|
| 主体 | 宠物是画面与产品语义中心 |
| 人的角色 | 主人、家庭成员、商家、医生作为记录者、管理者、决策者出现 |
| 情绪 | 温暖、可信、克制、精致、有陪伴感 |
| 专业感 | 医疗、保险、交易相关场景保持清晰、干净、可信 |
| UI 风格 | Apple Health inspired、frosted glass、cold white-blue gray、low saturation |
| 画面密度 | 信息清晰，留白充分，层级明确 |
| 品牌记忆 | 蓝色主色、冷白背景、玻璃卡片、宠物主体、关系感 |

视觉关键词：

```text
pet-first, companion, trustworthy, clean, soft clinical, Apple Health inspired,
frosted glass, cold white-blue gray, low saturation, gentle depth,
structured pet life timeline, local trust, warm but professional
```

---

## 3. 颜色 Token

生图时必须优先使用以下颜色。需要透明度时使用同色系 alpha 变化。

| Token | Hex / Value | 用途 |
|---|---|---|
| Primary | `#4F8CFF` | 品牌主色、主按钮、选中态、核心图标 |
| Primary Light | `#6BCBFF` | 高光、轻量渐变、辅助强调 |
| Primary Dark | `#3A6FCC` | 深色强调、品牌符号阴影、可读性增强 |
| Success | `#34C759` | 健康良好、完成状态、安全提示 |
| Warning | `#FF9500` | 待处理、提醒、交易注意 |
| Danger | `#FF3B30` | 风险、异常、错误、紧急状态 |
| Teal | `#5AC8FA` | 医疗、清洁、信息辅助 |
| Purple | `#AF52DE` | 特殊状态、纪念、轻情绪点缀 |
| Background | `#F7F9FC` | 页面背景、画面主底色 |
| Card Solid | `#FFFFFF` | 卡片、弹层、信息容器 |
| Label Primary | `#1A1D26` | 主标题、关键文字 |
| Label Secondary | `#6E7681` | 次级文字、说明 |
| Label Tertiary | `#9CA3AF` | 辅助文字、弱信息 |
| Label Quaternary | `#D1D5DB` | 分割、占位、弱边框 |
| Primary Background | `rgba(79,140,255,0.08)` | 主色浅底 |
| Primary Background Soft | `rgba(79,140,255,0.04)` | 大面积柔和底 |
| Card | `rgba(255,255,255,0.75)` | 玻璃卡片 |
| Card Border | `rgba(255,255,255,0.6)` | 玻璃边框 |
| Separator | `rgba(0,0,0,0.05)` | 分割线 |
| Separator Soft | `rgba(0,0,0,0.03)` | 弱分割线 |

禁用倾向：

| 项目 | 约束 |
|---|---|
| 大面积暖棕 / 咖啡 / 米色 | 会偏离当前冷白蓝灰体系 |
| 大面积紫蓝渐变 | 容易变成通用 AI 科技感 |
| 高饱和霓虹色 | 会削弱医疗、交易和保险可信度 |
| 复杂多彩插画 | 会破坏 App 级一致性 |
| 厚重黑色背景 | 仅在明确暗色主题图中使用 |

---

## 4. 布局与材质 Token

| Token | 数值 | 生图表达 |
|---|---|---|
| Spacing | `4 / 8 / 12 / 16 / 20 / 24 / 32pt` | 4pt 栅格、紧凑但有呼吸感 |
| Radius Small | `8pt` | 小标签、工具按钮 |
| Radius Medium | `12pt` | 普通按钮、输入框 |
| Radius Large | `16pt` | 常规卡片 |
| Radius Extra Large | `20pt` | 首屏主卡 |
| Radius 2XL | `24pt` | 大卡片、宠物主视觉容器 |
| Material | frosted glass | 白色半透明卡片、柔和模糊、细边框 |
| Typography | SF Pro / PingFang SC | iOS 系统字体、清晰、现代 |

---

## 5. 通用母 Prompt

以下内容作为所有生图任务的基础 Prompt。根据任务追加第 7 章的场景模板。

```text
Create a high-end visual asset for "Maohuoban" (毛伙伴), a pet-first companion platform.

Core concept:
- The pet is the main subject of the product and the visual composition.
- Humans are caretakers, recorders, decision makers, and service participants.
- The product connects each pet's profile, life timeline, pet relationships, local services, medical records, trade evidence, and insurance coordination.

Visual style:
- Apple Health inspired iOS visual system.
- Frosted glass cards, cold white-blue gray environment, low saturation, clean hierarchy.
- Warm but professional, gentle companion feeling, trustworthy for pet healthcare, local services, trade, and insurance.
- Soft depth, subtle shadow, precise spacing, polished iOS app quality.

Use this exact color system:
- Primary blue: #4F8CFF
- Light blue: #6BCBFF
- Dark blue: #3A6FCC
- Background: #F7F9FC
- Card white: #FFFFFF
- Primary text: #1A1D26
- Secondary text: #6E7681
- Tertiary text: #9CA3AF
- Separator: rgba(0,0,0,0.05)
- Health green: #34C759
- Warning orange: #FF9500
- Danger red: #FF3B30
- Medical teal: #5AC8FA
- Special accent purple: #AF52DE

Design language:
- Rounded cards with 16-24pt radius.
- Frosted glass panels with soft white transparency.
- 4pt spacing grid.
- iOS-native interface quality.
- Clean pet portrait or pet-centered visual focus.
- No clutter, no childish toy style, no generic stock-photo feeling.
```

---

## 6. 通用负向 Prompt

```text
Avoid warm beige, brown, coffee, sand, orange-dominant palettes.
Avoid dark heavy slate interfaces unless specifically requested.
Avoid neon gradients, cyberpunk, generic AI tech glow, excessive purple-blue gradients.
Avoid childish cartoon toy style, cheap mascot style, random paw-print overload.
Avoid generic stock photos, blurry pets, unreadable text, fake UI clutter.
Avoid complex decorative background blobs or floating gradient orbs.
Avoid overly cute baby-like expression for medical, trade, insurance, or trust scenes.
Avoid brand colors outside the specified Maohuoban color tokens.
```

---

## 7. 场景模板

### 7.1 首页 UI 设计稿

```text
Generate an iPhone app home screen UI for Maohuoban.

Scene:
- Current pet home as the first screen.
- The main pet card is the largest visual focus.
- Show today's care status: appetite, energy, stool, weight, vaccine or deworming reminder.
- Include quick actions: record daily event, health record, book hospital, import trade pet.
- Include a "today's companion" relationship card: littermate, same city, same disease, same hospital, or same source.
- Include 2-3 recent timeline events.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Apple Health inspired, frosted glass, cold white-blue gray, low saturation.
- Use pet photo or clean pet portrait as the first visual signal.
- Keep text minimal and legible. Use Chinese UI labels only if they can be rendered cleanly.

Format:
- iPhone 17 Pro vertical screen.
- 9:19.5 aspect ratio.
- High fidelity UI mockup, no device frame unless requested.
```

### 7.2 宠物世界 UI 设计稿

```text
Generate an iPhone app feed screen for Maohuoban's Pet World.

Scene:
- A pet-centered event feed, where each card belongs to a pet, not a human influencer.
- Cards show pet avatar, pet name, breed, age stage, city, event content, relation explanation, topic tags.
- Recommendation reasons should feel pet-based: same litter, same city, same age, same disease, same hospital, same source.
- Include interaction actions: like, comment, follow pet, save.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Clean iOS feed layout, structured cards, frosted glass surfaces, soft shadows.
- The pet identity must be visually stronger than the human account identity.

Format:
- iPhone vertical screen.
- High fidelity UI mockup.
```

### 7.3 同城 UI 设计稿

```text
Generate an iPhone app local city services screen for Maohuoban.

Scene:
- Local trust boundary for pet hospitals, catteries, kennels, pet stores, trade, and services.
- Include city selector, search, nearby verified hospitals, verified catteries or kennels, transparent care packages, consultation or appointment entry.
- Local entities should look trustworthy, verified, and easy to compare.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Professional, clean, service-oriented, local trust feeling.
- Use medical teal #5AC8FA for hospital-related details, primary blue #4F8CFF for core actions, warning orange #FF9500 only for reminders.

Format:
- iPhone vertical screen.
- High fidelity UI mockup.
```

### 7.4 Logo / App Icon

```text
Create an app icon and logo concept for Maohuoban (毛伙伴).

Concept:
- Pet-first companion platform.
- The symbol should suggest pet companionship, pet relationship network, and trustworthy lifelong pet profile.
- Suitable for iOS app icon and small-size recognition.

Style:
- Use primary blue #4F8CFF as the main brand color.
- Use light blue #6BCBFF as highlight and dark blue #3A6FCC for depth.
- Background may use #F7F9FC or a clean blue gradient based only on #4F8CFF, #6BCBFF, #3A6FCC.
- Rounded, simple, memorable, premium iOS app icon quality.
- Minimal geometry, clear silhouette, no complex text.

Format:
- Square 1:1.
- Centered symbol.
- Safe margin for iOS rounded corners.
- Provide a clean icon concept with no mockup background.
```

### 7.5 IP 形象

```text
Create a mascot / IP character for Maohuoban.

Character concept:
- A gentle pet companion spirit representing "毛伙伴".
- It should feel caring, smart, trustworthy, and calm.
- It can combine soft pet features with a clean digital companion feeling.
- Suitable for onboarding, empty states, care reminders, and friendly system guidance.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Rounded shapes, soft fur feeling, clean silhouette.
- Friendly expression, warm but professional.
- Avoid overly childish cartoon toy style.
- Avoid complex clothing, busy props, random paw-print decoration.

Format:
- Transparent or clean #F7F9FC background.
- Full body and bust variations are acceptable.
- 1:1 or 4:5 aspect ratio.
```

### 7.6 默认宠物头像

```text
Create default pet avatar illustrations for Maohuoban.

Scene:
- Clean avatar set for cats and dogs.
- The avatar should work before users upload a real pet photo.
- Include variants for cat, dog, unknown pet, and memorial pet if requested.

Style:
- Use primary blue #4F8CFF and soft background #F7F9FC.
- Rounded, simple, calm, clean iOS avatar quality.
- Minimal facial features, clear silhouette, friendly but not childish.
- Frosted glass or soft circular background.

Format:
- Square 1:1.
- Centered head portrait.
- Safe crop for circular avatar.
- No text.
```

### 7.7 功能图标

```text
Create a consistent icon set for Maohuoban.

Icon set:
- Home, Pet World, City, Messages, Mine.
- Record event, health record, book hospital, import trade pet.
- Appetite, energy, stool, weight, vaccine, deworming, revisit.

Style:
- iOS outline icon style.
- 1.5-2pt stroke feeling.
- Rounded stroke caps and joins.
- Use #4F8CFF for active icons, #9CA3AF for inactive icons, #34C759 / #FF9500 / #FF3B30 only for semantic status.
- Minimal, readable at 24pt.

Format:
- White or transparent background.
- Consistent grid and optical size.
- No text.
```

### 7.8 空状态 / 引导插画

```text
Create an empty state illustration for Maohuoban.

Scene options:
- No pet profile yet: a calm pet waiting to be added.
- No events yet: a clean timeline card waiting for the first record.
- No local service result: a pet looking at a simple map marker.
- No messages yet: a pet beside a soft message bubble.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Minimal illustration, soft frosted card, clean iOS empty state.
- Keep visual focus on the pet and the action context.
- Avoid dense background and decorative clutter.

Format:
- 4:3 or 1:1.
- Clean #F7F9FC background.
- No long text in the image.
```

### 7.9 医院 / 商家 / 保险场景图

```text
Create a trustworthy service scene for Maohuoban.

Scene:
- Pet hospital, cattery, kennel, pet store, trade evidence, or insurance claim support.
- Show a pet-centered record or service moment.
- The scene should communicate local trust, structured records, and responsible service.

Style:
- Use the Maohuoban master prompt and exact color tokens.
- Clinical clean but warm, professional but approachable.
- Use #5AC8FA for medical accents, #34C759 for healthy state, #FF9500 for reminders, #4F8CFF for primary actions.
- Keep people secondary and pet-centered.

Format:
- 16:9 for presentation cover.
- 4:3 for document illustration.
- 1:1 for card cover.
```

---

## 8. Prompt 变量

生成具体图片时，用以下变量替换模板。

| 变量 | 示例 |
|---|---|
| `{asset_type}` | UI mockup / app icon / mascot / avatar / icon set |
| `{screen}` | Home / Pet World / City / Messages / Mine |
| `{species}` | cat / dog / unknown pet |
| `{breed}` | ragdoll cat / golden retriever / mixed breed |
| `{age_stage}` | kitten / adult / senior |
| `{scene}` | daily record / hospital visit / trade import / littermate discovery |
| `{relationship}` | same litter / same city / same disease / same hospital / same source |
| `{entity}` | pet hospital / cattery / kennel / pet store |
| `{aspect_ratio}` | 1:1 / 4:3 / 16:9 / 9:19.5 |
| `{output_style}` | high fidelity UI / icon / mascot / clean illustration |

组合格式：

```text
[通用母 Prompt]

Asset type: {asset_type}
Scene: {scene}
Subject: {species}, {breed}, {age_stage}
Relationship signal: {relationship}
Output style: {output_style}
Aspect ratio: {aspect_ratio}

[对应场景模板]
[通用负向 Prompt]
```

---

## 9. 出图一致性检查清单

| 检查项 | 通过标准 |
|---|---|
| 主体 | 第一视觉中心是宠物或宠物相关对象 |
| 色彩 | 使用 `#4F8CFF / #6BCBFF / #3A6FCC / #F7F9FC` 作为主系统 |
| 材质 | 卡片具备白色玻璃感、轻边框、柔和阴影 |
| 风格 | 整体接近 iOS 原生、Apple Health、低饱和、清爽 |
| 专业感 | 医疗、交易、保险场景看起来可信 |
| 宠物关系 | 涉及 UGC 或推荐时能看出宠物之间的关系 |
| 文本 | AI 生成文字不清晰时改为无文字版本 |
| 图标 | 24pt 小尺寸仍能识别 |
| Logo | 缩小到 App 图标尺寸仍有清晰轮廓 |
| IP | 亲近、克制、可信，能用于引导和空状态 |

---

## 10. 资产命名建议

| 类型 | 命名格式 |
|---|---|
| UI 设计稿 | `ui_{screen}_{variant}_{date}.png` |
| Logo | `brand_logo_{variant}_{date}.png` |
| App Icon | `app_icon_{variant}_{date}.png` |
| IP 形象 | `ip_character_{pose}_{date}.png` |
| 默认头像 | `avatar_{species}_{variant}_{date}.png` |
| 功能图标 | `icon_{function}_{state}_{date}.png` |
| 运营视觉 | `cover_{scene}_{ratio}_{date}.png` |

---

## 11. 默认生成参数建议

| 类型 | 比例 | 建议 |
|---|---|---|
| App UI | `9:19.5` | 高保真、无设备壳、iOS 竖屏 |
| App Icon | `1:1` | 中心符号、保留安全边距 |
| Logo | `1:1` / `4:3` | 输出符号版和横版组合 |
| IP 形象 | `1:1` / `4:5` | 输出头像、半身、全身 |
| 默认头像 | `1:1` | 圆形裁切安全 |
| 功能图标 | `1:1` | 统一线宽和网格 |
| 运营封面 | `16:9` / `4:3` | 标题区域留白 |

---

## 12. 当前定档

| 项目 | 结论 |
|---|---|
| 主视觉系统 | 冷白蓝灰、低饱和、Apple Health inspired |
| 主色 | `#4F8CFF` |
| 辅助色 | `#6BCBFF / #3A6FCC / #5AC8FA` |
| 语义色 | `#34C759 / #FF9500 / #FF3B30 / #AF52DE` |
| 主体 | 宠物 |
| 核心气质 | 温暖、可信、克制、精致 |
| 默认资产生成方式 | 先用母 Prompt，再叠加场景模板和负向 Prompt |
