use dojo::{
    meta::{Layout}, model::{ModelDefinition, ModelIndex, members::{MemberStore},},
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::entity_id_from_key,
};

pub trait EntityKey<E, K> {}

/// Trait `EntityParser` defines the interface for parsing and serializing entities of type `E`.
pub trait EntityParser<E> {
    /// Parses and returns the ID of the entity as a `felt252`.
    fn parse_id(self: @E) -> felt252;
    /// Serializes the values of the entity and returns them as a `Span<felt252>`.
    fn serialize_values(self: @E) -> Span<felt252>;
}

/// The `Entity` trait defines a set of methods that must be implemented by any entity type `E`.
/// This trait provides a standardized way to interact with entities, including retrieving their
/// identifiers, values, and metadata, as well as constructing entities from values.
pub trait Entity<E> {
    /// Returns the unique identifier of the entity, being a hash derived from the keys.
    fn id(self: @E) -> felt252;
    /// Returns a span of values associated with the entity, every field of a model
    /// that is not a key.
    fn values(self: @E) -> Span<felt252>;
    /// Constructs an entity from its identifier and values.
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<E>;
    /// Returns the name of the entity type.
    fn name() -> ByteArray;
    /// Returns the namespace of the entity type.
    fn namespace() -> ByteArray;
    /// Returns the tag of the entity type.
    fn tag() -> ByteArray;
    /// Returns the version of the entity type.
    fn version() -> u8;
    /// Returns a unique selector for the entity type.
    fn selector() -> felt252;
    /// Returns the layout of the entity type.
    fn layout() -> Layout;
    /// Returns the hash of the entity type's name.
    fn name_hash() -> felt252;
    /// Returns the hash of the entity type's namespace.
    fn namespace_hash() -> felt252;
    /// Returns a selector for the entity.
    fn instance_selector(self: @E) -> felt252;
    /// Returns the layout of the entity.
    fn instance_layout(self: @E) -> Layout;
}

/// Trait `EntityStore` provides an interface for managing entities through a world dispatcher.
pub trait EntityStore<E> {
    /// Retrieves an entity based on a given key. The key in this context is a types containing
    /// all the model keys.
    fn get_entity<K, +Drop<K>, +Serde<K>, +EntityKey<E, K>>(self: @IWorldDispatcher, key: K) -> E;
    /// Retrieves an entity based on its id.
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    /// Updates an entity in the store.
    fn update(self: IWorldDispatcher, entity: @E);
    /// Deletes an entity from the store.
    fn delete_entity(self: IWorldDispatcher, entity: @E);
    /// Deletes an entity based on its id.
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252);
    /// Retrieves a member from an entity based on its id and the member's id.
    fn get_member_from_id<T, +MemberStore<E, T>>(
        self: @IWorldDispatcher, entity_id: felt252, member_id: felt252
    ) -> T;
    /// Updates a member of an entity based on its id and the member's id.
    fn update_member_from_id<T, +MemberStore<E, T>>(
        self: IWorldDispatcher, entity_id: felt252, member_id: felt252, value: T
    );
}

pub impl EntityImpl<E, +Serde<E>, +ModelDefinition<E>, +EntityParser<E>> of Entity<E> {
    fn id(self: @E) -> felt252 {
        EntityParser::<E>::parse_id(self)
    }
    fn values(self: @E) -> Span<felt252> {
        EntityParser::<E>::serialize_values(self)
    }
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<E> {
        let mut serialized: Array<felt252> = array![entity_id];
        serialized.append_span(values);
        let mut span = serialized.span();
        Serde::<E>::deserialize(ref span)
    }
    fn name() -> ByteArray {
        ModelDefinition::<E>::name()
    }
    fn namespace() -> ByteArray {
        ModelDefinition::<E>::namespace()
    }
    fn tag() -> ByteArray {
        ModelDefinition::<E>::tag()
    }
    fn version() -> u8 {
        ModelDefinition::<E>::version()
    }
    fn selector() -> felt252 {
        ModelDefinition::<E>::selector()
    }
    fn layout() -> Layout {
        ModelDefinition::<E>::layout()
    }
    fn name_hash() -> felt252 {
        ModelDefinition::<E>::name_hash()
    }
    fn namespace_hash() -> felt252 {
        ModelDefinition::<E>::namespace_hash()
    }
    fn instance_selector(self: @E) -> felt252 {
        ModelDefinition::<E>::selector()
    }
    fn instance_layout(self: @E) -> Layout {
        ModelDefinition::<E>::layout()
    }
}

pub impl EntityStoreImpl<E, +Entity<E>, +Drop<E>> of EntityStore<E> {
    fn get_entity<K, +Drop<K>, +Serde<K>, +EntityKey<E, K>>(self: @IWorldDispatcher, key: K) -> E {
        Self::get_entity_from_id(self, entity_id_from_key(@key))
    }

    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E {
        let mut values = IWorldDispatcherTrait::entity(
            *self, Entity::<E>::selector(), ModelIndex::Id(entity_id), Entity::<E>::layout()
        );
        match Entity::<E>::from_values(entity_id, ref values) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Entity: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
        }
    }

    fn update(self: IWorldDispatcher, entity: @E) {
        IWorldDispatcherTrait::set_entity(
            self,
            Entity::<E>::selector(),
            ModelIndex::Id(Entity::<E>::id(entity)),
            Entity::<E>::values(entity),
            Entity::<E>::layout()
        );
    }
    fn delete_entity(self: IWorldDispatcher, entity: @E) {
        Self::delete_from_id(self, Entity::<E>::id(entity));
    }
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252) {
        IWorldDispatcherTrait::delete_entity(
            self, Entity::<E>::selector(), ModelIndex::Id(entity_id), Entity::<E>::layout()
        );
    }

    fn get_member_from_id<T, +MemberStore<E, T>>(
        self: @IWorldDispatcher, entity_id: felt252, member_id: felt252
    ) -> T {
        MemberStore::<E, T>::get_member(self, entity_id, member_id)
    }

    fn update_member_from_id<T, +MemberStore<E, T>>(
        self: IWorldDispatcher, entity_id: felt252, member_id: felt252, value: T
    ) {
        MemberStore::<E, T>::update_member(self, entity_id, member_id, value);
    }
}

/// Test implementation of the `ModelEntity` trait to bypass permission checks.
#[cfg(target: "test")]
pub trait ModelEntityTest<E> {
    fn update_test(self: @E, world: IWorldDispatcher);
    fn delete_test(self: @E, world: IWorldDispatcher);
}

/// Implementation of the `ModelEntityTest` trait for testing purposes, bypassing permission checks.
#[cfg(target: "test")]
pub impl ModelEntityTestImpl<E, +Entity<E>> of ModelEntityTest<E> {
    fn update_test(self: @E, world: IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher {
            contract_address: world.contract_address
        };

        dojo::world::IWorldTestDispatcherTrait::set_entity_test(
            world_test,
            Entity::<E>::selector(),
            ModelIndex::Id(Entity::<E>::id(self)),
            Entity::<E>::values(self),
            Entity::<E>::layout()
        );
    }

    fn delete_test(self: @E, world: IWorldDispatcher) {
        let world_test = dojo::world::IWorldTestDispatcher {
            contract_address: world.contract_address
        };

        dojo::world::IWorldTestDispatcherTrait::delete_entity_test(
            world_test,
            Entity::<E>::selector(),
            ModelIndex::Id(Entity::<E>::id(self)),
            Entity::<E>::layout()
        );
    }
}
