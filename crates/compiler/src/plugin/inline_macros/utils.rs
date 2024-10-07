use std::collections::HashSet;

use cairo_lang_defs::plugin::PluginDiagnostic;
use cairo_lang_diagnostics::Severity;
use cairo_lang_filesystem::cfg::CfgSet;
use cairo_lang_syntax::node::ast::{self, ExprPath, ExprStructCtorCall};
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::kind::SyntaxKind;
use cairo_lang_syntax::node::{SyntaxNode, TypedStablePtr, TypedSyntaxNode};
use camino::Utf8PathBuf;
use dojo_types::naming;
use scarb::compiler::Profile;
use scarb::core::Config;

use crate::compiler::annotation::{AnnotationInfo, DojoAnnotation};
use crate::namespace_config::{DOJO_ANNOTATIONS_DIR_CFG_KEY, WORKSPACE_CURRENT_PROFILE_CFG_KEY};

#[derive(Debug)]
pub enum SystemRWOpRecord {
    StructCtor(ExprStructCtorCall),
    Path(ExprPath),
}

pub fn parent_of_kind(
    db: &dyn cairo_lang_syntax::node::db::SyntaxGroup,
    target: &SyntaxNode,
    kind: SyntaxKind,
) -> Option<SyntaxNode> {
    let mut new_target = target.clone();
    while let Some(parent) = new_target.parent() {
        if kind == parent.kind(db) {
            return Some(parent);
        }
        new_target = parent;
    }
    None
}

/// Reads all the resources and namespaces from annotations.
pub fn load_resources_and_namespaces_from_annotations(
    cfg_set: &CfgSet,
    whitelisted_namespaces: &[String],
) -> anyhow::Result<(Vec<String>, Vec<String>, Vec<String>)> {
    fn process_annotations<T: AnnotationInfo>(
        whitelisted_namespaces: &[String],
        annotations: &Vec<T>,
        namespaces: &mut HashSet<String>,
    ) -> anyhow::Result<Vec<String>> {
        let mut output = HashSet::<String>::new();
        for annotation in annotations {
            let qualified_path = annotation.qualified_path();
            let namespace = naming::split_tag(&annotation.tag())?.0;

            if !whitelisted_namespaces.is_empty() && !whitelisted_namespaces.contains(&namespace) {
                continue;
            }

            output.insert(qualified_path);
            namespaces.insert(namespace);
        }

        Ok(output.into_iter().collect())
    }

    let dojo_annotations_dir = get_dojo_annotations_dir(cfg_set.clone())?;
    let scarb_toml = dojo_annotations_dir
        .parent()
        .expect("Profile dir should have parent")
        .parent()
        .expect("Annotations dir dir should have parent")
        .join("Scarb.toml");

    let config = Config::builder(scarb_toml.clone())
        .profile(Profile::new(get_current_profile(cfg_set.clone())?.into())?)
        .build()?;

    let ws = scarb::ops::read_workspace(config.manifest_path(), &config)?;

    let annotations = DojoAnnotation::read(&ws)?;

    let mut namespaces = HashSet::<String>::new();

    let models_vec =
        process_annotations(whitelisted_namespaces, &annotations.models, &mut namespaces)?;
    let events_vec =
        process_annotations(whitelisted_namespaces, &annotations.events, &mut namespaces)?;

    let namespaces_vec: Vec<String> = namespaces.into_iter().collect();

    Ok((namespaces_vec, models_vec, events_vec))
}

/// Gets the Dojo annotations directory for the current profile from the cfg_set.
pub fn get_dojo_annotations_dir(cfg_set: CfgSet) -> anyhow::Result<Utf8PathBuf> {
    for cfg in cfg_set.into_iter() {
        if cfg.key == DOJO_ANNOTATIONS_DIR_CFG_KEY {
            return Ok(Utf8PathBuf::from(cfg.value.unwrap().as_str().to_string()));
        }
    }

    Err(anyhow::anyhow!("dojo_annotations_dir not found"))
}

/// Gets the current profile from the cfg_set.
pub fn get_current_profile(cfg_set: CfgSet) -> anyhow::Result<String> {
    for cfg in cfg_set.into_iter() {
        if cfg.key == WORKSPACE_CURRENT_PROFILE_CFG_KEY {
            return Ok(cfg.value.unwrap().as_str().to_string());
        }
    }

    Err(anyhow::anyhow!("current profile not found"))
}

/// Extracts the namespaces from a fixed size array of strings.
pub fn extract_namespaces(
    db: &dyn SyntaxGroup,
    expression: &ast::Expr,
) -> Result<Vec<String>, PluginDiagnostic> {
    let mut namespaces = vec![];

    match expression {
        ast::Expr::FixedSizeArray(array) => {
            for element in array.exprs(db).elements(db) {
                if let ast::Expr::String(string_literal) = element {
                    namespaces.push(
                        string_literal
                            .as_syntax_node()
                            .get_text(db)
                            .replace('\"', ""),
                    );
                } else {
                    return Err(PluginDiagnostic {
                        stable_ptr: element.stable_ptr().untyped(),
                        message: "Expected a string literal".to_string(),
                        severity: Severity::Error,
                    });
                }
            }
        }
        _ => {
            return Err(PluginDiagnostic {
                stable_ptr: expression.stable_ptr().untyped(),
                message: "The list of namespaces should be a fixed size array of strings."
                    .to_string(),
                severity: Severity::Error,
            });
        }
    }

    Ok(namespaces)
}
