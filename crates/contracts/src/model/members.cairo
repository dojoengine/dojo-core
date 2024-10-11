use dojo::{
    utils::{find_model_field_layout, serialize_inline, deserialize_unwrap}, meta::Layout,
    model::{ModelIndex, ModelDefinition}, world::{IWorldDispatcher, IWorldDispatcherTrait}
};
use core::panic_with_felt252;

pub trait MemberStore<M, T> {
    fn get_member(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252,) -> T;
    fn update_member(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T);
}


fn update_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    entity_id: felt252,
    values: Span<felt252>,
) {
    match find_model_field_layout(layout, member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::set_entity(
                world, model_id, ModelIndex::MemberId((entity_id, member_id)), values, field_layout,
            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}

fn get_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    entity_id: felt252,
) -> Span<felt252> {
    match find_model_field_layout(layout, member_id) {
        Option::Some(field_layout) => {
            IWorldDispatcherTrait::entity(
                world, model_id, ModelIndex::MemberId((entity_id, member_id)), field_layout
            )
        },
        Option::None => panic_with_felt252('bad member id')
    }
}


pub impl MemberStoreImpl<M, T, +ModelDefinition<M>, +Serde<T>, +Drop<T>> of MemberStore<M, T> {
    fn get_member(self: @IWorldDispatcher, member_id: felt252, entity_id: felt252) -> T {
        deserialize_unwrap::<
            T
        >(
            get_serialized_member(
                *self,
                ModelDefinition::<M>::selector(),
                member_id,
                ModelDefinition::<M>::layout(),
                entity_id
            )
        )
    }
    fn update_member(self: IWorldDispatcher, member_id: felt252, entity_id: felt252, value: T,) {
        update_serialized_member(
            self,
            ModelDefinition::<M>::selector(),
            member_id,
            ModelDefinition::<M>::layout(),
            entity_id,
            serialize_inline::<T>(@value)
        )
    }
}

