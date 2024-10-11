//! ResourceMetadata model.
//!
//! Manually expand to ensure that dojo-core
//! does not depend on dojo plugin to be built.
//!
use core::array::ArrayTrait;
use core::byte_array::ByteArray;
use core::poseidon::poseidon_hash_span;
use core::serde::Serde;

use dojo::model::{ModelIndex, model::{ModelImpl, ModelParser, KeyParser}};
use dojo::meta::introspect::{Introspect, Ty, Struct, Member};
use dojo::meta::{Layout, FieldLayout};
use dojo::utils;
use dojo::utils::{serialize_inline};
use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

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

pub impl ResourceMetadataAttributesImpl of dojo::model::ModelAttributes<ResourceMetadata> {
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
}


pub impl ResourceMetadataModelKeyImpl of KeyParser<ResourceMetadata, felt252> {
    #[inline(always)]
    fn parse_key(self: @ResourceMetadata) -> felt252 {
        *self.resource_id
    }
}

pub impl ResourceMetadataModelParser of ModelParser<ResourceMetadata> {
    fn serialise_keys(self: @ResourceMetadata) -> Span<felt252> {
        [*self.resource_id].span()
    }
    fn serialise_values(self: @ResourceMetadata) -> Span<felt252> {
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
    use super::{ResourceMetadata, ResourceMetadataAttributesImpl};

    use dojo::meta::introspect::{Introspect, Ty};
    use dojo::meta::Layout;

    #[storage]
    struct Storage {}

    #[external(v0)]
    fn selector(self: @ContractState) -> felt252 {
        ResourceMetadataAttributesImpl::selector()
    }

    fn name(self: @ContractState) -> ByteArray {
        ResourceMetadataAttributesImpl::name()
    }

    fn version(self: @ContractState) -> u8 {
        ResourceMetadataAttributesImpl::version()
    }

    fn namespace(self: @ContractState) -> ByteArray {
        ResourceMetadataAttributesImpl::namespace()
    }

    #[external(v0)]
    fn unpacked_size(self: @ContractState) -> Option<usize> {
        Introspect::<ResourceMetadata>::size()
    }

    #[external(v0)]
    fn packed_size(self: @ContractState) -> Option<usize> {
        dojo::meta::layout::compute_packed_size(Introspect::<ResourceMetadata>::layout())
    }

    #[external(v0)]
    fn layout(self: @ContractState) -> Layout {
        Introspect::<ResourceMetadata>::layout()
    }

    #[external(v0)]
    fn schema(self: @ContractState) -> Ty {
        Introspect::<ResourceMetadata>::ty()
    }

    #[external(v0)]
    fn ensure_abi(self: @ContractState, model: ResourceMetadata) {}
}
