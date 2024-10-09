use dojo::{
    meta::{Layout},
    model::{
        ModelAttributes, attributes::ModelIndex,
        members::{key::{KeyTrait, KeyParserTrait}},
        members::{MemberStore},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

// Needs to be generated
pub trait EntitySerde<E>{
    fn id(self: E) -> felt252;
    fn values(self: E) -> Span<felt252>;
    fn id_values(self: E) -> (felt252, Span<felt252>);
}

pub trait EntityTrait<E>{
    fn entity_id(self: E) -> felt252;
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> E;
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
    fn get_member_from_id<T, +MemberStore<E, T>>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T;
    // Update a member of a model in the world using its entity id
    fn update_member_from_id<T, +MemberStore<E, T>>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T);
}

pub impl EntityImpl<E, +EntitySerde<E>, +Serde<E>> of EntityTrait<E> {
    fn entity_id(self: E) -> felt252 {
        EntitySerde::<E>::id(self)
    }
    fn from_values(entity_id: felt252, ref values: Span<felt252>) -> E{
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
}

impl EntityStoreImpl<
    E, +EntityTrait<E>, +EntitySerde<E>, +ModelAttributes<E>,
>  of EntityStore<E>{
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
        EntityTrait::<E>::from_values(entity_id, ref values)
    }

    fn update(self: IWorldDispatcher, entity: E) {
        let (entity_id, values) = EntitySerde::<E>::id_values(entity);
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

    fn get_member_from_id<T, +MemberStore<E, T>>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T {
        MemberStore::<E, T>::get_member(self, member_id, entity_id)
    }

    fn update_member_from_id<T, +MemberStore<E, T>>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T) {
        MemberStore::<E, T>::update_member(self,  member_id,  entity_id,  value);
    }
}