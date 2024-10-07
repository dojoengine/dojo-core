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
fn test_deploy_contract_for_namespace_owner() {
    let world = deploy_world();
    let class_hash = test_contract::TEST_CLASS_HASH.try_into().unwrap();

    let bob = starknet::contract_address_const::<0xb0b>();
    world.grant_owner(bytearray_hash(@"dojo"), bob);

    // the account owns the 'test_contract' namespace so it should be able to deploy the contract.
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    drop_all_events(world.contract_address);

    let contract_address = world.register_contract('salt1', class_hash, [].span());

    let event = match starknet::testing::pop_log::<Event>(world.contract_address).unwrap() {
        Event::ContractRegistered(event) => event,
        _ => panic!("no ContractRegistered event"),
    };

    let dispatcher = IContractDispatcher { contract_address };

    assert(event.salt == 'salt1', 'bad event salt');
    assert(event.class_hash == class_hash, 'bad class_hash');
    assert(event.selector == dispatcher.selector(), 'bad contract selector');
    assert(
        event.address != core::num::traits::Zero::<ContractAddress>::zero(), 'bad contract address'
    );
}

#[test]
#[should_panic(
    expected: ("Account `2827` does NOT have OWNER role on namespace `dojo`", 'ENTRYPOINT_FAILED',)
)]
fn test_deploy_contract_for_namespace_writer() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    world.grant_writer(bytearray_hash(@"dojo"), bob);

    // the account has write access to the 'test_contract' namespace so it should be able to deploy
    // the contract.
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    world.register_contract('salt1', test_contract::TEST_CLASS_HASH.try_into().unwrap(), [].span());
}


#[test]
#[should_panic(
    expected: ("Account `2827` does NOT have OWNER role on namespace `dojo`", 'ENTRYPOINT_FAILED',)
)]
fn test_deploy_contract_no_namespace_owner_access() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    world.register_contract('salt1', test_contract::TEST_CLASS_HASH.try_into().unwrap(), [].span());
}

#[test]
#[should_panic(expected: ("Namespace `buzz_namespace` is not registered", 'ENTRYPOINT_FAILED',))]
fn test_deploy_contract_with_unregistered_namespace() {
    let world = deploy_world();
    world.register_contract('salt1', buzz_contract::TEST_CLASS_HASH.try_into().unwrap(), [].span());
}

// It's CONTRACT_NOT_DEPLOYED for now as in this example the contract is not a dojo contract
// and it's not the account that is calling the deploy_contract function.
#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED', 'ENTRYPOINT_FAILED',))]
fn test_deploy_contract_through_malicious_contract() {
    let world = deploy_world();

    let bob = starknet::contract_address_const::<0xb0b>();
    let malicious_contract = starknet::contract_address_const::<0xdead>();

    world.grant_owner(bytearray_hash(@"dojo"), bob);

    // the account owns the 'test_contract' namespace so it should be able to deploy the contract.
    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(malicious_contract);

    world.register_contract('salt1', test_contract::TEST_CLASS_HASH.try_into().unwrap(), [].span());
}

#[test]
fn test_upgrade_contract_from_resource_owner() {
    let world = deploy_world();
    let class_hash = test_contract::TEST_CLASS_HASH.try_into().unwrap();

    let bob = starknet::contract_address_const::<0xb0b>();

    world.grant_owner(bytearray_hash(@"dojo"), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    let contract_address = world.register_contract('salt1', class_hash, [].span());
    let dispatcher = IContractDispatcher { contract_address };

    drop_all_events(world.contract_address);

    world.upgrade_contract(class_hash);

    let event = starknet::testing::pop_log::<Event>(world.contract_address);
    assert(event.is_some(), 'no event)');

    if let Event::ContractUpgraded(event) = event.unwrap() {
        assert(event.selector == dispatcher.selector(), 'bad contract selector');
        assert(event.class_hash == class_hash, 'bad class_hash');
    } else {
        core::panic_with_felt252('no ContractUpgraded event');
    };
}

#[test]
#[should_panic(
    expected: (
        "Account `659918` does NOT have OWNER role on contract (or its namespace) `dojo-test_contract`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_contract_from_resource_writer() {
    let world = deploy_world();
    let class_hash = test_contract::TEST_CLASS_HASH.try_into().unwrap();

    let bob = starknet::contract_address_const::<0xb0b>();
    let alice = starknet::contract_address_const::<0xa11ce>();

    world.grant_owner(bytearray_hash(@"dojo"), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    let contract_address = world.register_contract('salt1', class_hash, [].span());

    let dispatcher = IContractDispatcher { contract_address };

    world.grant_writer(dispatcher.selector(), alice);

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);

    world.upgrade_contract(class_hash);
}

#[test]
#[should_panic(
    expected: (
        "Account `659918` does NOT have OWNER role on contract (or its namespace) `dojo-test_contract`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_contract_from_random_account() {
    let world = deploy_world();
    let class_hash = test_contract::TEST_CLASS_HASH.try_into().unwrap();

    let _contract_address = world.register_contract('salt1', class_hash, [].span());

    let alice = starknet::contract_address_const::<0xa11ce>();

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);

    world.upgrade_contract(class_hash);
}

#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED', 'ENTRYPOINT_FAILED',))]
fn test_upgrade_contract_through_malicious_contract() {
    let world = deploy_world();
    let class_hash = test_contract::TEST_CLASS_HASH.try_into().unwrap();

    let bob = starknet::contract_address_const::<0xb0b>();
    let malicious_contract = starknet::contract_address_const::<0xdead>();

    world.grant_owner(bytearray_hash(@"dojo"), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    let _contract_address = world.register_contract('salt1', class_hash, [].span());

    starknet::testing::set_contract_address(malicious_contract);

    world.upgrade_contract(class_hash);
}
