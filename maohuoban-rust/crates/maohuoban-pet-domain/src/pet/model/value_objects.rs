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
    ManagedStatus,
    SourceKind,
    EventKind,
    Visibility,
}
