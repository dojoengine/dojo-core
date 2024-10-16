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


    #[derive(Drop, Serde)]
    pub struct Point {
        pub x: u32,
        pub y: u32,
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
    fn despawn(ref world: IWorldDispatcher);
    fn move(ref world: IWorldDispatcher, new_x: u32, new_y: u32);
    fn get_position(world: @IWorldDispatcher) -> models::Point;
    fn get_x(world: @IWorldDispatcher) -> u32;
    fn get_y(world: @IWorldDispatcher) -> u32;
}

#[dojo::contract]
pub mod actions {
    use dojo::model::ModelStore;
    use super::{
        IActions,
        models::{Position, PositionEntity, PositionMembersStore, Point},
        events::PositionUpdated
    };

    #[derive(Drop, Serde)]
    #[dojo::model]
    pub struct ModelInContract {
        #[key]
        pub id: u32,
        pub a: u8,
    }

    fn dojo_init(ref world: IWorldDispatcher, id: u32, a: u8) {
        let m = ModelInContract { id, a };
        world.set(@m);
    }

    #[abi(embed_v0)]
    impl ActionsImpl of IActions<ContractState> {
        fn spawn(ref world: IWorldDispatcher) {
            let caller = starknet::get_caller_address();

            let position = Position { player: caller, x: 1, y: 2 };

            world.set(@position);
            let _position: Position = world.get(caller);
            emit!(world, PositionUpdated { player: caller, new_x: 1, new_y: 2 });
        }

        fn despawn(ref world: IWorldDispatcher) {
            let caller = starknet::get_caller_address();
            ModelStore::<Position>::delete_from_key(world, caller);
        }

        fn move(ref world: IWorldDispatcher, new_x: u32, new_y: u32) {
            let caller = starknet::get_caller_address();
            let mut position: Position = world.get(caller);
            position.x = new_x;
            position.y = new_y;
            world.set(@position);
            emit!(world, PositionUpdated { player: caller, new_x, new_y });
        }

        fn get_position(world: @IWorldDispatcher) -> Point {
            let caller = starknet::get_caller_address();
            let entity: PositionEntity = world.get_entity(caller);
            Point { x: entity.x, y: entity.y }
        }

        fn get_x(world: @IWorldDispatcher) -> u32 {
            let caller = starknet::get_caller_address();
            PositionMembersStore::get_x(@world, caller)
        }

        fn get_y(world: @IWorldDispatcher) -> u32 {
            let caller = starknet::get_caller_address();
            PositionMembersStore::get_y(@world, caller)
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
    use dojo::world::IWorldDispatcherTrait;
    use dojo::model::ModelStore;
    use super::actions::ModelInContract;

    #[test]
    fn test_spawn_world_full() {
        let _world = spawn_test_world!();
    }

    #[test]
    fn test_dojo_init_flow() {
        let world = spawn_test_world!();

        let actions_addr = world
            .register_contract('salt1', super::actions::TEST_CLASS_HASH.try_into().unwrap());

        world.grant_writer(dojo::utils::bytearray_hash(@"ds"), actions_addr);

        world.init_contract(selector_from_tag!("ds-actions"), [10, 20].span());
        
        let model: ModelInContract = world.get(10);
        assert_eq!(model.a, 20);
    }
}

