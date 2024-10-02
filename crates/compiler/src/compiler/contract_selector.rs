//! Contract selector for the Dojo compiler.
//!
//! The contract selector is used to select contracts to be compiled, and identify the contracts
//! inside the database using glob patterns and Cairo qualified paths.

use anyhow::Result;
use convert_case::{Case, Casing};
use scarb::core::PackageName;
use serde::{Deserialize, Serialize};

pub const GLOB_PATH_SELECTOR: &str = "*";
pub const CAIRO_PATH_SEPARATOR: &str = "::";

#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub struct ContractSelector(String);

impl ContractSelector {
    pub fn new(path: String) -> Self {
        Self(path)
    }

    pub fn package(&self) -> PackageName {
        let parts = self
            .0
            .split_once(CAIRO_PATH_SEPARATOR)
            .unwrap_or((self.0.as_str(), ""));
        PackageName::new(parts.0)
    }

    /// Returns the path with the model name in snake case.
    /// This is used to match the output of the `compile()` function and Dojo plugin naming for
    /// models contracts.
    pub fn path_with_model_snake_case(&self) -> String {
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

    /// Validates the contract selector.
    /// The contract selector is valid if it has at most one wildcard.
    pub fn is_valid(&self) -> Result<()> {
        if self.full_path().matches(GLOB_PATH_SELECTOR).count() > 1 {
            anyhow::bail!("Contract path `{}` has multiple wildcard selectors, only one '*' selector is allowed.",
            self.full_path());
        }

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_package() {
        let selector = ContractSelector::new("my_package::my_contract".to_string());
        assert_eq!(selector.package(), PackageName::new("my_package"));

        let selector_no_separator = ContractSelector::new("my_package".to_string());
        assert_eq!(
            selector_no_separator.package(),
            PackageName::new("my_package")
        );
    }

    #[test]
    fn test_path_with_model_snake_case() {
        let selector = ContractSelector::new("my_package::MyContract".to_string());
        assert_eq!(
            selector.path_with_model_snake_case(),
            "my_package::my_contract"
        );

        let selector_multiple_segments =
            ContractSelector::new("my_package::sub_package::MyContract".to_string());
        assert_eq!(
            selector_multiple_segments.path_with_model_snake_case(),
            "my_package::sub_package::my_contract"
        );

        // In snake case, erc20 should be erc_20. This test ensures that the path is converted to snake
        // case only for the model's name.
        let selector_erc20 = ContractSelector::new("my_package::erc20::Token".to_string());
        assert_eq!(
            selector_erc20.path_with_model_snake_case(),
            "my_package::erc20::token"
        );
    }

    #[test]
    fn test_full_path() {
        let selector = ContractSelector::new("my_package::sub_package::MyContract".to_string());
        assert_eq!(selector.full_path(), "my_package::sub_package::MyContract");
    }

    #[test]
    fn test_is_valid() {
        let valid_selector =
            ContractSelector::new("my_package::sub_package::MyContract".to_string());
        assert!(valid_selector.is_valid().is_ok());

        let invalid_selector = ContractSelector::new("my_package::*::*::MyContract".to_string());
        assert!(invalid_selector.is_valid().is_err());
    }

    #[test]
    fn test_matches() {
        let selector = ContractSelector::new("my_package::*".to_string());
        assert!(selector.matches("my_package::sub_package::MyContract"));
        assert!(selector.matches("my_package::other_package::MyContract"));
        assert!(!selector.matches("other_package::sub_package::MyContract"));
        assert!(!selector.matches("package::sub_package::OtherContract"));
    }
}
