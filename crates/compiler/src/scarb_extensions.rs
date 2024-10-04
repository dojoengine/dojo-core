use camino::Utf8Path;
use scarb::{core::Workspace, flock::Filesystem};

use crate::MANIFESTS_DIR;

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
    fn manfiests_dir_profile(&self) -> Filesystem;
}

impl WorkspaceExt for Workspace<'_> {
    fn target_dir_profile(&self) -> Filesystem {
        self.target_dir().child(
            self.current_profile()
                .expect("Current profile always exists")
                .as_str(),
        )
    }

    fn manfiests_dir_profile(&self) -> Filesystem {
        let base_dir = self.manifest_path().parent().unwrap();
        let fs = Filesystem::new(base_dir.to_path_buf()).child(MANIFESTS_DIR);

        fs.child(
            self.current_profile()
                .expect("Current profile always exists")
                .as_str(),
        )
    }
}
