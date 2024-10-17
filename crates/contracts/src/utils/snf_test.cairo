use starknet::{ClassHash, ContractAddress};
use snforge_std::{declare, ContractClassTrait, DeclareResultTrait};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait, Resource};
use core::panics::panic_with_byte_array;

#[derive(Drop)]
pub enum TestResource {
    Event: ByteArray,
    Model: ByteArray,
    Contract: ByteArray,
}

/// Spawns a test world registering namespaces and resources.
///
/// # Arguments
///
/// * `namespaces` - Namespaces to register.
/// * `resources` - Resources to register.
///
/// # Returns
///
/// * World dispatcher
pub fn spawn_test_world(
    namespaces: Span<ByteArray>, resources: Span<TestResource>
) -> IWorldDispatcher {
    let world_contract = declare("world").unwrap().contract_class();
    let class_hash_felt: felt252 = (*world_contract.class_hash).into();
    let (world_address, _) = world_contract.deploy(@array![class_hash_felt]).unwrap();

    let world = IWorldDispatcher { contract_address: world_address };

    let mut namespaces = namespaces;
    while let Option::Some(namespace) = namespaces.pop_front() {
        world.register_namespace(namespace.clone());
    };

    for r in resources {
        match r {
            TestResource::Event(name) => {
                let ch: ClassHash = *declare(name.clone()).unwrap().contract_class().class_hash;
                world.register_event(ch);
            },
            TestResource::Model(name) => {
                let ch: ClassHash = *declare(name.clone()).unwrap().contract_class().class_hash;
                world.register_model(ch);
            },
            TestResource::Contract(name) => {
                let ch: ClassHash = *declare(name.clone()).unwrap().contract_class().class_hash;
                world.register_model(ch);
            },
        }
    };

    world
}

/// Extension trait for world dispatcher to test resources.
pub trait WorldTestExt {
    fn resource_contract_address(
        self: IWorldDispatcher, namespace: ByteArray, name: ByteArray
    ) -> ContractAddress;
    fn resource_class_hash(
        self: IWorldDispatcher, namespace: ByteArray, name: ByteArray
    ) -> ClassHash;
}

impl WorldTestExtImpl of WorldTestExt {
    fn resource_contract_address(
        self: IWorldDispatcher, namespace: ByteArray, name: ByteArray
    ) -> ContractAddress {
        match self.resource(dojo::utils::selector_from_names(@namespace, @name)) {
            Resource::Contract((ca, _)) => ca,
            Resource::Event((ca, _)) => ca,
            Resource::Model((ca, _)) => ca,
            _ => panic_with_byte_array(
                @format!("Resource is not registered: {}-{}", namespace, name)
            )
        }
    }

    fn resource_class_hash(
        self: IWorldDispatcher, namespace: ByteArray, name: ByteArray
    ) -> ClassHash {
        match self.resource(dojo::utils::selector_from_names(@namespace, @name)) {
            Resource::Contract((_, ch)) => ch.try_into().unwrap(),
            Resource::Event((_, ch)) => ch.try_into().unwrap(),
            Resource::Model((_, ch)) => ch.try_into().unwrap(),
            _ => panic_with_byte_array(
                @format!("Resource is not registered: {}-{}", namespace, name)
            ),
        }
    }
}