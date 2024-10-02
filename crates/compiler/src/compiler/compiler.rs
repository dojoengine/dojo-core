use std::collections::HashMap;
use std::rc::Rc;
use std::str::FromStr;

use anyhow::{anyhow, Context, Result};
use cairo_lang_compiler::db::RootDatabase;
use cairo_lang_compiler::CompilerConfig;
use cairo_lang_defs::ids::NamedLanguageElementId;
use cairo_lang_filesystem::db::FilesGroup;
use cairo_lang_filesystem::ids::{CrateId, CrateLongId};
use cairo_lang_starknet::compile::compile_prepared_db;
use cairo_lang_starknet::contract::{find_contracts, ContractDeclaration};
use cairo_lang_starknet_classes::allowed_libfuncs::{AllowedLibfuncsError, ListSelector};
use cairo_lang_starknet_classes::contract_class::ContractClass;
use cairo_lang_utils::UpcastMut;
use camino::Utf8PathBuf;
use convert_case::{Case, Casing};
use itertools::{izip, Itertools};
use scarb::compiler::helpers::build_compiler_config;
use scarb::compiler::{CairoCompilationUnit, CompilationUnitAttributes, Compiler};
use scarb::core::{Config, Package, PackageName, TargetKind, TomlManifest, Workspace};
use scarb::ops::CompileOpts;
use scarb_ui::args::{FeaturesSpec, PackagesFilter};
use scarb_ui::Ui;
use semver::Version;
use serde::{Deserialize, Serialize};
use smol_str::SmolStr;
use starknet::core::types::contract::SierraClass;
use starknet::core::types::Felt;
use tracing::{trace, trace_span};

use crate::scarb_internal::debug::SierraToCairoDebugInfo;

const GLOB_PATH_SELECTOR: &str = "*";

#[derive(Debug, Clone)]
pub struct CompiledArtifact {
    /// THe class hash of the Sierra contract.
    pub class_hash: Felt,
    /// The actual compiled Sierra contract class.
    pub contract_class: Rc<ContractClass>,
    pub debug_info: Option<Rc<SierraToCairoDebugInfo>>,
}

/// A type alias for a map of compiled artifacts by their path.
type CompiledArtifactByPath = HashMap<String, CompiledArtifact>;

const CAIRO_PATH_SEPARATOR: &str = "::";

#[cfg(test)]
#[path = "compiler_test.rs"]
mod test;

#[derive(Debug, Default)]
pub struct DojoCompiler {
    /// Output the debug information of the compiled Sierra contracts.
    ///
    /// Mainly used for the Walnut debugger integration. It is used
    /// internally by Walnut to build the Dojo project with the Sierra
    /// debug information. This flag has no use outside of that.
    output_debug_info: bool,
}

impl DojoCompiler {
    pub fn new(output_debug_info: bool) -> Self {
        Self { output_debug_info }
    }

    pub fn compile_workspace(
        config: &Config,
        packages_filter: Option<PackagesFilter>,
        features: FeaturesSpec,
    ) -> Result<()> {
        let ws = scarb::ops::read_workspace(config.manifest_path(), config)?;

        let packages: Vec<Package> = if let Some(filter) = packages_filter {
            filter.match_many(&ws)?.into_iter().collect()
        } else {
            ws.members().collect()
        };

        for p in &packages {
            check_package_dojo_version(&ws, p)?;
        }

        let _profile_name = ws
            .current_profile()
            .expect("Scarb profile is expected.")
            .to_string();

        // Manifest path is always a file, we can unwrap safely to get the parent folder.
        let _manifest_dir = ws.manifest_path().parent().unwrap().to_path_buf();

        // TODO: clean base manifests dir.
        //let profile_dir = manifest_dir.join(MANIFESTS_DIR).join(profile_name);
        //CleanArgs::clean_manifests(&profile_dir)?;

        trace!(?packages);

        let compile_info = crate::scarb_internal::compile_workspace(
            config,
            CompileOpts {
                include_target_names: vec![],
                include_target_kinds: vec![],
                exclude_target_kinds: vec![TargetKind::TEST],
                features: features.try_into()?,
            },
            packages.iter().map(|p| p.id).collect(),
        )?;

        trace!(?compile_info, "Compiled workspace.");

        Ok(())
    }
}

/// Checks if the package has a compatible version of dojo-core.
/// In case of a workspace with multiple packages, each package is individually checked
/// and the workspace manifest path is returned in case of virtual workspace.
pub fn check_package_dojo_version(ws: &Workspace<'_>, package: &Package) -> anyhow::Result<()> {
    if let Some(dojo_dep) = package
        .manifest
        .summary
        .dependencies
        .iter()
        .find(|dep| dep.name.as_str() == "dojo")
    {
        let dojo_version = env!("CARGO_PKG_VERSION");

        let dojo_dep_str = dojo_dep.to_string();

        // Only in case of git dependency with an explicit tag, we check if the tag is the same as
        // the current version.
        if dojo_dep_str.contains("git+")
            && dojo_dep_str.contains("tag=v")
            && !dojo_dep_str.contains(dojo_version)
        {
            if let Ok(cp) = ws.current_package() {
                let path = if cp.id == package.id {
                    package.manifest_path()
                } else {
                    ws.manifest_path()
                };

                anyhow::bail!(
                    "Found dojo-core version mismatch: expected {}. Please verify your dojo \
                     dependency in {}",
                    dojo_version,
                    path
                )
            } else {
                // Virtual workspace.
                anyhow::bail!(
                    "Found dojo-core version mismatch: expected {}. Please verify your dojo \
                     dependency in {}",
                    dojo_version,
                    ws.manifest_path()
                )
            }
        }
    }

    Ok(())
}

pub fn generate_version() -> String {
    const DOJO_VERSION: &str = env!("CARGO_PKG_VERSION");
    let scarb_version = scarb::version::get().version;
    let scarb_sierra_version = scarb::version::get().sierra.version;
    let scarb_cairo_version = scarb::version::get().cairo.version;

    let version_string = format!(
        "{}\nscarb: {}\ncairo: {}\nsierra: {}",
        DOJO_VERSION, scarb_version, scarb_cairo_version, scarb_sierra_version,
    );
    version_string
}

/// Verifies that the Cairo version specified in the manifest file is compatible with the current
/// version of Cairo used by Dojo.
pub fn verify_cairo_version_compatibility(manifest_path: &Utf8PathBuf) -> Result<()> {
    let scarb_cairo_version = scarb::version::get().cairo;

    let Ok(manifest) = TomlManifest::read_from_path(manifest_path) else {
        return Ok(());
    };
    let Some(package) = manifest.package else {
        return Ok(());
    };
    let Some(cairo_version) = package.cairo_version else {
        return Ok(());
    };

    let version_req = cairo_version.as_defined().unwrap();
    let version = Version::from_str(scarb_cairo_version.version).unwrap();

    trace!(version_req = %version_req, version = %version, "Cairo version compatibility.");

    if !version_req.matches(&version) {
        anyhow::bail!(
            "Cairo version `{version_req}` specified in the manifest file `{manifest_path}` is not supported by dojo, which is expecting `{version}`. \
             Please verify and update dojo or change the Cairo version in the manifest file.",
        );
    };

    Ok(())
}

#[derive(Debug, Default, Serialize, Deserialize)]
#[serde(rename_all = "kebab-case")]
pub struct Props {
    pub build_external_contracts: Option<Vec<ContractSelector>>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContractSelector(String);

impl ContractSelector {
    fn package(&self) -> PackageName {
        let parts = self
            .0
            .split_once(CAIRO_PATH_SEPARATOR)
            .unwrap_or((self.0.as_str(), ""));
        PackageName::new(parts.0)
    }

    /// Returns the path with the model name in snake case.
    /// This is used to match the output of the `compile()` function and Dojo plugin naming for
    /// models contracts.
    fn path_with_model_snake_case(&self) -> String {
        let (path, last_segment) = self
            .0
            .rsplit_once(CAIRO_PATH_SEPARATOR)
            .unwrap_or(("", &self.0));

        // We don't want to snake case the whole path because some of names like `erc20`
        // will be changed to `erc_20`, and leading to invalid paths.
        // The model name has to be snaked case as it's how the Dojo plugin names the Model's
        // contract.
        format!(
            "{}{}{}",
            path,
            CAIRO_PATH_SEPARATOR,
            last_segment.to_case(Case::Snake)
        )
    }

    /// Checks if the contract selector is/has a wildcard.
    /// Wildcard selectors are only supported in the last segment of the path.
    pub fn is_wildcard(&self) -> bool {
        self.0.ends_with(GLOB_PATH_SELECTOR)
    }

    /// Returns the partial path without the wildcard.
    pub fn partial_path(&self) -> String {
        let parts = self
            .0
            .split_once(GLOB_PATH_SELECTOR)
            .unwrap_or((self.0.as_str(), ""));
        parts.0.to_string()
    }

    /// Returns the full path.
    pub fn full_path(&self) -> String {
        self.0.clone()
    }

    /// Checks if the contract path matches the selector with wildcard support.
    pub fn matches(&self, contract_path: &str) -> bool {
        if self.is_wildcard() {
            contract_path.starts_with(&self.partial_path())
        } else {
            contract_path == self.path_with_model_snake_case()
        }
    }
}

impl Compiler for DojoCompiler {
    fn target_kind(&self) -> TargetKind {
        TargetKind::new("dojo")
    }

    fn compile(
        &self,
        unit: CairoCompilationUnit,
        db: &mut RootDatabase,
        ws: &Workspace<'_>,
    ) -> Result<()> {
        let props: Props = unit.main_component().target_props()?;
        verify_props(&props)?;

        let main_crate_ids = collect_main_crate_ids(&unit, db);
        let compiler_config = build_compiler_config(&unit, &main_crate_ids, ws);

        trace!(unit = %unit.name(), ?props, "Compiling unit dojo compiler.");

        let contracts = find_project_contracts(
            db,
            main_crate_ids.clone(),
            props.build_external_contracts.clone(),
            &ws.config().ui(),
        )?;

        compile_contracts(
            db,
            &contracts,
            compiler_config,
            &ws.config().ui(),
            self.output_debug_info,
        )?;

        // TODO: write artifacts to disk.

        Ok(())
    }
}

/// Verifies the props are correct.
///
/// Currently, it verifies that the external contracts path do not have multiple global path selectors.
fn verify_props(props: &Props) -> Result<()> {
    if let Some(external_contracts) = props.build_external_contracts.clone() {
        for path in external_contracts.iter() {
            if path.0.matches(GLOB_PATH_SELECTOR).count() > 1 {
                anyhow::bail!("external contract path `{}` has multiple global path selectors, only one '*' selector is allowed",
                path.0);
            }
        }
    }

    Ok(())
}

/// Finds the contracts in the project.
///
/// First searches for internal contracts in the main crates.
/// Then searches for external contracts in the external crates.
fn find_project_contracts(
    db: &mut RootDatabase,
    main_crate_ids: Vec<CrateId>,
    external_contracts: Option<Vec<ContractSelector>>,
    ui: &Ui,
) -> Result<Vec<ContractDeclaration>> {
    let internal_contracts = {
        let _ = trace_span!("find_internal_contracts").enter();
        find_contracts(db, &main_crate_ids)
    };

    let external_contracts = if let Some(external_contracts) = external_contracts {
        let _ = trace_span!("find_external_contracts").enter();
        trace!(external_contracts = ?external_contracts, "External contracts selectors from manifest.");

        let crate_ids = collect_crates_ids_from_selectors(db, &external_contracts);

        let filtered_contracts: Vec<ContractDeclaration> = find_contracts(db, crate_ids.as_ref())
            .into_iter()
            .filter(|decl| {
                let contract_path = decl.module_id().full_path(db);
                external_contracts
                    .iter()
                    .any(|selector| selector.matches(&contract_path))
            })
            .collect::<Vec<ContractDeclaration>>();

        // Display warnings for external contracts that were not found, due to invalid paths
        // most of the time.
        external_contracts
            .iter()
            .filter(|selector| {
                !filtered_contracts.iter().any(|decl| {
                    let contract_path = decl.module_id().full_path(db);
                    selector.matches(&contract_path)
                })
            })
            .for_each(|selector| {
                let diagnostic = format!("No contract found for path `{}`.", selector.full_path());
                ui.warn(diagnostic);
            });

        // Display contracts that were found.
        let contract_paths = filtered_contracts
            .iter()
            .map(|decl| decl.module_id().full_path(db))
            .collect::<Vec<_>>();

        trace!(contracts = ?contract_paths, "Collecting all the contracts eligible for compilation.");

        filtered_contracts
    } else {
        trace!("No external contracts found in the manifest.");
        Vec::new()
    };

    Ok(internal_contracts
        .into_iter()
        .chain(external_contracts)
        .collect())
}

/// Compiles the contracts.
fn compile_contracts(
    db: &mut RootDatabase,
    contracts: &[ContractDeclaration],
    compiler_config: CompilerConfig,
    ui: &Ui,
    do_output_debug_info: bool,
) -> Result<CompiledArtifactByPath> {
    let contracts: Vec<&ContractDeclaration> = contracts.iter().collect::<Vec<_>>();

    let classes = {
        let _ = trace_span!("compile_starknet").enter();
        compile_prepared_db(db, &contracts, compiler_config)?
    };

    let debug_info_classes: Vec<Option<SierraToCairoDebugInfo>> = if do_output_debug_info {
        let debug_classes =
            crate::scarb_internal::debug::compile_prepared_db_to_debug_info(db, &contracts)?;

        debug_classes
            .into_iter()
            .map(|d| Some(crate::scarb_internal::debug::get_sierra_to_cairo_debug_info(&d, db)))
            .collect()
    } else {
        vec![None; contracts.len()]
    };

    let mut compiled_classes: CompiledArtifactByPath = HashMap::new();
    let list_selector = ListSelector::default();

    for (decl, contract_class, debug_info) in izip!(contracts, classes, debug_info_classes) {
        let contract_name = decl.submodule_id.name(db.upcast_mut());
        // note that the qualified path is in snake case while
        // the `full_path()` method of StructId uses the original struct name case.
        // (see in `get_dojo_model_artifacts`)
        let qualified_path = decl.module_id().full_path(db.upcast_mut());

        match contract_class.validate_version_compatible(list_selector.clone()) {
            Ok(()) => {}
            Err(AllowedLibfuncsError::UnsupportedLibfunc {
                invalid_libfunc,
                allowed_libfuncs_list_name: _,
            }) => {
                let diagnostic = format! {r#"
                    Contract `{contract_name}` ({qualified_path}) includes `{invalid_libfunc}` function that is not allowed in the default libfuncs for public Starknet networks (mainnet, sepolia).
                    It will work on Katana, but don't forget to remove it before deploying on a public Starknet network.
                "#};

                ui.warn(diagnostic);
            }
            Err(e) => {
                return Err(e).with_context(|| {
                    format!(
                        "Failed to check allowed libfuncs for contract: {}",
                        contract_name
                    )
                });
            }
        }

        let class_hash =
            compute_class_hash_of_contract_class(&contract_class).with_context(|| {
                format!(
                    "problem computing class hash for contract `{}`",
                    qualified_path.clone()
                )
            })?;

        compiled_classes.insert(
            qualified_path,
            CompiledArtifact {
                class_hash,
                contract_class: Rc::new(contract_class),
                debug_info: debug_info.map(Rc::new),
            },
        );
    }

    Ok(compiled_classes)
}

/// Computes the class hash of a contract class.
fn compute_class_hash_of_contract_class(class: &ContractClass) -> Result<Felt> {
    let class_str = serde_json::to_string(&class)?;
    let sierra_class = serde_json::from_str::<SierraClass>(&class_str)
        .map_err(|e| anyhow!("error parsing Sierra class: {e}"))?;
    sierra_class
        .class_hash()
        .map_err(|e| anyhow!("problem hashing sierra contract: {e}"))
}

/// Collects the main crate ids for Dojo including the core crates.
pub fn collect_main_crate_ids(unit: &CairoCompilationUnit, db: &RootDatabase) -> Vec<CrateId> {
    let mut main_crate_ids = scarb::compiler::helpers::collect_main_crate_ids(&unit, db);

    if unit.main_package_id.name.to_string() != "dojo" {
        let core_crate_ids: Vec<CrateId> = collect_crates_ids_from_selectors(
            db,
            &[
                ContractSelector("dojo::contract::base_contract::base".to_string()),
                ContractSelector("dojo::world::world_contract::world".to_string()),
            ],
        );

        main_crate_ids.extend(core_crate_ids);
    }

    main_crate_ids
}
/// Collects the crate ids containing the given contract selectors.
pub fn collect_crates_ids_from_selectors(
    db: &RootDatabase,
    contract_selectors: &[ContractSelector],
) -> Vec<CrateId> {
    contract_selectors
        .iter()
        .map(|selector| selector.package().into())
        .unique()
        .map(|package_name: SmolStr| db.intern_crate(CrateLongId::Real(package_name)))
        .collect::<Vec<_>>()
}
