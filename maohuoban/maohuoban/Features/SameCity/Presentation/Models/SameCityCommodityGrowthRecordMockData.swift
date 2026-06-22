import Foundation

// SameCityCommodityGrowthRecordMockData 商品成长记录 Mock 数据
// 核心职责：
// - 为商品详情成长记录入口和全屏页提供稳定样例
// - 隔离成长记录时间轴 mock 与商品详情主体 mock
enum SameCityCommodityGrowthRecordMockData {
    static let goldenArchive = SameCityCommodityGrowthRecordArchive(
        navigationTitle: "成长档案",
        title: "金渐层弟弟的成长日记",
        recorderName: "星梦名猫苑",
        memoryCount: 45,
        entries: [
            SameCityCommodityGrowthRecordEntry(
                id: "today-sun-nap",
                dateText: "今天 10:30",
                ageText: "3 个月 2 天",
                nodeStyle: .regular,
                dataTag: nil,
                content: "刚吃完早饭，在阳光下睡大觉。呼噜声巨大，超级粘人。",
                mediaItems: [
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "today-sun-nap-photo",
                        assetName: "HomeGalleryAlbum2",
                        aspect: .portrait
                    )
                ]
            ),
            SameCityCommodityGrowthRecordEntry(
                id: "third-vaccine",
                dateText: "6月15日",
                ageText: "2 个月 28 天",
                nodeStyle: .medical,
                dataTag: SameCityCommodityGrowthRecordDataTag(
                    systemImage: "syringe.fill",
                    text: "第三针疫苗已完成",
                    style: .medical
                ),
                content: "带去医院打了最后一针妙三多，还做了全面的基础体检，医生说骨架发育得非常好，是个壮实的小伙子！",
                mediaItems: [
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "third-vaccine-photo-1",
                        assetName: "HomeGalleryAlbum3",
                        aspect: .square
                    ),
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "third-vaccine-photo-2",
                        assetName: "HomePetAlbum4",
                        aspect: .square
                    )
                ]
            ),
            SameCityCommodityGrowthRecordEntry(
                id: "weight-june",
                dateText: "6月1日",
                ageText: "2 个月 14 天",
                nodeStyle: .regular,
                dataTag: SameCityCommodityGrowthRecordDataTag(
                    systemImage: "scalemass.fill",
                    text: "体重录入 1.25 kg",
                    style: .weight
                ),
                content: "食欲爆棚，开始换幼猫猫粮了，体重长得很快。",
                mediaItems: []
            ),
            SameCityCommodityGrowthRecordEntry(
                id: "siblings-play",
                dateText: "5月20日",
                ageText: "2 个月 2 天",
                nodeStyle: .regular,
                dataTag: nil,
                content: "和同窝的兄弟姐妹在一起玩疯了，最调皮的就是他。",
                mediaItems: [
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "siblings-play-photo-1",
                        assetName: "HomePetAlbum2",
                        aspect: .square
                    ),
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "siblings-play-photo-2",
                        assetName: "HomeGalleryAlbum2",
                        aspect: .square
                    ),
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "siblings-play-photo-3",
                        assetName: "HomeGalleryAlbum3",
                        aspect: .square
                    )
                ]
            ),
            SameCityCommodityGrowthRecordEntry(
                id: "birth",
                dateText: "3月18日",
                ageText: "出生日",
                nodeStyle: .milestone,
                dataTag: SameCityCommodityGrowthRecordDataTag(
                    systemImage: "scalemass.fill",
                    text: "出生体重 105g",
                    style: .weight
                ),
                content: "平安降生！是一只毛色非常干净的 NY12 小公猫，眼睛还没睁开，叫声很响亮。",
                mediaItems: [
                    SameCityCommodityGrowthRecordMediaItem(
                        id: "birth-photo",
                        assetName: "HomePetAlbum3",
                        aspect: .portrait
                    )
                ]
            )
        ]
    )
}
