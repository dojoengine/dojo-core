#[starknet::contract]
pub mod sn_actions {
    #[storage]
    struct Storage {}
}

// MODELS nested in contracts not supported anymore.


#[derive(Introspect, Drop, Serde)]
#[dojo_model(namespace: "sn")]
pub struct M {
    #[key]
    pub a: felt252,
    pub b: felt252,
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_1() {
        
    }
}
