# 动态头像 Live Photo 方案

- 更新时间：2026-06-19
- 状态：方案归档，后续按优先级实施
- 目标：评估 Live Photo 作为宠物动态头像的可行性，明确前后端契约、展示策略、裁剪策略和实施边界。

## 1. 结论

Live Photo 作为宠物动态头像可行，但应作为 P1 能力推进。当前背景 Live Photo 链路已经具备基础设施，头像链路仍是静态图片上传、圆形裁剪和静态展示。动态头像不能通过复用背景字段或前端兼容补丁实现，必须作为头像媒体的一等能力进入后端 DTO、媒体 usage、绑定、派生和前端展示模型。

动态头像的核心原则：

| 原则 | 说明 |
|---|---|
| 后端 DTO 是唯一数据源 | 宠物头像是否支持动态、静态图 URL、Live Photo 组件 URL、尺寸和裁剪信息都由后端返回 |
| 静态头像是基础能力 | 所有动态头像都必须有稳定静态图，供列表、小头像、失败兜底和低性能场景使用 |
| 动态头像是增强能力 | 只有适合播放的场景展示 Live Photo，其他场景展示静态图 |
| usage 独立建模 | 动态头像使用独立 `pet.avatar.live_photo`，不复用 `pet.background.live_photo` |
| 裁剪不破坏原始组件 | 原始 Live Photo still 和 paired video 保留，裁剪通过 metadata 和派生图表达 |

## 2. 当前工程现状

| 模块 | 当前状态 |
|---|---|
| 图片头像 | iOS 通过 `PetProfileAvatarPreviewScreen` 选择图片，进入 `MHBCircularImageCropScreen` 圆形裁剪，再上传 `pet.avatar` |
| 背景 Live Photo | iOS 已支持选择 Live Photo，上传 still 和 paired video，后端用 `media_asset_components` 保存组合组件 |
| 媒体 usage | 后端已有 `pet.avatar`、`pet.background.image`、`pet.background.video`、`pet.background.live_photo` |
| 组件模型 | 后端已有 `media_asset_components`，支持 `still` 和 `paired_video` |
| 前端展示组件 | 已有 `MHBLocalLivePhotoView`、`MHBRemoteLivePhotoView`、`MHBPHLivePhotoRepresentable` |
| 头像展示 | 目前头像展示模型只消费静态 `avatar_url/avatar_width/avatar_height` |

结论：动态头像可以复用 Live Photo 基础设施能力，但需要扩展头像专属业务契约和展示边界。

## 3. 产品展示策略

| 场景 | 展示策略 | 原因 |
|---|---|---|
| 宠物档案头像预览页 | 展示 Live Photo，支持点击或长按播放 | 头像预览是强上下文，用户预期看到完整效果 |
| 编辑档案顶部宠物头像 | 可展示 Live Photo，也可默认静态后按交互播放 | 保持编辑页性能稳定，避免多头像同时播放 |
| 首页沉浸头部内头像 | 可展示 Live Photo，但播放应受交互或可见性控制 | 首页首屏可以承载情绪价值，但需要控制资源消耗 |
| 多宠切换器 | 默认静态图 | 横向列表容易出现多个头像，动态播放会增加耗电和卡顿 |
| 聊天、列表、商家、医疗等小尺寸头像 | 静态图 | 小尺寸动态收益低，性能和流量成本高 |
| 网络失败、资源缺失、低数据模式 | 静态图或物种兜底 | 动态能力不能影响头像基本可见性 |

## 4. 后端契约设计

### 4.1 媒体 usage 扩展

新增头像 Live Photo usage：

| usage | 用途 |
|---|---|
| `pet.avatar` | 宠物静态头像 |
| `pet.avatar.live_photo` | 宠物动态头像组合媒体 |
| `pet.background.live_photo` | 宠物背景 Live Photo |

需要同步更新：

| 位置 | 目标 |
|---|---|
| Domain `MediaUsageKind` | 增加 `PetAvatarLivePhoto` |
| PostgreSQL check constraint | `media_assets.usage_kind` 和 `media_bindings.usage_kind` 支持 `pet.avatar.live_photo` |
| HTTP 上传路由 | 增加 pending avatar live photo 上传接口 |
| Application service | 支持头像 Live Photo 上传和绑定 |
| Repository | 复用组合媒体组件持久化，保持头像 usage 独立 |
| GC worker | 清理原始资产、组件对象和派生对象 |

### 4.2 DTO 目标形态

宠物摘要和详情 DTO 应同时返回静态头像和动态头像增强数据：

```json
{
  "avatar_url": "/media/pet-avatar-poster.jpg",
  "avatar_width": 512,
  "avatar_height": 512,
  "avatar_live_photo": {
    "asset_id": "uuid",
    "still_url": "/media/live/still.heic",
    "paired_video_url": "/media/live/motion.mov",
    "poster_url": "/media/pet-avatar-poster.jpg",
    "width": 512,
    "height": 512,
    "crop_metadata": {
      "x": 0.12,
      "y": 0.08,
      "width": 0.76,
      "height": 0.76
    }
  }
}
```

字段语义：

| 字段 | 说明 |
|---|---|
| `avatar_url` | 所有场景可消费的静态头像 URL，动态头像存在时也必须返回 |
| `avatar_live_photo.still_url` | Live Photo 静态组件原始 URL |
| `avatar_live_photo.paired_video_url` | Live Photo 配对视频组件 URL |
| `avatar_live_photo.poster_url` | 后端生成的头像静态派生图，通常与 `avatar_url` 一致 |
| `avatar_live_photo.width/height` | 动态头像展示尺寸，必须返回 |
| `avatar_live_photo.crop_metadata` | 前端展示裁剪区域和后端派生生成共用的归一化裁剪信息 |

## 5. 裁剪策略

动态头像应进入圆形裁剪流程，但裁剪不直接改写 Live Photo 原始组件。

| 阶段 | 处理 |
|---|---|
| 选择 | 前端从相册获取 Live Photo still 和 paired video |
| 裁剪 | 前端使用 still preview 进入圆形裁剪页，得到归一化 crop metadata |
| 上传 | 前端上传 still、paired video 和 crop metadata |
| 后端处理 | 后端保存原始组件，基于 still 和 crop metadata 生成静态头像派生图 |
| 展示 | 大头像场景用 Live Photo 组件 + 圆形容器裁剪，小头像场景用派生静态头像 |

这样可以避免两个问题：

| 问题 | 规避方式 |
|---|---|
| 直接裁剪 still 导致 Live Photo 组件关系失效 | 原始 still 和 paired video 不改写 |
| 小头像加载 Live Photo 成本过高 | 小头像只消费后端派生静态图 |

## 6. iOS 数据流设计

### 6.1 Domain 模型

建议在宠物头像模型中引入明确的媒体类型，而不是在 View 中用多个 URL 自行判断：

```swift
enum PetAvatarMedia: Equatable {
    case fallback(species: PetProfileEditProfile.Species)
    case remoteImage(url: String, width: Int?, height: Int?)
    case remoteLivePhoto(
        stillURL: String,
        pairedVideoURL: String,
        posterURL: String,
        width: Int?,
        height: Int?,
        cropMetadata: MHBImageCropMetadata?
    )
}
```

### 6.2 Store 职责

| 层 | 职责 |
|---|---|
| View | 渲染头像媒体，转发选择、裁剪、确认事件 |
| Store | 持有上传进度、上传结果、绑定结果和一次性 Toast 事件 |
| Repository | 上传 multipart、绑定资产、解析后端 DTO |
| Mapper | 将后端头像 DTO 映射为 `PetAvatarMedia` |

View 不能根据文件后缀、URL 形态或 mock 资源推断动态头像。动态能力必须来自后端 DTO。

### 6.3 上传接口

前端新增头像 Live Photo 上传命令：

| 命令 | 输入 | 输出 |
|---|---|---|
| `uploadAvatarLivePhoto` | `PetLivePhotoUploadDraft` | `PetMediaUploadResult` |
| `bindUploadedMedia` | `asset_id` | 最新媒体绑定结果 |

添加宠物和编辑宠物都复用同一套上传 Store。保存按钮禁用逻辑继续由上传 slot 状态决定。

## 7. 后端处理策略

| 能力 | 要求 |
|---|---|
| 资源校验 | still 必须是图片类型，paired video 必须是视频类型 |
| 尺寸返回 | still 尺寸和静态派生图尺寸必须返回 |
| 视频元数据 | paired video 能提取尺寸和时长则记录，不能提取时不影响上传成功 |
| 派生图 | 基于 crop metadata 生成圆形头像所需静态派生图 |
| 主题色 | 动态头像不必参与首页背景主题色，后续如有头像氛围色需求再扩展 |
| 绑定替换 | 新动态头像绑定成功后，旧 `pet.avatar` 或 `pet.avatar.live_photo` 绑定失效 |
| 清理 | 旧头像资产、组件和派生对象进入 GC 清理策略 |

## 8. 性能与交互约束

| 约束 | 策略 |
|---|---|
| 多头像列表性能 | 列表、小尺寸头像只展示静态图 |
| 首页首屏性能 | Live Photo 仅在头像足够大且可见时加载 |
| 网络流量 | 先展示 `poster_url`，用户交互或可见后再加载 paired video |
| 播放控制 | 默认静态，点击、长按或进入预览页播放 |
| 缓存 | still、poster、paired video 都走 RustFS/CDN Cache-Control |
| 失败兜底 | Live Photo 加载失败后保持静态头像，不进入错误态页面 |

## 9. 安全与合规

| 项 | 要求 |
|---|---|
| 鉴权 | 上传和绑定必须要求当前登录用户有效 |
| 所有权 | pending 资产只能由上传用户绑定到自己拥有的宠物 |
| 文件大小 | still 和 paired video 分别限制大小，总大小也需要限制 |
| MIME 校验 | 不能只信任客户端 `Content-Type`，后端需要基于内容做基础校验 |
| 审计 | 上传、绑定、替换、清理都写媒体审计事件 |
| 爬虫防护 | 动态头像 URL 与现有媒体 URL 一样走鉴权策略或受控公开策略 |

## 10. 实施切片

| 顺序 | 切片 | 验收标准 |
|---|---|---|
| 1 | 后端 usage 和迁移 | 数据库约束、Domain enum、契约测试支持 `pet.avatar.live_photo` |
| 2 | 后端上传接口 | avatar live photo multipart 上传成功，返回 asset/components/尺寸 |
| 3 | 后端绑定和 DTO | 宠物详情、首页摘要、多宠切换 DTO 返回静态头像和 `avatar_live_photo` |
| 4 | 后端派生图 | 基于 crop metadata 生成头像 poster，`avatar_url` 指向可稳定展示的静态图 |
| 5 | iOS Domain / DTO | 前端解析 `avatar_live_photo` 并映射为头像媒体模型 |
| 6 | iOS 上传 Store | 添加/编辑头像 Live Photo 走统一上传进度、禁用保存和 Toast |
| 7 | iOS 展示接入 | 预览页展示动态头像，列表和小头像展示静态图 |
| 8 | 观测 SDK | 上传、绑定、DTO 解析、展示降级接入诊断事件 |
| 9 | 回归测试 | 添加宠物、编辑头像、切换宠物、重新启动后头像一致 |

## 11. 验证门禁

| 层 | 验证 |
|---|---|
| Rust 格式 | `cargo fmt --all --check` |
| Rust 编译 | `cargo check --workspace --all-targets` |
| Rust 契约 | 覆盖 avatar live photo 上传、绑定、替换、清理 |
| iOS 编译 | `xcodebuild -project maohuoban/maohuoban.xcodeproj -scheme maohuoban -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=27.0' -configuration Debug build` |
| iOS 数据流 | Repository / Store 测试覆盖 DTO 解析、上传成功、上传失败、绑定成功 |
| 真机验证 | Live Photo 选择、裁剪、上传、预览播放、重启后展示一致 |

## 12. 暂不进入本期的内容

| 内容 | 原因 |
|---|---|
| 用户账号动态头像 | 当前产品主体是宠物，先完成宠物头像 |
| 动态头像全列表自动播放 | 性能收益比低 |
| 动态头像主题色 | 背景主题色已满足首页视觉，头像主题色可后续独立评估 |
| 服务端真实裁剪 paired video | 成本高且容易破坏 Live Photo 语义，当前采用 metadata + 容器裁剪 |
| Android 兼容 | 当前工程目标是 iOS，跨端方案另行评估 |

