#[derive($derive_tags$)]
pub struct $model_type$Entity {
    __id: felt252, // private field
    $members_values$
} 

type $model_type$KeyType = $key_type$;

pub impl $model_type$ModelKeyImpl of dojo::model::members::key::KeyParserTrait<$model_type$, $model_type$KeyType>{
    #[inline(always)]
    fn serde_key(self: @$model_type$) -> $model_type$KeyType {
        $keys_to_tuple$
    }
} 

pub impl $model_type$KeyImpl = dojo::model::members::key::KeyImpl<$model_type$KeyType>;

// Impl to get the static attributes of a model
pub mod $model_name_snake$_attributes {
    use super::$model_type$;
    pub impl $model_type$AttributesImpl<T> of dojo::model::ModelAttributes<T>{
        #[inline(always)]
        fn version() -> u8 {
            $model_version$
        }
       
        #[inline(always)]
        fn selector() -> felt252 {
            $model_selector$
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
        fn name() -> ByteArray {
            "$model_type$"
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
        fn layout() -> dojo::meta::Layout {
            dojo::meta::Introspect::<$model_type$>::layout()
        }
    }
    
}


pub impl $model_type$Attributes = $model_name_snake$_attributes::$model_type$AttributesImpl<$model_type$>;
pub impl $model_type$EntityAttributes = $model_name_snake$_attributes::$model_type$AttributesImpl<$model_type$Entity>;

pub impl $model_type$ModelSerdeImpl of dojo::model::model::ModelSerde<$model_type$>{
    fn serde_keys(self: @$model_type$) -> Span<felt252> {
        dojo::model::members::MemberTrait::<$model_type$KeyType>::serialize(
            @$model_type$ModelKeyImpl::serde_key(self)
        )
    }
    fn serde_values(self: @$model_type$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
    fn serde_keys_values(self: @$model_type$) -> (Span<felt252>, Span<felt252>) {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        (Self::serde_keys(self), core::array::ArrayTrait::span(@serialized))
    }
}

pub impl $model_type$EntitySerdeImpl of dojo::model::entity::EntitySerde<$model_type$Entity>{
    fn serde_id(self: @$model_type$Entity) -> felt252 {
        *self.__id
    }
    fn serde_values(self: @$model_type$Entity) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }
    fn serde_id_values(self: @$model_type$Entity) -> (felt252, Span<felt252>) {
        (*self.__id, Self::serde_values(self))
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
pub mod $model_name_snake$ {
    use super::$model_type$;
    use super::I$model_type$;
    use super::$model_type$Attributes;
    use super::$model_type$ModelImpl;
    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl of dojo::model::IModel<ContractState>{
        fn name(self: @ContractState) -> ByteArray {
            $model_type$Attributes::name()
        }

        fn namespace(self: @ContractState) -> ByteArray {
            $model_type$Attributes::namespace()
        }

        fn tag(self: @ContractState) -> ByteArray {
            $model_type$Attributes::tag()
        }

        fn version(self: @ContractState) -> u8 {
            $model_type$Attributes::version()
        }

        fn selector(self: @ContractState) -> felt252 {
            $model_type$Attributes::selector()
        }

        fn name_hash(self: @ContractState) -> felt252 {
            $model_type$Attributes::name_hash()
        }

        fn namespace_hash(self: @ContractState) -> felt252 {
            $model_type$Attributes::namespace_hash()
        }

        fn unpacked_size(self: @ContractState) -> Option<usize> {
            dojo::meta::Introspect::<$model_type$>::size()
        }

        fn packed_size(self: @ContractState) -> Option<usize> {
            dojo::meta::layout::compute_packed_size($model_type$Attributes::layout())
        }

        fn layout(self: @ContractState) -> dojo::meta::Layout {
            $model_type$Attributes::layout()
        }

        fn schema(self: @ContractState) -> dojo::meta::introspect::Ty {
            dojo::meta::Introspect::<$model_type$>::ty()
        }
    }

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
