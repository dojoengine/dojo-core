pub mod models {
    use starknet::ContractAddress;

    #[derive(Drop, Serde)]
    #[dojo::model(namespace: "ns1")]
    pub struct UnmappedModel {
        #[key]
        pub id: u32,
        pub data: u32,
    }

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

pub mod events {
    use starknet::ContractAddress;

    #[derive(Drop, Serde)]
    #[dojo::event]
    pub struct PositionUpdated {
        #[key]
        pub player: ContractAddress,
        pub new_x: u32,
        pub new_y: u32,
    }
}

#[dojo::interface]
pub trait IActions {
    fn spawn(ref world: IWorldDispatcher);
}

#[dojo::contract]
pub mod actions {
    use dojo::model::ModelStore;
    use super::{IActions, models::{Position}, events::PositionUpdated};

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
            let position: Position = world.get(caller);
            world.set(position);

            emit!(world, PositionUpdated { player: caller, new_x: 1, new_y: 2 });
        }
    }
}

#[starknet::contract]
pub mod sn_actions {
    #[storage]
    struct Storage {}
}

#[cfg(test)]
mod tests {
    #[test]
    fn test_spawn_world_full() {
        let _world = spawn_test_world!();
    }
}
