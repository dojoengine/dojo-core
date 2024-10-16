use dojo::{model::{Model, IModel, ModelDef}, meta::{Layout, Ty}};

#[starknet::embeddable]
pub impl IModelImpl<TContractState, M, +Model<M>> of IModel<TContractState> {
    fn name(self: @TContractState) -> ByteArray {
        Model::<M>::name()
    }

    fn namespace(self: @TContractState) -> ByteArray {
        Model::<M>::namespace()
    }

    fn tag(self: @TContractState) -> ByteArray {
        Model::<M>::tag()
    }

    fn version(self: @TContractState) -> u8 {
        Model::<M>::version()
    }

    fn selector(self: @TContractState) -> felt252 {
        Model::<M>::selector()
    }

    fn name_hash(self: @TContractState) -> felt252 {
        Model::<M>::name_hash()
    }

    fn namespace_hash(self: @TContractState) -> felt252 {
        Model::<M>::namespace_hash()
    }

    fn schema(self: @TContractState) -> Ty {
        Model::<M>::schema()
    }

    fn layout(self: @TContractState) -> Layout {
        Model::<M>::layout()
    }

    fn unpacked_size(self: @TContractState) -> Option<usize> {
        Model::<M>::unpacked_size()
    }

    fn packed_size(self: @TContractState) -> Option<usize> {
        Model::<M>::packed_size()
    }

    fn definition(self: @TContractState) -> ModelDef {
        Model::<M>::definition()
    }
}