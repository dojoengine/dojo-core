pub mod models {
    use starknet::ContractAddress;

    #[derive(Drop, Serde)]
    #[dojo::model]
    pub struct Position {
        #[key]
        pub player: ContractAddress,
        pub x: u32,
        pub y: u32,
    }

    #[derive(Drop, Serde)]
    #[dojo::model]
    pub struct ModelA {
        #[key]
        pub id: u32,
        pub a: felt252,
    }
}

#[dojo::interface]
pub trait IActions {
    fn spawn(ref world: IWorldDispatcher);
}

#[dojo::contract]
pub mod actions {
    use super::{IActions, models::{Position, PositionStore}};

    #[derive(Drop, Serde)]
    #[dojo::model]
    pub struct ModelInContract {
        #[key]
        pub id: u32,
        pub a: u8,
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref world: IWorldDispatcher) {
            let caller = starknet::get_caller_address();

            let position = Position { player: caller, x: 1, y: 2 };
            position.set(world);
        }
    }
}

#[starknet::contract]
pub mod sn_actions {

    #[storage]
    struct Storage {}

}
