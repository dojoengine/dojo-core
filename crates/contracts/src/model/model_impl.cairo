use dojo::{
        model::{
        Model, 
        IModel,
        ModelIndex, 
        ModelAttributes, 
        Layout,
        introspect::{Introspect, Ty},
    },
    world::{IWorldDispatcher, IWorldDispatcherTrait},
};



pub impl ModelImpl<
    M, +Serde<M>, +Drop<M>, +ModelAttributes<M>, +Introspect<M>
> of Model<M> {
    fn get(world: dojo::world::, keys: Span<felt252>) -> M {
        let mut values = IWorldDispatcherTrait::entity(
            world,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(keys),
            Introspect::<M>::layout()
        );
        let mut _keys = keys;

        $type_name$Store::from_values(ref _keys, ref values)
    }

   fn set_model(
        self: @M,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::set_entity(
            world,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(ModelImpl::<T>::keys(self)),
            ModelImpl::<T>::values(self),
            Introspect::<M>::layout()
        );
    }

    fn delete_model(
        self: @M,
        world: IWorldDispatcher
    ) {
        IWorldDispatcherTrait::delete_entity(
            world,
            ModelAttributes::<M>::SELECTOR,
            ModelIndex::Keys(ModelImpl::<T>::keys(self)),
            Introspect::<M>::layout()
        );
    }

    fn get_member(
        world: IWorldDispatcher,
        keys: Span<felt252>,
        member_id: felt252
    ) -> Span<felt252> {
        match dojo::utils::find_model_field_layout(Introspect::<M>::layout(), member_id) {
            Option::Some(field_layout) => {
                let entity_id = dojo::utils::entity_id_from_keys(keys);
                IWorldDispatcherTrait::entity(
                    world,
                    ModelAttributes::<M>::SELECTOR,
                    ModelIndex::MemberId((entity_id, member_id)),
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    fn set_member(
        self: @M,
        world: IWorldDispatcher,
        member_id: felt252,
        values: Span<felt252>
    ) {
        match dojo::utils::find_model_field_layout(Introspect::<M>::layout(), member_id) {
            Option::Some(field_layout) => {
                IWorldDispatcherTrait::set_entity(
                    world,
                    ModelAttributes::<M>::SELECTOR,
                    ModelIndex::MemberId((self.entity_id(), member_id)),
                    values,
                    field_layout
                )
            },
            Option::None => core::panic_with_felt252('bad member id')
        }
    }

    #[inline(always)]
    fn name() -> ByteArray {
        ModelAttributes::<M>::name()
    }

    #[inline(always)]
    fn namespace() -> ByteArray {
        ModelAttributes::<M>::namespace()
    }

    #[inline(always)]
    fn tag() -> ByteArray {
        ModelAttributes::<M>::tag()
    }

    #[inline(always)]
    fn version() -> u8 {
        ModelAttributes::<M>::VERSION
    }

    #[inline(always)]
    fn selector() -> felt252 {
        ModelAttributes::<M>::SELECTOR
    }

    #[inline(always)]
    fn instance_selector() -> felt252 {
        ModelAttributes::<M>::SELECTOR
    }

    #[inline(always)]
    fn name_hash() -> felt252 {
        ModelAttributes::<M>::NAME_HASH
    }

    #[inline(always)]
    fn namespace_hash() -> felt252 {
        ModelAttributes::<M>::NAMESPACE_HASH
    }

    #[inline(always)]
    fn entity_id(self: @$type_name$) -> felt252 {
        core::poseidon::poseidon_hash_span(self.keys())
    }

    #[inline(always)]
    fn keys(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_keys$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn values(self: @$type_name$) -> Span<felt252> {
        let mut serialized = core::array::ArrayTrait::new();
        $serialized_values$
        core::array::ArrayTrait::span(@serialized)
    }

    #[inline(always)]
    fn layout() -> Layout {
        Introspect::<M>::layout()
    }

    #[inline(always)]
    fn instance_layout() -> Layout {
        Introspect::<M>::layout()
    }

    #[inline(always)]
    fn packed_size() -> Option<usize> {
        layout::compute_packed_size(Introspect::<M>::layout())
    }
}