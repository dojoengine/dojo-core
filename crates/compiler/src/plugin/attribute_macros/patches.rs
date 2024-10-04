pub const DEFAULT_INIT_PATCH: &str = "
#[starknet::interface]
pub trait IDojoInit<ContractState> {
    fn $init_name$(self: @ContractState);
}

#[abi(embed_v0)]
pub impl IDojoInitImpl of IDojoInit<ContractState> {
    fn $init_name$(self: @ContractState) {
        if starknet::get_caller_address() != self.world().contract_address {
            core::panics::panic_with_byte_array(
                @format!(\"Only the world can init contract `{}`, but caller \
 is `{:?}`\",
                self.tag(),
                starknet::get_caller_address(),
            ));
        }
    }
}
";

pub const CONTRACT_PATCH: &str = "
                #[starknet::contract]
                pub mod $name$ {
                    use dojo::world;
                    use dojo::world::IWorldDispatcher;
                    use dojo::world::IWorldDispatcherTrait;
                    use dojo::world::IWorldProvider;
                    use dojo::contract::IContract;
                    use starknet::storage::{
                        StorageMapReadAccess, StorageMapWriteAccess, StoragePointerReadAccess, \
                     StoragePointerWriteAccess
                    };

                    component!(path: dojo::contract::upgradeable::upgradeable, storage: \
                     upgradeable, event: UpgradeableEvent);

                    #[abi(embed_v0)]
                    pub impl ContractImpl of IContract<ContractState> {
                        fn name(self: @ContractState) -> ByteArray {
                            \"$name$\"
                        }

                        fn namespace(self: @ContractState) -> ByteArray {
                            \"$contract_namespace$\"
                        }

                        fn tag(self: @ContractState) -> ByteArray {
                            \"$contract_tag$\"
                        }

                        fn name_hash(self: @ContractState) -> felt252 {
                            $contract_name_hash$
                        }

                        fn namespace_hash(self: @ContractState) -> felt252 {
                            $contract_namespace_hash$
                        }

                        fn selector(self: @ContractState) -> felt252 {
                            $contract_selector$
                        }
                    }

                    #[abi(embed_v0)]
                    impl WorldProviderImpl of IWorldProvider<ContractState> {
                        fn world(self: @ContractState) -> IWorldDispatcher {
                            self.world_dispatcher.read()
                        }
                    }

                    #[abi(embed_v0)]
                    impl UpgradableImpl = \
                     dojo::contract::upgradeable::upgradeable::UpgradableImpl<ContractState>;

                    $body$
                }
";

pub const MODEL_PATCH: &str = "
#[derive(Drop, Serde)]
pub struct $type_name$Entity {
    __id: felt252, // private field
    $members_values$
}

#[generate_trait]
pub impl $type_name$EntityStoreImpl of $type_name$EntityStore {
    fn get(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $type_name$Entity {
        $type_name$ModelEntityImpl::get(world, entity_id)
    }

    fn update(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::model::ModelEntity::<$type_name$Entity>::update_entity(self, world);
    }

    fn delete(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::model::ModelEntity::<$type_name$Entity>::delete_entity(self, world);
    }

    $entity_field_accessors$
}

#[generate_trait]
pub impl $type_name$StoreImpl of $type_name$Store {
    fn entity_id_from_keys($param_keys$) -> felt252 {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$
        core::poseidon::poseidon_hash_span(serialized.span())
    }

    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<$type_name$> {
        $deserialized_keys$
        $deserialized_values$

        Option::Some(
            $type_name$ {
                $member_key_names$
                $member_value_names$
            }
        )
    }

    fn get(world: dojo::world::IWorldDispatcher, $param_keys$) -> $type_name$ {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$

        dojo::model::Model::<$type_name$>::get(world, serialized.span())
    }

    fn set(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        dojo::model::Model::<$type_name$>::set_model(self, world);
    }

    fn delete(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        dojo::model::Model::<$type_name$>::delete_model(self, world);
    }

    $field_accessors$
}

pub impl $type_name$ModelEntityImpl of dojo::model::ModelEntity<$type_name$Entity> {
    fn id(self: @$type_name$Entity) -> felt252 {
        *self.__id
    }

    fn values(self: @$type_name$Entity) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }

    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<$type_name$Entity> {
        $deserialized_values$

        Option::Some(
            $type_name$Entity {
                __id: entity_id,
                $member_value_names$
            }
        )
    }

    fn get(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $type_name$Entity {
        let mut values = dojo::world::IWorldDispatcherTrait::entity(
            world,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Id(entity_id),
            dojo::model::Model::<$type_name$>::layout()
        );
        match Self::from_values(entity_id, ref values) {
            Option::Some(x) => x,
            Option::None => {
                panic!(\"ModelEntity `$type_name$Entity`: deserialization failed.\")
            }
        }
    }

    fn update_entity(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::set_entity(
            world,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            self.values(),
            dojo::model::Model::<$type_name$>::layout()
        );
    }

    fn delete_entity(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::delete_entity(
            world,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            dojo::model::Model::<$type_name$>::layout()
        );
    }

    fn get_member(
        world: dojo::world::IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout(dojo::model::Model::<$type_name$>::layout(), \
             member_id) {
            Option::Some(field_layout) => {
                dojo::world::IWorldDispatcherTrait::entity(
                    world,
                    dojo::model::Model::<$type_name$>::selector(),
                    dojo::model::ModelIndex::MemberId((entity_id, member_id)),
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    fn set_member(
        self: @$type_name$Entity,
        world: dojo::world::IWorldDispatcher,
        member_id: felt252,
        values: Span<felt252>,
    ) {
        match dojo::utils::find_model_field_layout(dojo::model::Model::<$type_name$>::layout(), \
             member_id) {
            Option::Some(field_layout) => {
                dojo::world::IWorldDispatcherTrait::set_entity(
                    world,
                    dojo::model::Model::<$type_name$>::selector(),
                    dojo::model::ModelIndex::MemberId((self.id(), member_id)),
                    values,
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }
}

#[cfg(target: \"test\")]
pub impl $type_name$ModelEntityTestImpl of dojo::model::ModelEntityTest<$type_name$Entity> {
    fn update_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: \
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            self.values(),
            dojo::model::Model::<$type_name$>::layout()
        );
    }

    fn delete_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: \
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            dojo::model::Model::<$type_name$>::layout()
        );
    }
}

pub impl $type_name$ModelImpl of dojo::model::Model<$type_name$> {
    fn get(world: dojo::world::IWorldDispatcher, keys: Span<felt252>) -> $type_name$ {
        let mut values = dojo::world::IWorldDispatcherTrait::entity(
            world,
            Self::selector(),
            dojo::model::ModelIndex::Keys(keys),
            Self::layout()
        );
        let mut _keys = keys;

        match $type_name$Store::from_values(ref _keys, ref values) {
            Option::Some(x) => x,
            Option::None => {
                panic!(\"Model `$type_name$`: deserialization failed.\")
            }
        }
    }

   fn set_model(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        dojo::world::IWorldDispatcherTrait::set_entity(
            world,
            Self::selector(),
            dojo::model::ModelIndex::Keys(Self::keys(self)),
            Self::values(self),
            Self::layout()
        );
    }

    fn delete_model(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        dojo::world::IWorldDispatcherTrait::delete_entity(
            world,
            Self::selector(),
            dojo::model::ModelIndex::Keys(Self::keys(self)),
            Self::layout()
        );
    }

    fn get_member(
        world: dojo::world::IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout(Self::layout(), member_id) {
            Option::Some(field_layout) => {
                let entity_id = dojo::utils::entity_id_from_keys(keys);
                dojo::world::IWorldDispatcherTrait::entity(
                    world,
                    Self::selector(),
                    dojo::model::ModelIndex::MemberId((entity_id, member_id)),
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    fn set_member(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher,
        member_id: felt252,
        values: Span<felt252>
    ) {
        match dojo::utils::find_model_field_layout(Self::layout(), member_id) {
            Option::Some(field_layout) => {
                dojo::world::IWorldDispatcherTrait::set_entity(
                    world,
                    Self::selector(),
                    dojo::model::ModelIndex::MemberId((self.entity_id(), member_id)),
                    values,
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    #[inline(always)]
    fn name() -> ByteArray {
        \"$type_name$\"
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        \"$model_namespace$\"
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        \"$model_tag$\"
    }

    #[inline(always)]
    fn version() -> u8 {
        $model_version$
    }

    #[inline(always)]
    fn selector() -> felt252 {
        $model_selector$
    }

    #[inline(always)]
    fn instance_selector(self: @$type_name$) -> felt252 {
        Self::selector()
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        $model_name_hash$
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        $model_namespace_hash$
    }

    #[inline(always)]
    fn entity_id(self: @$type_name$) -> felt252 {
        core::poseidon::poseidon_hash_span(self.keys())
    }

    #[inline(always)]
    fn keys(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn values(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn layout() -> dojo::meta::Layout {
        dojo::meta::introspect::Introspect::<$type_name$>::layout()
    }

    #[inline(always)]
    fn instance_layout(self: @$type_name$) -> dojo::meta::Layout {
        Self::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        dojo::meta::layout::compute_packed_size(Self::layout())
    }
}

#[cfg(target: \"test\")]
pub impl $type_name$ModelTestImpl of dojo::model::ModelTest<$type_name$> {
   fn set_test(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: \
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Keys(dojo::model::Model::<$type_name$>::keys(self)),
            dojo::model::Model::<$type_name$>::values(self),
            dojo::model::Model::<$type_name$>::layout()
        );
    }

    fn delete_test(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: \
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            dojo::model::Model::<$type_name$>::selector(),
            dojo::model::ModelIndex::Keys(dojo::model::Model::<$type_name$>::keys(self)),
            dojo::model::Model::<$type_name$>::layout()
        );
    }
}

#[starknet::interface]
pub trait I$contract_name$<T> {
    fn ensure_abi(self: @T, model: $type_name$);
}

#[starknet::contract]
pub mod $contract_name$ {
    use super::$type_name$;
    use super::I$contract_name$;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl of dojo::model::IModel<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
           \"$type_name$\"
        }

        fn namespace(self: @ContractState) -> ByteArray {
           \"$model_namespace$\"
        }

        fn tag(self: @ContractState) -> ByteArray {
            \"$model_tag$\"
        }

        fn version(self: @ContractState) -> u8 {
           $model_version$
        }

        fn selector(self: @ContractState) -> felt252 {
           $model_selector$
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $model_name_hash$
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $model_namespace_hash$
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            dojo::meta::introspect::Introspect::<$type_name$>::size()
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            dojo::model::Model::<$type_name$>::packed_size()
        }

        fn layout(self: @ContractState) -> dojo::meta::Layout {
            dojo::model::Model::<$type_name$>::layout()
        }

        fn schema(self: @ContractState) -> dojo::meta::introspect::Ty {
            dojo::meta::introspect::Introspect::<$type_name$>::ty()
        }
    }

    #[abi(embed_v0)]
    impl $contract_name$Impl of I$contract_name$<ContractState>{
        fn ensure_abi(self: @ContractState, model: $type_name$) {
        }
    }
}
";

pub const EVENT_PATCH: &str = "
pub impl $type_name$EventImpl of dojo::event::Event<$type_name$> {

    fn emit(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::emit(
            world,
            Self::selector(),
            Self::keys(self),
            Self::values(self),
            Self::historical()
        );
    }

    #[inline(always)]
    fn name() -> ByteArray {
        \"$type_name$\"
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        \"$event_namespace$\"
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        \"$event_tag$\"
    }

    #[inline(always)]
    fn version() -> u8 {
        $event_version$
    }

    #[inline(always)]
    fn selector() -> felt252 {
        $event_selector$
    }

    #[inline(always)]
    fn instance_selector(self: @$type_name$) -> felt252 {
        Self::selector()
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        $event_name_hash$
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        $event_namespace_hash$
    }

    #[inline(always)]
    fn layout() -> dojo::meta::Layout {
        dojo::meta::introspect::Introspect::<$type_name$>::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        dojo::meta::layout::compute_packed_size(Self::layout())
    }

    #[inline(always)]
    fn unpacked_size() -> Option<usize> {
        dojo::meta::introspect::Introspect::<$type_name$>::size()
    }

    #[inline(always)]
    fn schema(self: @$type_name$) -> dojo::meta::introspect::Ty {
        dojo::meta::introspect::Introspect::<$type_name$>::ty()
    }

    #[inline(always)]
    fn historical() -> bool {
        $event_historical$
    }

    #[inline(always)]
    fn keys(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn values(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
}

#[starknet::contract]
pub mod $contract_name$ {
    use super::$type_name$;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoEventImpl of dojo::event::IEvent<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
           \"$type_name$\"
        }

        fn namespace(self: @ContractState) -> ByteArray {
           \"$event_namespace$\"
        }

        fn tag(self: @ContractState) -> ByteArray {
            \"$event_tag$\"
        }

        fn version(self: @ContractState) -> u8 {
           $event_version$
        }

        fn selector(self: @ContractState) -> felt252 {
           $event_selector$
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $event_name_hash$
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $event_namespace_hash$
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            dojo::meta::introspect::Introspect::<$type_name$>::size()
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            dojo::event::Event::<$type_name$>::packed_size()
        }

        fn layout(self: @ContractState) -> dojo::meta::Layout {
            dojo::event::Event::<$type_name$>::layout()
        }

        fn schema(self: @ContractState) -> dojo::meta::introspect::Ty {
            dojo::meta::introspect::Introspect::<$type_name$>::ty()
        }
    }
}
";
