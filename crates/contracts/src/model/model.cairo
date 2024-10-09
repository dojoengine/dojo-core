use starknet::SyscallResult;

use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait}, 
    utils::{Descriptor, DescriptorTrait}, 
    meta::{Layout, introspect::Ty},
    model::{
        ModelAttributes, attributes::ModelIndex, 
        members::{MemberStore, key::{KeyTrait, KeyParserTrait}}
    }
};

pub trait ModelSerde<M>{
    fn _keys(self: @M) -> Span<felt252>;
    fn _values(self: @M) -> Span<felt252>;
    fn _keys_values(self: @M) -> (Span<felt252>, Span<felt252>);
}

pub trait Model<M> {
    fn key<K,  +KeyParserTrait<M, K>>(self: @M) -> K;
    fn entity_id<K, +KeyTrait<K>, +KeyParserTrait<M, K>, +Drop<K>>(self: @M) -> felt252;
    fn keys(self: @M) -> Span<felt252>;
    fn values(self: @M) -> Span<felt252>;
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> M;
    fn instance_selector(self: @M) -> felt252;
    fn instance_layout(self: @M) -> Layout;
}

pub trait ModelStore<M, K> {
    // Get a model from the world
    fn get(self: @IWorldDispatcher, key: K) -> M;
    // Set a model in the world
    fn set(self: IWorldDispatcher, model: M);
    // Delete a model from the world from its key
    fn delete(self: IWorldDispatcher, key: K);
    // Get a member of a model from the world
    fn get_member<T, +MemberStore<M, T>, +Drop<T>>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T;
    // Update a member of a model in the world
    fn update_member<T, +MemberStore<M, T>, +Drop<T>>(self: IWorldDispatcher, member_id: felt252, key: K, value: T);
}

pub impl ModelImpl<M, +ModelSerde<M>, +Serde<M>, +ModelAttributes<M>> of Model<M> {
    fn key<K,  +KeyParserTrait<M, K>>(self: @M) -> K {
        KeyParserTrait::<M, K>::key(self)
    }
    fn entity_id<K, +KeyTrait<K>, +KeyParserTrait<M, K>, +Drop<K>>(self: @M) -> felt252 {
        KeyTrait::<K>::to_entity_id(@Self::key::<K>(self))
    }
    fn keys(self: @M) -> Span<felt252> {
        ModelSerde::<M>::_keys(self)
    }
    fn values(self: @M) -> Span<felt252> {
        ModelSerde::<M>::_values(self)
    }
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> M{
        let mut serialized: Array<felt252> = keys.into();
        serialized.append_span(values);
        let mut span = serialized.span();

        match Serde::<M>::deserialize(ref span) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Model: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
            
        }
    }
    fn instance_selector(self: @M) -> felt252 {
        ModelAttributes::<M>::selector()
    }
    fn instance_layout(self: @M) -> Layout {
        ModelAttributes::<M>::layout()
    }

}

impl ModelStoreImpl<
    M, 
    K,
    +ModelSerde<M>,
    +Model<M>,
    +ModelAttributes<M>,
    +Drop<K>,
    +Drop<M>,
    +KeyTrait<K>,
>  of ModelStore<M, K>{
    fn get(self: @IWorldDispatcher, mut key: K) -> M {
        let mut keys = KeyTrait::<K>::serialize(@key);
        let mut values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<M>::selector(),
            ModelIndex::Keys(keys),
            ModelAttributes::<M>::layout()
        );
        Model::<M>::from_values(ref keys, ref values)
    }

    fn set(self: IWorldDispatcher, model: M) {
        let (keys, values) = ModelSerde::<M>::_keys_values(@model);
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<M>::selector(),
            ModelIndex::Keys(keys),
            values,
            ModelAttributes::<M>::layout()
        );
    }

    fn delete(self: IWorldDispatcher, key: K) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<M>::selector(),
            ModelIndex::Keys(KeyTrait::<K>::serialize(@key)),
            ModelAttributes::<M>::layout()
        );
    }
    
    fn get_member<T, +MemberStore<M, T>, +Drop<T>>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T {
        MemberStore::<M, T>::get_member(self, member_id, KeyTrait::<K>::to_entity_id(@key))
    }

    fn update_member<T, +MemberStore<M, T>, +Drop<T>>(self: IWorldDispatcher, member_id: felt252, key: K, value: T) {
        MemberStore::<M, T>::update_member(self, member_id, KeyTrait::<K>::to_entity_id(@key), value);
    }
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
