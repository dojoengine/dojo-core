use dojo::{
    utils::entity_id_from_keys,
    model::{
        Model, 
        ModelEntity,
        IModel,
        ModelIndex, 
        ModelAttributes, 
        Layout,
        model::{ModelKeyValueTrait, EntityIdValueTrait},
        introspect::{Introspect, Ty},
        layout::compute_packed_size,
        members::{set_serialized_member, get_serialized_member},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};



pub impl ModelImpl<
    T, 
    +Serde<T>, 
    +Drop<T>, 
    +ModelAttributes<T>, 
    +Introspect<T>, 
    +ModelKeyValueTrait<T>
> of Model<T> {
    fn get(world: IWorldDispatcher, keys: Span<felt252>) -> T {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(keys),
            ModelAttributes::<T>::layout()
        );
        ModelKeyValueTrait::<T>::from_serialized_values(keys, values)
    }

   fn set_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(Self::keys(self)),
            ModelKeyValueTrait::<T>::serialized_values(self),
            ModelAttributes::<T>::layout()
        );
    }

    fn delete_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(ModelKeyValueTrait::<T>::serialized_keys(self)),
            ModelAttributes::<T>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252
    ) -> Span<felt252> {
        get_serialized_member(
            world, 
            entity_id_from_keys(keys), 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout()
        )
    }

    fn set_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252,
        values: Span<felt252>
    ) {
        set_serialized_member(
            world, entity_id_from_keys(keys), 
            ModelAttributes::<T>::SELECTOR,  
            member_id, 
            ModelAttributes::<T>::layout(), 
            values
        )
    }

    #[inline(always)]
    fn name() -> ByteArray {
        ModelAttributes::<T>::name()
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        ModelAttributes::<T>::namespace()
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        ModelAttributes::<T>::tag()
    }

    #[inline(always)]
    fn version() -> u8 {
        ModelAttributes::<T>::VERSION
    }

    #[inline(always)]
    fn selector() -> felt252 {
        ModelAttributes::<T>::SELECTOR
    }

    #[inline(always)]
    fn instance_selector(self: @T) -> felt252 {
        ModelAttributes::<T>::SELECTOR
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        ModelAttributes::<T>::NAME_HASH
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        ModelAttributes::<T>::NAMESPACE_HASH
    }

    #[inline(always)]
    fn entity_id(self: @T) -> felt252 {
        ModelKeyValueTrait::<T>::entity_id(self)
    }

    #[inline(always)]
    fn keys(self: @T) -> Span<felt252> {
        ModelKeyValueTrait::<T>::serialized_keys(self)
    }

    #[inline(always)]
    fn values(self: @T) -> Span<felt252> {
        ModelKeyValueTrait::<T>::serialized_values(self)
    }

    #[inline(always)]
    fn layout() -> Layout {
        ModelAttributes::<T>::layout()
    }

    #[inline(always)]
    fn instance_layout(self: @T) -> Layout {
        ModelAttributes::<T>::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        compute_packed_size(ModelAttributes::<T>::layout())
    }
}


pub impl ModelEntityImpl<
    T, 
    +Serde<T>, 
    +Drop<T>, 
    +ModelAttributes<T>, 
    +EntityIdValueTrait<T>
> of ModelEntity<T> {
    fn id(self: @T) -> felt252 {
        EntityIdValueTrait::<T>::id(self)
    }

    fn values(self: @T) -> Span<felt252> {
        EntityIdValueTrait::<T>::serialized_values(self)
    }

    fn from_values(entity_id: felt252, values: Span<felt252>) -> T {
        EntityIdValueTrait::<T>::from_serialized_values(entity_id, values)
    }

    fn get(world: dojo::world::IWorldDispatcher, entity_id: felt252) -> T {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(entity_id),
            ModelAttributes::<T>::layout()
        );
        Self::from_values(entity_id, values)
    }

    fn update_entity(self: @T, world: dojo::world::IWorldDispatcher) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(Self::id(self)),
            Self::values(self),
            ModelAttributes::<T>::layout()
        );
    }

    fn delete_entity(self: @T, world: dojo::world::IWorldDispatcher) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Id(Self::id(self)),
            ModelAttributes::<T>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252
    ) -> Span<felt252> {
        get_serialized_member(
            world, 
            entity_id, 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout()
        )
    }

    fn set_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
        values: Span<felt252>
    ) {
        set_serialized_member(
            world, 
            entity_id, 
            ModelAttributes::<T>::SELECTOR, 
            member_id, 
            ModelAttributes::<T>::layout(), 
            values
        )
    }
}