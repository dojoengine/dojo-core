use dojo::{
    meta::{Layout},
    model::{
        ModelAttributes, attributes::ModelIndex, members::{key::{KeyTrait, KeyParserTrait}},
        members::{MemberStore},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

// Needs to be generated
pub trait EntitySerde<E> {
    fn _id(self: @E) -> felt252;
    fn _values(self: @E) -> Span<felt252>;
    fn _id_values(self: @E) -> (felt252, Span<felt252>);
}

pub trait Entity<E> {
    fn entity_id(self: @E) -> felt252;
    fn values(self: @E) -> Span<felt252>;
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> E;
    fn instance_selector(self: @E) -> felt252;
    fn instance_layout(self: @E) -> Layout;
}

pub trait EntityStore<E> {
    // Get an entity from the world
    fn get_entity<K, +KeyTrait<K>, +Drop<K>>(self: @IWorldDispatcher, key: K) -> E;
    // Get an entity from the world using its entity id
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    // Update an entity in the world
    fn update(self: IWorldDispatcher, entity: E);
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

pub impl EntityImpl<E, +EntitySerde<E>, +Serde<E>, +ModelAttributes<E>> of Entity<E> {
    fn entity_id(self: @E) -> felt252 {
        EntitySerde::<E>::_id(self)
    }
    fn values(self: @E) -> Span<felt252> {
        EntitySerde::<E>::_values(self)
    }
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> E {
        let mut serialized: Array<felt252> = array![entity_id];
        serialized.append_span(values);
        let mut span = serialized.span();

        match Serde::<E>::deserialize(ref span) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Entity: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                )
            }
        }
    }
    fn instance_selector(self: @E) -> felt252 {
        ModelAttributes::<E>::selector()
    }
    fn instance_layout(self: @E) -> Layout {
        ModelAttributes::<E>::layout()
    }
}

pub impl EntityStoreImpl<
    E, +Entity<E>, +EntitySerde<E>, +ModelAttributes<E>, +Drop<E>
> of EntityStore<E> {
    fn get_entity<K, +KeyTrait<K>, +Drop<K>>(self: @IWorldDispatcher, key: K) -> E {
        Self::get_entity_from_id(self, KeyTrait::<K>::to_entity_id(@key))
    }

    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E {
        let mut values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<E>::selector(),
            ModelIndex::Id(entity_id),
            ModelAttributes::<E>::layout()
        );
        Entity::<E>::from_values(entity_id, ref values)
    }

    fn update(self: IWorldDispatcher, entity: E) {
        let (entity_id, values) = EntitySerde::<E>::_id_values(@entity);
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<E>::selector(),
            ModelIndex::Id(entity_id),
            values,
            ModelAttributes::<E>::layout()
        );
    }

    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<E>::selector(),
            ModelIndex::Id(entity_id),
            ModelAttributes::<E>::layout()
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
