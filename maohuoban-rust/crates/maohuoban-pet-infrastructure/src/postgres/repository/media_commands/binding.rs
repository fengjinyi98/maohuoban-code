use maohuoban_pet_application::pet::BindUploadedPetMediaInput;
use maohuoban_pet_domain::pet::{
    MediaAssetComponent, MediaDerivative, PetMediaUploadResult, PetResult,
};
use sqlx::{Postgres, Transaction};
use uuid::Uuid;

use super::diagnostics::record_binding_stage;
use crate::postgres::repository::PostgresPetRepository;
use crate::postgres::repository::rows::{
    MediaAssetComponentRow, MediaAssetRow, MediaBindingRow, MediaDerivativeRow,
};
use crate::postgres::repository::storage::to_infrastructure_error;

impl PostgresPetRepository {
    pub(in crate::postgres::repository) async fn bind_uploaded_pet_media_command(
        &self,
        input: BindUploadedPetMediaInput,
    ) -> PetResult<PetMediaUploadResult> {
        let mut transaction = match self.pool.begin().await.map_err(to_infrastructure_error) {
            Ok(transaction) => transaction,
            Err(error) => {
                record_binding_stage("repository.transaction_started", &input, None, 0, false);
                return Err(error);
            }
        };
        let (asset_row, binding_row, derivative_rows, component_rows) =
            Self::bind_uploaded_media_in_transaction(
                &mut transaction,
                input.pet_id,
                input.owner_user_id,
                input.asset_id,
            )
            .await
            .inspect_err(|_error| {
                record_binding_stage("repository.bound", &input, None, 0, false);
            })?;
        if let Err(error) = transaction.commit().await.map_err(to_infrastructure_error) {
            record_binding_stage("repository.committed", &input, None, 0, false);
            return Err(error);
        }

        let upload = PetMediaUploadResult {
            asset: asset_row.try_into()?,
            binding: Some(binding_row.try_into()?),
            derivatives: derivative_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaDerivative>>>()?,
            components: component_rows
                .into_iter()
                .map(TryInto::try_into)
                .collect::<PetResult<Vec<MediaAssetComponent>>>()?,
        };
        record_binding_stage(
            "repository.committed",
            &input,
            Some(&upload.asset),
            upload.derivatives.len(),
            true,
        );
        Ok(upload)
    }

    pub(in crate::postgres::repository) async fn bind_uploaded_media_in_transaction(
        transaction: &mut Transaction<'_, Postgres>,
        pet_id: Uuid,
        owner_user_id: Uuid,
        asset_id: Uuid,
    ) -> PetResult<(
        MediaAssetRow,
        MediaBindingRow,
        Vec<MediaDerivativeRow>,
        Vec<MediaAssetComponentRow>,
    )> {
        let current_asset =
            Self::select_owned_media_asset_for_binding(transaction, asset_id, owner_user_id)
                .await?;
        let usage_kind = current_asset.usage_kind;

        Self::queue_replaced_media(transaction, pet_id, usage_kind).await?;
        let asset_row = Self::mark_media_asset_bound(transaction, asset_id, pet_id).await?;
        let binding_row = Self::insert_media_binding_for_asset(
            transaction,
            asset_id,
            pet_id,
            owner_user_id,
            usage_kind,
        )
        .await?;
        Self::update_pet_media_reference_by_usage(
            transaction,
            pet_id,
            owner_user_id,
            asset_id,
            usage_kind,
        )
        .await?;
        Self::insert_bound_audit_event_for_asset(
            transaction,
            pet_id,
            owner_user_id,
            asset_id,
            usage_kind,
        )
        .await?;
        let derivative_rows = Self::select_media_derivatives(transaction, asset_id).await?;
        let component_rows = Self::select_media_asset_components(transaction, asset_id).await?;

        Ok((asset_row, binding_row, derivative_rows, component_rows))
    }
}
