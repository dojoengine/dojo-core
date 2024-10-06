#[derive(Drop, Serde)]
pub struct $type_name$Entity {
    pub __id: felt252, // private field
    $members_values$
} 

mod $contract_name$_generated {
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

        #[inline(always)]
        fn layout() -> dojo::model::Layout {
            dojo::model::introspect::Introspect::<$type_name$>::layout()
        }
    }

    pub impl $type_name$ModelKeyValue of dojo::model::model::ModelKeyValueTrait<$type_name$> {
        fn entity_id(self: @$type_name$) -> felt252 {
            core::poseidon::poseidon_hash_span(Self::serialized_keys(self))
        }
    
        fn serialized_keys(self: @$type_name$) -> Span<felt252> {
            let mut serialized = core::array::ArrayTrait::new();
            $serialized_keys$
            core::array::ArrayTrait::span(@serialized)
        }
    
        fn serialized_values(self: @$type_name$) -> Span<felt252> {
            let mut serialized = core::array::ArrayTrait::new();
            $serialized_values$
            core::array::ArrayTrait::span(@serialized)
        }
    
        fn from_serialized_values(keys: Span<felt252>, values: Span<felt252>) -> $type_name$ {
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
    
    pub impl $type_name$EntityIdValue of dojo::model::model::EntityIdValueTrait<$type_name$Entity>{
        fn id(self: @$type_name$Entity) -> felt252 {
            *self.__id
        }
        fn serialized_values(self: @$type_name$Entity) -> Span<felt252> {
            let mut serialized = core::array::ArrayTrait::new();
            $serialized_values$
            core::array::ArrayTrait::span(@serialized)
        }
        fn from_serialized_values(entity_id: felt252, values: Span<felt252>) -> $type_name$Entity {
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
    }

    pub impl $type_name$ModelImpl = dojo::model::model::ModelImpl<$type_name$>;
    pub impl $type_name$ModelEntityImpl = dojo::model::model::ModelEntityImpl<$type_name$Entity>;
}
pub use $contract_name$_generated::{$type_name$ModelImpl, $type_name$ModelEntityImpl};

pub impl $type_name$Attributes = $contract_name$_generated::$type_name$AttributesImpl<$type_name$>;
pub impl $type_name$EntityAttributes = $contract_name$_generated::$type_name$AttributesImpl<$type_name$Entity>;



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
    fn serialize_keys($param_keys$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_param_keys$
        serialized.span()
    }

    fn entity_id_from_keys($param_keys$) -> felt252 {
        core::poseidon::poseidon_hash_span(Self::serialize_keys($keys$))
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
        $type_name$ModelImpl::get(world, Self::serialize_keys($keys$))
    }

    fn set(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        $type_name$ModelImpl::set_model(self, world);
    }

    fn delete(self: @$type_name$, world: dojo::world::IWorldDispatcher) {
        $type_name$ModelImpl::delete_model(self, world);
    }

    $field_accessors$
}

#[cfg(target: "test")]
pub impl $type_name$ModelEntityTestImpl of dojo::model::ModelEntityTest<$type_name$Entity> {
    fn update_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id($type_name$ModelEntityImpl::id(self)),
            $type_name$ModelEntityImpl::values(self),
            $type_name$ModelImpl::layout()
        );
    }

    fn delete_test(self: @$type_name$Entity, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher { contract_address: 
             world.contract_address };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            $type_name$ModelImpl::selector(),
            dojo::model::ModelIndex::Id($type_name$ModelEntityImpl::id(self)),
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