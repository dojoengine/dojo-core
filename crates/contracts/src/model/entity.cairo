use dojo::{
    meta::{Layout}, model::{ModelDefinition, ModelIndex, members::{MemberStore},},
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::entity_id_from_key,
};

pub trait EntityKey<E, K> {}


/// Trait `EntityParser` defines the interface for parsing and serializing entities of type `E`.
///
/// # Methods
/// - `parse_id(self: @E) -> felt252`:
///   Parses and returns the ID of the entity as a `felt252`.
///
/// - `serialize_values(self: @E) -> Span<felt252>`:
///   Serializes the values of the entity and returns them as a `Span<felt252>`.
pub trait EntityParser<E> {
    fn parse_id(self: @E) -> felt252;
    fn serialize_values(self: @E) -> Span<felt252>;
}


/// The `Entity` trait defines a set of methods that must be implemented by any entity type `E`.
/// This trait provides a standardized way to interact with entities, including retrieving their
/// identifiers, values, and metadata, as well as constructing entities from values.
///
/// Methods:
/// - `id(self: @E) -> felt252`: Returns the unique identifier of the entity.
/// - `values(self: @E) -> Span<felt252>`: Returns a span of values associated with the entity.
/// - `from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<E>`: Constructs an
/// entity
///   from the given identifier and values, returning an `Option` that contains the entity if
///   successful.
///
/// Metadata Methods:
/// - `name() -> ByteArray`: Returns the name of the entity type.
/// - `namespace() -> ByteArray`: Returns the namespace of the entity type.
/// - `tag() -> ByteArray`: Returns the tag associated with the entity type.
/// - `version() -> u8`: Returns the version of the entity type.
/// - `selector() -> felt252`: Returns a unique selector for the entity type.
/// - `layout() -> Layout`: Returns the layout of the entity type.
/// - `name_hash() -> felt252`: Returns the hash of the entity type's name.
/// - `namespace_hash() -> felt252`: Returns the hash of the entity type's namespace.
/// - `instance_selector(self: @E) -> felt252`: Returns a selector for the entity.
/// - `instance_layout(self: @E) -> Layout`: Returns the layout of the entity.
pub trait Entity<E> {
    fn id(self: @E) -> felt252;
    fn values(self: @E) -> Span<felt252>;
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<E>;

    fn name() -> ByteArray;
    fn namespace() -> ByteArray;
    fn tag() -> ByteArray;
    fn version() -> u8;
    fn selector() -> felt252;
    fn layout() -> Layout;
    fn name_hash() -> felt252;
    fn namespace_hash() -> felt252;
    fn instance_selector(self: @E) -> felt252;
    fn instance_layout(self: @E) -> Layout;
}


/// Trait `EntityStore` provides an interface for managing entities within a world dispatcher.
///
/// # Type Parameters
/// - `E`: The type of the entity.
///
/// # Methods
/// - `fn get_entity<K, +Drop<K>, +Serde<K>, +EntityKey<E, K>>(self: @IWorldDispatcher, key: K) ->
/// E`
///   Retrieves an entity based on a given key.
///
/// - `fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E`
///   Retrieves an entity based on its ID.
///
/// - `fn update(self: IWorldDispatcher, entity: @E)`
///   Updates the given entity.
///
/// - `fn delete_entity(self: IWorldDispatcher, entity: @E)`
///   Deletes the given entity.
///
/// - `fn delete_from_id(self: IWorldDispatcher, entity_id: felt252)`
///   Deletes an entity based on its ID.
///
/// - `fn get_member_from_id<T, +MemberStore<E, T>>(self: @IWorldDispatcher, member_id: felt252,
/// entity_id: felt252) -> T`
///   Retrieves a member of an entity based on the member's ID and the entity's ID.
///
/// - `fn update_member_from_id<T, +MemberStore<E, T>>(self: IWorldDispatcher, member_id: felt252,
/// entity_id: felt252, value: T)`
///   Updates a member of an entity based on the member's ID and the entity's ID.
pub trait EntityStore<E> {
    fn get_entity<K, +Drop<K>, +Serde<K>, +EntityKey<E, K>>(self: @IWorldDispatcher, key: K) -> E;
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    fn update(self: IWorldDispatcher, entity: @E);
    fn delete_entity(self: IWorldDispatcher, entity: @E);
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252);
    fn get_member_from_id<T, +MemberStore<E, T>>(
        self: @IWorldDispatcher, entity_id: felt252, member_id: felt252
    ) -> T;
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

#[cfg(target: "test")]
pub trait ModelEntityTest<E> {
    fn update_test(self: @E, world: IWorldDispatcher);
    fn delete_test(self: @E, world: IWorldDispatcher);
}


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
