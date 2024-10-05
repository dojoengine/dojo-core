
#[derive(Drop, Serde)]
pub struct $type_name$Entity {
    __id: felt252, // private field
    $members_values$
}

mod $contract_name$_attributes {
    use super::{$type_name$, $type_name$Entity};   
    pub impl $type_name$AttributesImpl<M> of dojo::model::ModelAttributes<M>{
        const VERSION: u8 = $model_version$;
        const SELECTOR: felt252 = $model_selector$;
        const NAME_HASH: felt252 = $model_name_hash$;
        const NAMESPACE_HASH: felt252 = $model_namespace_hash$;

        #[inline(always)]
        fn name() -> ByteArray {
            "$type_name$"
        }
        
        #[inline(always)]
        fn namespace() -> ByteArray {
            "$model_namespace$"
        }
        
        #[inline(always)]
        fn tag() -> ByteArray {
            "$model_tag$"
        }
    }
    pub impl $type_name$Attributes = $type_name$AttributesImpl<$type_name$>;
    pub impl $type_name$EntityAttributes = $type_name$AttributesImpl<$type_name$Entity>;
}

pub use $contract_name$_attributes::{$type_name$Attributes, $type_name$EntityAttributes};

pub impl $type_name$ModelKeyValue of dojo::model::model::ModelKeyValueTrait<$type_name$> {
    fn keys(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }

    fn values(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }

    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> $type_name$ {
        let mut serialized = core::array::ArrayTrait::new();
        serialized.append_span(keys);
        serialized.append_span(values);
        let mut serialized = core::array::ArrayTrait::span(@serialized);

        let entity = core::serde::Serde::<$type_name$>::deserialize(ref serialized);

        if core::option::OptionTrait::<$type_name$>::is_none(@entity) {
            panic!(
                "Model `$type_name$`: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
            );
        }

        core::option::OptionTrait::<$type_name$>::unwrap(entity)
    }
}




pub impl $type_name$ModelImpl = dojo::model::model_impl::ModelImpl<$type_name$>;

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

    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> $type_name$ {
        let mut serialized = core::array::ArrayTrait::new();
        serialized.append_span(keys);
        serialized.append_span(values);
        let mut serialized = core::array::ArrayTrait::span(@serialized);

        let entity = core::serde::Serde::<$type_name$>::deserialize(ref serialized);

        if core::option::OptionTrait::<$type_name$>::is_none(@entity) {
            panic!(
                "Model `$type_name$`: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
            );
        }

        core::option::OptionTrait::<$type_name$>::unwrap(entity)
    }

    fn get(world: dojo::world::IWorldDispatcher, $param_keys$) -> $type_name$ {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$

        $type_name$ModelImpl::get(world, serialized.span())
    }

    fn set(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        $type_name$ModelImpl::set_model(self, world);
    }

    fn delete(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        $type_name$ModelImpl::delete_model(self, world);
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

    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> $type_name$Entity {
        let mut serialized = array![entity_id];
        serialized.append_span(values);
        let mut serialized = core::array::ArrayTrait::span(@serialized);

        let entity_values = core::serde::Serde::<$type_name$Entity>::deserialize(ref serialized);
        if core::option::OptionTrait::<$type_name$Entity>::is_none(@entity_values) {
            panic!(
                "ModelEntity `$type_name$Entity`: deserialization failed."
            );
        }
        core::option::OptionTrait::<$type_name$Entity>::unwrap(entity_values)
    }

    fn get(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> $type_name$Entity {
        let mut values = dojo::world::IWorldDispatcherTrait::entity(
            world,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id(entity_id),
            $type_name$ModelImpl::layout()
        );
        Self::from_values(entity_id, ref values)
    }

    fn update_entity(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::set_entity(
            world,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            self.values(),
            $type_name$ModelImpl::layout()
        );
    }

    fn delete_entity(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        dojo::world::IWorldDispatcherTrait::delete_entity(
            world,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            $type_name$ModelImpl::layout()
        );
    }

    fn get_member(
        world: dojo::world::IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout($type_name$ModelImpl::layout(), 
             member_id) {
            Option::Some(field_layout) => {
                dojo::world::IWorldDispatcherTrait::entity(
                    world,
                    $type_name$ModelImpl::selector(),
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
        match dojo::utils::find_model_field_layout($type_name$ModelImpl::layout(), 
             member_id) {
            Option::Some(field_layout) => {
                dojo::world::IWorldDispatcherTrait::set_entity(
                    world,
                    $type_name$ModelImpl::selector(),
                    dojo::model::ModelIndex::MemberId((self.id(), member_id)),
                    values,
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }
}

#[cfg(target: "test")]
pub impl $type_name$ModelEntityTestImpl of dojo::model::ModelEntityTest<$type_name$Entity> {
    fn update_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            self.values(),
            $type_name$ModelImpl::layout()
        );
    }

    fn delete_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id(self.id()),
            $type_name$ModelImpl::layout()
        );
    }
}



#[cfg(target: "test")]
pub impl $type_name$ModelTestImpl of dojo::model::ModelTest<$type_name$> {
   fn set_test(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Keys($type_name$ModelImpl::keys(self)),
            $type_name$ModelImpl::values(self),
            $type_name$ModelImpl::layout()
        );
    }

    fn delete_test(
        self: @$type_name$,
        world: dojo::world::IWorldDispatcher
    ) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Keys($type_name$ModelImpl::keys(self)),
            $type_name$ModelImpl::layout()
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
    use super::$type_name$Attributes;
    use super::$type_name$ModelImpl;
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl of dojo::model::IModel<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
            $type_name$Attributes::name()
        }

        fn namespace(self: @ContractState) -> ByteArray {
            $type_name$Attributes::namespace()
        }

        fn tag(self: @ContractState) -> ByteArray {
            $type_name$Attributes::tag()
        }

        fn version(self: @ContractState) -> u8 {
            $type_name$Attributes::VERSION
        }

        fn selector(self: @ContractState) -> felt252 {
            $type_name$Attributes::SELECTOR
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $type_name$Attributes::NAME_HASH
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $type_name$Attributes::NAMESPACE_HASH
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            dojo::model::introspect::Introspect::<$type_name$>::size()
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            $type_name$ModelImpl::packed_size()
        }

        fn layout(self: @ContractState) -> dojo::model::Layout {
            $type_name$ModelImpl::layout()
        }

        fn schema(self: @ContractState) -> dojo::model::introspect::Ty {
            dojo::model::introspect::Introspect::<$type_name$>::ty()
        }
    }

    #[abi(embed_v0)]
    impl $contract_name$Impl of I$contract_name$<ContractState>{
        fn ensure_abi(self: @ContractState, model: $type_name$) {
        }
    }
}