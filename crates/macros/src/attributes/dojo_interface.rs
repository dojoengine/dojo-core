use crate::diagnostic_ext::DiagnosticsExt;
use crate::token_stream_ext::{TokenStreamExt, TokenStreamsExt};
use cairo_lang_macro::{attribute_macro, Diagnostic, Diagnostics, ProcMacroResult, TokenStream};
use cairo_lang_parser::utils::SimpleParserDatabase;
use cairo_lang_syntax::node::db::SyntaxGroup;
use cairo_lang_syntax::node::helpers::BodyItems;
use cairo_lang_syntax::node::kind::SyntaxKind::ItemTrait;
use cairo_lang_syntax::node::{ast, Terminal, TypedSyntaxNode};
use std::collections::HashMap;

use crate::syntax::self_param;
use crate::syntax::world_param::{self, WorldParamInjectionKind};

const DOJO_INTERFACE_ATTR: &str = "dojo_interface";

#[attribute_macro]
pub fn dojo_interface(_args: TokenStream, token_stream: TokenStream) -> ProcMacroResult {
    let db = SimpleParserDatabase::default();
    let (syn_file, _diagnostics) = db.parse_virtual_with_diagnostics(token_stream);

    for n in syn_file.descendants(&db) {
        if n.kind(&db) == ItemTrait {
            let trait_ast = ast::ItemTrait::from_syntax_node(&db, n);

            match DojoInterface::from_trait(&db, &trait_ast) {
                Some(interface) => {
                    return ProcMacroResult::new(interface.token_stream)
                        .with_diagnostics(Diagnostics::new(interface.diagnostics));
                }
                None => return ProcMacroResult::new(TokenStream::empty()),
            };
        }
    }

    ProcMacroResult::new(TokenStream::empty())
}

#[derive(Debug)]
pub struct DojoInterface {
    pub token_stream: TokenStream,
    pub diagnostics: Vec<Diagnostic>,
}

impl DojoInterface {
    pub fn from_trait(db: &dyn SyntaxGroup, trait_ast: &ast::ItemTrait) -> Option<DojoInterface> {
        let name = trait_ast.name(db).text(db);

        let mut interface = DojoInterface {
            token_stream: TokenStream::empty(),
            diagnostics: vec![],
        };

        let mut nodes = vec![];

        if let ast::MaybeTraitBody::Some(body) = trait_ast.body(db) {
            let body_nodes: Vec<_> = body
                .items_vec(db)
                .iter()
                .map(|el| {
                    if let ast::TraitItem::Function(ref fn_ast) = el {
                        return interface.rewrite_function(db, fn_ast.clone());
                    }

                    interface.diagnostics.push_error(format!(
                        "Anything other than functions is not supported in a \
                                  {DOJO_INTERFACE_ATTR}."
                    ));

                    TokenStream::empty()
                })
                .collect();

            nodes.push(TokenStream::interpolate_patched(
                "
                #[starknet::interface]
                pub trait $name$<TContractState> {
                    $body$
                }
                ",
                &HashMap::from([
                    ("name".to_string(), name.to_string()),
                    (
                        "body".to_string(),
                        body_nodes.join_to_token_stream("\n").to_string(),
                    ),
                ]),
            ));
        } else {
            nodes.push(TokenStream::interpolate_patched(
                "
                #[starknet::interface]
                pub trait $name$<TContractState> {}
                ",
                &HashMap::from([("name".to_string(), name.to_string())]),
            ));
        }

        interface.token_stream = nodes.join_to_token_stream("");

        crate::debug_expand(
            &format!("INTERFACE PATCH: {name}"),
            &interface.token_stream.to_string(),
        );

        Some(interface)
    }

    /// Rewrites parameter list by adding `self` parameter based on the `world` parameter.
    pub fn rewrite_parameters(
        &mut self,
        db: &dyn SyntaxGroup,
        param_list: ast::ParamList,
    ) -> String {
        let mut params = param_list
            .elements(db)
            .iter()
            .map(|e| e.as_syntax_node().get_text(db))
            .collect::<Vec<_>>();

        let is_self_used = self_param::check_parameter(db, &param_list);

        let world_injection =
            world_param::parse_world_injection(db, param_list, &mut self.diagnostics);

        if is_self_used && world_injection != WorldParamInjectionKind::None {
            self.diagnostics
                .push_error("You cannot use `self` and `world` parameters together.".to_string());
        }

        match world_injection {
            WorldParamInjectionKind::None => {
                if !is_self_used {
                    params.insert(0, "self: @TContractState".to_string());
                }
            }
            WorldParamInjectionKind::View => {
                params.remove(0);
                params.insert(0, "self: @TContractState".to_string());
            }
            WorldParamInjectionKind::External => {
                params.remove(0);
                params.insert(0, "ref self: TContractState".to_string());
            }
        };

        params.join(", ")
    }

    /// Rewrites function declaration by adding `self` parameter if missing,
    pub fn rewrite_function(
        &mut self,
        db: &dyn SyntaxGroup,
        fn_ast: ast::TraitItemFunction,
    ) -> TokenStream {
        let fn_name = fn_ast.declaration(db).name(db).text(db);
        let return_type = fn_ast
            .declaration(db)
            .signature(db)
            .ret_ty(db)
            .as_syntax_node()
            .get_text(db);

        let params_str =
            self.rewrite_parameters(db, fn_ast.declaration(db).signature(db).parameters(db));

        let declaration_node =
            TokenStream::new(format!("fn {}({}) {};", fn_name, params_str, return_type));

        declaration_node
    }
}
