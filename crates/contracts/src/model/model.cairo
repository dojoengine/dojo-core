use starknet::SyscallResult;

use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::{Descriptor, DescriptorTrait},
    meta::{Layout, introspect::Ty}, model::{ModelDefinition, ModelIndex, members::MemberStore},
    utils::{entity_id_from_key, serialize_inline, deserialize_unwrap, entity_id_from_keys}
};


/// Trait `KeyParser` defines a trait for parsing keys from a given model.
///
/// # Type Parameters
/// - `M`: The type of the model from which the key will be parsed.
/// - `K`: The type of the key that will be parsed from the model.
///
/// # Methods
/// - `fn parse_key(self: @M) -> K;`
///   - Parses and returns the key from the given model instance.
pub trait KeyParser<M, K> {
    fn parse_key(self: @M) -> K;
}

/// Defines a trait for parsing models, providing methods to serialize keys and values.
///
/// # Type Parameters:
/// - `M`: The type of the model to be parsed.
///
/// # Methods:
/// - `serialize_keys(self: @M) -> Span<felt252>`: Serializes the keys of the model into a `Span` of
/// `felt252`.
/// - `serialize_values(self: @M) -> Span<felt252>`: Serializes the values of the model into a
/// `Span` of `felt252`.
pub trait ModelParser<M> {
    fn serialize_keys(self: @M) -> Span<felt252>;
    fn serialize_values(self: @M) -> Span<felt252>;
}

/// The `Model` trait defines a set of methods that must be implemented by any type `M` that
/// conforms to this trait.
/// It provides a standardized way to interact with models, including retrieving keys, entity IDs,
/// and values, as well as constructing models from values and obtaining metadata about the model
/// such as name, namespace, version, and layout.
///
/// Methods:
/// - `key<K, +KeyParser<M, K>>(self: @M) -> K`: Retrieves the key of the model.
/// - `entity_id(self: @M) -> felt252`: Retrieves the entity ID of the model.
/// - `keys(self: @M) -> Span<felt252>`: Retrieves the keys of the model as a span of `felt252`
///         values.
/// - `values(self: @M) -> Span<felt252>`: Retrieves the values of the model as a span of `felt252`
///         values.
/// - `from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<M>`: Constructs a
///         model from the given keys and values.
/// - `name() -> ByteArray`: Retrieves the name of the model as a `ByteArray`.
/// - `namespace() -> ByteArray`: Retrieves the namespace of the model as a `ByteArray`.
/// - `tag() -> ByteArray`: Retrieves the tag of the model as a `ByteArray`.
/// - `version() -> u8`: Retrieves the version of the model.
/// - `selector() -> felt252`: Retrieves the selector of the model.
/// - `layout() -> Layout`: Retrieves the layout of the model.
/// - `name_hash() -> felt252`: Retrieves the hash of the model's name.
/// - `namespace_hash() -> felt252`: Retrieves the hash of the model's namespace.
/// - `instance_selector(self: @M) -> felt252`: Retrieves the selector for an instance of the model.
/// - `instance_layout(self: @M) -> Layout`: Retrieves the layout for an instance of the model.
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


/// The `ModelStore` trait defines a set of methods for managing models within a world dispatcher.
///
/// # Type Parameters
/// - `M`: The type of the model.
/// - `K`: The type of the key used to identify models.
/// - `T`: The type of the member within the model.
///
/// # Methods
/// - `fn get<K, +Drop<K>, +Serde<K>>(self: @IWorldDispatcher, key: K) -> M`: Retrieves a model of
///         type `M` using the provided key of type `K`.
/// - `fn set(self: IWorldDispatcher, model: @M)`: Stores the provided model of type `M`.
/// - `fn delete(self: IWorldDispatcher, model: @M)`: Deletes the provided model of type `M`.
/// - `fn delete_from_key<K, +Drop<K>, +Serde<K>>(self: IWorldDispatcher, key: K)`: Deletes a model
///         of type `M` using the provided key of type `K`.
/// - `fn get_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
///         self: @IWorldDispatcher, member_id: felt252, key: K
///    ) -> T`: Retrieves a member of type `T` from a model of type `M` using the provided member ID
///   and key of type `K`.
/// - `fn update_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
///         self: IWorldDispatcher, member_id: felt252, key: K, value: T
///    )`: Updates a member of type `T` within a model of type `M` using the provided member ID, key
///         of type `K`, and new value of type `T`.
pub trait ModelStore<M> {
    fn get<K, +Drop<K>, +Serde<K>>(self: @IWorldDispatcher, key: K) -> M;
    fn set(self: IWorldDispatcher, model: @M);
    fn delete(self: IWorldDispatcher, model: @M);
    fn delete_from_key<K, +Drop<K>, +Serde<K>>(self: IWorldDispatcher, key: K);
    fn get_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: @IWorldDispatcher, key: K, member_id: felt252
    ) -> T;
    fn update_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: IWorldDispatcher, key: K, member_id: felt252, value: T
    );
}

pub impl ModelImpl<M, +ModelParser<M>, +ModelDefinition<M>, +Serde<M>> of Model<M> {
    fn key<K, +KeyParser<M, K>>(self: @M) -> K {
        KeyParser::<M, K>::parse_key(self)
    }
    fn entity_id(self: @M) -> felt252 {
        entity_id_from_keys(Self::keys(self))
    }
    fn keys(self: @M) -> Span<felt252> {
        ModelParser::<M>::serialize_keys(self)
    }
    fn values(self: @M) -> Span<felt252> {
        ModelParser::<M>::serialize_values(self)
    }
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<M> {
        let mut serialized: Array<felt252> = keys.into();
        serialized.append_span(values);
        let mut span = serialized.span();

        Serde::<M>::deserialize(ref span)
    }

    fn name() -> ByteArray {
        ModelDefinition::<M>::name()
    }
    fn namespace() -> ByteArray {
        ModelDefinition::<M>::namespace()
    }
    fn tag() -> ByteArray {
        ModelDefinition::<M>::tag()
    }
    fn version() -> u8 {
        ModelDefinition::<M>::version()
    }
    fn selector() -> felt252 {
        ModelDefinition::<M>::selector()
    }
    fn layout() -> Layout {
        ModelDefinition::<M>::layout()
    }
    fn name_hash() -> felt252 {
        ModelDefinition::<M>::name_hash()
    }
    fn namespace_hash() -> felt252 {
        ModelDefinition::<M>::namespace_hash()
    }
    fn instance_selector(self: @M) -> felt252 {
        ModelDefinition::<M>::selector()
    }
    fn instance_layout(self: @M) -> Layout {
        ModelDefinition::<M>::layout()
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
        self: @IWorldDispatcher, key: K, member_id: felt252
    ) -> T {
        MemberStore::<M, T>::get_member(self, entity_id_from_key::<K>(@key), member_id)
    }

    fn update_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: IWorldDispatcher, key: K, member_id: felt252, value: T
    ) {
        MemberStore::<M, T>::update_member(self, entity_id_from_key::<K>(@key), member_id, value);
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
