use dojo::{
    world::{IWorldDispatcher, IWorldDispatcherTrait},
    meta::{Layout, introspect::Ty, layout::compute_packed_size},
    model::{ModelDefinition, ModelDef, ModelIndex, members::MemberStore},
    utils::{entity_id_from_key, serialize_inline, entity_id_from_keys}
};

/// Trait `KeyParser` defines a trait for parsing keys from a given model.
pub trait KeyParser<M, K> {
    /// Parses the key from the given model.
    fn parse_key(self: @M) -> K;
}

/// Defines a trait for parsing models, providing methods to serialize keys and values.
pub trait ModelParser<M> {
    /// Serializes the keys of the model.
    fn serialize_keys(self: @M) -> Span<felt252>;
    /// Serializes the values of the model.
    fn serialize_values(self: @M) -> Span<felt252>;
}

/// The `Model` trait.
///
/// It provides a standardized way to interact with models.
pub trait Model<M> {
    /// Parses the key from the given model, where `K` is a type containing the keys of the model.
    fn key<K, +KeyParser<M, K>>(self: @M) -> K;
    /// Returns the entity id of the model.
    fn entity_id(self: @M) -> felt252;
    /// Returns the keys of the model.
    fn keys(self: @M) -> Span<felt252>;
    /// Returns the values of the model.
    fn values(self: @M) -> Span<felt252>;
    /// Constructs a model from the given keys and values.
    fn from_values(ref keys: Span<felt252>, ref values: Span<felt252>) -> Option<M>;
    /// Returns the name of the model.
    fn name() -> ByteArray;
    /// Returns the version of the model.
    fn version() -> u8;
    /// Returns the schema of the model.
    fn schema() -> Ty;
    /// Returns the memory layout of the model.
    fn layout() -> Layout;
    /// Returns the unpacked size of the model. Only applicable for fixed size models.
    fn unpacked_size() -> Option<usize>;
    /// Returns the packed size of the model. Only applicable for fixed size models.
    fn packed_size() -> Option<usize>;
    /// Returns the instance selector of the model.
    fn instance_layout(self: @M) -> Layout;
    /// Returns the definition of the model.
    fn definition() -> ModelDef;
}

/// The `ModelStore` trait defines a set of methods for managing models through a world dispatcher.
///
/// # Type Parameters
/// - `M`: The type of the model.
/// - `K`: The type of the key used to identify models.
/// - `T`: The type of the member within the model.
pub trait ModelStore<M> {
    /// Retrieves a model of type `M` using the provided key of type `K`.
    fn get<K, +Drop<K>, +Serde<K>>(self: @IWorldDispatcher, key: K) -> M;
    /// Sets a model of type `M`.
    fn set(self: IWorldDispatcher, model: @M);
    /// Deletes a model of type `M`.
    fn delete(self: IWorldDispatcher, model: @M);
    /// Deletes a model of type `M` using the provided key of type `K`.
    fn delete_from_key<K, +Drop<K>, +Serde<K>>(self: IWorldDispatcher, key: K);
    /// Retrieves a member of type `T` from a model of type `M` using the provided member id and key
    /// of type `K`.
    fn get_member<T, K, +MemberStore<M, T>, +Drop<T>, +Drop<K>, +Serde<K>>(
        self: @IWorldDispatcher, key: K, member_id: felt252
    ) -> T;
    /// Updates a member of type `T` within a model of type `M` using the provided member id, key of
    /// type `K`, and new value of type `T`.
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

    fn version() -> u8 {
        ModelDefinition::<M>::version()
    }

    fn layout() -> Layout {
        ModelDefinition::<M>::layout()
    }

    fn schema() -> Ty {
        ModelDefinition::<M>::schema()
    }

    fn unpacked_size() -> Option<usize> {
        ModelDefinition::<M>::size()
    }

    fn packed_size() -> Option<usize> {
        compute_packed_size(ModelDefinition::<M>::layout())
    }

    fn instance_layout(self: @M) -> Layout {
        ModelDefinition::<M>::layout()
    }

    fn definition() -> ModelDef {
        ModelDef {
            name: Self::name(),
            version: Self::version(),
            layout: Self::layout(),
            schema: Self::schema(),
            packed_size: Self::packed_size(),
            unpacked_size: Self::unpacked_size()
        }
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

/// The `ModelTest` trait.
///
/// It provides a standardized way to interact with models for testing purposes,
/// bypassing the permission checks.
#[cfg(target: "test")]
pub trait ModelTest<T> {
    fn set_test(self: @T, world: IWorldDispatcher);
    fn delete_test(self: @T, world: IWorldDispatcher);
}

/// The `ModelTestImpl` implementation for testing purposes.
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
