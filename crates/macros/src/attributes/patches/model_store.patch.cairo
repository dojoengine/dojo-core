#[derive($entity_derive_attr_names$)]
pub struct $model_type$Entity {
    __id: felt252, // private field
    $members_values$
} 

type $model_type$KeyType = $key_type$;

pub impl $model_type$KeyParser of dojo::model::model::KeyParser<$model_type$, $model_type$KeyType>{
    #[inline(always)]
    fn parse_key(self: @$model_type$) -> $model_type$KeyType {
        $keys_to_tuple$
    }
}

impl $model_type$EntityKey of dojo::model::entity::EntityKey<$model_type$Entity, $model_type$KeyType> {
}

// Impl to get the static definition of a model
pub mod $model_type_snake$_definition {
    use super::$model_type$;
    pub impl $model_type$DefinitionImpl<T> of dojo::model::ModelDefinition<T>{
        #[inline(always)]
        fn name() -> ByteArray {
            "$model_type$"
        }

        #[inline(always)]
        fn version() -> u8 {
            $model_version$
        }

        #[inline(always)]
        fn layout() -> dojo::meta::Layout {
            dojo::meta::Introspect::<$model_type$>::layout()
        }

        #[inline(always)]
        fn schema() -> dojo::meta::introspect::Ty {
            dojo::meta::Introspect::<$model_type$>::ty()
        }

        #[inline(always)]
        fn size() -> Option<usize> {
            dojo::meta::Introspect::<$model_type$>::size()
        }
    }
}

pub impl $model_type$Definition = $model_type_snake$_definition::$model_type$DefinitionImpl<$model_type$>;
pub impl $model_type$EntityDefinition = $model_type_snake$_definition::$model_type$DefinitionImpl<$model_type$Entity>;

pub impl $model_type$ModelParser of dojo::model::model::ModelParser<$model_type$>{
    fn serialize_keys(self: @$model_type$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }
    fn serialize_values(self: @$model_type$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
} 

pub impl $model_type$EntityParser of dojo::model::entity::EntityParser<$model_type$Entity>{
    fn parse_id(self: @$model_type$Entity) -> felt252 {
        *self.__id
    }
    fn serialize_values(self: @$model_type$Entity) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
}

pub impl $model_type$ModelImpl = dojo::model::model::ModelImpl<$model_type$>;
pub impl $model_type$Store = dojo::model::model::ModelStoreImpl<$model_type$>;

pub impl $model_type$EntityImpl = dojo::model::entity::EntityImpl<$model_type$Entity>;
pub impl $model_type$EntityStore = dojo::model::entity::EntityStoreImpl<$model_type$Entity>;

#[generate_trait]
pub impl $model_type$MembersStoreImpl of $model_type$MembersStore {
$field_accessors$
}

#[starknet::interface]
pub trait I$model_type$<T> {
    fn ensure_abi(self: @T, model: $model_type$);
}

#[starknet::contract]
pub mod $model_type_snake$ {
    use super::$model_type$;
    use super::I$model_type$;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl = dojo::model::component::IModelImpl<ContractState, $model_type$>;

    #[abi(embed_v0)]
    impl $model_type$Impl of I$model_type$<ContractState>{
        fn ensure_abi(self: @ContractState, model: $model_type$) {
        }
    }
}


#[cfg(target: "test")]
pub impl $model_type$ModelTestImpl = dojo::model::model::ModelTestImpl<$model_type$>;

#[cfg(target: "test")]
pub impl $model_type$ModelEntityTestImpl = dojo::model::entity::ModelEntityTestImpl<$model_type$Entity>;
