use dojo::{
    model::{
        model::{ModelIndex, KeyTrait, ModelStore, EntityStore,},
        Layout, introspect::Introspect,
        members::{MemberTrait},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};

pub trait ModelStore<M, K> {
    // Get a model from the world
    fn get(self: @IWorldDispatcher, key: K) -> M;
    // Set a model in the world
    fn set(self: IWorldDispatcher, model: M);
    // Delete a model from the world from its key
    fn delete(self: IWorldDispatcher, key: K);
    // Get a member of a model from the world
    fn get_member<T>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T;
    // Update a member of a model in the world
    fn update_member<T>(self: IWorldDispatcher, member_id: felt252, key: K, value: T);
}

// pub trait ModelStore<M> {
//     // Get a model from the world
//     fn get(self: @IWorldDispatcher, key: K) -> M;
//     // Set a model in the world
//     fn set(self: IWorldDispatcher, model: M);
//     // Delete a model from the world from its key
//     fn delete<K>(self: IWorldDispatcher, key: K);
//     // Get a member of a model from the world
//     fn get_member<T>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T;
//     // Update a member of a model in the world
//     fn update_member<T>(self: IWorldDispatcher, member_id: felt252, key: K, value: T);
// }

pub trait EntityStore<E> {
    // Get an entity from the world
    fn get_entity::<K>(self: @IWorldDispatcher, key: K) -> E;
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

pub trait WorldStore<M, E, K> {
    // Get a model from the world
    fn get(self: @IWorldDispatcher, key: K) -> M;
    // Get an entity from the world
    fn get_entity(self: @IWorldDispatcher, key: K) -> E;
    // Get an entity from the world using its entity id
    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E;
    // Set a model in the world
    fn set(self: IWorldDispatcher, model: M);
    // Update an entity in the world
    fn update(self: IWorldDispatcher, entity: E);
    // Delete a model from the world from its key
    fn delete(self: IWorldDispatcher, key: K);
    // Delete an entity from the world from its entity id
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252);
    // Get a member of a model from the world
    fn get_member<T>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T;
    // Get a member of a model from the world using its entity id
    fn get_member_from_id<T>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T;
    // Update a member of a model in the world
    fn update_member<T>(self: IWorldDispatcher, member_id: felt252, key: K, value: T);
    // Update a member of a model in the world using its entity id
    fn update_member_from_id<T>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T);
}



impl ModelStoreImpl<
    M, 
    K,
    +ModelStore<M>,
    +KeyTrait<K>,
    +ModelAttributes<M>,
>  of ModelStore<M, K>{
    fn get(self: @IWorldDispatcher, key: K) -> M {
        let values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(KeyTrait::<K>::serialize(key)),
            ModelAttributes::<M>::layout()
        );
        ModelStore::<M>::from_values(keys, values)
    }

    fn set(self: IWorldDispatcher, model: M) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(KeyTrait::<K>::serialize(model)),
            ModelStore::<M>::values(model),
            Introspect::<M>::layout()
        );
    }

    fn delete(self: IWorldDispatcher, key: K) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(KeyTrait::<K>::serialize(key)),
            Introspect::<M>::layout()
        );
    }
    
    fn get_member<T, +Drop<T>, +Serde<T>>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T {
        Self::get_member_from_id(self, KeyTrait::<K>::to_entity_id(key), member_id)
    }

    fn update_member<T, +Drop<T>, +Serde<T>>(self: IWorldDispatcher, member_id: felt252, key: K, value: T) {
        Self::set_member_from_id(self, KeyTrait::<K>::to_entity_id(key), member_id, value);
    }
}

impl EntityStoreImpl<
    E, +EntityStore<E>, +ModelAttributes<E>,
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
        EntityStore::<E>::from_values(entity_id, values)
    }

    fn update(self: IWorldDispatcher, entity: E) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<E>::SELECTOR,
            ModelIndex::Id(EntityStore::<E>::id(entity)),
            EntityStore::<E>::values(entity),
            ModelAttributes::<E>::layout()
        );
    }
    
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Id(entity_id),
            Introspect::<M>::layout()
        );
    }

    fn get_member_from_id<T, +Drop<T>, +Serde<T>>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T {
        let values = get_serialized_member(
            self, 
            entity_id, 
            ModelAttributes::<M>::SELECTOR, 
            member_id, 
            ModelAttributes::<E>::layout()
        );
        Serde::<T>::deserialize(values)
        ValueTrait::<T>::deserialize(values)
    }

    fn update_member<T, +ValueTrait<T>>(self: IWorldDispatcher, member_id: felt252, key: K, value: T) {
        Self::set_member_from_id(self, KeyTrait::<K>::to_entity_id(key), member_id, value);
    }

    fn update_member_from_id<T, +ValueTrait<T>>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T) {
        set_serialized_member(
            self, 
            entity_id, 
            ModelAttributes::<M>::SELECTOR, 
            member_id, 
            Introspect::<M>::layout(), 
            ValueTrait::<T>::serialize(value)
        );
    }
}

impl WorldStoreImpl<
    M, 
    E, 
    K,
    +ModelStore<M>,
    +EntityStore<E>,
    +KeyTrait<K>,
    +ModelAttributes<M>,

>  of WorldStore<M, E, K>{
    fn get(self: @IWorldDispatcher, key: K) -> M {
        let values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(KeyTrait::<K>::serialize(key)),
            ModelAttributes::<M>::layout()
        );
        ModelStore::<M>::from_values(keys, values)
    }

    fn get_entity(self: @IWorldDispatcher, key: K) -> E {
        Self::get_entity_from_id(self, KeyTrait::<K>::to_entity_id(key))
    }

    fn get_entity_from_id(self: @IWorldDispatcher, entity_id: felt252) -> E {
        let values = IWorldDispatcherTrait::entity(
            *self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Id(entity_id),
            ModelAttributes::<M>::layout()
        );
        EntityStore::<E>::from_values(entity_id, values)
    }

    fn set(self: IWorldDispatcher, model: M) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(ModelStore::<M>::keys(KeyTrait::<K>::serialize(model.key()))),
            ModelStore::<M>::values(model),
            Introspect::<M>::layout()
        );
    }

    fn update(self: IWorldDispatcher, entity: E) {
        IWorldDispatcherTrait::set_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Id(EntityStore::<E>::id(entity)),
            EntityStore::<E>::values(entity),
            Introspect::<M>::layout()
        );
    }

    fn delete(self: IWorldDispatcher, key: K) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(KeyTrait::<K>::serialize(key)),
            Introspect::<M>::layout()
        );
    }
    
    fn delete_from_id(self: IWorldDispatcher, entity_id: felt252) {
        IWorldDispatcherTrait::delete_entity(
            self,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Id(entity_id),
            Introspect::<M>::layout()
        );
    }

    fn get_member<T, +Drop<T>, +Serde<T>>(self: @IWorldDispatcher, member_id: felt252, key: K) -> T {
        Self::get_member_from_id(self, KeyTrait::<K>::to_entity_id(key), member_id)
    }

    fn get_member_from_id<T, +Drop<T>, +Serde<T>>(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T {
        let values = get_serialized_member(
            self, 
            entity_id, 
            ModelAttributes::<M>::SELECTOR, 
            member_id, 
            Introspect::<M>::layout()
        );
        ValueTrait::<T>::deserialize(values)
    }

    fn update_member<T, +ValueTrait<T>>(self: IWorldDispatcher, member_id: felt252, key: K, value: T) {
        Self::set_member_from_id(self, KeyTrait::<K>::to_entity_id(key), member_id, value);
    }

    fn update_member_from_id<T, +ValueTrait<T>>(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T) {
        set_serialized_member(
            self, 
            entity_id, 
            ModelAttributes::<M>::SELECTOR, 
            member_id, 
            Introspect::<M>::layout(), 
            ValueTrait::<T>::serialize(value)
        );
    }
}