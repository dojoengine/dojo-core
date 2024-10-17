//! ResourceMetadata model.
//!
//! Manually expand to ensure that dojo-core
//! does not depend on dojo plugin to be built.
//!
use core::poseidon::poseidon_hash_span;

use dojo::model::model::{ModelImpl, ModelParser, KeyParser};
use dojo::meta::introspect::{Introspect, Ty, Struct, Member};
use dojo::meta::{Layout, FieldLayout};
use dojo::utils;
use dojo::utils::{serialize_inline};

pub fn initial_address() -> starknet::ContractAddress {
    starknet::contract_address_const::<0>()
}

pub fn initial_class_hash() -> starknet::ClassHash {
    starknet::class_hash::class_hash_const::<
        0x03f75587469e8101729b3b02a46150a3d99315bc9c5026d64f2e8a061e413255
    >()
}

#[derive(Drop, Serde, PartialEq, Clone, Debug)]
pub struct ResourceMetadata {
    // #[key]
    pub resource_id: felt252,
    pub metadata_uri: ByteArray,
}

pub impl ResourceMetadataDefinitionImpl of dojo::model::ModelDefinition<ResourceMetadata> {
    #[inline(always)]
    fn name() -> ByteArray {
        "ResourceMetadata"
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        "__DOJO__"
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        "__DOJO__-ResourceMetadata"
    }

    #[inline(always)]
    fn version() -> u8 {
        1
    }

    #[inline(always)]
    fn selector() -> felt252 {
        poseidon_hash_span([Self::namespace_hash(), Self::name_hash()].span())
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        utils::bytearray_hash(@Self::name())
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        utils::bytearray_hash(@Self::namespace())
    }

    #[inline(always)]
    fn layout() -> Layout {
        Introspect::<ResourceMetadata>::layout()
    }

    #[inline(always)]
    fn schema() -> Ty {
        Introspect::<ResourceMetadata>::ty()
    }

    #[inline(always)]
    fn size() -> Option<usize> {
        Introspect::<ResourceMetadata>::size()
    }
}


pub impl ResourceMetadataModelKeyImpl of KeyParser<ResourceMetadata, felt252> {
    #[inline(always)]
    fn parse_key(self: @ResourceMetadata) -> felt252 {
        *self.resource_id
    }
}

pub impl ResourceMetadataModelParser of ModelParser<ResourceMetadata> {
    fn serialize_keys(self: @ResourceMetadata) -> Span<felt252> {
        [*self.resource_id].span()
    }
    fn serialize_values(self: @ResourceMetadata) -> Span<felt252> {
        serialize_inline(self.metadata_uri)
    }
}

pub impl ResourceMetadataModelImpl = ModelImpl<ResourceMetadata>;


pub impl ResourceMetadataIntrospect<> of Introspect<ResourceMetadata<>> {
    #[inline(always)]
    fn size() -> Option<usize> {
        Option::None
    }

    #[inline(always)]
    fn layout() -> Layout {
        Layout::Struct(
            [FieldLayout { selector: selector!("metadata_uri"), layout: Layout::ByteArray }].span()
        )
    }

    #[inline(always)]
    fn ty() -> Ty {
        Ty::Struct(
            Struct {
                name: 'ResourceMetadata', attrs: [].span(), children: [
                    Member {
                        name: 'resource_id', ty: Ty::Primitive('felt252'), attrs: ['key'].span()
                    },
                    Member { name: 'metadata_uri', ty: Ty::ByteArray, attrs: [].span() }
                ].span()
            }
        )
    }
}

#[starknet::contract]
pub mod resource_metadata {
    use super::{ResourceMetadata};

    use dojo::{meta::{Layout, Ty}, model::{ModelDef, Model}};

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn selector(self: @ContractState) -> felt252 {
        Model::<ResourceMetadata>::selector()
    }

    fn name(self: @ContractState) -> ByteArray {
        Model::<ResourceMetadata>::name()
    }

    fn version(self: @ContractState) -> u8 {
        Model::<ResourceMetadata>::version()
    }

    fn namespace(self: @ContractState) -> ByteArray {
        Model::<ResourceMetadata>::namespace()
    }

    #[external(v0)]
    fn unpacked_size(self: @ContractState) -> Option<usize> {
        Model::<ResourceMetadata>::unpacked_size()
    }

    #[external(v0)]
    fn packed_size(self: @ContractState) -> Option<usize> {
        Model::<ResourceMetadata>::packed_size()
    }

    #[external(v0)]
    fn layout(self: @ContractState) -> Layout {
        Model::<ResourceMetadata>::layout()
    }

    #[external(v0)]
    fn schema(self: @ContractState) -> Ty {
        Model::<ResourceMetadata>::schema()
    }

    #[external(v0)]
    fn definition(self: @ContractState) -> ModelDef {
        Model::<ResourceMetadata>::definition()
    }

    #[external(v0)]
    fn ensure_abi(self: @ContractState, model: ResourceMetadata) {}
}
