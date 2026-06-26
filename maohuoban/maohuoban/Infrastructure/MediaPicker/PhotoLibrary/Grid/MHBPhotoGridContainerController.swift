import SwiftUI
import UIKit

// MHBPhotoGridContainerController 照片网格容器控制器
// 核心职责：
// - 承载 UICollectionView 照片网格和滚动日期浮层
// - 根据网格滚动位置同步日期浮层内容和位置
@MainActor
final class MHBPhotoGridContainerController: UIViewController {
    private let gridController: MHBPhotoGridController
    private let dateBadgeHost = UIHostingController(
        rootView: MHBPhotoGridScrollDateBadge(title: "")
    )

    private var dateBadgeCenterYConstraint: NSLayoutConstraint?
    private var dateBadgeTrailingConstraint: NSLayoutConstraint?
    private var dateBadgeSnapshot: MHBPhotoGridScrollDateSnapshot?

    init(gridController: MHBPhotoGridController) {
        self.gridController = gridController
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupGrid()
        setupDateBadge()
        gridController.onScrollDateChanged = { [weak self] snapshot in
            self?.updateDateBadge(snapshot)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateDateBadgePosition()
    }

    private func setupGrid() {
        view.backgroundColor = .black
        let collectionView = gridController.collectionView
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func setupDateBadge() {
        addChild(dateBadgeHost)
        dateBadgeHost.view.backgroundColor = .clear
        dateBadgeHost.view.isUserInteractionEnabled = false
        dateBadgeHost.view.alpha = 0
        dateBadgeHost.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(dateBadgeHost.view)
        dateBadgeHost.didMove(toParent: self)

        let centerYConstraint = dateBadgeHost.view.centerYAnchor.constraint(equalTo: view.topAnchor)
        let trailingConstraint = dateBadgeHost.view.trailingAnchor.constraint(
            equalTo: view.trailingAnchor,
            constant: -8
        )
        self.dateBadgeCenterYConstraint = centerYConstraint
        self.dateBadgeTrailingConstraint = trailingConstraint

        NSLayoutConstraint.activate([
            centerYConstraint,
            trailingConstraint
        ])
    }

    private func updateDateBadge(_ snapshot: MHBPhotoGridScrollDateSnapshot?) {
        dateBadgeSnapshot = snapshot

        guard let snapshot else {
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseOut]) {
                self.dateBadgeHost.view.alpha = 0
            }
            return
        }

        dateBadgeHost.rootView = MHBPhotoGridScrollDateBadge(title: snapshot.title)
        dateBadgeHost.view.invalidateIntrinsicContentSize()
        updateDateBadgePosition()
        UIView.animate(withDuration: 0.15, delay: 0, options: [.curveEaseIn]) {
            self.dateBadgeHost.view.alpha = 1
        }
    }

    private func updateDateBadgePosition() {
        guard let snapshot = dateBadgeSnapshot else {
            return
        }

        let badgeHeight: CGFloat = 28
        let verticalPadding: CGFloat = 4
        let availableHeight = max(0, view.bounds.height - badgeHeight - verticalPadding * 2)
        let centerY = verticalPadding + badgeHeight * 0.5 + availableHeight * snapshot.progress
        dateBadgeCenterYConstraint?.constant = centerY
        dateBadgeTrailingConstraint?.constant = -8
    }
}
