-- 用户级宠物相册边界
-- 核心职责：
-- - 将相册归属收敛到 owner_user_id 用户空间
-- - 保留 pet_id 作为可选来源宠物/筛选上下文，而不是相册所有权

ALTER TABLE pet_albums
    ALTER COLUMN pet_id DROP NOT NULL;

ALTER TABLE pet_album_assets
    ALTER COLUMN pet_id DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_pet_albums_owner_keyset
    ON pet_albums(owner_user_id, is_pinned DESC, updated_at DESC, id DESC)
    WHERE archived_at IS NULL;

COMMENT ON COLUMN pet_albums.pet_id IS
    '可选来源宠物或默认筛选上下文；相册归属以 owner_user_id 为准。';

COMMENT ON COLUMN pet_album_assets.pet_id IS
    '可选照片来源宠物；照片归属通过相册 owner_user_id 与媒体 uploaded_by_user_id 校验。';
