//! `dojo_contract` attribute macro.
//!
//!

use cairo_lang_macro::{
    attribute_macro, AuxData, Diagnostic, Diagnostics, ProcMacroResult, TokenStream,
};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::{BodyItems, QueryAttrs};
use cairo_lang_syntax::node::kind::SyntaxKind::ItemModule;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};

use std::collections::HashMap;

use cairo_lang_syntax::node::ast::{
    MaybeModuleBody, OptionReturnTypeClause,
};
use dojo_types::naming;

use crate::aux_data::ContractAuxData;
use crate::diagnostic_ext::DiagnosticsExt;
use crate::syntax::utils::parse_arguments_kv;
use crate::syntax::world_param::{self, WorldParamInjectionKind};
use crate::syntax::{self_param, utils as syntax_utils};
use crate::token_stream_ext::{TokenStreamExt, TokenStreamsExt};

use super::patches::{CONTRACT_PATCH, DEFAULT_INIT_PATCH};
use super::struct_parser::validate_namings_diagnostics;

const DOJO_CONTRACT_ATTR: &str = "dojo_contract";
const CONSTRUCTOR_FN: &str = "constructor";
const DOJO_INIT_FN: &str = "dojo_init";
const CONTRACT_NAMESPACE: &str = "namespace";

#[attribute_macro]
pub fn dojo_contract(args: TokenStream, token_stream: TokenStream) -> ProcMacroResult {
    println!("args: {}", args);

    // Arguments of the macro are already parsed. Hence, we can't use the query_attr since the
    // attribute that triggered the macro execution is not available in the syntax node.
    let parsed_args = parse_arguments_kv(&args.to_string());

    let contract_namespace = if let Some(contract_namespace) = parsed_args.get(CONTRACT_NAMESPACE) {
        contract_namespace.to_string()
    } else {
        return ProcMacroResult::new(TokenStream::empty())
            .with_diagnostics(Diagnostics::new(vec![Diagnostic::error(
                format!("{DOJO_CONTRACT_ATTR} attribute requires a '{CONTRACT_NAMESPACE}' argument. Use `#[{DOJO_CONTRACT_ATTR} ({CONTRACT_NAMESPACE}: \"<namespace>\")]` to specify the namespace.",
                ))]));
    };

    let db = SimpleParserDatabase::default();
    let (syn_file, _diagnostics) = db.parse_virtual_with_diagnostics(token_stream);

    for n in syn_file.descendants(&db) {
        // Process only the first module expected to be the contract.
        if n.kind(&db) == ItemModule {
            let module_ast = ast::ItemModule::from_syntax_node(&db, n);

            // TODO: for the error, we need more information like line number of at least the file name.
            // Check first the behavior on error.
            match DojoContract::from_module(&contract_namespace, &db, &module_ast) {
                Some(c) => {
                    return ProcMacroResult::new(c.token_stream)
                        .with_diagnostics(Diagnostics::new(c.diagnostics))
                        .with_aux_data(AuxData::new(
                            serde_json::to_vec(&ContractAuxData {
                                name: c.name.to_string(),
                                namespace: c.namespace.to_string(),
                                systems: c.systems.clone(),
                            })
                            .expect("Failed to serialize contract aux data to bytes"),
                        ))
                }
                None => return ProcMacroResult::new(TokenStream::empty()),
            };
        }
    }

    ProcMacroResult::new(TokenStream::empty())
}

#[derive(Debug)]
pub struct DojoContract {
    pub name: String,
    pub namespace: String,
    pub diagnostics: Vec<Diagnostic>,
    pub systems: Vec<String>,
    pub token_stream: TokenStream,
}

impl DojoContract {
    pub fn from_module(
        contract_namespace: &str,
        db: &dyn SyntaxGroup,
        module_ast: &ast::ItemModule,
    ) -> Option<DojoContract> {
        let name = module_ast.name(db).text(db);

        let mut contract = DojoContract {
            diagnostics: vec![],
            systems: vec![],
            token_stream: TokenStream::empty(),
            name: name.to_string(),
            namespace: String::new(),
        };

        let contract_tag = naming::get_tag(&contract_namespace, &name);

        contract.namespace = contract_namespace.to_string();

        contract.diagnostics.extend(validate_attributes(db, module_ast));

        contract.diagnostics.extend(validate_namings_diagnostics(
            &[
                ("contract namespace", &contract_namespace),
                ("contract name", &name),
            ],
        ));

        let contract_name_hash = naming::compute_bytearray_hash(&name);
        let contract_namespace_hash = naming::compute_bytearray_hash(&contract_namespace);
        let contract_selector =
            naming::compute_selector_from_hashes(contract_namespace_hash, contract_name_hash);

        let mut has_event = false;
        let mut has_storage = false;
        let mut has_init = false;
        let mut has_constructor = false;

        if let MaybeModuleBody::Some(body) = module_ast.body(db) {
            // TODO: Use `.iter_items_in_cfg(db, metadata.cfg_set)` when possible
            // to ensure we don't loop on items that are not in the current cfg set.
            let mut body_nodes: Vec<TokenStream> = body
                .items_vec(db)
                .iter()
                .map(|el| {
                    if let ast::ModuleItem::Enum(ref enum_ast) = el {
                        if enum_ast.name(db).text(db).to_string() == "Event" {
                            has_event = true;

                            return contract.merge_event(db, enum_ast.clone());
                        }
                    } else if let ast::ModuleItem::Struct(ref struct_ast) = el {
                        if struct_ast.name(db).text(db).to_string() == "Storage" {
                            has_storage = true;
                            return contract.merge_storage(db, struct_ast.clone());
                        }
                    } else if let ast::ModuleItem::Impl(ref impl_ast) = el {
                        // If an implementation is not targetting the ContractState,
                        // the auto injection of self and world is not applied.
                        let trait_path = impl_ast.trait_path(db).node.get_text(db);
                        if trait_path.contains("<ContractState>") {
                            return contract.rewrite_impl(db, impl_ast.clone());
                        }
                    } else if let ast::ModuleItem::FreeFunction(ref fn_ast) = el {
                        let fn_decl = fn_ast.declaration(db);
                        let fn_name = fn_decl.name(db).text(db);

                        if fn_name == CONSTRUCTOR_FN {
                            has_constructor = true;
                            return contract.handle_constructor_fn(db, fn_ast);
                        }

                        if fn_name == DOJO_INIT_FN {
                            has_init = true;
                            return contract.handle_init_fn(db, fn_ast);
                        }
                    }

                    TokenStream::new(el.as_syntax_node().get_text(db))
                })
                .collect::<Vec<_>>();

            if !has_constructor {
                let node = TokenStream::new(
                    "
                    #[constructor]
                        fn constructor(ref self: ContractState) {
                            self.world_provider.initializer();
                        }
                    "
                    .to_string(),
                );

                body_nodes.push(node);
            }

            if !has_init {
                let node = TokenStream::interpolate_patched(
                    DEFAULT_INIT_PATCH,
                    &HashMap::from([("init_name".to_string(), DOJO_INIT_FN.to_string())]),
                );

                body_nodes.push(node);
            }

            if !has_event {
                body_nodes.push(contract.create_event());
            }

            if !has_storage {
                body_nodes.push(contract.create_storage());
            }

            let code = TokenStream::interpolate_patched(
                CONTRACT_PATCH,
                &HashMap::from([
                    ("name".to_string(), name.to_string()),
                    (
                        "body".to_string(),
                        format!("{}", body_nodes.join_to_token_stream("")),
                    ),
                    (
                        "contract_namespace".to_string(),
                        contract_namespace.to_string(),
                    ),
                    (
                        "contract_name_hash".to_string(),
                        contract_name_hash.to_string(),
                    ),
                    (
                        "contract_namespace_hash".to_string(),
                        contract_namespace_hash.to_string(),
                    ),
                    (
                        "contract_selector".to_string(),
                        contract_selector.to_string(),
                    ),
                    ("contract_tag".to_string(), contract_tag),
                ]),
            );

            crate::debug_expand(
                &format!("CONTRACT PATCH: {contract_namespace}-{name}"),
                &code.to_string(),
            );

            return Some(contract);
        }

        None
    }

    /// If a constructor is provided, we should keep the user statements.
    /// We only inject the world provider initializer.
    fn handle_constructor_fn(
        &mut self,
        db: &dyn SyntaxGroup,
        fn_ast: &ast::FunctionWithBody,
    ) -> TokenStream {
        let fn_decl = fn_ast.declaration(db);

        let params_str = self.params_to_str(db, fn_decl.signature(db).parameters(db));

        let declaration_node = TokenStream::interpolate_patched(
            "
                #[constructor]
                fn constructor($params$) {
                    self.world_provider.initializer();
                }
            ",
            &HashMap::from([("params".to_string(), params_str)]),
        );

        let func_nodes = fn_ast
            .body(db)
            .statements(db)
            .elements(db)
            .iter()
            .map(|e| TokenStream::new(e.as_syntax_node().get_text(db)))
            .collect::<Vec<_>>();

        let mut nodes = vec![declaration_node];

        nodes.extend(func_nodes);

        // Close the constructor with users statements included.
        nodes.push(TokenStream::new("}\n".to_string()));

        nodes.join_to_token_stream("")
    }

    fn handle_init_fn(
        &mut self,
        db: &dyn SyntaxGroup,
        fn_ast: &ast::FunctionWithBody,
    ) -> TokenStream {
        let fn_decl = fn_ast.declaration(db);

        if let OptionReturnTypeClause::ReturnTypeClause(_) = fn_decl.signature(db).ret_ty(db) {
            self.diagnostics.push_error(format!(
                "The {} function cannot have a return type.",
                DOJO_INIT_FN
            ));
        }

        let (params_str, was_world_injected) =
            self.rewrite_parameters(db, fn_decl.signature(db).parameters(db));

        // Since the dojo init is meant to be called by the world, we don't need an
        // interface to be generated (which adds a considerable amount of code).
        let impl_node = TokenStream::new(
            "
            #[abi(per_item)]
            #[generate_trait]
            pub impl IDojoInitImpl of IDojoInit {
                #[external(v0)]
            "
            .to_string(),
        );

        let declaration_node = TokenStream::new(format!("fn {}({}) {{", DOJO_INIT_FN, params_str));

        let world_line_node = if was_world_injected {
            TokenStream::new("let world = self.world_provider.world();".to_string())
        } else {
            TokenStream::empty()
        };

        // Asserts the caller is the world, and close the init function.
        let assert_world_caller_node = TokenStream::new(
            "if starknet::get_caller_address() != self.world_provider.world().contract_address { \
             core::panics::panic_with_byte_array(@format!(\"Only the world can init contract \
             `{}`, but caller is `{:?}`\", self.tag(), starknet::get_caller_address())); }"
                .to_string(),
        );

        let func_nodes = fn_ast
            .body(db)
            .statements(db)
            .elements(db)
            .iter()
            .map(|e| TokenStream::new(e.as_syntax_node().get_text(db)))
            .collect::<Vec<_>>();

        let mut nodes = vec![
            impl_node,
            declaration_node,
            world_line_node,
            assert_world_caller_node,
        ];
        nodes.extend(func_nodes);
        // Close the init function + close the impl block.
        nodes.push(TokenStream::new("}\n}".to_string()));

        nodes.join_to_token_stream("")
    }

    pub fn merge_event(&mut self, db: &dyn SyntaxGroup, enum_ast: ast::ItemEnum) -> TokenStream {
        let elements = enum_ast.variants(db).elements(db);

        let variants = elements
            .iter()
            .map(|e| e.as_syntax_node().get_text(db))
            .collect::<Vec<_>>();
        let variants = variants.join(",\n");

        TokenStream::interpolate_patched(
            "
            #[event]
            #[derive(Drop, starknet::Event)]
            enum Event {
                UpgradeableEvent: upgradeable_cpt::Event,
                WorldProviderEvent: world_provider_cpt::Event,
                $variants$
            }
            ",
            &HashMap::from([("variants".to_string(), variants)]),
        )
    }

    pub fn create_event(&mut self) -> TokenStream {
        TokenStream::new(
            "
            #[event]
            #[derive(Drop, starknet::Event)]
            enum Event {
                UpgradeableEvent: upgradeable_cpt::Event,
                WorldProviderEvent: world_provider_cpt::Event,
            }
            "
            .to_string(),
        )
    }

    pub fn merge_storage(
        &mut self,
        db: &dyn SyntaxGroup,
        struct_ast: ast::ItemStruct,
    ) -> TokenStream {
        let elements = struct_ast.members(db).elements(db);

        let members = elements
            .iter()
            .map(|e| e.as_syntax_node().get_text(db))
            .collect::<Vec<_>>();
        let members = members.join(",\n");

        TokenStream::interpolate_patched(
            "
            #[storage]
            struct Storage {
                #[substorage(v0)]
                upgradeable: upgradeable_cpt::Storage,
                #[substorage(v0)]
                world_provider: world_provider_cpt::Storage,
                $members$
            }
            ",
            &HashMap::from([("members".to_string(), members)]),
        )
    }

    pub fn create_storage(&mut self) -> TokenStream {
        TokenStream::new(
            "
            #[storage]
            struct Storage {
                #[substorage(v0)]
                upgradeable: upgradeable_cpt::Storage,
                #[substorage(v0)]
                world_provider: world_provider_cpt::Storage,
            }
            "
            .to_string(),
        )
    }

    /// Converts parameter list to it's string representation.
    pub fn params_to_str(&mut self, db: &dyn SyntaxGroup, param_list: ast::ParamList) -> String {
        let params = param_list
            .elements(db)
            .iter()
            .map(|param| param.as_syntax_node().get_text(db))
            .collect::<Vec<_>>();

        params.join(", ")
    }

    /// Rewrites parameter list by:
    ///  * adding `self` parameter based on the `world` parameter mutability. If `world` is not
    ///    provided, a `View` is assumed.
    ///  * removing `world` if present as first parameter, as it will be read from the first
    ///    function statement.
    ///
    /// Reports an error in case of:
    ///  * `self` used explicitly,
    ///  * multiple world parameters,
    ///  * the `world` parameter is not the first parameter and named 'world'.
    ///
    /// Returns
    ///  * the list of parameters in a String.
    ///  * true if the world has to be injected (found as the first param).
    pub fn rewrite_parameters(
        &mut self,
        db: &dyn SyntaxGroup,
        param_list: ast::ParamList,
    ) -> (String, bool) {
        let is_self_used = self_param::check_parameter(db, &param_list);

        let world_injection =
            world_param::parse_world_injection(db, param_list.clone(), &mut self.diagnostics);

        if is_self_used && world_injection != WorldParamInjectionKind::None {
            self.diagnostics.push_error(format!(
                "You cannot use `self` and `world` parameters together."
            ));
        }

        let mut params = param_list
            .elements(db)
            .iter()
            .filter_map(|param| {
                let (name, _, param_type) = syntax_utils::get_parameter_info(db, param.clone());

                // If the param is `IWorldDispatcher`, we don't need to keep it in the param list
                // as it is flatten in the first statement.
                if world_param::is_world_param(&name, &param_type) {
                    None
                } else {
                    Some(param.as_syntax_node().get_text(db))
                }
            })
            .collect::<Vec<_>>();

        match world_injection {
            WorldParamInjectionKind::None => {
                if !is_self_used {
                    params.insert(0, "self: @ContractState".to_string());
                }
            }
            WorldParamInjectionKind::View => {
                params.insert(0, "self: @ContractState".to_string());
            }
            WorldParamInjectionKind::External => {
                params.insert(0, "ref self: ContractState".to_string());
            }
        }

        (
            params.join(", "),
            world_injection != WorldParamInjectionKind::None,
        )
    }

    /// Rewrites function declaration by:
    ///  * adding `self` parameter if missing,
    ///  * removing `world` if present as first parameter (self excluded),
    ///  * adding `let world = self.world_provider.world();` statement at the beginning of the
    ///    function to restore the removed `world` parameter.
    ///  * if `has_generate_trait` is true, the implementation containing the function has the
    ///    `#[generate_trait]` attribute.
    pub fn rewrite_function(
        &mut self,
        db: &dyn SyntaxGroup,
        fn_ast: ast::FunctionWithBody,
        has_generate_trait: bool,
    ) -> Vec<String> {
        let fn_name = fn_ast.declaration(db).name(db).text(db);
        let return_type = fn_ast
            .declaration(db)
            .signature(db)
            .ret_ty(db)
            .as_syntax_node()
            .get_text(db);

        // Consider the function as a system if no return type is specified.
        if return_type.is_empty() {
            self.systems.push(fn_name.to_string());
        }

        let (params_str, was_world_injected) =
            self.rewrite_parameters(db, fn_ast.declaration(db).signature(db).parameters(db));

        let declaration_node = format!("fn {}({}) {} {{", fn_name, params_str, return_type);

        let world_line_node = if was_world_injected {
            "let world = self.world_provider.world();".to_string()
        } else {
            String::new()
        };

        let func_nodes = fn_ast
            .body(db)
            .statements(db)
            .elements(db)
            .iter()
            .map(|e| e.as_syntax_node().get_text(db))
            .collect::<Vec<_>>();

        if has_generate_trait && was_world_injected {
            self.diagnostics.push_error(format!(
                "You cannot use `world` and `#[generate_trait]` together. Use `self` \
                          instead."
            ));
        }

        let mut nodes = vec![declaration_node, world_line_node];
        nodes.extend(func_nodes);
        nodes.push("}".to_string());

        nodes
    }

    /// Rewrites all the functions of a Impl block.
    fn rewrite_impl(&mut self, db: &dyn SyntaxGroup, impl_ast: ast::ItemImpl) -> TokenStream {
        let generate_attrs = impl_ast.attributes(db).query_attr(db, "generate_trait");
        let has_generate_trait = !generate_attrs.is_empty();

        if let ast::MaybeImplBody::Some(body) = impl_ast.body(db) {
            // We shouldn't have generic param in the case of contract's endpoints.
            let impl_node = TokenStream::new(format!(
                "{} impl {} of {} {{",
                impl_ast.attributes(db).as_syntax_node().get_text(db),
                impl_ast.name(db).as_syntax_node().get_text(db),
                impl_ast.trait_path(db).as_syntax_node().get_text(db),
            ));

            let body_nodes: Vec<String> = body
                .items_vec(db)
                .iter()
                .flat_map(|el| {
                    if let ast::ImplItem::Function(ref fn_ast) = el {
                        return self.rewrite_function(db, fn_ast.clone(), has_generate_trait);
                    }
                    vec![el.as_syntax_node().get_text(db)]
                })
                .collect();

            let body_node = TokenStream::new(format!("{}", body_nodes.join("\n")));

            return vec![impl_node, body_node, TokenStream::new("}".to_string())]
                .join_to_token_stream("");
        }

        TokenStream::new(impl_ast.as_syntax_node().get_text(db))
    }
}

/// Validates the attributes of the dojo::contract attribute.
///
/// Parameters:
/// * db: The semantic database.
/// * module_ast: The AST of the contract module.
///
/// Returns:
/// * A vector of diagnostics.
fn validate_attributes(
    db: &dyn SyntaxGroup,
    module_ast: &ast::ItemModule,
) -> Vec<Diagnostic> {
    let mut diagnostics = vec![];

    if module_ast
        .attributes(db)
        .query_attr(db, DOJO_CONTRACT_ATTR)
        .first()
        .is_some()
    {
        diagnostics.push_error(format!(
            "Only one {} attribute is allowed per module.",
            DOJO_CONTRACT_ATTR
        ));
    }

    if module_ast
        .attributes(db)
        .query_attr(db, "dojo_model")
        .first()
        .is_some()
    {
        diagnostics.push_error(format!(
            "A {} can't be used together with a {}.",
            DOJO_CONTRACT_ATTR, "dojo_model"
        ));
    }

    if module_ast
        .attributes(db)
        .query_attr(db, "dojo_event")
        .first()
        .is_some()
    {
        diagnostics.push_error(format!(
            "A {} can't be used together with a {}.",
            DOJO_CONTRACT_ATTR, "dojo_event"
        ));
    }

    diagnostics
}
