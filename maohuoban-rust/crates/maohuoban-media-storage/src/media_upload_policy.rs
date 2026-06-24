/// MediaUploadUsage 媒资上传用途
/// 核心职责：
/// - 区分头像、背景、UGC、商品、医疗和视频等媒资场景
/// - 为统一上传策略提供用途索引
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum MediaUploadUsage {
    /// 用户 / 宠物头像
    Avatar,
    /// 用户 / 宠物主页背景图
    Cover,
    /// UGC 图片 / 相册
    UgcImage,
    /// 商品 / 服务图片
    CommodityImage,
    /// 医疗 / 报告图片
    MedicalImage,
    /// Live Photo 静态帧
    LivePhotoStill,
    /// 短视频
    ShortVideo,
}

/// MediaUploadPolicy 媒资上传策略
/// 核心职责：
/// - 按用途提供 body_limit、file_limit、MIME allowlist、像素上限和派生规格
/// - 作为 HTTP 路由 DefaultBodyLimit 和应用层校验的统一事实源
#[derive(Debug, Clone)]
pub struct MediaUploadPolicy {
    pub usage: MediaUploadUsage,
    /// HTTP body limit（含 multipart 开销），用于 DefaultBodyLimit
    pub body_limit_bytes: usize,
    /// 单文件真实限制，应用层校验
    pub file_limit_bytes: usize,
    /// 允许的 MIME 类型
    pub mime_allowlist: &'static [&'static str],
    /// 源图最长边像素上限
    pub max_long_edge_pixels: u32,
    /// 最大像素总数（兆像素）
    pub max_megapixels: f64,
    /// 推荐的编码质量 0.0-1.0
    pub default_quality: f32,
    /// 派生图宽度规格
    pub derivative_widths: &'static [u32],
    /// 用途标识字符串
    pub usage_kind: &'static str,
}

impl MediaUploadPolicy {
    /// avatar 头像上传策略
    /// 核心职责：
    /// - HTTP body 16MB，单文件 8MB
    /// - 允许 JPEG/PNG/WebP/HEIC
    /// - 最长边 2048，默认 JPEG 0.90
    #[must_use]
    pub const fn avatar() -> Self {
        Self {
            usage: MediaUploadUsage::Avatar,
            body_limit_bytes: 16 * 1024 * 1024,
            file_limit_bytes: 8 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/png", "image/webp", "image/heic"],
            max_long_edge_pixels: 2048,
            max_megapixels: 12.0,
            default_quality: 0.90,
            derivative_widths: &[256, 512, 1024],
            usage_kind: "avatar",
        }
    }

    /// cover 背景图上传统一策略（用户和宠物共用）
    /// 核心职责：
    /// - HTTP body 32MB，单文件 16MB
    /// - 允许 2K/4K 级源图，最长边 3840
    #[must_use]
    pub const fn cover() -> Self {
        Self {
            usage: MediaUploadUsage::Cover,
            body_limit_bytes: 32 * 1024 * 1024,
            file_limit_bytes: 16 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/png", "image/webp", "image/heic"],
            max_long_edge_pixels: 3840,
            max_megapixels: 32.0,
            default_quality: 0.90,
            derivative_widths: &[1080, 1600, 2560],
            usage_kind: "cover",
        }
    }

    /// ugc_image UGC 图片 / 相册上传策略
    /// 核心职责：
    /// - HTTP body 32MB，单文件 16MB，64MP 上限
    #[must_use]
    pub const fn ugc_image() -> Self {
        Self {
            usage: MediaUploadUsage::UgcImage,
            body_limit_bytes: 32 * 1024 * 1024,
            file_limit_bytes: 16 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/png", "image/webp", "image/heic"],
            max_long_edge_pixels: 8192,
            max_megapixels: 64.0,
            default_quality: 0.90,
            derivative_widths: &[720, 1080, 1600, 2560],
            usage_kind: "ugc.image",
        }
    }

    /// commodity_image 商品 / 服务图片上传策略
    /// 核心职责：
    /// - HTTP body 32MB，单文件 16MB
    #[must_use]
    pub const fn commodity_image() -> Self {
        Self {
            usage: MediaUploadUsage::CommodityImage,
            body_limit_bytes: 32 * 1024 * 1024,
            file_limit_bytes: 16 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/png", "image/webp"],
            max_long_edge_pixels: 8192,
            max_megapixels: 64.0,
            default_quality: 0.92,
            derivative_widths: &[800, 1600, 2560],
            usage_kind: "commodity.image",
        }
    }

    /// medical_image 医疗 / 报告图片上传策略
    /// 核心职责：
    /// - HTTP body 32MB，单文件 20MB，弱压缩保留可读性
    #[must_use]
    pub const fn medical_image() -> Self {
        Self {
            usage: MediaUploadUsage::MedicalImage,
            body_limit_bytes: 32 * 1024 * 1024,
            file_limit_bytes: 20 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/png", "image/webp"],
            max_long_edge_pixels: 8192,
            max_megapixels: 64.0,
            default_quality: 0.95,
            derivative_widths: &[1080, 1600, 2560],
            usage_kind: "medical.image",
        }
    }

    /// live_photo_still Live Photo 静态帧上传策略
    #[must_use]
    pub const fn live_photo_still() -> Self {
        Self {
            usage: MediaUploadUsage::LivePhotoStill,
            body_limit_bytes: 32 * 1024 * 1024,
            file_limit_bytes: 16 * 1024 * 1024,
            mime_allowlist: &["image/jpeg", "image/heic"],
            max_long_edge_pixels: 3840,
            max_megapixels: 32.0,
            default_quality: 0.90,
            derivative_widths: &[1080, 1600, 2560],
            usage_kind: "livephoto.still",
        }
    }

    /// short_video 短视频上传策略
    /// 核心职责：
    /// - HTTP body 512MB 起步，后续按直传/分片演进
    #[must_use]
    pub const fn short_video() -> Self {
        Self {
            usage: MediaUploadUsage::ShortVideo,
            body_limit_bytes: 512 * 1024 * 1024,
            file_limit_bytes: 512 * 1024 * 1024,
            mime_allowlist: &["video/mp4", "video/quicktime"],
            max_long_edge_pixels: 3840,
            max_megapixels: 0.0,    // 视频不使用像素限制
            default_quality: 0.0,   // 视频不使用 JPEG quality
            derivative_widths: &[], // 视频派生由转码策略定义
            usage_kind: "video.short",
        }
    }
}
