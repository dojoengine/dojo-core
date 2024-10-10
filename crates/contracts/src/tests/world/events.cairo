use starknet::{contract_address_const, ContractAddress, ClassHash};

use dojo::event::Event;
use dojo::utils::{bytearray_hash, entity_id_from_keys};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait, world};
use dojo::world::world::{
    NamespaceRegistered, ModelRegistered, ModelUpgraded, MetadataUpdate, ContractRegistered,
    ContractUpgraded
};
use dojo::contract::{IContractDispatcher, IContractDispatcherTrait};

use dojo::tests::helpers::{
    deploy_world, deploy_world_for_event_upgrades, drop_all_events, FooEvent, foo_event, buzz_event
};
use dojo::utils::test::spawn_test_world;

#[dojo::event(version: 2)]
pub struct FooEventBadLayoutType {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
}

#[dojo::event(version: 2)]
struct FooEventNameChanged {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
}

#[dojo::event(version: 2)]
struct FooEventMemberRemoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
}

#[dojo::event(version: 2)]
struct FooEventMemberAddedButRemoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
    pub c: u256,
    pub d: u256
}

#[dojo::event(version: 2)]
struct FooEventMemberAddedButMoved {
    #[key]
    pub caller: ContractAddress,
    pub b: u128,
    pub a: felt252,
    pub c: u256
}

#[dojo::event]
struct FooEventMemberButSameVersion {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
    pub c: u256
}

#[dojo::event(version: 2)]
struct FooEventMemberAdded {
    #[key]
    pub caller: ContractAddress,
    pub a: felt252,
    pub b: u128,
    pub c: u256
}

#[test]
fn test_register_event_for_namespace_owner() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world();
    world.grant_owner(Event::<FooEvent>::namespace_hash(), bob);

    drop_all_events(world.contract_address);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_event(foo_event::TEST_CLASS_HASH.try_into().unwrap());

    let event = starknet::testing::pop_log::<world::Event>(world.contract_address);
    assert(event.is_some(), 'no event)');

    if let world::Event::EventRegistered(event) = event.unwrap() {
        assert(event.name == Event::<FooEvent>::name(), 'bad event name');
        assert(event.namespace == Event::<FooEvent>::namespace(), 'bad event namespace');
        assert(
            event.class_hash == foo_event::TEST_CLASS_HASH.try_into().unwrap(),
            'bad event class_hash'
        );
        assert(
            event.address != core::num::traits::Zero::<ContractAddress>::zero(),
            'bad event prev address'
        );
    } else {
        core::panic_with_felt252('no EventRegistered event');
    }

    assert(world.is_owner(Event::<FooEvent>::selector(), bob), 'bob is not the owner');
}

#[test]
#[should_panic(
    expected: ("Account `2827` does NOT have OWNER role on namespace `dojo`", 'ENTRYPOINT_FAILED',)
)]
fn test_register_event_for_namespace_writer() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world();
    world.grant_writer(Event::<FooEvent>::namespace_hash(), bob);

    drop_all_events(world.contract_address);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_event(foo_event::TEST_CLASS_HASH.try_into().unwrap());
}

#[test]
fn test_upgrade_event_from_event_owner() {
    let bob = starknet::contract_address_const::<0xb0b>();

    let world = deploy_world_for_event_upgrades();
    world.grant_owner(Event::<FooEventMemberAdded>::selector(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);

    drop_all_events(world.contract_address);

    world
        .upgrade_event(
            Event::<FooEventMemberAdded>::selector(),
            foo_event_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );

    let event = starknet::testing::pop_log::<world::Event>(world.contract_address);
    assert(event.is_some(), 'no event)');

    if let world::Event::EventUpgraded(event) = event.unwrap() {
        assert(
            event.class_hash == foo_event_member_added::TEST_CLASS_HASH.try_into().unwrap(),
            'bad model class_hash'
        );

        assert(
            event.address != core::num::traits::Zero::<ContractAddress>::zero(),
            'bad model prev address'
        );
    } else {
        core::panic_with_felt252('no EventUpgraded event');
    }

    assert(world.is_owner(Event::<FooEventMemberAdded>::selector(), bob), 'bob is not the owner');
}

#[test]
fn test_upgrade_event() {
    let world = deploy_world_for_event_upgrades();

    drop_all_events(world.contract_address);

    world
        .upgrade_event(
            Event::<FooEventMemberAdded>::selector(),
            foo_event_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );

    let event = starknet::testing::pop_log::<ModelUpgraded>(world.contract_address);

    assert(event.is_some(), 'no ModelUpgraded event');
    let event = event.unwrap();
    assert(
        event.class_hash == foo_event_member_added::TEST_CLASS_HASH.try_into().unwrap(),
        'bad model class_hash'
    );
    assert(
        event.address != core::num::traits::Zero::<ContractAddress>::zero(), 'bad model address'
    );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new layout to upgrade the resource `3096059378939896478759206948098785810564909261576270289792934616419679543710`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_bad_layout_type() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEventBadLayoutType>::selector(),
            foo_event_bad_layout_type::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `1978613259126754154559259544144231349453413846292589556290196962649661425572`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_name_change() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEvent>::selector(),
            foo_event_name_changed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `361072533419516152961739976459841981071623312081985419948600214596129482087`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_member_removed() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEventMemberRemoved>::selector(),
            foo_event_member_removed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `158342804955206503831721217884579656766969504799505203580537759170121480691`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_member_added_but_removed() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEventMemberAddedButRemoved>::selector(),
            foo_event_member_added_but_removed::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "The new resource version of `3464629169105918854322628800815075086174820058177091358737862671011303488207` should be 2",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_member_added_but_same_version() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEventMemberButSameVersion>::selector(),
            foo_event_member_but_same_version::TEST_CLASS_HASH.try_into().unwrap()
        );
}


#[test]
#[should_panic(
    expected: (
        "Invalid new schema to upgrade the resource `2252659269513748615750074350172958465813667947162245103708863177206717341280`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_with_member_moved() {
    let world = deploy_world_for_event_upgrades();
    world
        .upgrade_event(
            Event::<FooEventMemberAddedButMoved>::selector(),
            foo_event_member_added_but_moved::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(
    expected: (
        "Account `659918` does NOT have OWNER role on event (or its namespace) `dojo-FooEventMemberAdded`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_upgrade_event_from_event_writer() {
    let alice = starknet::contract_address_const::<0xa11ce>();

    let world = deploy_world_for_event_upgrades();

    world.grant_writer(Event::<FooEvent>::selector(), alice);

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);
    world
        .upgrade_event(
            Event::<FooEvent>::selector(),
            foo_event_member_added::TEST_CLASS_HASH.try_into().unwrap()
        );
}

#[test]
#[should_panic(expected: ("Resource `dojo-FooEvent` is already registered", 'ENTRYPOINT_FAILED',))]
fn test_upgrade_event_from_random_account() {
    let bob = starknet::contract_address_const::<0xb0b>();
    let alice = starknet::contract_address_const::<0xa11ce>();

    let world = deploy_world();
    world.grant_owner(Event::<FooEvent>::namespace_hash(), bob);
    world.grant_owner(Event::<FooEvent>::namespace_hash(), alice);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(bob);
    world.register_event(foo_event::TEST_CLASS_HASH.try_into().unwrap());

    starknet::testing::set_account_contract_address(alice);
    starknet::testing::set_contract_address(alice);
    world.register_event(foo_event::TEST_CLASS_HASH.try_into().unwrap());
}

#[test]
#[should_panic(expected: ("Namespace `another_namespace` is not registered", 'ENTRYPOINT_FAILED',))]
fn test_register_event_with_unregistered_namespace() {
    let world = deploy_world();
    world.register_event(buzz_event::TEST_CLASS_HASH.try_into().unwrap());
}

// It's CONTRACT_NOT_DEPLOYED for now as in this example the contract is not a dojo contract
// and it's not the account that is calling the register_event function.
#[test]
#[should_panic(expected: ('CONTRACT_NOT_DEPLOYED', 'ENTRYPOINT_FAILED',))]
fn test_register_event_through_malicious_contract() {
    let bob = starknet::contract_address_const::<0xb0b>();
    let malicious_contract = starknet::contract_address_const::<0xdead>();

    let world = deploy_world();
    world.grant_owner(Event::<FooEvent>::namespace_hash(), bob);

    starknet::testing::set_account_contract_address(bob);
    starknet::testing::set_contract_address(malicious_contract);
    world.register_event(foo_event::TEST_CLASS_HASH.try_into().unwrap());
}
