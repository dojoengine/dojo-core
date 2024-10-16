#[starknet::component]
mod DojoModelComponent {
    use dojo::{model::{Model, ModelDef}, meta::{Layout, Ty}};

    #[storage]
    struct Storage {}

    #[event]
    #[derive(Drop, PartialEq, starknet::Event)]
    enum Event{}

    #[embeddable_as(ModelImpl)]
    impl IModelImpl<
        TContractState, M, +HasComponent<TContractState>, +Model<M>
    > of dojo::model::IModel<ComponentState<TContractState>> {
        fn name(self: @ComponentState<TContractState>) -> ByteArray {
            Model::<M>::name()
        }

        fn namespace(self: @ComponentState<TContractState>) -> ByteArray {
            Model::<M>::namespace()
        }

        fn tag(self: @ComponentState<TContractState>) -> ByteArray {
            Model::<M>::tag()
        }

        fn version(self: @ComponentState<TContractState>) -> u8 {
            Model::<M>::version()
        }

        fn selector(self: @ComponentState<TContractState>) -> felt252 {
            Model::<M>::selector()
        }

        fn name_hash(self: @ComponentState<TContractState>) -> felt252 {
            Model::<M>::name_hash()
        }

        fn namespace_hash(self: @ComponentState<TContractState>) -> felt252 {
            Model::<M>::namespace_hash()
        }

        fn schema(self: @ComponentState<TContractState>) -> Ty {
            Model::<M>::schema()
        }

        fn layout(self: @ComponentState<TContractState>) -> Layout {
            Model::<M>::layout()
        }

        fn unpacked_size(self: @ComponentState<TContractState>) -> Option<usize> {
            Model::<M>::unpacked_size()
        }

        fn packed_size(self: @ComponentState<TContractState>) -> Option<usize> {
            Model::<M>::packed_size()
        }

        fn definition(self: @ComponentState<TContractState>) -> ModelDef {
            Model::<M>::definition()
        }
    }
}