pub(crate) const ERROR_CODE: &str = "CODEX_PROJECT_STRUCTURE_HOOK";
pub(crate) const BLOCKING_EXIT_CODE: i32 = 2;
pub(crate) const SWIFT_GUIDELINE_LIMIT: usize = 250;
pub(crate) const SWIFT_HARD_LIMIT: usize = 400;
pub(crate) const RUST_GUIDELINE_LIMIT: usize = 300;
pub(crate) const RUST_HARD_LIMIT: usize = 500;
pub(crate) const RESPONSIBILITY_DIRS: &[&str] = &[
    "Domain",
    "Data",
    "Presentation",
    "Stores",
    "Services",
    "Infrastructure",
    "Theme",
];
