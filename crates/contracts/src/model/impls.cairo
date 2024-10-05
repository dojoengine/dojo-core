use dojo::{
        model::{
        Model, 
        IModel,
        ModelIndex, 
        ModelAttributes, 
        Layout,
        introspect::{Introspect, Ty},
        layout::compute_packed_size,
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};



pub impl ModelImpl<
    T, 
    +Serde<T>, 
    +Drop<T>, 
    +ModelAttributes<T>, 
    +Introspect<T>, 
    +dojo::model::model::ModelKeyValueTrait<T>
> of Model<T> {
    fn get(world: IWorldDispatcher, keys: Span<felt252>) -> T {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(keys),
            Introspect::<T>::layout()
        );
        let mut _keys = keys;

        dojo::model::model::ModelKeyValueTrait::<T>::from_values(ref _keys, ref values)
    }

   fn set_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(Self::keys(self)),
            Self::values(self),
            Introspect::<T>::layout()
        );
    }

    fn delete_model(
        self: @T,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<T>::SELECTOR,
            ModelIndex::Keys(Self::keys(self)),
            Introspect::<T>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout(Introspect::<T>::layout(), member_id) {
            Option::Some(field_layout) => {
                let entity_id = dojo::utils::entity_id_from_keys(keys);
                IWorldDispatcherTrait::entity(
                    world,
                    ModelAttributes::<T>::SELECTOR,
                    ModelIndex::MemberId((entity_id, member_id)),
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    fn set_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        member_id: felt252,
        values: Span<felt252>
    ) {
        match dojo::utils::find_model_field_layout(Introspect::<T>::layout(), member_id) {
            Option::Some(field_layout) => {
                IWorldDispatcherTrait::set_entity(
                    world,
                    ModelAttributes::<T>::SELECTOR,
                    ModelIndex::MemberId((entity_id, member_id)),
                    values,
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
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
        core::poseidon::poseidon_hash_span(Self::keys(self))
    }

    #[inline(always)]
    fn keys(self: @T) -> Span<felt252> {
        dojo::model::model::ModelKeyValueTrait::<T>::keys(self)
    }

    #[inline(always)]
    fn values(self: @T) -> Span<felt252> {
        dojo::model::model::ModelKeyValueTrait::<T>::values(self)
    }

    #[inline(always)]
    fn layout() -> Layout {
        Introspect::<T>::layout()
    }

    #[inline(always)]
    fn instance_layout(self: @T) -> Layout {
        Introspect::<T>::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        compute_packed_size(Introspect::<T>::layout())
    }
}
