#[starknet::contract]
pub mod sn_actions {
    #[storage]
    struct Storage {}
}

// MODELS nested in contracts not supported anymore.

#[dojo_model(namespace: "sn")]
struct InnerModel {
    #[key]
    id: u32,
    data: felt252,
}

#[dojo_contract(namespace: "sn")]
pub mod dojo_1 {
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_1() {
        
    }
}
