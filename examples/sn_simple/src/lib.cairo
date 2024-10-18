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

#[cfg(test)]
mod tests {
    use dojo::utils::snf_test::{spawn_test_world, TestResource, NamespaceDef};
    use dojo::model::ModelStore;
    use dojo::world::WorldStorageTrait;
    use super::{M, MValue, MMembersStore};

    #[test]
    fn dojo_event_emit() {
        let ns = "sn";

        let resources: Span<TestResource> = [
            //TestResource::Event("my_event"),
            TestResource::Model("m"),
        ].span();

        let namespace_def = NamespaceDef {
            namespace: ns.clone(),
            resources: resources,
        };

        let world = spawn_test_world([namespace_def].span());

        let mut world_storage = WorldStorageTrait::new(world, ns);
        println!("world_storage: {:?}", world_storage.namespace);

        let m = M { a: 1, b: 2 };
        world_storage.set(@m);

        let m2: M = world_storage.get(1);
        assert(m2.a == 1, 'bad a');
        assert(m2.b == 2, 'bad b');

        world_storage.set_namespace("ns1");
        println!("world_storage: {:?}", world_storage.namespace);

        let m3: M = world_storage.get(1);
        assert(m3.a == 1, 'bad a');
        assert(m3.b == 0, 'bad b');

        //let a: felt252 = MMembersStore::get_b(@world_storage, 1);

    }
}
