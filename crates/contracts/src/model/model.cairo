use starknet::SyscallResult;

use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::{Descriptor, DescriptorTrait},
    meta::{Layout, introspect::Ty},
    model::{ModelAttributes, attributes::ModelIndex, members::MemberStore},
    utils::{entity_id_from_key, serialize_inline, deserialize_unwrap, entity_id_from_keys}
};


pub trait KeyParser<M, K> {
    fn parse_key(self: @M) -> K;
}

pub trait ModelParser<M> {
    fn serialise_keys(self: @M) -> Span<felt252>;
    fn serialise_values(self: @M) -> Span<felt252>;
}

pub trait Model<M> {
    fn key<K, +KeyParser<M, K>>(self: @M) -> K;
    fn entity_id(self: @M) -> felt252;
    fn keys(self: @M) -> Span<felt252>;
    fn values(self: @M) -> Span<felt252>;
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<M>;

    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    fn version() -> u8;
    fn selector() -> felt252;
    fn layout() -> Layout;
    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;
    fn instance_selector(self: @M) -> felt252;
    fn instance_layout(self: @M) -> Layout;
}

pub trait ModelStore<M> {
    // Get a model from the world
    fn get<K, +Drop<K>, +Serde<K>>(self: @IWorldDispatcher, key: K) -> M;
    // Set a model in the world
    fn set(self: IWorldDispatcher, model: @M);
    // Get a member of a model from the world
    fn delete(self: IWorldDispatcher, model: @M);
    // Delete a model from the world from its key
    fn delete_from_key<K, +Drop<K>, +Serde<K>>(self: IWorldDispatcher, key: K);
    // Get a member of a model from the world
    fn get_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: @IWorldDispatcher, member_id: felt252, key: K
    ) -> T;
    // Update a member of a model in the world
    fn update_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: IWorldDispatcher, member_id: felt252, key: K, value: T
    );
}

pub impl ModelImpl<M, +ModelParser<M>, +ModelAttributes<M>, +Serde<M>> of Model<M> {
    fn key<K, +KeyParser<M, K>>(self: @M) -> K {
        KeyParser::<M, K>::parse_key(self)
    }
    fn entity_id(self: @M) -> felt252 {
        entity_id_from_keys(Self::keys(self))
    }
    fn keys(self: @M) -> Span<felt252> {
        ModelParser::<M>::serialise_keys(self)
    }
    fn values(self: @M) -> Span<felt252> {
        ModelParser::<M>::serialise_values(self)
    }
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<M> {
        let mut serialized: Array<felt252> = keys.into();
        serialized.append_span(values);
        let mut span = serialized.span();

        Serde::<M>::deserialize(ref span)
    }

    fn name() -> ByteArray {
        ModelAttributes::<M>::name()
    }
    fn namespace() -> ByteArray {
        ModelAttributes::<M>::namespace()
    }
    fn tag() -> ByteArray {
        ModelAttributes::<M>::tag()
    }
    fn version() -> u8 {
        ModelAttributes::<M>::version()
    }
    fn selector() -> felt252 {
        ModelAttributes::<M>::selector()
    }
    fn layout() -> Layout {
        ModelAttributes::<M>::layout()
    }
    fn name_hash() -> felt252 {
        ModelAttributes::<M>::name_hash()
    }
    fn namespace_hash() -> felt252 {
        ModelAttributes::<M>::namespace_hash()
    }
    fn instance_selector(self: @M) -> felt252 {
        ModelAttributes::<M>::selector()
    }
    fn instance_layout(self: @M) -> Layout {
        ModelAttributes::<M>::layout()
    }
}

pub impl ModelStoreImpl<M, +Model<M>, +Drop<M>> of ModelStore<M> {
    fn get<K, +Drop<K>, +Serde<K>>(self: @IWorldDispatcher, key: K) -> M {
        let mut keys = serialize_inline::<K>(@key);
        let mut values = IWorldDispatcherTrait::entity(
            *self, Model::<M>::selector(), ModelIndex::Keys(keys), Model::<M>::layout()
        );
        match Model::<M>::from_values(ref keys, ref values) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Model: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
        }
    }

    fn set(self: IWorldDispatcher, model: @M) {
        IWorldDispatcherTrait::set_entity(
            self,
            Model::<M>::selector(),
            ModelIndex::Keys(Model::<M>::keys(model)),
            Model::<M>::values(model),
            Model::<M>::layout()
        );
    }

    fn delete(self: IWorldDispatcher, model: @M) {
        IWorldDispatcherTrait::delete_entity(
            self,
            Model::<M>::selector(),
            ModelIndex::Keys(Model::<M>::keys(model)),
            Model::<M>::layout()
        );
    }

    fn delete_from_key<K, +Drop<K>, +Serde<K>>(self: IWorldDispatcher, key: K) {
        IWorldDispatcherTrait::delete_entity(
            self,
            Model::<M>::selector(),
            ModelIndex::Keys(serialize_inline::<K>(@key)),
            Model::<M>::layout()
        );
    }

    fn get_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: @IWorldDispatcher, member_id: felt252, key: K
    ) -> T {
        MemberStore::<M, T>::get_member(self, member_id, entity_id_from_key::<K>(@key))
    }

    fn update_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: IWorldDispatcher, member_id: felt252, key: K, value: T
    ) {
        MemberStore::<M, T>::update_member(self, member_id, entity_id_from_key::<K>(@key), value);
    }
}


#[cfg(target: "test")]
pub trait ModelTest<T> {
    fn set_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}


#[cfg(target: "test")]
pub impl ModelTestImpl<M, +Model<M>> of ModelTest<M> {
    fn set_test(self: @M, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher {
            contract_address: world.contract_address
        };
        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            Model::<M>::selector(),
            ModelIndex::Keys(Model::keys(self)),
            Model::<M>::values(self),
            Model::<M>::layout()
        );
    }

    fn delete_test(self: @M, world: dojo::world::IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher {
            contract_address: world.contract_address
        };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            Model::<M>::selector(),
            ModelIndex::Keys(Model::keys(self)),
            Model::<M>::layout()
        );
    }
}
