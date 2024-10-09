use dojo::{
    model::{
        model::{ModelIndex, KeyTraits},
        Layout, introspect::Introspect,
        members::{MemberStore},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

// Needs to be generated
pub trait EntitySerde<E>{
    fn id(self: @E) -> felt252;
    fn values(self: @E) -> Span<felt252>;
}

pub trait EntityTrait<E>{
    fn entity_id(self: @E) -> felt252;
    fn from_values(entity_id: felt252, values: Span<felt252>) -> E;
}

pub trait EntityStore<E> {
    // Get an entity from the world
    fn get_entity<K>(self: @IWorldDispatcher, key: K) -> E;
    // Get an entity from the world using its entity id
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    // Update an entity in the world
    fn update(self: IWorldDispatcher, entity: E);
    // Delete an entity from the world from its entity id
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252);
    // Get a member of a model from the world using its entity id
    fn get_member_from_id<T>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T;
    // Update a member of a model in the world using its entity id
    fn update_member_from_id<T>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T);
}

pub impl EntityImpl<E, +EntitySerde<E>> of EntityTrait<M, E, K> {
    fn entity_id(self: @E) -> felt252 {
        EntitySerde::<E>::id(self)
    }
    fn from_values(entity_id: felt252, values: Span<felt252>) -> E{
        let mut serialized: Array<felt252> = array![entity_id];
        serialized.append_span(values);
        
        match Serde::<E>::deserialize(ref serialized) {
            Option::Some(model) => model,
            Option::None => {
                panic!(
                    "Entity: deserialization failed. Ensure the length of the keys tuple is matching the number of #[key] fields in the model struct."
                );
            }
            
        }
    }
}

impl EntityStoreImpl<
    E, +EntityTrait<E>, +ModelAttributes<E>,
>  of EntityStore<E>{
    fn get_entity<K, +KeyTrait<K>>(self: @IWorldDispatcher, key: K) -> E {
        Self::get_entity_from_id(self, KeyTrait::<K>::to_entity_id(key))
    }

    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E {
        let values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<E>::SELECTOR,
            ModelIndex::Id(entity_id),
            ModelAttributes::<E>::layout()
        );
        EntityTrait::<E>::from_values(entity_id, values)
    }

    fn update(self: IWorldDispatcher, entity: E) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<E>::SELECTOR,
            ModelIndex::Id(EntityTrait::<E>::id(entity)),
            EntityTrait::<E>::values(entity),
            ModelAttributes::<E>::layout()
        );
    }
    
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<E>::SELECTOR,
            ModelIndex::Id(entity_id),
            ModelAttributes::<E>::layout()
        );
    }

    fn get_member_from_id<T, +MemberStore<T>>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T {
        MemberStore::<T>::get_member(
            self, 
            ModelAttributes::<E>::SELECTOR, 
            member_id, 
            ModelAttributes::<E>::layout(),
            entity_id, 
        )
    }

    fn update_member_from_id<T, +MemberStore<T>>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T) {
        MemberStore::<T>::update_member(
            self, entity_id, 
        );
        set_serialized_member(
            self, 
            entity_id, 
            ModelAttributes::<E>::SELECTOR, 
            member_id, 
            ModelAttributes::<E>::layout(), 
            ValueTrait::<T>::serialize(value)
        );
    }
}