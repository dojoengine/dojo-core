//! ResourceMetadata model.
//!
use dojo::model::model::Model;
use dojo::utils;

//#[derive(Introspect, Drop, Serde, PartialEq, Clone, Debug)]
//#[dojo_model]
pub struct ResourceMetadata2 {
    #[key]
    pub resource_id: felt252,
    pub metadata_uri: ByteArray,
}

pub fn default_address() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

pub fn default_class_hash() -> starknet::ClassHash {
    starknet::class_hash::class_hash_const::<0>()
}

pub fn resource_metadata_selector(default_namespace_hash: felt252) -> felt252 {
    utils::selector_from_namespace_and_name(
        default_namespace_hash, @Model::<ResourceMetadata>::name()
    )
}

// *> EXPAND MODEL PATCH: ResourceMetadata <*
#[derive(Drop, Serde, PartialEq, Clone, Debug)]
pub struct ResourceMetadata {
    #[key]
    pub resource_id: felt252,
    pub metadata_uri: ByteArray,
}
#[derive(Drop, Serde, PartialEq, Clone, Debug)]
pub struct ResourceMetadataValue {
    __id: felt252, // private field
    pub metadata_uri: ByteArray,
}

type ResourceMetadataKeyType = felt252;

pub impl ResourceMetadataKeyParser of dojo::model::model::KeyParser<
    ResourceMetadata, ResourceMetadataKeyType
> {
    #[inline(always)]
    fn parse_key(self: @ResourceMetadata) -> ResourceMetadataKeyType {
        *self.resource_id
    }
}

impl ResourceMetadataModelValueKey of dojo::model::model_value::ModelValueKey<
    ResourceMetadataValue, ResourceMetadataKeyType
> {}

// Impl to get the static definition of a model
pub mod resource_metadata_definition {
    use super::ResourceMetadata;
    pub impl ResourceMetadataDefinitionImpl<T> of dojo::model::ModelDefinition<T> {
        #[inline(always)]
        fn name() -> ByteArray {
            "ResourceMetadata"
        }

        #[inline(always)]
        fn version() -> u8 {
            0
        }

        #[inline(always)]
        fn layout() -> dojo::meta::Layout {
            dojo::meta::Introspect::<ResourceMetadata>::layout()
        }

        #[inline(always)]
        fn schema() -> dojo::meta::introspect::Ty {
            dojo::meta::Introspect::<ResourceMetadata>::ty()
        }

        #[inline(always)]
        fn size() -> Option<usize> {
            dojo::meta::Introspect::<ResourceMetadata>::size()
        }
    }
}

pub impl ResourceMetadataDefinition =
    resource_metadata_definition::ResourceMetadataDefinitionImpl<ResourceMetadata>;
pub impl ResourceMetadataModelValueDefinition =
    resource_metadata_definition::ResourceMetadataDefinitionImpl<ResourceMetadataValue>;

pub impl ResourceMetadataModelParser of dojo::model::model::ModelParser<ResourceMetadata> {
    fn serialize_keys(self: @ResourceMetadata) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(self.resource_id, ref serialized);

        core::array::ArrayTrait::span(@serialized)
    }
    fn serialize_values(self: @ResourceMetadata) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(self.metadata_uri, ref serialized);

        core::array::ArrayTrait::span(@serialized)
    }
}

pub impl ResourceMetadataModelValueParser of dojo::model::model_value::ModelValueParser<
    ResourceMetadataValue
> {
    fn parse_id(self: @ResourceMetadataValue) -> felt252 {
        *self.__id
    }
    fn serialize_values(self: @ResourceMetadataValue) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        core::serde::Serde::serialize(self.metadata_uri, ref serialized);

        core::array::ArrayTrait::span(@serialized)
    }
}

pub impl ResourceMetadataModelImpl = dojo::model::model::ModelImpl<ResourceMetadata>;
pub impl ResourceMetadataStore<S, +dojo::model::storage::ModelStorage<S, ResourceMetadata>> =
    dojo::model::model::ModelStoreImpl<S, ResourceMetadata>;

pub impl ResourceMetadataModelValueImpl =
    dojo::model::model_value::ModelValueImpl<ResourceMetadataValue>;
pub impl ResourceMetadataModelValueStore<
    S, +dojo::model::storage::ModelValueStorage<S, ResourceMetadataValue>
> =
    dojo::model::model_value::ModelValueStoreImpl<S, ResourceMetadataValue>;

#[generate_trait]
pub impl ResourceMetadataMembersStoreImpl<
    S,
    +dojo::model::storage::ModelStorage<S, ResourceMetadata>,
    +dojo::model::storage::MemberModelStorage<S, ResourceMetadata, ByteArray>,
    +dojo::model::storage::ModelValueStorage<S, ResourceMetadataValue>,
    +dojo::model::storage::ModelStorage<S, ResourceMetadataValue>,
    +dojo::model::storage::MemberModelStorage<S, ResourceMetadataValue, ByteArray>,
    +dojo::model::members::MemberStore::<S, dojo::model::metadata::ResourceMetadataValue, core::byte_array::ByteArray>,
    +Drop<S>,
> of ResourceMetadataMembersStore<S> {
    fn get_metadata_uri(self: @S, key: ResourceMetadataKeyType) -> ByteArray {
        ResourceMetadataStore::get_member(
            self, key, 815903823124453119243971298555977249487241195972064209763947138938752137060
        )
    }

    fn get_metadata_uri_from_id(self: @S, entity_id: felt252) -> ByteArray {
        ResourceMetadataModelValueStore::get_member_from_id(
            self,
            entity_id,
            815903823124453119243971298555977249487241195972064209763947138938752137060
        )
    }

    fn update_metadata_uri(
        self: S, key: ResourceMetadataKeyType, value: ByteArray
    ) {
        ResourceMetadataStore::update_member(
            self,
            key,
            815903823124453119243971298555977249487241195972064209763947138938752137060,
            value
        );
    }

    fn update_metadata_uri_from_id(
        self: S, entity_id: felt252, value: ByteArray
    ) {
        ResourceMetadataModelValueStore::update_member_from_id(
            self,
            entity_id,
            815903823124453119243971298555977249487241195972064209763947138938752137060,
            value
        );
    }
}

#[starknet::interface]
pub trait IResourceMetadata<T> {
    fn ensure_abi(self: @T, model: ResourceMetadata);
}

#[starknet::contract]
pub mod resource_metadata {
    use super::ResourceMetadata;
    use super::IResourceMetadata;

    #[storage]
    struct Storage {}

    #[abi(embed_v0)]
    impl DojoModelImpl =
        dojo::model::component::IModelImpl<ContractState, ResourceMetadata>;

    #[abi(embed_v0)]
    impl ResourceMetadataImpl of IResourceMetadata<ContractState> {
        fn ensure_abi(self: @ContractState, model: ResourceMetadata) {}
    }
}


#[cfg(target: "test")]
pub impl ResourceMetadataModelTestImpl<S, +dojo::model::storage::ModelStorageTest<S, ResourceMetadata>> =
    dojo::model::model::ModelTestImpl<S, ResourceMetadata>;

#[cfg(target: "test")]
pub impl ResourceMetadataModelValueTestImpl<S, +dojo::model::storage::ModelValueStorageTest<S, ResourceMetadataValue>> =
    dojo::model::model_value::ModelValueTestImpl<S, ResourceMetadataValue>;


// *> EXPAND DERIVE #[derive(Introspect)]

impl ResourceMetadataIntrospect<> of dojo::meta::introspect::Introspect<ResourceMetadata<>> {
    #[inline(always)]
    fn size() -> Option<usize> {
        Option::None
    }

    fn layout() -> dojo::meta::Layout {
        dojo::meta::Layout::Struct(
            array![
                dojo::meta::FieldLayout {
                    selector: 815903823124453119243971298555977249487241195972064209763947138938752137060,
                    layout: dojo::meta::introspect::Introspect::<ByteArray>::layout()
                }
            ]
                .span()
        )
    }

    #[inline(always)]
    fn ty() -> dojo::meta::introspect::Ty {
        dojo::meta::introspect::Ty::Struct(
            dojo::meta::introspect::Struct {
                name: 'ResourceMetadata',
                attrs: array![].span(),
                children: array![
                    dojo::meta::introspect::Member {
                        name: 'resource_id',
                        attrs: array!['key'].span(),
                        ty: dojo::meta::introspect::Introspect::<felt252>::ty()
                    },
                    dojo::meta::introspect::Member {
                        name: 'metadata_uri',
                        attrs: array![].span(),
                        ty: dojo::meta::introspect::Ty::ByteArray
                    }
                ]
                    .span()
            }
        )
    }
}
