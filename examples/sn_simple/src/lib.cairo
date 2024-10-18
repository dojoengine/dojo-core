use dojo::world::IWorldDispatcher;

#[starknet::contract]
pub mod sn_actions {
    #[storage]
    struct Storage {}
}

#[derive(Introspect, Drop, Serde)]
#[dojo_model]
pub struct M {
    #[key]
    pub a: felt252,
    pub b: felt252,
}

#[dojo_interface]
pub trait MyInterface {
    fn system_1(ref world: IWorldDispatcher, data: felt252) -> felt252;
    fn system_2(ref world: IWorldDispatcher);
    fn view_1(world: @IWorldDispatcher) -> felt252;
}

#[dojo_contract]
pub mod c1 {
    use super::MyInterface;

    #[abi(embed_v0)]
    impl MyInterfaceImpl of MyInterface<ContractState> {
        fn system_1(ref world: IWorldDispatcher, data: felt252) -> felt252 {
            let _world = world;
            42
        }

        fn system_2(ref world: IWorldDispatcher) {
            let _world = world;
        }

        fn view_1(world: @IWorldDispatcher) -> felt252 {
            let _world = world;
            89
        }
    }
}

#[derive(Introspect, Drop, Serde)]
#[dojo_event]
pub struct MyEvent {
    #[key]
    pub a: felt252,
    pub b: felt252,
}

#[cfg(test)]
mod tests {
    use dojo::utils::snf_test::{spawn_test_world, TestResource, WorldTestExt, NamespaceDef};
    use dojo::model::ModelStore;
    use dojo::world::WorldStorageTrait;
    use super::{MyEvent, MyEventEmitter, M};

    #[test]
    fn dojo_event_emit() {
        let ns = "sn".to_string();

        let resources: Span<TestResource> = [
            TestResource::Event("my_event"),
            TestResource::Model("m"),
        ].span();

        let namespace_def = NamespaceDef {
            namespace: ns.clone(),
            resources: resources,
        };

        let world = spawn_test_world([namespace_def].span());

        let world_storage = WorldStorageTrait::new(world, ns);

        world_storage.set(@M { a: 1, b: 2 });
        let m: M = world_storage.get(1);
        assert(m.a == 1, 'bad a');
        assert(m.b == 2, 'bad b');

        let e1 = MyEvent { a: 1, b: 2 };
        e1.emit(world);

        let _e1_address = world_storage.world.resource_contract_address("sn", "MyEvent");
    }
}
