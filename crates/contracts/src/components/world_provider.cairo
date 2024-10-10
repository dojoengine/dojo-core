use dojo::world::IWorldDispatcher;

#[starknet::interface]
pub trait IWorldProvider<T> {
    fn world(self: @T) -> IWorldDispatcher;
}

#[starknet::component]
pub mod WorldProviderComponent {
    use starknet::{ClassHash, ContractAddress, get_caller_address};
    use starknet::storage::{StoragePointerReadAccess, StoragePointerWriteAccess};

    use dojo::world::{IWorldDispatcher, IWorldDispatcherTrait};

    #[storage]
    pub struct Storage {
        world_dispatcher: IWorldDispatcher,
    }

    #[embeddable_as(WorldProviderImpl)]
    impl WorldProvider<
        TContractState, +HasComponent<TContractState>
    > of super::IWorldProvider<ComponentState<TContractState>> {
        fn world(self: @ComponentState<TContractState>) -> IWorldDispatcher {
            self.world_dispatcher.read()
        }
    }

    #[generate_trait]
    pub impl InternalImpl<
        TContractState, +HasComponent<TContractState>
    > of InternalTrait<TContractState> {
        fn initializer(ref self: ComponentState<TContractState>) {
            self
                .world_dispatcher
                .write(IWorldDispatcher { contract_address: get_caller_address() });
        }
    }
}
