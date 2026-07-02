import SwiftUI
import MaohuobanDiagnostics

// HomeImmersivePetHeaderForegroundMedia 首页头图前景媒体
// 核心职责：
// - 渲染清晰的宠物主体图片或视频
// - 为视频资源缺失时提供图片兜底
struct HomeImmersivePetHeaderForegroundMedia: View {
    let media: HomeDashboardSnapshot.PetHeroSummary.HeroMedia
    let imageWidth: CGFloat
    let imageHeight: CGFloat

    var body: some View {
        switch media {
        case .image(let assetName):
            foregroundImage(assetName: assetName)
                .onAppear {
                    recordHeroMediaAppearance(branch: "local_image", resolved: assetName.isEmpty == false)
                }
        case .remoteImage(let urlString, let fallbackAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBRemoteImage(url: url, contentMode: .fill) {
                    foregroundImage(assetName: fallbackAssetName)
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_image",
                        resolved: true,
                        urlString: urlString,
                        hasFallback: fallbackAssetName.isEmpty == false
                    )
                }
            } else {
                foregroundImage(assetName: fallbackAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_image",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: fallbackAssetName.isEmpty == false
                        )
                    }
            }
        case .video(let resourceName, let fileExtension, let fallbackImageAssetName):
            if MHBLocalMediaResource.url(resourceName: resourceName, fileExtension: fileExtension) != nil {
                MHBMutedLoopingVideoView(
                    resourceName: resourceName,
                    fileExtension: fileExtension
                )
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(branch: "local_video", resolved: true)
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(branch: "local_video", resolved: false, hasFallback: true)
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(branch: "local_video", resolved: false, hasFallback: false)
                    }
            }
        case .remoteVideo(let urlString, let fallbackImageURLString, let fallbackImageAssetName):
            if let url = MHBBackendEndpoint.resolve(urlString) {
                MHBMutedLoopingVideoView(url: url)
                    .frame(width: imageWidth, height: imageHeight)
                    .clipped()
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video",
                            resolved: true,
                            urlString: urlString,
                            hasFallback: fallbackImageURLString != nil || fallbackImageAssetName != nil
                        )
                    }
            } else if let fallbackImageURLString, let fallbackURL = MHBBackendEndpoint.resolve(fallbackImageURLString) {
                MHBRemoteImage(url: fallbackURL, contentMode: .fill) {
                    if let fallbackImageAssetName {
                        foregroundImage(assetName: fallbackImageAssetName)
                    } else {
                        Color.clear
                            .frame(width: imageWidth, height: imageHeight)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_video_fallback_remote_image",
                        resolved: false,
                        urlString: urlString,
                        hasFallback: true
                    )
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video_fallback_local_image",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: true
                        )
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_video_empty",
                            resolved: false,
                            urlString: urlString,
                            hasFallback: false
                        )
                    }
            }
        case .remoteLivePhoto(let stillURLString, let pairedVideoURLString, let cropMetadata, let fallbackImageAssetName):
            if let stillURL = MHBBackendEndpoint.resolve(stillURLString),
               let pairedVideoURL = MHBBackendEndpoint.resolve(pairedVideoURLString) {
                MHBRemoteLivePhotoView(
                    stillURL: stillURL,
                    pairedVideoURL: pairedVideoURL,
                    cropMetadata: cropMetadata
                ) {
                    if let fallbackImageAssetName {
                        foregroundImage(assetName: fallbackImageAssetName)
                    } else {
                        Color.clear
                            .frame(width: imageWidth, height: imageHeight)
                    }
                }
                .frame(width: imageWidth, height: imageHeight)
                .clipped()
                .onAppear {
                    recordHeroMediaAppearance(
                        branch: "remote_live_photo",
                        resolved: true,
                        urlString: stillURLString,
                        hasFallback: fallbackImageAssetName != nil
                    )
                }
            } else if let fallbackImageAssetName {
                foregroundImage(assetName: fallbackImageAssetName)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_live_photo_fallback_local_image",
                            resolved: false,
                            urlString: stillURLString,
                            hasFallback: true
                        )
                    }
            } else {
                Color.clear
                    .frame(width: imageWidth, height: imageHeight)
                    .onAppear {
                        recordHeroMediaAppearance(
                            branch: "remote_live_photo_empty",
                            resolved: false,
                            urlString: stillURLString,
                            hasFallback: false
                        )
                    }
            }
        }
    }

    private func foregroundImage(assetName: String) -> some View {
        Image(assetName)
            .resizable()
            .scaledToFill()
            .frame(width: imageWidth, height: imageHeight)
            .clipped()
    }

    private func recordHeroMediaAppearance(
        branch: String,
        resolved: Bool,
        urlString: String? = nil,
        hasFallback: Bool = false
    ) {
        Task {
            await Diagnostics.track(
                "home.hero_media_appeared",
                properties: [
                    "branch": .string(branch),
                    "resolved": .bool(resolved),
                    "has_url": .bool(urlString != nil),
                    "has_fallback": .bool(hasFallback)
                ]
            )
        }
    }
}
