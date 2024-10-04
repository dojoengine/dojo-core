use camino::Utf8Path;
use scarb::{core::Workspace, flock::Filesystem};

use crate::{MANIFESTS_BASE_DIR, MANIFESTS_DIR};

/// Handy enum for selecting the current profile or all profiles.
#[derive(Debug)]
pub enum ProfileSpec {
    WorkspaceCurrent,
    All,
}

/// Extension trait for the [`Filesystem`] type.
pub trait FilesystemExt {
    /// Returns a new Filesystem with the given subdirectories.
    ///
    /// This is a helper function since flock [`Filesystem`] only has a child method.
    fn children(&self, sub_dirs: &[impl AsRef<Utf8Path>]) -> Filesystem;
}

impl FilesystemExt for Filesystem {
    fn children(&self, sub_dirs: &[impl AsRef<Utf8Path>]) -> Self {
        if sub_dirs.is_empty() {
            return self.clone();
        }

        let mut result = self.clone();

        for sub_dir in sub_dirs {
            result = result.child(sub_dir);
        }

        result
    }
}

/// Extension trait for the [`Workspace`] type.
pub trait WorkspaceExt {
    /// Returns the target directory for the current profile.
    fn target_dir_profile(&self) -> Filesystem;
    /// Returns the manifests directory for the current profile.
    fn dojo_base_manfiests_dir_profile(&self) -> Filesystem;
    /// Returns the base manifests directory.
    fn dojo_manifests_dir(&self) -> Filesystem;
}

impl WorkspaceExt for Workspace<'_> {
    fn target_dir_profile(&self) -> Filesystem {
        self.target_dir().child(
            self.current_profile()
                .expect("Current profile always exists")
                .as_str(),
        )
    }

    fn dojo_base_manfiests_dir_profile(&self) -> Filesystem {
        let manifests_dir = self.dojo_manifests_dir();

        manifests_dir.children(&[
            self.current_profile()
                .expect("Current profile always exists")
                .as_str(),
            MANIFESTS_BASE_DIR,
        ])
    }

    fn dojo_manifests_dir(&self) -> Filesystem {
        let base_dir = self.manifest_path().parent().unwrap();
        Filesystem::new(base_dir.to_path_buf()).child(MANIFESTS_DIR)
    }
}
