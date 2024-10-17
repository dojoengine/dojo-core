use dojo::{
    utils::{find_model_field_layout, serialize_inline, deserialize_unwrap}, meta::Layout,
    model::{ModelIndex, ModelDefinition}, world::{IWorldDispatcher, IWorldDispatcherTrait}
};
use core::panic_with_felt252;

/// The `MemberStore` trait.
///
/// It provides a standardized way to interact with members of a model.
///
/// # Template Parameters
/// - `M`: The type of the model.
/// - `T`: The type of the member.
pub trait MemberStore<M, T> {
    /// Retrieves a member of type `T` from a model of type `M` using the provided member id and key
    /// of type `K`.
    fn get_member(self: @IWorldDispatcher, entity_id: felt252, member_id: felt252) -> T;
    /// Updates a member of type `T` within a model of type `M` using the provided member id, key of
    /// type `K`, and new value of type `T`.
    fn update_member(self: IWorldDispatcher, entity_id: felt252, member_id: felt252, value: T);
}

/// Updates a serialized member of a model.
fn update_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    layout: Layout,
    entity_id: felt252,
    member_id: felt252,
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

/// Retrieves a serialized member of a model.
fn get_serialized_member(
    world: IWorldDispatcher,
    model_id: felt252,
    layout: Layout,
    entity_id: felt252,
    member_id: felt252,
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
    fn get_member(self: @IWorldDispatcher, entity_id: felt252, member_id: felt252) -> T {
        deserialize_unwrap::<
            T
        >(
            get_serialized_member(
                *self,
                ModelDefinition::<M>::selector(),
                ModelDefinition::<M>::layout(),
                entity_id,
                member_id,
            )
        )
    }
    fn update_member(self: IWorldDispatcher, entity_id: felt252, member_id: felt252, value: T,) {
        update_serialized_member(
            self,
            ModelDefinition::<M>::selector(),
            ModelDefinition::<M>::layout(),
            entity_id,
            member_id,
            serialize_inline::<T>(@value)
        )
    }
}

