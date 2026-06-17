#[derive(Debug, Clone, Copy)]
pub enum PetErrorKind {
    Species,
    Sex,
    NeuterStatus,
    BackgroundMediaKind,
    MediaUsageKind,
    MediaAssetStatus,
    MediaBindingStatus,
    MediaDerivativeKind,
    MediaAssetComponentKind,
    ManagedStatus,
    SourceKind,
    EventKind,
    Visibility,
}
