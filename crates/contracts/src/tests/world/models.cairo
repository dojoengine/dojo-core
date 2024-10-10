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
    deploy_world, deploy_world_for_model_upgrades, drop_all_events, Foo, foo, Buzz, buzz,
    test_contract, buzz_contract
};
use dojo::utils::test::spawn_test_world;

#[derive(Copy, Drop, Serde, Debug, IntrospectPacked)]
#[dojo::model(version: 2)]
pub struct FooBadLayoutType {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model(version: 2)]
struct FooNameChanged {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model(version: 2)]
struct FooMemberRemoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model(version: 2)]
struct FooMemberAddedButRemoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
    pub c: u256,
    pub d: u256
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model(version: 2)]
struct FooMemberAddedButMoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
    pub a: felt252,
    pub c: u256
}


#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model]
struct FooMemberAddedButSameVersion {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
    pub c: u256
}

#[derive(Copy, Drop, Serde, Debug)]
#[dojo::model(version: 2)]
struct FooMemberAdded {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
    pub c: u256
}

#[test]
fn test_register_model_for_namespace_owner() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world();
    world.grant_owner(Model::<Foo>::namespace_hash(), bob);

    drop_all_events(world.contract_address);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    let event = starknet::testing::pop_log::<Event>(world.contract_address);
    assert(event.is_some(), 'no event)');

    if let Event::ModelRegistered(event) = event.unwrap() {
        assert(event.name == Model::<Foo>::name(), 'bad model name');
        assert(event.namespace == Model::<Foo>::namespace(), 'bad model namespace');
        assert(
            event.class_hash == foo::TEST_CLASS_HASH.try_into().unwrap(), 'bad model class_hash'
        );
        assert(
            event.address != core::num::traits::Zero::<ContractAddress>::zero(),
            'bad model prev address'
        );
    } else {
        core::panic_with_felt252('no ModelRegistered event');
    }

    assert(world.is_owner(Model::<Foo>::selector(), bob), 'bob is not the owner');
}

#[test]
#[should_panic(
    expected: ("Account `2827` does NOT have OWNER role on namespace `dojo`", 'ENTRYPOINT_FAILED',)
)]
fn test_register_model_for_namespace_writer() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world();
    world.grant_writer(Model::<Foo>::namespace_hash(), bob);

    drop_all_events(world.contract_address);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());
}

#[test]
fn test_upgrade_model_from_model_owner() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world_for_model_upgrades();
    world.grant_owner(Model::<FooMemberAdded>::selector(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    drop_all_events(world.contract_address);

    world
        .upgrade_model(
            Model::<FooMemberAdded>::selector(),
            foo_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );

    let event = starknet::testing::pop_log::<Event>(world.contract_address);
    assert(event.is_some(), 'no event)');

    if let Event::ModelUpgraded(event) = event.unwrap() {
        assert(
            event.class_hash == foo_member_added::TEST_CLASS_HASH.try_into().unwrap(),
            'bad model class_hash'
        );

        assert(
            event.address != core::num::traits::Zero::<ContractAddress>::zero(),
            'bad model prev address'
        );
    } else {
        core::panic_with_felt252('no ModelUpgraded event');
    }

    assert(world.is_owner(Model::<FooMemberAdded>::selector(), bob), 'bob is not the owner');
}

#[test]
fn test_upgrade_model() {
    let world = deploy_world_for_model_upgrades();

    drop_all_events(world.contract_address);

    world
        .upgrade_model(
            Model::<FooMemberAdded>::selector(),
            foo_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );

    let event = starknet::testing::pop_log::<ModelUpgraded>(world.contract_address);

    assert(event.is_some(), 'no ModelUpgraded event');
    let event = event.unwrap();
    assert(
        event.class_hash == foo_member_added::TEST_CLASS_HASH.try_into().unwrap(),
        'bad model class_hash'
    );
    assert(
        event.address != core::num::traits::Zero::<ContractAddress>::zero(), 'bad model address'
    );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new layout to upgrade the resource `3299332835749357934986569383926439331000812010239905600952804594672861482231`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_bad_layout_type() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<FooBadLayoutType>::selector(),
            foo_bad_layout_type::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `3123252206139358744730647958636922105676576163624049771737508399526017186883`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_name_change() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<Foo>::selector(), foo_name_changed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `991779734441782832082403572095809709808010858956594544283871161035940786254`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_member_removed() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<FooMemberRemoved>::selector(),
            foo_member_removed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `832347970429487891546414803397849087808560440584474009458460185937208465364`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_member_added_but_removed() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<FooMemberAddedButRemoved>::selector(),
            foo_member_added_but_removed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "The new resource version of `1624956305639059314433508277897382957139753261232513354727598365317619941481` should be 2",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_member_added_but_same_version() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<FooMemberAddedButSameVersion>::selector(),
            foo_member_added_but_same_version::TEST_CLASS_HASH.try_into().unwrap()
        );
}


#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `24285692591026114610735893315325215980821705916443621541163513530524539878`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_with_member_moved() {
    let world = deploy_world_for_model_upgrades();
    world
        .upgrade_model(
            Model::<FooMemberAddedButMoved>::selector(),
            foo_member_added_but_moved::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Account `659918` does NOT have OWNER role on model (or its namespace) `dojo-FooMemberAdded`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_model_from_model_writer() {
    let alice = starknet::contract_address_const::<0xa11ce>();

    let world = deploy_world_for_model_upgrades();

    world.grant_writer(Model::<Foo>::selector(), alice);

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);
    world
        .upgrade_model(
            Model::<Foo>::selector(), foo_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(expected: ("Resource `dojo-Foo` is already registered", 'ENTRYPOINT_FAILED',))]
fn test_upgrade_model_from_random_account() {
    let bob = starknet::contract_address_const::<0xb0b>();
    let alice = starknet::contract_address_const::<0xa11ce>();

    let world = deploy_world();
    world.grant_owner(Model::<Foo>::namespace_hash(), bob);
    world.grant_owner(Model::<Foo>::namespace_hash(), alice);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());
}

#[test]
#[should_panic(expected: ("Namespace `another_namespace` is not registered", 'ENTRYPOINT_FAILED',))]
fn test_register_model_with_unregistered_namespace() {
    let world = deploy_world();
    world.register_model(buzz::TEST_CLASS_HASH.try_into().unwrap());
}

// It's CONTRACT_NOT_DEPLOYED for now as in this example the contract is not a dojo contract
// and it's not the account that is calling the register_model function.
#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED', 'ENTRYPOINT_FAILED',))]
fn test_register_model_through_malicious_contract() {
    let bob = starknet::contract_address_const::<0xb0b>();
    let malicious_contract = starknet::contract_address_const::<0xdead>();

    let world = deploy_world();
    world.grant_owner(Model::<Foo>::namespace_hash(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(malicious_contract);
    world.register_model(foo::TEST_CLASS_HASH.try_into().unwrap());
}
