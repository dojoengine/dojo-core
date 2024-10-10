use core::fmt::{Display, Formatter, Error};

#[derive(Copy, Drop, PartialEq)]
pub enum Permission {
    Writer,
    Owner,
}

impl PermissionDisplay of Display<Permission> {
    fn fmt(self: @Permission, ref f: Formatter) -> Result<(), Error> {
        let str = match self {
            Permission::Writer => @"WRITER",
            Permission::Owner => @"OWNER",
        };
        f.buffer.append(str);
        Result::Ok(())
    }
}

#[starknet::contract]
pub mod world {
    use core::array::{ArrayTrait, SpanTrait};
    use core::box::BoxTrait;
    use core::hash::{HashStateExTrait, HashStateTrait};
    use core::num::traits::Zero;
    use core::option::OptionTrait;
    use core::pedersen::PedersenTrait;
    use core::serde::Serde;
    use core::to_byte_array::FormatAsByteArray;
    use core::traits::TryInto;
    use core::traits::Into;
    use core::panic_with_felt252;
    use core::panics::panic_with_byte_array;

    use starknet::{
        contract_address_const, get_caller_address, get_contract_address, get_tx_info, ClassHash,
        ContractAddress, syscalls::{deploy_syscall, emit_event_syscall, replace_class_syscall},
        SyscallResult, SyscallResultTrait, storage::Map,
    };
    pub use starknet::storage::{
        StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess,
        StoragePointerWriteAccess
    };

    use dojo::world::errors;
    use dojo::contract::components::upgradeable::{
        IUpgradeableDispatcher, IUpgradeableDispatcherTrait
    };
    use dojo::contract::{IContractDispatcher, IContractDispatcherTrait};
    use dojo::meta::Layout;
    use dojo::event::{IEventDispatcher, IEventDispatcherTrait};
    use dojo::model::{
        Model, IModelDispatcher, IModelDispatcherTrait, ResourceMetadata, ResourceMetadataTrait,
        metadata, ModelIndex
    };
    use dojo::storage;
    use dojo::utils::{
        entity_id_from_keys, bytearray_hash, Descriptor, DescriptorTrait, IDescriptorDispatcher,
        IDescriptorDispatcherTrait
    };
    use dojo::world::{
        IWorldDispatcher, IWorldDispatcherTrait, IWorld, IUpgradeableWorld, Resource,
        ResourceIsNoneTrait
    };
    use super::Permission;

    pub const WORLD: felt252 = 0;

    #[event]
    #[derive(Drop, starknet::Event)]
    pub enum Event {
        WorldSpawned: WorldSpawned,
        WorldUpgraded: WorldUpgraded,
        NamespaceRegistered: NamespaceRegistered,
        ModelRegistered: ModelRegistered,
        EventRegistered: EventRegistered,
        ContractRegistered: ContractRegistered,
        ModelUpgraded: ModelUpgraded,
        EventUpgraded: EventUpgraded,
        ContractUpgraded: ContractUpgraded,
        EventEmitted: EventEmitted,
        MetadataUpdate: MetadataUpdate,
        StoreSetRecord: StoreSetRecord,
        StoreUpdateRecord: StoreUpdateRecord,
        StoreUpdateMember: StoreUpdateMember,
        StoreDelRecord: StoreDelRecord,
        WriterUpdated: WriterUpdated,
        OwnerUpdated: OwnerUpdated,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WorldSpawned {
        pub creator: ContractAddress,
        pub class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WorldUpgraded {
        pub class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractRegistered {
        #[key]
        pub selector: felt252,
        pub address: ContractAddress,
        pub class_hash: ClassHash,
        pub salt: felt252,
        pub constructor_calldata: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ContractUpgraded {
        #[key]
        pub selector: felt252,
        pub class_hash: ClassHash,
    }

    #[derive(Drop, starknet::Event)]
    pub struct MetadataUpdate {
        #[key]
        pub resource: felt252,
        pub uri: ByteArray
    }

    #[derive(Drop, starknet::Event)]
    pub struct NamespaceRegistered {
        #[key]
        pub namespace: ByteArray,
        pub hash: felt252
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModelRegistered {
        #[key]
        pub name: ByteArray,
        #[key]
        pub namespace: ByteArray,
        pub class_hash: ClassHash,
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct ModelUpgraded {
        #[key]
        pub selector: felt252,
        pub class_hash: ClassHash,
        pub address: ContractAddress,
        pub prev_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventRegistered {
        #[key]
        pub name: ByteArray,
        #[key]
        pub namespace: ByteArray,
        pub class_hash: ClassHash,
        pub address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventUpgraded {
        #[key]
        pub selector: felt252,
        pub class_hash: ClassHash,
        pub address: ContractAddress,
        pub prev_address: ContractAddress,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoreSetRecord {
        #[key]
        pub table: felt252,
        #[key]
        pub entity_id: felt252,
        pub keys: Span<felt252>,
        pub values: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoreUpdateRecord {
        #[key]
        pub table: felt252,
        #[key]
        pub entity_id: felt252,
        pub values: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoreUpdateMember {
        #[key]
        pub table: felt252,
        #[key]
        pub entity_id: felt252,
        #[key]
        pub member_selector: felt252,
        pub values: Span<felt252>,
    }

    #[derive(Drop, starknet::Event)]
    pub struct StoreDelRecord {
        #[key]
        pub table: felt252,
        #[key]
        pub entity_id: felt252,
    }

    #[derive(Drop, starknet::Event)]
    pub struct WriterUpdated {
        #[key]
        pub resource: felt252,
        #[key]
        pub contract: ContractAddress,
        pub value: bool
    }

    #[derive(Drop, starknet::Event)]
    pub struct OwnerUpdated {
        #[key]
        pub resource: felt252,
        #[key]
        pub contract: ContractAddress,
        pub value: bool,
    }

    #[derive(Drop, starknet::Event)]
    pub struct EventEmitted {
        #[key]
        pub event_selector: felt252,
        #[key]
        pub system_address: ContractAddress,
        #[key]
        pub historical: bool,
        pub keys: Span<felt252>,
        pub values: Span<felt252>,
    }

    #[storage]
    struct Storage {
        nonce: usize,
        models_salt: usize,
        events_salt: usize,
        resources: Map::<felt252, Resource>,
        owners: Map::<(felt252, ContractAddress), bool>,
        writers: Map::<(felt252, ContractAddress), bool>,
    }

    /// Constructor for the world contract.
    ///
    /// # Arguments
    ///
    /// * `world_class_hash` - The class hash of the world contract that is being deployed.
    ///   As currently Starknet doesn't support a syscall to get the class hash of the
    ///   deploying contract, the hash of the world contract has to be provided at spawn time
    ///   This also ensures the world's address is always deterministic since the world class
    ///   hash can change when the world contract is upgraded.
    #[constructor]
    fn constructor(ref self: ContractState, world_class_hash: ClassHash) {
        let creator = starknet::get_tx_info().unbox().account_contract_address;

        self.resources.write(WORLD, Resource::World);
        self
            .resources
            .write(
                Model::<ResourceMetadata>::selector(),
                Resource::Model(
                    (metadata::initial_address(), Model::<ResourceMetadata>::namespace_hash())
                )
            );
        self.owners.write((WORLD, creator), true);

        let dojo_namespace = "__DOJO__";
        let dojo_namespace_hash = bytearray_hash(@dojo_namespace);

        self.resources.write(dojo_namespace_hash, Resource::Namespace(dojo_namespace));
        self.owners.write((dojo_namespace_hash, creator), true);

        self.emit(WorldSpawned { creator, class_hash: world_class_hash });
    }

    #[cfg(target: "test")]
    #[abi(embed_v0)]
    impl WorldTestImpl of dojo::world::IWorldTest<ContractState> {
        fn set_entity_test(
            ref self: ContractState,
            model_selector: felt252,
            index: ModelIndex,
            values: Span<felt252>,
            layout: Layout
        ) {
            self.set_entity_internal(model_selector, index, values, layout);
        }

        fn delete_entity_test(
            ref self: ContractState, model_selector: felt252, index: ModelIndex, layout: Layout
        ) {
            self.delete_entity_internal(model_selector, index, layout);
        }

        fn emit_event_test(
            ref self: ContractState,
            event_selector: felt252,
            keys: Span<felt252>,
            values: Span<felt252>,
            historical: bool
        ) {
            self
                .emit(
                    EventEmitted {
                        event_selector,
                        system_address: get_caller_address(),
                        historical,
                        keys,
                        values
                    }
                );
        }
    }

    #[abi(embed_v0)]
    impl World of IWorld<ContractState> {
        fn metadata(self: @ContractState, resource_selector: felt252) -> ResourceMetadata {
            let mut values = storage::entity_model::read_model_entity(
                Model::<ResourceMetadata>::selector(),
                entity_id_from_keys([resource_selector].span()),
                Model::<ResourceMetadata>::layout()
            );

            match ResourceMetadataTrait::from_values(resource_selector, ref values) {
                Option::Some(x) => x,
                Option::None => panic!("Model `ResourceMetadata`: deserialization failed.")
            }
        }

        fn set_metadata(ref self: ContractState, metadata: ResourceMetadata) {
            self.assert_caller_permissions(metadata.resource_id, Permission::Owner);

            storage::entity_model::write_model_entity(
                metadata.instance_selector(),
                metadata.entity_id(),
                metadata.values(),
                metadata.instance_layout()
            );

            self
                .emit(
                    MetadataUpdate { resource: metadata.resource_id, uri: metadata.metadata_uri }
                );
        }

        fn is_owner(self: @ContractState, resource: felt252, address: ContractAddress) -> bool {
            self.owners.read((resource, address))
        }

        fn grant_owner(ref self: ContractState, resource: felt252, address: ContractAddress) {
            if self.resources.read(resource).is_unregistered() {
                panic_with_byte_array(@errors::resource_not_registered(resource));
            }

            self.assert_caller_permissions(resource, Permission::Owner);

            self.owners.write((resource, address), true);

            self.emit(OwnerUpdated { contract: address, resource, value: true });
        }

        fn revoke_owner(ref self: ContractState, resource: felt252, address: ContractAddress) {
            if self.resources.read(resource).is_unregistered() {
                panic_with_byte_array(@errors::resource_not_registered(resource));
            }

            self.assert_caller_permissions(resource, Permission::Owner);

            self.owners.write((resource, address), false);

            self.emit(OwnerUpdated { contract: address, resource, value: false });
        }

        fn is_writer(self: @ContractState, resource: felt252, contract: ContractAddress) -> bool {
            self.writers.read((resource, contract))
        }

        fn grant_writer(ref self: ContractState, resource: felt252, contract: ContractAddress) {
            if self.resources.read(resource).is_unregistered() {
                panic_with_byte_array(@errors::resource_not_registered(resource));
            }

            self.assert_caller_permissions(resource, Permission::Owner);

            self.writers.write((resource, contract), true);

            self.emit(WriterUpdated { resource, contract, value: true });
        }

        fn revoke_writer(ref self: ContractState, resource: felt252, contract: ContractAddress) {
            if self.resources.read(resource).is_unregistered() {
                panic_with_byte_array(@errors::resource_not_registered(resource));
            }

            self.assert_caller_permissions(resource, Permission::Owner);

            self.writers.write((resource, contract), false);

            self.emit(WriterUpdated { resource, contract, value: false });
        }

        fn register_event(ref self: ContractState, class_hash: ClassHash) {
            let caller = get_caller_address();
            let salt = self.events_salt.read();

            let (contract_address, _) = starknet::syscalls::deploy_syscall(
                class_hash, salt.into(), [].span(), false,
            )
                .unwrap_syscall();
            self.events_salt.write(salt + 1);

            let descriptor = DescriptorTrait::from_contract_assert(contract_address);

            if !self.is_namespace_registered(descriptor.namespace_hash()) {
                panic_with_byte_array(@errors::namespace_not_registered(descriptor.namespace()));
            }

            self.assert_caller_permissions(descriptor.namespace_hash(), Permission::Owner);

            let maybe_existing_event = self.resources.read(descriptor.selector());
            if !maybe_existing_event.is_unregistered() {
                panic_with_byte_array(
                    @errors::event_already_registered(descriptor.namespace(), descriptor.name())
                );
            }

            self
                .resources
                .write(
                    descriptor.selector(),
                    Resource::Event((contract_address, descriptor.namespace_hash()))
                );
            self.owners.write((descriptor.selector(), caller), true);

            self
                .emit(
                    EventRegistered {
                        name: descriptor.name().clone(),
                        namespace: descriptor.namespace().clone(),
                        address: contract_address,
                        class_hash
                    }
                );
        }

        fn upgrade_event(ref self: ContractState, class_hash: ClassHash) {
            let salt = self.events_salt.read();

            let (new_contract_address, _) = starknet::syscalls::deploy_syscall(
                class_hash, salt.into(), [].span(), false,
            )
                .unwrap_syscall();

            self.events_salt.write(salt + 1);

            let new_descriptor = DescriptorTrait::from_contract_assert(new_contract_address);

            if !self.is_namespace_registered(new_descriptor.namespace_hash()) {
                panic_with_byte_array(
                    @errors::namespace_not_registered(new_descriptor.namespace())
                );
            }

            self.assert_caller_permissions(new_descriptor.selector(), Permission::Owner);

            let mut prev_address = core::num::traits::Zero::<ContractAddress>::zero();

            // If the namespace or name of the event have been changed, the descriptor
            // will be different, hence not upgradeable.
            match self.resources.read(new_descriptor.selector()) {
                Resource::Event((model_address, _)) => { prev_address = model_address; },
                Resource::Unregistered => {
                    panic_with_byte_array(
                        @errors::event_not_registered(
                            new_descriptor.namespace(), new_descriptor.name()
                        )
                    )
                },
                _ => panic_with_byte_array(
                    @errors::resource_conflict(
                        @format!("{}-{}", new_descriptor.namespace(), new_descriptor.name()),
                        @"event"
                    )
                )
            };

            self
                .resources
                .write(
                    new_descriptor.selector(),
                    Resource::Event((new_contract_address, new_descriptor.namespace_hash()))
                );

            self
                .emit(
                    EventUpgraded {
                        selector: new_descriptor.selector(),
                        prev_address,
                        address: new_contract_address,
                        class_hash,
                    }
                );
        }

        fn register_model(ref self: ContractState, class_hash: ClassHash) {
            let caller = get_caller_address();
            let salt = self.models_salt.read();

            let (contract_address, _) = starknet::syscalls::deploy_syscall(
                class_hash, salt.into(), [].span(), false,
            )
                .unwrap_syscall();
            self.models_salt.write(salt + 1);

            let descriptor = DescriptorTrait::from_contract_assert(contract_address);

            self.assert_namespace(descriptor.namespace());
            self.assert_name(descriptor.name());

            if !self.is_namespace_registered(descriptor.namespace_hash()) {
                panic_with_byte_array(@errors::namespace_not_registered(descriptor.namespace()));
            }

            self.assert_caller_permissions(descriptor.namespace_hash(), Permission::Owner);

            let maybe_existing_model = self.resources.read(descriptor.selector());
            if !maybe_existing_model.is_unregistered() {
                panic_with_byte_array(
                    @errors::model_already_registered(descriptor.namespace(), descriptor.name())
                );
            }

            self
                .resources
                .write(
                    descriptor.selector(),
                    Resource::Model((contract_address, descriptor.namespace_hash()))
                );
            self.owners.write((descriptor.selector(), caller), true);

            self
                .emit(
                    ModelRegistered {
                        name: descriptor.name().clone(),
                        namespace: descriptor.namespace().clone(),
                        address: contract_address,
                        class_hash
                    }
                );
        }

        fn upgrade_model(ref self: ContractState, class_hash: ClassHash) {
            let salt = self.models_salt.read();

            let (new_contract_address, _) = starknet::syscalls::deploy_syscall(
                class_hash, salt.into(), [].span(), false,
            )
                .unwrap_syscall();

            self.models_salt.write(salt + 1);

            let new_descriptor = DescriptorTrait::from_contract_assert(new_contract_address);

            self.assert_namespace(new_descriptor.namespace());
            self.assert_name(new_descriptor.name());

            if !self.is_namespace_registered(new_descriptor.namespace_hash()) {
                panic_with_byte_array(
                    @errors::namespace_not_registered(new_descriptor.namespace())
                );
            }

            self.assert_caller_permissions(new_descriptor.selector(), Permission::Owner);

            let mut prev_address = core::num::traits::Zero::<ContractAddress>::zero();

            // If the namespace or name of the model have been changed, the descriptor
            // will be different, hence not upgradeable.
            match self.resources.read(new_descriptor.selector()) {
                Resource::Model((model_address, _)) => { prev_address = model_address; },
                Resource::Unregistered => {
                    panic_with_byte_array(
                        @errors::model_not_registered(
                            new_descriptor.namespace(), new_descriptor.name()
                        )
                    )
                },
                _ => panic_with_byte_array(
                    @errors::resource_conflict(
                        @format!("{}-{}", new_descriptor.namespace(), new_descriptor.name()),
                        @"model"
                    )
                )
            };

            self
                .resources
                .write(
                    new_descriptor.selector(),
                    Resource::Model((new_contract_address, new_descriptor.namespace_hash()))
                );

            self
                .emit(
                    ModelUpgraded {
                        selector: new_descriptor.selector(),
                        prev_address,
                        address: new_contract_address,
                        class_hash,
                    }
                );
        }

        fn register_namespace(ref self: ContractState, namespace: ByteArray) {
            self.assert_namespace(@namespace);

            let caller = get_caller_address();

            let hash = bytearray_hash(@namespace);

            match self.resources.read(hash) {
                Resource::Namespace => panic_with_byte_array(
                    @errors::namespace_already_registered(@namespace)
                ),
                Resource::Unregistered => {
                    self.resources.write(hash, Resource::Namespace(namespace.clone()));
                    self.owners.write((hash, caller), true);

                    self.emit(NamespaceRegistered { namespace, hash });
                },
                _ => {
                    panic_with_byte_array(@errors::resource_conflict(@namespace, @"namespace"));
                }
            };
        }

        fn register_contract(
            ref self: ContractState,
            salt: felt252,
            class_hash: ClassHash,
            constructor_calldata: Span<felt252>
        ) -> ContractAddress {
            let caller = get_caller_address();

            let (contract_address, _) = deploy_syscall(
                class_hash, salt, constructor_calldata, false
            )
                .unwrap_syscall();

            let descriptor = DescriptorTrait::from_contract_assert(contract_address);

            self.assert_namespace(descriptor.namespace());
            self.assert_name(descriptor.name());

            let maybe_existing_contract = self.resources.read(descriptor.selector());
            if !maybe_existing_contract.is_unregistered() {
                panic_with_byte_array(
                    @errors::contract_already_registered(descriptor.namespace(), descriptor.name())
                );
            }

            if !self.is_namespace_registered(descriptor.namespace_hash()) {
                panic_with_byte_array(@errors::namespace_not_registered(descriptor.namespace()));
            }

            self.assert_caller_permissions(descriptor.namespace_hash(), Permission::Owner);

            self.owners.write((descriptor.selector(), caller), true);
            self
                .resources
                .write(
                    descriptor.selector(),
                    Resource::Contract((contract_address, descriptor.namespace_hash()))
                );

            self
                .emit(
                    ContractRegistered {
                        salt,
                        class_hash,
                        address: contract_address,
                        selector: descriptor.selector(),
                        constructor_calldata
                    }
                );

            contract_address
        }

        fn upgrade_contract(ref self: ContractState, class_hash: ClassHash) -> ClassHash {
            // Using a library call is not safe as arbitrary code is executed.
            // But deploying the contract we can check the descriptor.
            // If a new syscall supports calling library code with safety checks, we could switch
            // back to using it. But for now, this is the safest option even if it's more expensive.
            let (check_address, _) = deploy_syscall(
                class_hash, starknet::get_tx_info().unbox().transaction_hash, [].span(), false
            )
                .unwrap_syscall();

            let new_descriptor = DescriptorTrait::from_contract_assert(check_address);

            self.assert_namespace(new_descriptor.namespace());
            self.assert_name(new_descriptor.name());

            if let Resource::Contract((contract_address, _)) = self
                .resources
                .read(new_descriptor.selector()) {
                self.assert_caller_permissions(new_descriptor.selector(), Permission::Owner);

                let existing_descriptor = DescriptorTrait::from_contract_assert(contract_address);

                assert!(
                    existing_descriptor == new_descriptor, "invalid contract descriptor for upgrade"
                );

                IUpgradeableDispatcher { contract_address }.upgrade(class_hash);
                self.emit(ContractUpgraded { class_hash, selector: new_descriptor.selector() });

                class_hash
            } else {
                panic_with_byte_array(
                    @errors::resource_conflict(new_descriptor.name(), @"contract")
                )
            }
        }

        fn uuid(ref self: ContractState) -> usize {
            let current = self.nonce.read();
            self.nonce.write(current + 1);
            current
        }

        fn emit_event(
            ref self: ContractState,
            event_selector: felt252,
            keys: Span<felt252>,
            values: Span<felt252>,
            historical: bool
        ) {
            if let Resource::Event((_, _)) = self.resources.read(event_selector) {
                self.assert_caller_permissions(event_selector, Permission::Writer);

                self
                    .emit(
                        EventEmitted {
                            event_selector,
                            system_address: get_caller_address(),
                            historical,
                            keys,
                            values,
                        }
                    );
            } else {
                panic_with_byte_array(
                    @errors::resource_conflict(@format!("{event_selector}"), @"event")
                );
            }
        }

        fn entity(
            self: @ContractState, model_selector: felt252, index: ModelIndex, layout: Layout
        ) -> Span<felt252> {
            match index {
                ModelIndex::Keys(keys) => {
                    let entity_id = entity_id_from_keys(keys);
                    storage::entity_model::read_model_entity(model_selector, entity_id, layout)
                },
                ModelIndex::Id(entity_id) => {
                    storage::entity_model::read_model_entity(model_selector, entity_id, layout)
                },
                ModelIndex::MemberId((
                    entity_id, member_id
                )) => {
                    storage::entity_model::read_model_member(
                        model_selector, entity_id, member_id, layout
                    )
                }
            }
        }

        fn set_entity(
            ref self: ContractState,
            model_selector: felt252,
            index: ModelIndex,
            values: Span<felt252>,
            layout: Layout
        ) {
            if let Resource::Model((_, _)) = self.resources.read(model_selector) {
                self.assert_caller_permissions(model_selector, Permission::Writer);
                self.set_entity_internal(model_selector, index, values, layout);
            } else {
                panic_with_byte_array(
                    @errors::resource_conflict(@format!("{model_selector}"), @"model")
                );
            }
        }

        fn delete_entity(
            ref self: ContractState, model_selector: felt252, index: ModelIndex, layout: Layout
        ) {
            if let Resource::Model((_, _)) = self.resources.read(model_selector) {
                self.assert_caller_permissions(model_selector, Permission::Writer);
                self.delete_entity_internal(model_selector, index, layout);
            } else {
                panic_with_byte_array(
                    @errors::resource_conflict(@format!("{model_selector}"), @"model")
                );
            }
        }

        fn resource(self: @ContractState, selector: felt252) -> Resource {
            self.resources.read(selector)
        }
    }

    #[abi(embed_v0)]
    impl UpgradeableWorld of IUpgradeableWorld<ContractState> {
        fn upgrade(ref self: ContractState, new_class_hash: ClassHash) {
            assert(new_class_hash.is_non_zero(), 'invalid class_hash');

            if !self.is_caller_world_owner() {
                panic_with_byte_array(@errors::not_owner_upgrade(get_caller_address(), WORLD));
            }

            replace_class_syscall(new_class_hash).unwrap();

            self.emit(WorldUpgraded { class_hash: new_class_hash });
        }
    }

    #[generate_trait]
    impl SelfImpl of SelfTrait {
        #[inline(always)]
        /// Indicates if the caller is the owner of the world.
        fn is_caller_world_owner(self: @ContractState) -> bool {
            self.is_owner(WORLD, get_caller_address())
        }

        /// Asserts the caller has the required permissions for a resource, following the
        /// permissions hierarchy:
        /// 1. World Owner
        /// 2. Namespace Owner
        /// 3. Resource Owner
        /// [if writer]
        /// 4. Namespace Writer
        /// 5. Resource Writer
        ///
        /// This function is expected to be called very often as it's used to check permissions
        /// for all the resource access in the system.
        /// For this reason, here are the following optimizations:
        ///     * Use several single `if` because it seems more efficient than a big one with
        ///       several conditions based on how cairo is lowered to sierra.
        ///     * Sort conditions by order of probability so once a condition is met, the function
        ///       returns.
        ///
        /// # Arguments
        ///   * `resource_selector` - the selector of the resource.
        ///   * `permission` - the required permission.
        fn assert_caller_permissions(
            self: @ContractState, resource_selector: felt252, permission: Permission
        ) {
            let caller = get_caller_address();

            if permission == Permission::Writer {
                if self.is_writer(resource_selector, caller) {
                    return;
                }
            }

            if self.is_owner(resource_selector, caller) {
                return;
            }

            if self.is_caller_world_owner() {
                return;
            }

            // At this point, [`Resource::Contract`] and [`Resource::Model`] requires extra checks
            // by switching to the namespace hash being the resource selector.
            let namespace_hash = match self.resources.read(resource_selector) {
                Resource::Contract((_, namespace_hash)) => { namespace_hash },
                Resource::Model((_, namespace_hash)) => { namespace_hash },
                Resource::Unregistered => {
                    panic_with_byte_array(@errors::resource_not_registered(resource_selector))
                },
                _ => self.panic_with_details(caller, resource_selector, permission)
            };

            if permission == Permission::Writer {
                if self.is_writer(namespace_hash, caller) {
                    return;
                }
            }

            if self.is_owner(namespace_hash, caller) {
                return;
            }

            self.panic_with_details(caller, resource_selector, permission)
        }

        ///
        fn assert_name(self: @ContractState, name: @ByteArray) {
            if !dojo::utils::is_name_valid(name) {
                panic_with_byte_array(@errors::invalid_naming("Name", name))
            }
        }

        ///
        fn assert_namespace(self: @ContractState, namespace: @ByteArray) {
            if !dojo::utils::is_name_valid(namespace) {
                panic_with_byte_array(@errors::invalid_naming("Namespace", namespace))
            }
        }

        /// Panics with the caller details.
        ///
        /// # Arguments
        ///   * `caller` - the address of the caller.
        ///   * `resource_selector` - the selector of the resource.
        ///   * `permission` - the required permission.
        fn panic_with_details(
            self: @ContractState,
            caller: ContractAddress,
            resource_selector: felt252,
            permission: Permission
        ) -> core::never {
            let resource_name = match self.resources.read(resource_selector) {
                Resource::Contract((
                    contract_address, _
                )) => {
                    let d = IDescriptorDispatcher { contract_address };
                    format!("contract (or its namespace) `{}`", d.tag())
                },
                Resource::Event((
                    contract_address, _
                )) => {
                    let d = IDescriptorDispatcher { contract_address };
                    format!("event (or its namespace) `{}`", d.tag())
                },
                Resource::Model((
                    contract_address, _
                )) => {
                    let d = IDescriptorDispatcher { contract_address };
                    format!("model (or its namespace) `{}`", d.tag())
                },
                Resource::Namespace(ns) => { format!("namespace `{}`", ns) },
                Resource::World => { format!("world") },
                Resource::Unregistered => { panic!("Unreachable") }
            };

            let caller_name = if caller == get_tx_info().account_contract_address {
                format!("Account `{:?}`", caller)
            } else {
                // If the caller is not a dojo contract, the `d.selector()` will fail. In the
                // future we should use the SRC5 to first query the contract to see if
                // it implements the `IDescriptor` interface.
                // For now, we just assume that the caller is a dojo contract as it's 100% of
                // the dojo use cases at the moment.
                // If the contract is not an account or a dojo contract, tests will display
                // "CONTRACT_NOT_DEPLOYED" as the error message. In production, the error message
                // will display "ENTRYPOINT_NOT_FOUND".
                let d = IDescriptorDispatcher { contract_address: caller };
                format!("Contract `{}`", d.tag())
            };

            panic_with_byte_array(
                @format!("{} does NOT have {} role on {}", caller_name, permission, resource_name)
            )
        }

        /// Indicates if the provided namespace is already registered
        ///
        /// # Arguments
        ///   * `namespace_hash` - the hash of the namespace.
        #[inline(always)]
        fn is_namespace_registered(self: @ContractState, namespace_hash: felt252) -> bool {
            match self.resources.read(namespace_hash) {
                Resource::Namespace => true,
                _ => false
            }
        }

        /// Sets the model value for a model record/entity/member.
        ///
        /// # Arguments
        ///
        /// * `model_selector` - The selector of the model to be set.
        /// * `index` - The index of the record/entity/member to write.
        /// * `values` - The value to be set, serialized using the model layout format.
        /// * `layout` - The memory layout of the model.
        fn set_entity_internal(
            ref self: ContractState,
            model_selector: felt252,
            index: ModelIndex,
            values: Span<felt252>,
            layout: Layout
        ) {
            match index {
                ModelIndex::Keys(keys) => {
                    let entity_id = entity_id_from_keys(keys);
                    storage::entity_model::write_model_entity(
                        model_selector, entity_id, values, layout
                    );
                    self.emit(StoreSetRecord { table: model_selector, keys, values, entity_id });
                },
                ModelIndex::Id(entity_id) => {
                    storage::entity_model::write_model_entity(
                        model_selector, entity_id, values, layout
                    );
                    self.emit(StoreUpdateRecord { table: model_selector, entity_id, values });
                },
                ModelIndex::MemberId((
                    entity_id, member_selector
                )) => {
                    storage::entity_model::write_model_member(
                        model_selector, entity_id, member_selector, values, layout
                    );
                    self
                        .emit(
                            StoreUpdateMember {
                                table: model_selector, entity_id, member_selector, values
                            }
                        );
                }
            }
        }

        /// Deletes an entity for the given model, setting all the values to 0 in the given layout.
        ///
        /// # Arguments
        ///
        /// * `model_selector` - The selector of the model to be deleted.
        /// * `index` - The index of the record/entity to delete.
        /// * `layout` - The memory layout of the model.
        fn delete_entity_internal(
            ref self: ContractState, model_selector: felt252, index: ModelIndex, layout: Layout
        ) {
            match index {
                ModelIndex::Keys(keys) => {
                    let entity_id = entity_id_from_keys(keys);
                    storage::entity_model::delete_model_entity(model_selector, entity_id, layout);
                    self.emit(StoreDelRecord { table: model_selector, entity_id });
                },
                ModelIndex::Id(entity_id) => {
                    storage::entity_model::delete_model_entity(model_selector, entity_id, layout);
                    self.emit(StoreDelRecord { table: model_selector, entity_id });
                },
                ModelIndex::MemberId(_) => { panic_with_felt252(errors::DELETE_ENTITY_MEMBER); }
            }
        }
    }
}
