use starknet::{contract_address_const, ContractAddress, ClassHash};

use dojo::model::{Model, ResourceMetadata};
use dojo::utils::{bytearray_hash, entity_id_from_keys};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait, world};
use dojo::world::world::{
    Event, NamespaceRegistered, ModelRegistered, ModelUpgraded, MetadataUpdate, ContractRegistered,
    ContractUpgraded
};
use dojo::contract::{IContractDispatcher, IContractDispatcherTrait};

use dojo::tests::helpers::{
    deploy_world, deploy_world_for_model_upgrades, deploy_world_for_event_upgrades, drop_all_events,
    Foo, foo, Buzz, buzz, test_contract, buzz_contract
};
use dojo::utils::test::spawn_test_world;

#[test]
fn test_register_namespace() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    drop_all_events(world.contract_address);

    let namespace = "namespace";
    let hash = bytearray_hash(@namespace);

    world.register_namespace(namespace.clone());

    assert(world.is_owner(hash, bob), 'namespace not registered');

    match starknet::testing::pop_log::<Event>(world.contract_address).unwrap() {
        Event::NamespaceRegistered(event) => {
            assert(event.namespace == namespace, 'bad namespace');
            assert(event.hash == hash, 'bad hash');
        },
        _ => panic!("no NamespaceRegistered event"),
    }
}

#[test]
#[should_panic(expected: ("Namespace `namespace` is already registered", 'ENTRYPOINT_FAILED',))]
fn test_register_namespace_already_registered_same_caller() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    world.register_namespace("namespace");
    world.register_namespace("namespace");
}

#[test]
#[should_panic(expected: ("Namespace `namespace` is already registered", 'ENTRYPOINT_FAILED',))]
fn test_register_namespace_already_registered_other_caller() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    world.register_namespace("namespace");

    let alice = starknet::contract_address_const::<0xa11ce>();
    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);

    world.register_namespace("namespace");
}
