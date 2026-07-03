use maohuoban_pet_application::pet::{
    AddPetAlbumAssetInput, CreatePetAlbumInput, UpdatePetAlbumInput,
};
use maohuoban_pet_domain::pet::{PetAlbum, PetAlbumAsset, PetError, PetResult};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::PostgresPetAlbumRepository;
use super::errors::to_infrastructure_error;
use super::rows::{PetAlbumAssetRow, PetAlbumRow};

impl PostgresPetAlbumRepository {
    pub(super) async fn create_pet_album_command(
        &self,
        input: CreatePetAlbumInput,
    ) -> PetResult<PetAlbum> {
        let row = sqlx::query_as::<_, PetAlbumRow>(
            r#"
            INSERT INTO pet_albums (
                id,
                pet_id,
                owner_user_id,
                title,
                description,
                is_private,
                is_pinned,
                cover_asset_id
            )
            VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
            RETURNING
                id,
                pet_id,
                owner_user_id,
                title,
                description,
                is_private,
                is_pinned,
                cover_asset_id,
                photo_count,
                archived_at,
                created_at,
                updated_at
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.source_pet_id)
        .bind(input.owner_user_id)
        .bind(input.title)
        .bind(input.description)
        .bind(input.is_private)
        .bind(input.is_pinned)
        .bind(input.cover_asset_id)
        .fetch_one(&self.pool)
        .await
        .map_err(to_infrastructure_error)?;

        row.try_into()
    }

    pub(super) async fn update_pet_album_command(
        &self,
        input: UpdatePetAlbumInput,
    ) -> PetResult<PetAlbum> {
        let row = sqlx::query_as::<_, PetAlbumRow>(
            r#"
            UPDATE pet_albums album
            SET
                title = COALESCE($3, album.title),
                description = COALESCE($4, album.description),
                is_private = COALESCE($5, album.is_private),
                is_pinned = COALESCE($6, album.is_pinned),
                cover_asset_id = COALESCE($7, album.cover_asset_id),
                updated_at = now()
            WHERE album.id = $1
              AND album.archived_at IS NULL
              AND album.owner_user_id = $2
            RETURNING
                album.id,
                album.pet_id,
                album.owner_user_id,
                album.title,
                album.description,
                album.is_private,
                album.is_pinned,
                album.cover_asset_id,
                album.photo_count,
                album.archived_at,
                album.created_at,
                album.updated_at
            "#,
        )
        .bind(input.album_id)
        .bind(input.owner_user_id)
        .bind(input.title)
        .bind(input.description)
        .bind(input.is_private)
        .bind(input.is_pinned)
        .bind(input.cover_asset_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetAlbumNotFound)?;

        row.try_into()
    }

    pub(super) async fn archive_pet_album_command(
        &self,
        album_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum> {
        let row = sqlx::query_as::<_, PetAlbumRow>(
            r#"
            UPDATE pet_albums album
            SET archived_at = now(), updated_at = now()
            WHERE album.id = $1
              AND album.archived_at IS NULL
              AND album.owner_user_id = $2
            RETURNING
                album.id,
                album.pet_id,
                album.owner_user_id,
                album.title,
                album.description,
                album.is_private,
                album.is_pinned,
                album.cover_asset_id,
                album.photo_count,
                album.archived_at,
                album.created_at,
                album.updated_at
            "#,
        )
        .bind(album_id)
        .bind(owner_user_id)
        .fetch_optional(&self.pool)
        .await
        .map_err(to_infrastructure_error)?
        .ok_or(PetError::PetAlbumNotFound)?;

        row.try_into()
    }

    pub(super) async fn add_pet_album_asset_command(
        &self,
        input: AddPetAlbumAssetInput,
    ) -> PetResult<PetAlbumAsset> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let source_pet_id =
            lock_album_source_pet_id(&mut transaction, input.album_id, input.owner_user_id)
                .await?
                .ok_or(PetError::PetAlbumNotFound)?;
        bind_album_media_asset(
            &mut transaction,
            input.asset_id,
            source_pet_id,
            input.owner_user_id,
        )
        .await?;

        let row = sqlx::query_as::<_, PetAlbumAssetRow>(
            r#"
            WITH inserted AS (
                INSERT INTO pet_album_assets (
                    id,
                    album_id,
                    pet_id,
                    asset_id,
                    added_by_user_id,
                    caption,
                    sort_taken_at
                )
                VALUES ($1, $2, $3, $4, $5, $6, COALESCE($7, now()))
                RETURNING
                    id,
                    album_id,
                    pet_id,
                    asset_id,
                    added_by_user_id,
                    caption,
                    sort_taken_at,
                    removed_at,
                    created_at,
                    updated_at
            )
            SELECT
                inserted.id,
                inserted.album_id,
                inserted.pet_id,
                inserted.asset_id,
                media.sha256_hex,
                media.width,
                media.height,
                inserted.added_by_user_id,
                inserted.caption,
                inserted.sort_taken_at,
                inserted.removed_at,
                inserted.created_at,
                inserted.updated_at
            FROM inserted
            INNER JOIN media_assets media ON media.id = inserted.asset_id
            "#,
        )
        .bind(Uuid::new_v4())
        .bind(input.album_id)
        .bind(source_pet_id)
        .bind(input.asset_id)
        .bind(input.owner_user_id)
        .bind(input.caption)
        .bind(input.sort_taken_at)
        .fetch_one(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        update_album_after_asset_added(&mut transaction, input.album_id, input.asset_id).await?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;
        row.try_into()
    }

    pub(super) async fn remove_pet_album_asset_command(
        &self,
        album_asset_id: Uuid,
        owner_user_id: Uuid,
    ) -> PetResult<PetAlbum> {
        let mut transaction = self.pool.begin().await.map_err(to_infrastructure_error)?;
        let (album_id, asset_id) =
            lock_album_asset_for_remove(&mut transaction, album_asset_id, owner_user_id)
                .await?
                .ok_or(PetError::PetAlbumAssetNotFound)?;

        sqlx::query(
            r#"
            UPDATE pet_album_assets
            SET removed_at = now(), updated_at = now()
            WHERE id = $1
            "#,
        )
        .bind(album_asset_id)
        .execute(&mut *transaction)
        .await
        .map_err(to_infrastructure_error)?;

        let next_cover_asset_id = next_album_cover_asset_id(&mut transaction, album_id).await?;
        let album = update_album_after_asset_removed(
            &mut transaction,
            album_id,
            asset_id,
            next_cover_asset_id,
        )
        .await?;
        transaction
            .commit()
            .await
            .map_err(to_infrastructure_error)?;
        album.try_into()
    }
}

async fn lock_album_source_pet_id(
    transaction: &mut Transaction<'_, Postgres>,
    album_id: Uuid,
    owner_user_id: Uuid,
) -> PetResult<Option<Option<Uuid>>> {
    sqlx::query_scalar::<_, Option<Uuid>>(
        r#"
        SELECT album.pet_id
        FROM pet_albums album
        WHERE album.id = $1
          AND album.archived_at IS NULL
          AND album.owner_user_id = $2
        FOR UPDATE OF album
        "#,
    )
    .bind(album_id)
    .bind(owner_user_id)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

async fn bind_album_media_asset(
    transaction: &mut Transaction<'_, Postgres>,
    asset_id: Uuid,
    source_pet_id: Option<Uuid>,
    owner_user_id: Uuid,
) -> PetResult<()> {
    let updated_asset_id = sqlx::query_scalar::<_, Uuid>(
        r#"
        UPDATE media_assets
        SET owner_pet_id = $2, status = 'bound', updated_at = now()
        WHERE id = $1
          AND uploaded_by_user_id = $3
          AND usage_kind = 'pet.album.photo'
          AND deleted_at IS NULL
        RETURNING id
        "#,
    )
    .bind(asset_id)
    .bind(source_pet_id)
    .bind(owner_user_id)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;

    updated_asset_id
        .map(|_| ())
        .ok_or(PetError::PetAlbumAssetNotFound)
}

async fn update_album_after_asset_added(
    transaction: &mut Transaction<'_, Postgres>,
    album_id: Uuid,
    asset_id: Uuid,
) -> PetResult<()> {
    sqlx::query(
        r#"
        UPDATE pet_albums
        SET
            photo_count = photo_count + 1,
            cover_asset_id = COALESCE(cover_asset_id, $2),
            updated_at = now()
        WHERE id = $1
        "#,
    )
    .bind(album_id)
    .bind(asset_id)
    .execute(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)?;
    Ok(())
}

async fn lock_album_asset_for_remove(
    transaction: &mut Transaction<'_, Postgres>,
    album_asset_id: Uuid,
    owner_user_id: Uuid,
) -> PetResult<Option<(Uuid, Uuid)>> {
    sqlx::query_as::<_, (Uuid, Uuid)>(
        r#"
        SELECT album_asset.album_id, album_asset.asset_id
        FROM pet_album_assets album_asset
        INNER JOIN pet_albums album ON album.id = album_asset.album_id
        WHERE album_asset.id = $1
          AND album_asset.removed_at IS NULL
          AND album.archived_at IS NULL
          AND album.owner_user_id = $2
        FOR UPDATE OF album_asset, album
        "#,
    )
    .bind(album_asset_id)
    .bind(owner_user_id)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

async fn next_album_cover_asset_id(
    transaction: &mut Transaction<'_, Postgres>,
    album_id: Uuid,
) -> PetResult<Option<Uuid>> {
    sqlx::query_scalar::<_, Uuid>(
        r#"
        SELECT asset_id
        FROM pet_album_assets
        WHERE album_id = $1
          AND removed_at IS NULL
        ORDER BY sort_taken_at DESC, created_at DESC, id DESC
        LIMIT 1
        "#,
    )
    .bind(album_id)
    .fetch_optional(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}

async fn update_album_after_asset_removed(
    transaction: &mut Transaction<'_, Postgres>,
    album_id: Uuid,
    removed_asset_id: Uuid,
    next_cover_asset_id: Option<Uuid>,
) -> PetResult<PetAlbumRow> {
    sqlx::query_as::<_, PetAlbumRow>(
        r#"
        UPDATE pet_albums
        SET
            photo_count = GREATEST(photo_count - 1, 0),
            cover_asset_id = CASE
                WHEN cover_asset_id = $2 THEN $3
                ELSE cover_asset_id
            END,
            updated_at = now()
        WHERE id = $1
        RETURNING
            id,
            pet_id,
            owner_user_id,
            title,
            description,
            is_private,
            is_pinned,
            cover_asset_id,
            photo_count,
            archived_at,
            created_at,
            updated_at
        "#,
    )
    .bind(album_id)
    .bind(removed_asset_id)
    .bind(next_cover_asset_id)
    .fetch_one(&mut **transaction)
    .await
    .map_err(to_infrastructure_error)
}
