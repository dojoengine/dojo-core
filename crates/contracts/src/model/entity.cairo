use dojo::{
    meta::{Layout}, model::{ModelAttributes, attributes::ModelIndex, members::{MemberStore},},
    world::{IWorldDispatcher, IWorldDispatcherTrait}, utils::entity_id_from_key,
};

pub trait EntityKey<E, K> {}

// Needs to be generated
pub trait EntityParser<E> {
    fn parse_id(self: @E) -> felt252;
    fn serialise_values(self: @E) -> Span<felt252>;
}


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

pub trait EntityStore<E> {
    // Get an entity from the world
    fn get_entity<K, +Drop<K>, +Serde<K>, +EntityKey<E, K>>(self: @IWorldDispatcher, key: K) -> E;
    // Get an entity from the world using its entity id
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    // Update an entity in the world
    fn update(self: IWorldDispatcher, entity: @E);
    // Delete an entity from the
    fn delete_entity(self: IWorldDispatcher, entity: @E);
    // Delete an entity from the world from its entity id
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252);
    // Get a member of a model from the world using its entity id
    fn get_member_from_id<T, +MemberStore<E, T>>(
        self: @IWorldDispatcher, member_id: felt252, entity_id: felt252
    ) -> T;
    // Update a member of a model in the world using its entity id
    fn update_member_from_id<T, +MemberStore<E, T>>(
        self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T
    );
}

pub impl EntityImpl<E, +Serde<E>, +ModelAttributes<E>, +EntityParser<E>> of Entity<E> {
    fn id(self: @E) -> felt252 {
        EntityParser::<E>::parse_id(self)
    }
    fn values(self: @E) -> Span<felt252> {
        EntityParser::<E>::serialise_values(self)
    }
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> Option<E> {
        let mut serialized: Array<felt252> = array![entity_id];
        serialized.append_span(values);
        let mut span = serialized.span();
        Serde::<E>::deserialize(ref span)
    }
    fn name() -> ByteArray {
        ModelAttributes::<E>::name()
    }
    fn namespace() -> ByteArray {
        ModelAttributes::<E>::namespace()
    }
    fn tag() -> ByteArray {
        ModelAttributes::<E>::tag()
    }
    fn version() -> u8 {
        ModelAttributes::<E>::version()
    }
    fn selector() -> felt252 {
        ModelAttributes::<E>::selector()
    }
    fn layout() -> Layout {
        ModelAttributes::<E>::layout()
    }
    fn name_hash() -> felt252 {
        ModelAttributes::<E>::name_hash()
    }
    fn namespace_hash() -> felt252 {
        ModelAttributes::<E>::namespace_hash()
    }
    fn instance_selector(self: @E) -> felt252 {
        ModelAttributes::<E>::selector()
    }
    fn instance_layout(self: @E) -> Layout {
        ModelAttributes::<E>::layout()
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
        self: @IWorldDispatcher, member_id: felt252, entity_id: felt252
    ) -> T {
        MemberStore::<E, T>::get_member(self, member_id, entity_id)
    }

    fn update_member_from_id<T, +MemberStore<E, T>>(
        self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T
    ) {
        MemberStore::<E, T>::update_member(self, member_id, entity_id, value);
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
