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

#[dojo_contract(namespace: "sn")]
pub mod c1 {
}

#[cfg(test)]
mod tests {
    //use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};

    #[test]
    fn test_1() {
        // First declare and deploy a contract
        // let contract = declare("m").unwrap().contract_class();
        // Alternatively we could use `deploy_syscall` here
        //let (contract_address, _) = contract.deploy(@array![]).unwrap();
        assert(true, 'aa');
    }
}
