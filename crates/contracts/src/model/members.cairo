use dojo::{
    utils::find_model_field_layout,
    model::{Layout, ModelIndex},
    world::{IWorldDispatcher, IWorldDispatcherTrait}
};
use core::{
    array::ArrayTrait,
    option::OptionTrait,
    panic_with_felt252,
    serde::Serde,
};

pub fn set_serialized_member(
    world: IWorldDispatcher,
    entity_id: felt252,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    values: Span<felt252>,
) {
    match find_model_field_layout(layout, member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::set_entity(
                world,
                model_id,
                ModelIndex::MemberId((entity_id, member_id)),
                values,
                field_layout,

            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}

pub fn get_serialized_member(
    world: IWorldDispatcher,
    entity_id: felt252,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
) -> Span<felt252> {
    match find_model_field_layout(layout, 
         member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::entity(
                world,
                model_id,
                ModelIndex::MemberId((entity_id, member_id)),
                field_layout
            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}


#[generate_trait]
pub impl MemberSerdeImpl<T, +Serde<T>, +Drop<T>> of MemberSerdeTrait<T> {
    fn serialize_member(value: T) -> Span<felt252> {
        let mut serialized = ArrayTrait::new();
        Serde::<T>::serialize(@value, ref serialized);
        serialized.span()
    }

    fn deserialize_member(values: Span<felt252>) -> T {
        let mut values = values.into();
        let value = Serde::<T>::deserialize(ref values);
        match value {
            Option::Some(value) => value,
            Option::None => panic!("Member: deserialization failed.")
        }
    }

    fn get_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
    ) -> T {
        Self::deserialize_member(get_serialized_member(world, entity_id, model_id, member_id, layout))
    }
    fn set_member(
        world: IWorldDispatcher,
        entity_id: felt252,
        model_id: felt252,
        member_id: felt252,
        layout: Layout,
        value: T,
    ) {
        set_serialized_member(world, entity_id, model_id, member_id, layout, Self::serialize_member(value))
    }
}
