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
fn test_set_metadata_world() {
    let world = deploy_world();

    let metadata = ResourceMetadata {
        resource_id: 0, metadata_uri: format!("ipfs:world_with_a_long_uri_that")
    };

    world.set_metadata(metadata.clone());

    assert(world.metadata(0) == metadata, 'invalid metadata');
}

#[test]
fn test_set_metadata_resource_owner() {
    let world = spawn_test_world(["dojo"].span(), [foo::TEST_CLASS_HASH].span(), [].span());

    let bob = starknet::contract_address_const::<0xb0b>();

    world.grant_owner(Model::<Foo>::selector(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    let metadata = ResourceMetadata {
        resource_id: Model::<Foo>::selector(), metadata_uri: format!("ipfs:bob")
    };

    drop_all_events(world.contract_address);

    // Metadata must be updated by a direct call from an account which has owner role
    // for the attached resource.
    world.set_metadata(metadata.clone());
    assert(world.metadata(Model::<Foo>::selector()) == metadata, 'bad metadata');

    match starknet::testing::pop_log::<Event>(world.contract_address).unwrap() {
        Event::MetadataUpdate(event) => {
            assert(event.resource == metadata.resource_id, 'bad resource');
            assert(event.uri == metadata.metadata_uri, 'bad uri');
        },
        _ => panic!("no MetadataUpdate event"),
    }
}

#[test]
#[should_panic(
    expected: (
        "Account `2827` does NOT have OWNER role on model (or its namespace) `dojo-Foo`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_set_metadata_not_possible_for_resource_writer() {
    let world = spawn_test_world(["dojo"].span(), [foo::TEST_CLASS_HASH].span(), [].span());

    let bob = starknet::contract_address_const::<0xb0b>();

    world.grant_writer(Model::<Foo>::selector(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    let metadata = ResourceMetadata {
        resource_id: Model::<Foo>::selector(), metadata_uri: format!("ipfs:bob")
    };

    world.set_metadata(metadata.clone());
}

#[test]
#[should_panic(
    expected: ("Account `2827` does NOT have OWNER role on world", 'ENTRYPOINT_FAILED',)
)]
fn test_set_metadata_not_possible_for_random_account() {
    let world = deploy_world();

    let metadata = ResourceMetadata { // World metadata.
        resource_id: 0, metadata_uri: format!("ipfs:bob"),
    };

    let bob = starknet::contract_address_const::<0xb0b>();
    starknet::testing::set_contract_address(bob);
    starknet::testing::set_account_contract_address(bob);

    // Bob access follows the conventional ACL, he can't write the world
    // metadata if he does not have access to it.
    world.set_metadata(metadata);
}

#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED', 'ENTRYPOINT_FAILED',))]
fn test_set_metadata_through_malicious_contract() {
    let world = spawn_test_world(["dojo"].span(), [foo::TEST_CLASS_HASH].span(), [].span());

    let bob = starknet::contract_address_const::<0xb0b>();
    let malicious_contract = starknet::contract_address_const::<0xdead>();

    world.grant_owner(Model::<Foo>::selector(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(malicious_contract);

    let metadata = ResourceMetadata {
        resource_id: Model::<Foo>::selector(), metadata_uri: format!("ipfs:bob")
    };

    world.set_metadata(metadata.clone());
}
