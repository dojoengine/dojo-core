use starknet::SyscallResult;

use dojo::meta::Layout;
use dojo::meta::introspect::Ty;
use dojo::world::IWorldDispatcher;
use dojo::utils::{Descriptor, DescriptorTrait};

use dojo::{
    utils::entity_id_from_keys,
    model::{
        Layout,
        members::{set_serialized_member, get_serialized_member},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

pub trait ModelSerde<M>{
    fn keys(self: @M) -> Span<felt252>;
    fn values(self: @M) -> Span<felt252>;
}

pub trait ModelTrait<M, K> {
    fn key(self: @M) -> K;
    fn entity_id(self: @M) -> felt252;
    fn from_values(keys: Span<felt252>, values: Span<felt252>) -> M;
}

pub trait ModelEntityTrait<M, E, K>{
    fn to_model(self: @E, key:K) -> M;
    fn to_entity(self: @M) -> E;
}

pub impl ModelImpl<
    M,
    E,
    K,
    +ModelSerde<M>,
    +EntitySerde<E>,
    +KeyTrait<K>,
> of ModelTrait<M, E, K> {
    fn key(self: @M) -> K {
        KeyTrait::<K>::deserialize(ModelStore::keys(self))
    }

    fn entity_id(self: @M) -> felt252 {
        KeyTrait::<K>::to_entity_id()
    }

    fn to_entity(self: @M) -> E {
        EntityStore::<E>::from_values(
            Self::entity_id(self), 
            ModelStore::values(self)
        )
    }

    fn from_values(keys: Span<felt252>, values: Span<felt252>) -> M{
        let mut serialized: Array<felt252> = keys.into();
        serialized.append_span(values);

        match Serde::<M>::deserialize(ref serialized) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Model: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                );
            }
            
        }
    }
}

pub impl MemberModelStoreImpl<
    T,
    +MemberStore<T>,
    +ModelAttributes<T>,> of MemberModelStore<T> {
    }

#[cfg(target: "test")]
pub trait ModelTest<T> {
    fn set_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}

#[cfg(target: "test")]
pub trait ModelEntityTest<T> {
    fn update_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}
