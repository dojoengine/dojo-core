use core::option::OptionTrait;
use core::traits::TryInto;

use starknet::ClassHash;

use dojo::contract::components::upgradeable::{IUpgradeableDispatcher, IUpgradeableDispatcherTrait};
use dojo::utils::test::{spawn_test_world};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

#[starknet::contract]
pub mod contract_invalid_upgrade {
    use dojo::contract::IContract;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    pub impl ContractImpl of IContract<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "test_contract"
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn tag(self: @ContractState) -> ByteArray {
            "dojo-test_contract"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }

        fn selector(self: @ContractState) -> felt252 {
            selector_from_tag!("dojo-test_contract")
        }
    }
}

#[dojo::contract]
mod test_contract {}

#[starknet::interface]
pub trait IQuantumLeap<T> {
    fn plz_more_tps(self: @T) -> felt252;
}

#[starknet::contract]
pub mod test_contract_upgrade {
    use dojo::contract::IContract;
    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};
    use dojo::contract::components::world_provider::IWorldProvider;

    #[storage]
    struct Storage {}

    #[constructor]
    fn constructor(ref self: ContractState) {}

    #[abi(embed_v0)]
    pub impl QuantumLeap of super::IQuantumLeap<ContractState> {
        fn plz_more_tps(self: @ContractState) -> felt252 {
            'daddy'
        }
    }

    #[abi(embed_v0)]
    pub impl WorldProviderImpl of IWorldProvider<ContractState> {
        fn world(self: @ContractState) -> IWorldDispatcher {
            IWorldDispatcher { contract_address: starknet::contract_address_const::<'world'>() }
        }
    }

    #[abi(embed_v0)]
    pub impl ContractImpl of IContract<ContractState> {
        fn name(self: @ContractState) -> ByteArray {
            "test_contract"
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn tag(self: @ContractState) -> ByteArray {
            "dojo-test_contract"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }

        fn selector(self: @ContractState) -> felt252 {
            selector_from_tag!("dojo-test_contract")
        }
    }
}

// Utils
fn deploy_world() -> IWorldDispatcher {
    spawn_test_world(["dojo"].span(), [].span())
}

#[test]
#[available_gas(7000000)]
fn test_upgrade_from_world() {
    let world = deploy_world();

    let base_address = world
        .register_contract('salt', test_contract::TEST_CLASS_HASH.try_into().unwrap());
    let new_class_hash: ClassHash = test_contract_upgrade::TEST_CLASS_HASH.try_into().unwrap();

    world.upgrade_contract(new_class_hash);

    let quantum_dispatcher = IQuantumLeapDispatcher { contract_address: base_address };
    assert(quantum_dispatcher.plz_more_tps() == 'daddy', 'quantum leap failed');
}

#[test]
#[available_gas(7000000)]
#[should_panic(
    expected: ('class_hash not world provider', 'ENTRYPOINT_FAILED', 'ENTRYPOINT_FAILED')
)]
fn test_upgrade_from_world_not_world_provider() {
    let world = deploy_world();

    let _ = world.register_contract('salt', test_contract::TEST_CLASS_HASH.try_into().unwrap());
    let new_class_hash: ClassHash = contract_invalid_upgrade::TEST_CLASS_HASH.try_into().unwrap();

    world.upgrade_contract(new_class_hash);
}

#[test]
#[available_gas(6000000)]
#[should_panic(expected: ('must be called by world', 'ENTRYPOINT_FAILED'))]
fn test_upgrade_direct() {
    let world = deploy_world();

    let base_address = world
        .register_contract('salt', test_contract::TEST_CLASS_HASH.try_into().unwrap());
    let new_class_hash: ClassHash = test_contract_upgrade::TEST_CLASS_HASH.try_into().unwrap();

    let upgradeable_dispatcher = IUpgradeableDispatcher { contract_address: base_address };
    upgradeable_dispatcher.upgrade(new_class_hash);
}

#[starknet::interface]
trait IMetadataOnly<T> {
    fn selector(self: @T) -> felt252;
    fn name(self: @T) -> ByteArray;
    fn namespace(self: @T) -> ByteArray;
    fn namespace_hash(self: @T) -> felt252;
    fn name_hash(self: @T) -> felt252;
}

#[starknet::contract]
mod invalid_legacy_model {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl InvalidModelMetadata of super::IMetadataOnly<ContractState> {
        fn selector(self: @ContractState) -> felt252 {
            // Pre-computed address of a contract deployed through the world.
            0x1b1edb46931b1a98d8c6ecf2703e8483ec1d85fb75b3e9c061eab383fc8f8f1
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name(self: @ContractState) -> ByteArray {
            "invalid_legacy_model"
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }
    }
}

#[starknet::contract]
mod invalid_legacy_model_world {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl InvalidModelName of super::IMetadataOnly<ContractState> {
        fn selector(self: @ContractState) -> felt252 {
            // World address is 0, and not registered as deployed through the world
            // as it's itself.
            0
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name(self: @ContractState) -> ByteArray {
            "invalid_legacy_model"
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }
    }
}

#[starknet::contract]
mod invalid_model {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl InvalidModelSelector of super::IMetadataOnly<ContractState> {
        fn selector(self: @ContractState) -> felt252 {
            // Use the resource identifier of the contract deployed through the world
            // instead of the address.
            selector_from_tag!("dojo-test_contract")
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name(self: @ContractState) -> ByteArray {
            "invalid_model"
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }
    }
}

#[starknet::contract]
mod invalid_model_world {
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl InvalidModelSelector of super::IMetadataOnly<ContractState> {
        fn selector(self: @ContractState) -> felt252 {
            // World address is 0, and not registered as deployed through the world
            // as it's itself.
            0
        }

        fn namespace(self: @ContractState) -> ByteArray {
            "dojo"
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::namespace(self))
        }

        fn name(self: @ContractState) -> ByteArray {
            "invalid_model_world"
        }

        fn name_hash(self: @ContractState) -> felt252 {
            dojo::utils::bytearray_hash(@Self::name(self))
        }
    }
}

#[test]
#[available_gas(60000000)]
#[should_panic(
    expected: (
        "Descriptor: `selector` mismatch, expected `926629585226688883233756580070288922289294279106806075757077946233183245741` but found `2368393732245529956313345237151518608283468650081902115301417183793437311044`",
        'ENTRYPOINT_FAILED',
    )
)]
fn test_deploy_from_world_invalid_model() {
    let world = deploy_world();

    let _ = world.register_contract(0, test_contract::TEST_CLASS_HASH.try_into().unwrap());

    world.register_model(invalid_model::TEST_CLASS_HASH.try_into().unwrap());
}

#[test]
#[available_gas(6000000)]
#[should_panic(expected: ("Descriptor: selector `0` is a reserved selector", 'ENTRYPOINT_FAILED',))]
fn test_deploy_from_world_invalid_model_descriptor() {
    let world = deploy_world();
    world.register_model(invalid_model_world::TEST_CLASS_HASH.try_into().unwrap());
}
