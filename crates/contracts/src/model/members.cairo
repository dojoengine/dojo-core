use dojo::model::Layout;

pub fn set_member(
    world: dojo::world::IWorldDispatcher,
    entity_id: felt252,
    model_id: felt252,
    member_id: felt252,
    layout: Layout,
    values: Span<felt252>,
) {
    match dojo::utils::find_model_field_layout(layout, 
         member_id) {
        Option::Some(field_layout) => {
            dojo::world::IWorldDispatcherTrait::set_entity(
                world,
                model_id,
                dojo::model::ModelIndex::MemberId((entity_id, member_id)),
                values,
                field_layout
            )
        },
        Option::None => core::panic_with_felt252('bad member id')
    }
}